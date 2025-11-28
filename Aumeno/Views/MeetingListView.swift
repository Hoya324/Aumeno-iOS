//
//  MeetingListView.swift
//  Aumeno
//
//  Created by Claude Code
//

import SwiftUI

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingViewModel()
    @State private var selectedMeeting: Meeting?
    @State private var floatingWindow: FloatingWindowController?
    @State private var showingOnboarding = false
    @State private var showingSlackConfig = false
    @State private var showingAddWorkspace = false
    @State private var showingMeetingEditor = false
    @State private var showingKeywordManager = false
    @State private var editingMeeting: Meeting?
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

                // Meeting List
                if viewModel.meetings.isEmpty {
                    emptyStateView
                } else {
                    meetingListView
                }

                // Status Bar
                statusBarView
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12)) // #1E1E1E
        .preferredColorScheme(.dark)
        .onChange(of: selectedMeeting) { _, newValue in
            if let meeting = newValue {
                openFloatingWindow(for: meeting)
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
        .sheet(isPresented: $showingMeetingEditor) {
            MeetingEditorView(meeting: nil) { meeting in
                viewModel.saveMeeting(meeting)
            }
        }
        .sheet(isPresented: $showingKeywordManager) {
            KeywordManagerView()
        }
        .sheet(item: $editingMeeting) { meeting in
            MeetingEditorView(meeting: meeting) { updatedMeeting in
                viewModel.saveMeeting(updatedMeeting)
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
        .onChange(of: viewModel.meetings) { _, _ in
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
                // New Meeting button (Ghost style)
                Button(action: { showingMeetingEditor = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))

                        Text("New Meeting")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(white: 0.93))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Keyword Manager button (Ghost style)
                Button(action: { showingKeywordManager = true }) {
                    Image(systemName: "tag")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.93))
                        .frame(width: 30, height: 30)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Tags")

                // Slack Config button (Ghost style)
                Button(action: { showingSlackConfig = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.93))
                        .frame(width: 30, height: 30)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Settings")

                // Sync button (Ghost style)
                Button(action: { viewModel.manualSync() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                            .animation(
                                viewModel.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                value: viewModel.isSyncing
                            )

                        Text("Sync")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(white: 0.93))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSyncing)
                .opacity(viewModel.isSyncing ? 0.5 : 1.0)
            }
        }
    }

    var filteredMeetings: [Meeting] {
        if let filter = selectedFilter {
            if filter == "manual" {
                return viewModel.meetings.filter { $0.isManual }
            } else {
                return viewModel.meetings.filter { $0.slackConfigID == filter }
            }
        }
        return viewModel.meetings
    }

    // MARK: - Meeting List

    private var meetingListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredMeetings) { meeting in
                    MeetingRowView(meeting: meeting)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMeeting = meeting
                        }
                        .contextMenu {
                            Button("Open Note") {
                                selectedMeeting = meeting
                            }

                            if meeting.isManual {
                                Button("Edit") {
                                    editingMeeting = meeting
                                }
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                viewModel.deleteMeeting(meeting)
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
                Text("No Messages Yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(white: 0.93))

                Text("Messages from Slack will appear here")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.67))
            }

            Button(action: { viewModel.manualSync() }) {
                Text("Sync Now")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.93))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar

    private var statusBarView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isSyncing ? Color.green : Color.gray.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isSyncing)

                    Text(viewModel.isSyncing ? "Syncing..." : "Connected")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.67))
                }

                Spacer()

                // Meeting count
                Text("\(viewModel.meetings.count) message\(viewModel.meetings.count != 1 ? "s" : "")")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.67))

                if let error = viewModel.errorMessage {
                    Divider()
                        .frame(height: 12)
                        .padding(.horizontal, 8)

                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(Color.orange.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(red: 0.09, green: 0.09, blue: 0.09)) // Slightly darker
        }
    }

    // MARK: - Floating Window

    private func openFloatingWindow(for meeting: Meeting) {
        // Close existing window
        floatingWindow?.close()

        // Create new floating window
        let noteView = NotePopupView(viewModel: viewModel, meeting: meeting)
        floatingWindow = FloatingWindowController(rootView: noteView)
        floatingWindow?.show()

        // Reset selection
        selectedMeeting = nil
    }

    private func loadAvailableFilters() {
        do {
            availableFilters = try ConfigurationManager.shared.fetchAllConfigurations()
        } catch {
            print("❌ Failed to load filters: \(error)")
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? Color(white: 0.93) : Color(white: 0.60))
            }
            .foregroundColor(isSelected ? Color(white: 0.93) : Color(white: 0.67))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meeting Row

struct MeetingRowView: View {
    let meeting: Meeting
    @State private var slackConfigName: String? = "Manual"
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(meeting.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.93))
                    .lineLimit(2)

                // Metadata row
                HStack(spacing: 12) {
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.67))

                        Text(meeting.formattedScheduledTime)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.67))
                    }

                    // Source badge
                    if let configName = slackConfigName {
                        Text(configName)
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.60))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(3)
                    }

                    // Location indicator
                    if let location = meeting.location, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.67))

                            Text(location)
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.67))
                                .lineLimit(1)
                        }
                    }

                    // Link indicator
                    if let _ = meeting.notionLink, !meeting.notionLink!.isEmpty {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.67))
                    }

                    // Note indicator
                    if meeting.hasNote {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.67))
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.gray.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.15)),
            alignment: .bottom
        )
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onAppear {
            loadSlackConfigName()
        }
    }

    private func loadSlackConfigName() {
        guard let configID = meeting.slackConfigID else { return }

        do {
            if let config = try ConfigurationManager.shared.fetchConfiguration(id: configID) {
                slackConfigName = config.channelName.isEmpty ? config.name : config.channelName
            }
        } catch {
            print("❌ Failed to load Slack config name: \(error)")
        }
    }

    private var statusColor: Color {
        if meeting.isPast {
            return Color.gray.opacity(0.3)
        } else if meeting.isOngoing() {
            return Color.green
        } else if meeting.isUpcoming(within: 30) {
            return Color.orange.opacity(0.8)
        } else {
            return Color.gray.opacity(0.5)
        }
    }
}

// MARK: - Preview

#Preview {
    MeetingListView()
        .frame(width: 700, height: 500)
}
