import SwiftUI
import AppKit

struct CalendarView: View {
    @EnvironmentObject private var viewModel: MeetingViewModel
    @State private var currentDate = Date()
    @State private var selectedDate: Date = Date()
    @State private var days: [Day] = []
    @State private var selectedWorkspace: String? = nil
    @State private var availableWorkspaces: [SlackConfiguration] = []

    private let calendarHelper = CalendarHelper()
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    @State private var selectedChannelID: String? = nil
    @State private var selectedScheduleType: ScheduleType? = nil // New state for type filter
    
    private var availableChannels: [(id: String, name: String)] {
        guard let workspaceID = selectedWorkspace else { return [] }
        let schedulesForWorkspace = viewModel.schedules.filter { $0.workspaceID == workspaceID }
        
        let channelTuples = schedulesForWorkspace.compactMap { schedule -> (String, String)? in
            guard let id = schedule.channelID, let name = schedule.channelName else { return nil }
            return (id, name)
        }
        
        let unique = Set(channelTuples.map { "\($0.0)||\($0.1)" })
        
        return unique.compactMap { combined -> (String, String)? in
            let parts = combined.components(separatedBy: "||")
            guard parts.count == 2 else { return nil }
            return (parts[0], parts[1])
        }
        .sorted(by: { $0.1 < $1.1 })
    }
    
    private var filteredSchedules: [Schedule] {
        var schedulesToDisplay = viewModel.schedules

        if let selectedWorkspace = selectedWorkspace {
            // If a specific workspace is selected, show schedules from that workspace
            // AND manually created schedules (which don't have a workspaceID)
            schedulesToDisplay = schedulesToDisplay.filter { schedule in
                // Include manual schedules OR schedules matching the selected workspace
                return schedule.source == .manual || (schedule.workspaceID == selectedWorkspace)
            }
            if let selectedChannelID = selectedChannelID {
                // If a specific channel is selected within a workspace,
                // further filter for that channel, but still include manual schedules.
                schedulesToDisplay = schedulesToDisplay.filter { schedule in
                    // Include manual schedules OR schedules matching both selected workspace AND channel
                    return schedule.source == .manual || (schedule.channelID == selectedChannelID && schedule.workspaceID == selectedWorkspace)
                }
            }
        }
        // If selectedWorkspace is nil ("All Workspaces"), all schedules are already included in schedulesToDisplay.

        // Apply ScheduleType filter if selected
        if let selectedType = selectedScheduleType {
            schedulesToDisplay = schedulesToDisplay.filter { $0.type == selectedType }
        }

        return schedulesToDisplay
    }

    @State private var editingSchedule: Schedule?
    @State private var showingScheduleEditor = false
    @State private var showingOnboarding = false
    @State private var showingSlackConfig = false
    @State private var showingKeywordManager = false
    @State private var showingAddChannel = false

    @State private var topSentinelId = UUID()
    @State private var bottomSentinelId = UUID()

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceSidebarView(
                workspaces: availableWorkspaces,
                selectedWorkspace: selectedWorkspace,
                onSelect: { workspaceId in
                    selectedWorkspace = workspaceId
                    selectedChannelID = nil
                },
                onAddWorkspace: {
                    showingSlackConfig = true
                }
            )

            Divider()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal)
                    .padding(.top)

                Group {
                    if selectedWorkspace != nil {
                        channelFilterView
                            .padding(.horizontal)
                    } else {
                        EmptyView()
                    }
                }
                
                typeFilterView // New type filter
                    .padding(.horizontal)
                
                daysOfWeekView
                    .padding(.horizontal)

                GeometryReader { outerGeometry in
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) { // ScrollView content starts here
                            LazyVGrid(columns: columns, spacing: 10) {
                                // Top sentinel to load previous months
                                Color.clear
                                    .frame(height: 1)
                                    .id(topSentinelId)
                                    .onAppear {
                                        loadMoreContent(direction: .up)
                                    }

                                ForEach(days) { day in
                                    GeometryReader { geometry in
                                        dayCell(for: day)
                                            .id(day.id)
                                            .opacity(getOpacity(geometry: geometry, scrollViewHeight: outerGeometry.size.height, day: day))
                                            .onAppear { // Use onAppear to detect when a day enters the visible area
                                                // This is a simplified way to detect visible month
                                                // For more accurate tracking, consider using a preference key
                                                if abs(geometry.frame(in: .named("scrollView")).midY - outerGeometry.size.height / 2) < 100 { // within a certain threshold
                                                    let calendar = Calendar.current
                                                    let components = calendar.dateComponents([.year, .month], from: day.date)
                                                    if let newCurrentDate = calendar.date(from: components),
                                                       !calendar.isDate(newCurrentDate, equalTo: currentDate, toGranularity: .month) {
                                                        currentDate = newCurrentDate
                                                    }
                                                }
                                            }
                                    }
                                    .frame(height: 60) // Must give GeometryReader a frame, matching dayCell's height
                                }

                                // Bottom sentinel to load next months
                                Color.clear
                                    .frame(height: 1)
                                    .id(bottomSentinelId)
                                    .onAppear {
                                        loadMoreContent(direction: .down)
                                    }
                            } // End of LazyVGrid
                            .padding(.horizontal)
                            .padding(.bottom)
                            .onAppear {
                                // Scroll to the current month on appear
                                if let targetDay = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: currentDate) }) {
                                    proxy.scrollTo(targetDay.id, anchor: .center)
                                }
                            }
                        } // End of ScrollView content
                        .coordinateSpace(name: "scrollView") // Apply coordinateSpace to the ScrollView itself
                    } // End of ScrollViewReader
                } // End of outerGeometry
            }

            Divider()

            TimelineView(
                selectedDate: selectedDate,
                schedules: filteredSchedules,
                onAdd: {
                    editingSchedule = nil
                    showingScheduleEditor = true
                },
                onEdit: { schedule in
                    editingSchedule = schedule
                    showingScheduleEditor = true
                },
                onDelete: { schedule in
                    viewModel.deleteSchedule(schedule)
                }
            )
        }
        .onAppear {
            setup()
        }
        .onChange(of: currentDate) { _, _ in
            updateDays()
        }
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorView(schedule: editingSchedule, defaultStartDate: selectedDate, defaultEndDate: nil) { schedule in
                viewModel.saveSchedule(schedule)
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                viewModel.manualSync()
                loadWorkspaces()
            }
        }
        .sheet(isPresented: $showingKeywordManager) {
            KeywordManagerView()
        }
        .sheet(isPresented: $showingSlackConfig) {
            SlackConfigurationView()
                .onDisappear(perform: loadWorkspaces)
        }
        .sheet(isPresented: $showingAddChannel) {
            SlackConfigurationView(preselectedWorkspaceID: selectedWorkspace)
                .onDisappear(perform: loadWorkspaces)
        }
    }

    



    @State private var visibleDateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let startOfPreviousMonth = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth)!
        let endOfNextMonth = calendar.date(byAdding: .month, value: 2, to: startOfCurrentMonth)!
        return startOfPreviousMonth...endOfNextMonth
    }()
    @State private var isLoadingMore = false

    private func loadMoreContent(direction: ScrollDirection) {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        
        let calendar = Calendar.current
        let monthsToLoad = 3 // Load 3 months at a time
        
        if direction == .up {
            if let newStartDate = calendar.date(byAdding: .month, value: -monthsToLoad, to: visibleDateRange.lowerBound) {
                visibleDateRange = newStartDate...visibleDateRange.upperBound
            }
        } else { // direction == .down
            if let newEndDate = calendar.date(byAdding: .month, value: monthsToLoad, to: visibleDateRange.upperBound) {
                visibleDateRange = visibleDateRange.lowerBound...newEndDate
            }
        }
        
        // This is important: updateDays() is called here after visibleDateRange changes
        // so the days array reflects the new range.
        updateDays() 
        isLoadingMore = false
    }

    enum ScrollDirection {
        case up, down
    }

    private func setup() {
        updateDays()

        loadWorkspaces()
        viewModel.checkFirstLaunch { needsOnboarding in
            if needsOnboarding { showingOnboarding = true }
        }
    }

    private func loadWorkspaces() {
        do {
            availableWorkspaces = try DatabaseManager.shared.fetchAllConfigurations()
            if let first = availableWorkspaces.first, selectedWorkspace == nil {
                selectedWorkspace = first.id
            }
        } catch {
            print("❌ [CalendarView] Error loading workspaces: \(error)")
            availableWorkspaces = []
            selectedWorkspace = nil
        }
    }

    private func updateDays() {
        days.removeAll()
        let calendar = Calendar.current
        
        var date = visibleDateRange.lowerBound
        while date <= visibleDateRange.upperBound {
            days.append(contentsOf: calendarHelper.daysInMonth(for: date))
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { break }
            date = nextMonth
        }
        
        // Ensure currentDate (for header) is within the visible range if possible,
        // or at least close to the center.
        if !visibleDateRange.contains(currentDate) {
            currentDate = Date() // Reset to today if it's out of range.
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { currentDate = calendarHelper.minusMonth(date: currentDate) }) {
                Image(systemName: "chevron.left")
            }.buttonStyle(.plain)

            Text(calendarHelper.monthYearString(from: currentDate))
                .font(.title2).fontWeight(.bold)

            Button(action: { currentDate = calendarHelper.plusMonth(date: currentDate) }) {
                Image(systemName: "chevron.right")
            }.buttonStyle(.plain)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { showingAddChannel = true }) {
                    Image(systemName: "plus.message.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Add Channel")

                Button(action: { showingSlackConfig = true }) {
                    Image(systemName: "gearshape").font(.system(size: 14))
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.manualSync() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync")
                    }
                }
                .buttonStyle(DarkPrimaryButtonStyle())
                .disabled(viewModel.isSyncing)
            }
        }
        .padding(.vertical, 10)
    }

    private var daysOfWeekView: some View {
        HStack {
            // Get short weekday symbols and adjust order based on firstWeekday
            let calendar = Calendar.current
            let weekdaySymbols = calendar.shortWeekdaySymbols
            let firstWeekdayIndex = calendar.firstWeekday - 1 // Calendar.firstWeekday is 1-based

            let orderedWeekdaySymbols = Array(weekdaySymbols[firstWeekdayIndex..<weekdaySymbols.count] + weekdaySymbols[0..<firstWeekdayIndex])

            ForEach(orderedWeekdaySymbols, id: \.self) { day in
                Text(day.uppercased()) // Ensure uppercase for consistency with original
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    private var channelFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All Channels",
                    count: viewModel.schedules.filter { $0.workspaceID == selectedWorkspace }.count,
                    isSelected: selectedChannelID == nil
                ) {
                    selectedChannelID = nil
                }

                ForEach(availableChannels, id: \.id) { channel in
                    FilterChip(
                        title: "#\(channel.name)",
                        count: viewModel.schedules.filter { $0.channelID == channel.id }.count,
                        isSelected: selectedChannelID == channel.id
                    ) {
                        selectedChannelID = channel.id
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var typeFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All Types",
                    count: viewModel.schedules.count, // Total schedules count, before any type filtering
                    isSelected: selectedScheduleType == nil
                ) {
                    selectedScheduleType = nil
                }

                ForEach(ScheduleType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.typeDisplayName, // Assuming ScheduleType has typeDisplayName
                        count: viewModel.schedules.filter { $0.type == type }.count,
                        isSelected: selectedScheduleType == type
                    ) {
                        selectedScheduleType = type
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }



    private func dayCell(for day: Day) -> some View {
        let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)

        let schedulesForDay: [Schedule] = {
            let startOfDay = Calendar.current.startOfDay(for: day.date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            return filteredSchedules.filter { schedule in
                let scheduleEnd = schedule.endDateTime ?? schedule.startDateTime
                let filterResult = (schedule.startDateTime < endOfDay) && (scheduleEnd >= startOfDay)
                
                return filterResult
            }
        }()

        return Button(action: { selectedDate = day.date }) {
            VStack(spacing: 4) {
                Text(day.dayOfMonth)
                    .fontWeight(day.isToday ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : (day.isToday ? .white : (day.isFromCurrentMonth ? .primary : .secondary)))
                    .frame(maxWidth: .infinity)
                    .padding(4)
                    .background(day.isToday ? Color.blue.opacity(0.8) : .clear)
                    .clipShape(Circle())

                HStack(spacing: 3) {
                    ForEach(Array(schedulesForDay.prefix(4)), id: \.id) { schedule in
                        Circle()
                            .fill(color(for: schedule))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)

                Spacer()
            }
            .frame(height: 60)
            .background(isSelected ? Color.accentColor.opacity(0.5) : .clear)
            .cornerRadius(8)

        }
        .buttonStyle(.plain)
    }

    private func color(for schedule: Schedule) -> Color {
        if let tagID = schedule.tagID,
           let tag = viewModel.tag(for: tagID),
           let colorFromTag = Color(hex: tag.color) {
            return colorFromTag
        }
        if let ws = schedule.workspaceColor, let ns = NSColor(hex: ws) { return Color(ns) }
        return .gray
    }

    private func getOpacity(geometry: GeometryProxy, scrollViewHeight: CGFloat, day: Day) -> Double {
        let midY = geometry.frame(in: .named("scrollView")).midY
        let distance = abs(midY - (scrollViewHeight / 2))
        
        let normalizedDistance = min(1, distance / (scrollViewHeight / 2))
        var baseOpacity = 1.0 - (normalizedDistance * 0.7) // Fades from 1.0 to 0.3

        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(day.date, equalTo: currentDate, toGranularity: .month)

        // If the day is not from the current month being displayed in the header, make it more transparent
        if !isCurrentMonth {
            baseOpacity *= 0.4 // Reduce opacity for days not in the current header month
        }
        
        return baseOpacity
    }
}

#Preview {
    CalendarView()
        .environmentObject(MeetingViewModel())
        .preferredColorScheme(.dark)
        .frame(width: 1000, height: 600)
}
