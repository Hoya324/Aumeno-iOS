//
//  MeetingListView.swift
//  Aumeno
//
//  Created by Hoya324
//

import SwiftUI

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingViewModel()
    @State private var selectedSchedule: Schedule?
    @State private var floatingWindow: FloatingWindowController?
    @State private var showingOnboarding = false
    @State private var showingSlackConfig = false
    @State private var showingAddWorkspace = false
    @State private var showingScheduleEditor = false
    @State private var showingKeywordManager = false
    @State private var editingSchedule: Schedule?
    @State private var selectedFilter: String? = nil  // nil = All
    @State private var availableFilters: [SlackConfiguration] = []

    var body: some View {
        HStack(spacing: 0) {
            // Workspace Sidebar
            WorkspaceSidebarView(
                workspaces: availableFilters,
                selectedWorkspace: selectedFilter,
                onSelect: { workspaceID in
                    selectedFilter = workspaceID
                },
                onAddWorkspace: {
                    showingSlackConfig = true
                }
            )

            Divider()
                .background(Color.gray.opacity(0.3))

            // Main Content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Schedule List
                if viewModel.schedules.isEmpty {
                    emptyStateView
                } else {
                    scheduleListView
                }

                // Status Bar
                statusBarView
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12)) // #1E1E1E
        .preferredColorScheme(.dark)
        .onChange(of: selectedSchedule) { _, newValue in
            if let schedule = newValue {
                openFloatingWindow(for: schedule)
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                viewModel.manualSync()
            }
        }
        .sheet(isPresented: $showingSlackConfig) {
            SlackConfigurationView()
        }
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorView(schedule: nil) { schedule in
                viewModel.saveSchedule(schedule)
            }
        }
        .sheet(isPresented: $showingKeywordManager) {
            KeywordManagerView()
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditorView(schedule: schedule) { updatedSchedule in
                viewModel.saveSchedule(updatedSchedule)
            }
        }
        .onAppear {
            viewModel.checkFirstLaunch { needsOnboarding in
                if needsOnboarding {
                    showingOnboarding = true
                }
            }
            loadAvailableFilters()
        }
        .onChange(of: viewModel.schedules) { _, _ in
            loadAvailableFilters()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aumeno")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(Color(white: 0.93)) // #EEEEEE

                Text("Slack Note Manager")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(white: 0.67)) // #AAAAAA
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: { showingScheduleEditor = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New Schedule")
                    }
                }
                .buttonStyle(DarkSecondaryButtonStyle())

                Button(action: { showingKeywordManager = true }) {
                    Image(systemName: "tag")
                }
                .buttonStyle(DarkSecondaryButtonStyle())
                .help("Tags")

                Button(action: { showingSlackConfig = true }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(DarkSecondaryButtonStyle())
                .help("Settings")

                Button(action: { viewModel.manualSync() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                            .animation(
                                viewModel.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                value: viewModel.isSyncing
                            )
                        Text("Sync")
                    }
                }
                .buttonStyle(DarkPrimaryButtonStyle())
                .disabled(viewModel.isSyncing)
            }
        }
    }

    var filteredSchedules: [Schedule] {
        if let filter = selectedFilter {
            if filter == "manual" {
                return viewModel.schedules.filter { $0.isManual }
            } else {
                return viewModel.schedules.filter { $0.workspaceID == filter }
            }
        }
        return viewModel.schedules
    }

    // MARK: - Schedule List

    private var scheduleListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredSchedules) { schedule in
                    ScheduleRowView(schedule: schedule)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSchedule = schedule
                        }
                        .contextMenu {
                            Button("Open Note") {
                                selectedSchedule = schedule
                            }

                            if schedule.isManual {
                                Button("Edit") {
                                    editingSchedule = schedule
                                }
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                viewModel.deleteSchedule(schedule)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Color.gray.opacity(0.4))

            VStack(spacing: 6) {
                Text("No Schedules Yet")
                    .font(.system(size: 17, weight: .semibold))
                Text("Schedules from Slack will appear here")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Button(action: { viewModel.manualSync() }) {
                Text("Sync Now")
            }
            .buttonStyle(DarkPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar

    private var statusBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isSyncing ? Color.green : Color.gray.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isSyncing)
                    Text(viewModel.isSyncing ? "Syncing..." : "Connected")
                }
                Spacer()
                Text("\(viewModel.schedules.count) schedule\(viewModel.schedules.count != 1 ? "s" : "")")
                if let error = viewModel.errorMessage {
                    Divider().frame(height: 12).padding(.horizontal, 8)
                    Text(error).lineLimit(1)
                }
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
        }
    }

    // MARK: - Floating Window

    private func openFloatingWindow(for schedule: Schedule) {
        floatingWindow?.close()
        let noteView = NotePopupView(viewModel: viewModel, schedule: schedule)
        floatingWindow = FloatingWindowController(rootView: noteView)
        floatingWindow?.show()
        selectedSchedule = nil
    }

    private func loadAvailableFilters() {
        do {
            availableFilters = try DatabaseManager.shared.fetchAllConfigurations()
        } catch {
            print("❌ Failed to load filters: \(error)")
        }
    }
}

// MARK: - Schedule Row

struct ScheduleRowView: View {
    let schedule: Schedule
    @State private var slackConfigName: String? = "Manual"
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text(schedule.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.93))
                    .lineLimit(2)
                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                        Text(schedule.formattedStartDateTime)
                                        if let formattedEndDateTime = schedule.formattedEndDateTime {
                                            Text(" - ")
                                            Text(formattedEndDateTime)
                                        }
                                    }                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    
                    if let configName = slackConfigName {
                        Text(configName)
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.60))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(3)
                    }

                    if let location = schedule.location, !location.isEmpty {
                        HStack(spacing: 2) { Image(systemName: "location"); Text(location) }
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    }
                    if let links = schedule.links, !links.isEmpty { Image(systemName: "link") }
                    if schedule.hasNote { Image(systemName: "note.text") }
                }
                .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.15)), alignment: .bottom)
        .onHover { hovering in isHovering = hovering }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onAppear(perform: loadSlackConfigName)
    }

    private func loadSlackConfigName() {
        guard let configID = schedule.workspaceID else { return }
        do {
            if let config = try DatabaseManager.shared.fetchConfiguration(id: configID) {
                slackConfigName = config.channelName.isEmpty ? config.name : config.channelName
            }
        } catch {
            print("❌ Failed to load Slack config name: \(error)")
        }
    }

    private var statusColor: Color {
        if schedule.isPast { return .gray }
        if schedule.isOngoing() { return .green }
        if schedule.isUpcoming(within: 30) { return .orange }
        return .gray.opacity(0.5)
    }
}

#Preview {
    MeetingListView()
        .frame(width: 700, height: 500)
}
