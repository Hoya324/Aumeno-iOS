//
//  SlackConfigurationView.swift
//  Aumeno
//
//  Created by Hoya324
//

import SwiftUI
import AppKit

// MARK: - Main View
struct SlackConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configurations: [SlackConfiguration] = []
    @State private var showingEditorSheet = false // Use a more generic name for clarity
    @State private var editingType: ConfigurationEditorView.EditingType? // Use the new EditingType
    @State private var errorMessage: String?
    @State private var showingError = false
    @AppStorage(Constants.notificationEnabledKey) private var notificationsEnabled: Bool = true

    
    // New property to receive preselected workspace ID
    let preselectedWorkspaceID: String?

    // Initializer to handle the new property
    init(preselectedWorkspaceID: String? = nil) {
        self.preselectedWorkspaceID = preselectedWorkspaceID
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider().background(Color.gray.opacity(0.3))

            if !configurations.isEmpty {
                HStack {
                    Image(systemName: "info.circle").font(.system(size: 10)).foregroundColor(Color(white: 0.67))
                    Text("\(configurations.count) configuration(s) loaded").font(.system(size: 10)).foregroundColor(Color(white: 0.67))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color(red: 0.09, green: 0.09, blue: 0.09))
            }

            if configurations.isEmpty {
                emptyStateView
            } else {
                configurationListView
            }
        }
        .frame(width: 700, height: 500)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
        .onAppear {
            loadConfigurations()
            // If a preselected workspace is provided, find it and show the editor for adding a channel
            if let wsID = preselectedWorkspaceID {
                // We need to find the corresponding WorkspaceGroup
                // This will happen after configurations are loaded
                DispatchQueue.main.async { // Ensure configurations are loaded
                    if let workspaceGroup = groupedConfigurations.first(where: { $0.id == wsID }) {
                        editingType = .newChannelInExistingWorkspace(workspaceGroup: workspaceGroup)
                        showingEditorSheet = true
                    } else {
                        // Handle error or show a message if preselected workspace not found
                        errorMessage = "Preselected workspace not found."
                        showingError = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditorSheet) {
            ConfigurationEditorView(
                editingType: editingType ?? .newConfig, // Default to .newConfig if nil
                onSave: { type, config in // Updated signature
                    saveConfiguration(type: type, config: config)
                }
            )
            .onDisappear {
                // If we were in "add channel" mode from CalendarView, dismiss the whole SlackConfigurationView
                if preselectedWorkspaceID != nil {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

// MARK: - Helper Structs
    struct WorkspaceGroup: Identifiable, Equatable { // Add Equatable conformance
        // Use a UUID derived from uniqueWorkspaceKey for a stable and unique ID for the group
        let id: String 
        let name: String
        let token: String
        let userID: String?
        let teamID: String?
        let color: String
        var channels: [SlackConfiguration] // List of channels belonging to this workspace

        // Implement custom Equatable conformance due to the channels array
        static func == (lhs: SlackConfigurationView.WorkspaceGroup, rhs: SlackConfigurationView.WorkspaceGroup) -> Bool {
            lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.token == rhs.token &&
            lhs.userID == rhs.userID &&
            lhs.teamID == rhs.teamID && // Add teamID to Equatable
            lhs.color == rhs.color &&
            lhs.channels == rhs.channels // SlackConfiguration is Equatable
        }

        // Initialize from a representative SlackConfiguration
        init(from config: SlackConfiguration) {
            self.name = config.name
            self.token = config.token
            self.userID = config.userID
            self.teamID = config.teamID
            self.color = config.color
            self.channels = [] // Will be populated later
            self.id = "\(config.name)-\(config.token)-\(config.userID ?? "")-\(config.teamID ?? "")-\(config.color)".sha256() // Use SHA256 for stable ID
        }

        // To identify unique workspaces, we'll use a combination of name, token, and userID, and color
        var uniqueWorkspaceKey: String {
            return "\(name)-\(token)-\(userID ?? "")-\(teamID ?? "")-\(color)"
        }
    }

    private var groupedConfigurations: [WorkspaceGroup] {
        let groupedDictionary = Dictionary(grouping: configurations) { config in
            // Group by a unique identifier for the workspace: name, token, userID, color
            "\(config.name)-\(config.token)-\(config.userID ?? "")-\(config.color)"
        }

        var workspaceGroups: [WorkspaceGroup] = []
        for (_, configs) in groupedDictionary {
            guard let firstConfig = configs.first else { continue }
            var workspaceGroup = WorkspaceGroup(from: firstConfig) // Use the defined initializer
            // Sort channels by channelName for consistent display
            workspaceGroup.channels = configs.sorted { $0.channelName < $1.channelName }
            workspaceGroups.append(workspaceGroup)
        }
        // Sort workspace groups by name
        return workspaceGroups.sorted { $0.name < $1.name }
    }

    private var headerView: some View {        HStack {
            Text("Slack Integrations").font(.system(size: 22, weight: .bold, design: .default)).foregroundColor(Color(white: 0.93))
            Spacer()
            HStack(spacing: 10) {
                Toggle(isOn: $notificationsEnabled) {
                    Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(notificationsEnabled ? Color(white: 0.93) : Color.gray.opacity(0.6))
                }
                .toggleStyle(.button)
                .help(notificationsEnabled ? "Disable Notifications" : "Enable Notifications")
                
                Button(action: { loadConfigurations() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .medium)).foregroundColor(Color(white: 0.93))
                        .frame(width: 30, height: 30).background(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain).help("Refresh")
                
                Button(action: { showingEditorSheet = true; editingType = .newConfig }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                        Text("Add").font(.system(size: 12, weight: .medium))
                    }.foregroundColor(Color(white: 0.93)).padding(.horizontal, 14).padding(.vertical, 7).background(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain)
            }
            Button(action: { dismiss() }) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .medium)).foregroundColor(Color(white: 0.67))
                    .frame(width: 28, height: 28).background(Color.clear)
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }.buttonStyle(.plain)
        }.padding(.horizontal, 24).padding(.vertical, 20)
    }

    private var configurationListView: some View {
        List { // Use List for better hierarchical display capabilities
            ForEach(groupedConfigurations) { workspaceGroup in
                Section(header: WorkspaceHeaderView(workspaceGroup: workspaceGroup, onEdit: { // Edit workspace
                    editingType = .existingWorkspace(workspaceGroup: workspaceGroup) // Set editingType for workspace
                    showingEditorSheet = true
                })) {
                    ForEach(workspaceGroup.channels) { config in
                        ConfigurationRow(config: config)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button("Edit Channel") { editingType = .existingConfig(config); showingEditorSheet = true }
                                Button(config.isEnabled ? "Disable Channel" : "Enable Channel") { toggleConfiguration(config) }
                                Divider()
                                Button("Delete Channel", role: .destructive) { deleteConfiguration(config) }
                            }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle").font(.system(size: 48, weight: .thin)).foregroundColor(Color.gray.opacity(0.4))
            VStack(spacing: 6) {
                Text("No Slack Integrations").font(.system(size: 17, weight: .semibold)).foregroundColor(Color(white: 0.93))
                Text("Add a Slack workspace to get started").font(.system(size: 14)).foregroundColor(Color(white: 0.67))
            }
            Button(action: { showingEditorSheet = true; editingType = .newConfig }) {
                Text("Add First Slack").font(.system(size: 13, weight: .medium)).foregroundColor(Color(white: 0.93))
                    .padding(.horizontal, 20).padding(.vertical, 8).background(Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }.buttonStyle(.plain).padding(.top, 8)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadConfigurations() {
        do {
            try DatabaseManager.shared.cleanupCorruptedConfigurations()
            configurations = try DatabaseManager.shared.fetchAllConfigurations()
        } catch { errorMessage = "Failed to load configurations: \(error.localizedDescription)"; showingError = true }
    }
    
    private func saveConfiguration(type: ConfigurationEditorView.EditingType, config: SlackConfiguration) {
        do {
            switch type {
            case .newConfig, .existingConfig, .newChannelInExistingWorkspace:
                // These all result in saving a single SlackConfiguration
                try DatabaseManager.shared.insertConfiguration(config)
            case .existingWorkspace(let workspaceGroup):
                // When editing a workspace, we need to update all configs belonging to that workspace
                let oldUniqueKey = workspaceGroup.uniqueWorkspaceKey

                // Get all configurations that match the OLD unique key
                let configsToUpdate = configurations.filter {
                    "\($0.name)-\($0.token)-\($0.userID ?? "")-\($0.color)" == oldUniqueKey
                }
                
                // Update each matching configuration with the new workspace details
                for var oldConfig in configsToUpdate {
                    oldConfig.name = config.name
                    oldConfig.token = config.token
                    oldConfig.userID = config.userID
                    oldConfig.teamID = config.teamID
                    oldConfig.color = config.color
                    try DatabaseManager.shared.insertConfiguration(oldConfig)
                }
            }
            loadConfigurations() // Reload all configurations after saving
        } catch { errorMessage = "Failed to save configuration: \(error.localizedDescription)"; showingError = true }
    }

    private func toggleConfiguration(_ config: SlackConfiguration) {
        var updatedConfig = config
        updatedConfig.isEnabled.toggle()
        saveConfiguration(type: .existingConfig(config), config: updatedConfig) // Pass existingConfig type
    }

    private func deleteConfiguration(_ config: SlackConfiguration) {
        do {
            try DatabaseManager.shared.deleteConfiguration(id: config.id)
            loadConfigurations()
        } catch { errorMessage = "Failed to delete configuration: \(error.localizedDescription)"; showingError = true }
    }
}

// MARK: - Workspace Header View
struct WorkspaceHeaderView: View {
    let workspaceGroup: SlackConfigurationView.WorkspaceGroup // Access the nested struct
    let onEdit: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            // Workspace color indicator
            Circle()
                .fill(Color(hex: workspaceGroup.color) ?? .gray)
                .frame(width: 8, height: 8)

            Text(workspaceGroup.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.9))
            
            Text("(\(workspaceGroup.token.prefix(5))...)") // Show partial token
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(white: 0.6))

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? Color(white: 0.8) : Color(white: 0.6))
            }
            .buttonStyle(.plain)
            .help("Edit Workspace Details")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(6)
        .onHover { hovering in isHovering = hovering }
    }
}

// MARK: - Configuration Row (No changes needed here)
struct ConfigurationRow: View {
    let config: SlackConfiguration
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            Circle().fill(config.isEnabled ? Color.green : Color.gray.opacity(0.3)).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text("#\(config.channelName)").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(white: 0.93)) // Main title: Channel Name
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text(config.name).font(.system(size: 11)).foregroundColor(Color(white: 0.67)) // Subtitle: Workspace Name
                        Image(systemName: "number").font(.system(size: 10)).foregroundColor(Color(white: 0.67))
                        Text(config.channelID).font(.system(size: 11)).foregroundColor(Color(white: 0.67))
                    }
                    if !config.keywords.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag").font(.system(size: 10)).foregroundColor(Color(white: 0.67))
                            Text("\(config.keywords.count) keywords").font(.system(size: 11)).foregroundColor(Color(white: 0.67))
                        }
                    } else {
                        Text("All messages").font(.system(size: 11)).foregroundColor(Color.gray.opacity(0.5)).italic()
                    }
                }
            }
            Spacer()
            Text(config.isEnabled ? "Active" : "Disabled").font(.system(size: 10, weight: .medium)).foregroundColor(config.isEnabled ? Color.green : Color.gray)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill((config.isEnabled ? Color.green : Color.gray).opacity(0.15)))
        }.padding(.horizontal, 24).padding(.vertical, 14)
        .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.15)), alignment: .bottom)
        .onHover { hovering in isHovering = hovering }.animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Configuration Editor (Modified)
struct ConfigurationEditorView: View {
    @Environment(\.dismiss) private var dismiss

    enum EditingType: Equatable { // Add Equatable conformance
        case newConfig // Adding a brand new configuration (workspace + channel)
        case existingConfig(SlackConfiguration) // Editing an existing SlackConfiguration (channel)
        case newChannelInExistingWorkspace(workspaceGroup: SlackConfigurationView.WorkspaceGroup) // Adding a new channel to an existing workspace
        case existingWorkspace(workspaceGroup: SlackConfigurationView.WorkspaceGroup) // Editing an entire workspace
    }
    let editingType: EditingType
    // Pass back the editingType along with the new/updated config
    let onSave: (EditingType, SlackConfiguration) -> Void

    @State private var workspaceName: String
    @State private var channelName: String
    @State private var token: String
    @State private var channelID: String
    @State private var userID: String
    @State private var teamID: String
    @State private var color: Color
    @State private var selectedKeywords: Set<String>
    @State private var customKeyword = ""
    
    @State private var initialConfig: SlackConfiguration? // Store original config if editing existing
    
    @State private var isLoadingWorkspace = false // No longer needs to load original config from DB directly
    @State private var loadingError: String?

    private let isWorkspaceEditing: Bool
    private let isNewChannel: Bool
    private let isExistingConfig: Bool

    init(editingType: EditingType, onSave: @escaping (EditingType, SlackConfiguration) -> Void) {
        self.editingType = editingType
        self.onSave = onSave
        
        self.isWorkspaceEditing = {
            if case .existingWorkspace = editingType { return true }
            return false
        }()
        self.isNewChannel = {
            if case .newChannelInExistingWorkspace = editingType { return true }
            return false
        }()
        self.isExistingConfig = {
            if case .existingConfig = editingType { return true }
            return false
        }()
        
        var initialWorkspaceName: String?
        var initialChannelName: String?
        var initialToken: String?
        var initialChannelID: String?
        var initialUserID: String? // Make it optional here
        var initialTeamID: String? // Make it optional here
        var initialColor = Color.gray
        var initialKeywords: Set<String> = []

        switch editingType {
        case .newConfig:
            // All defaults
            break
        case .existingConfig(let config):
            _initialConfig = State(initialValue: config)
            initialWorkspaceName = config.name
            initialChannelName = config.channelName
            initialToken = config.token
            initialChannelID = config.channelID
            initialUserID = config.userID // This is now String?
            initialTeamID = config.teamID // This is now String?
            if let nsColor = NSColor(hex: config.color) {
                initialColor = Color(nsColor)
            }
            initialKeywords = Set(config.keywords)
        case .newChannelInExistingWorkspace(let workspaceGroup):
            initialWorkspaceName = workspaceGroup.name
            initialToken = workspaceGroup.token
            initialUserID = workspaceGroup.userID // This is now String?
            initialTeamID = workspaceGroup.teamID // This is now String?
            if let groupColor = NSColor(hex: workspaceGroup.color) {
                initialColor = Color(groupColor)
            }
            // ChannelName, ChannelID will be empty for new channel
        case .existingWorkspace(let workspaceGroup):
            initialWorkspaceName = workspaceGroup.name
            initialToken = workspaceGroup.token
            initialUserID = workspaceGroup.userID // This is now String?
            initialTeamID = workspaceGroup.teamID // This is now String?
            if let groupColor = NSColor(hex: workspaceGroup.color) {
                initialColor = Color(groupColor)
            }
            // ChannelName, ChannelID are not relevant when editing workspace details
            // Keywords are not relevant when editing workspace details
        }
        
        _workspaceName = State(initialValue: initialWorkspaceName ?? "")
        _channelName = State(initialValue: initialChannelName ?? "")
        _token = State(initialValue: initialToken ?? "")
        _channelID = State(initialValue: initialChannelID ?? "")
        _userID = State(initialValue: initialUserID ?? "")
        _teamID = State(initialValue: initialTeamID ?? "")
        _color = State(initialValue: initialColor)
        _selectedKeywords = State(initialValue: initialKeywords)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewTitle).font(.system(size: 20, weight: .bold, design: .default)).foregroundColor(Color(white: 0.93))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium)).foregroundColor(Color(white: 0.67))
                        .frame(width: 28, height: 28).background(Color.clear)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain)
            }.padding(24)

            Divider().background(Color.gray.opacity(0.3))

            ScrollView {
                if loadingError != nil { // isLoadingWorkspace is always false now
                    Text("Error: \(loadingError ?? "Unknown error")")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    formContent
                }
            } // Removed .onAppear(perform: loadOriginalWorkspaceConfig)

            Divider().background(Color.gray.opacity(0.3))

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(DarkSecondaryButtonStyle())
                Spacer()
                Button(saveButtonText) { save() }.buttonStyle(DarkPrimaryButtonStyle()).disabled(!canSave).opacity(canSave ? 1.0 : 0.4)
            }.padding(24)
        }.frame(width: 500, height: 600)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
    }
    
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("워크스페이스 이름").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                    TextField("예: 테스트 워크스페이스", text: $workspaceName)
                        .textFieldStyle(.plain).font(.system(size: 14)).padding(10).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        .disabled(!(editingType == .newConfig || isWorkspaceEditing)) // Disabled if adding channel or editing existing config
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("색상").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                    ColorPicker("", selection: $color).labelsHidden().padding(4).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        .disabled(!(editingType == .newConfig || isWorkspaceEditing)) // Disabled if adding channel or editing existing config
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("채널 이름").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                TextField("예: 일반, 회의공지", text: $channelName)
                    .textFieldStyle(.plain).font(.system(size: 14)).padding(10).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .disabled(isWorkspaceEditing) // Disabled if editing workspace
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SLACK TOKEN (\(isNewChannel || isExistingConfig ? "워크스페이스에서 상속" : "필수"))")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                TextField("xoxp-...", text: $token)
                    .textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).padding(10).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .disabled(!(editingType == .newConfig || isWorkspaceEditing)) // Disabled if adding channel or editing existing config
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CHANNEL ID").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                TextField("C0000000000", text: $channelID)
                    .textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).padding(10).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .disabled(isWorkspaceEditing) // Disabled if editing workspace
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("SLACK USER ID (멘션 감지용) (\(isNewChannel || isExistingConfig ? "워크스페이스에서 상속" : "선택 사항"))")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                TextField("U0000000000", text: $userID)
                    .textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).padding(10).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .disabled(!(editingType == .newConfig || isWorkspaceEditing)) // Disabled if adding channel or editing existing config
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SLACK TEAM ID (딥링크 생성용) (\(isNewChannel || isExistingConfig ? "워크스페이스에서 상속" : "필수"))")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                TextField("T0000000000", text: $teamID)
                    .textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).padding(10).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .disabled(!(editingType == .newConfig || isWorkspaceEditing)) // Disabled if adding channel or editing existing config
            }
            
            helpSection
            keywordSection
        }.padding(24)
    }

    private var viewTitle: String {
        switch editingType {
        case .newConfig:
            return "Add New Slack Integration"
        case .existingConfig(let config):
            return "Edit Channel: \(config.channelName)"
        case .newChannelInExistingWorkspace(let workspaceGroup):
            return "Add Channel to \(workspaceGroup.name)"
        case .existingWorkspace(let workspaceGroup):
            return "Edit Workspace: \(workspaceGroup.name)"
        }
    }
    
    private var saveButtonText: String {
        switch editingType {
        case .newConfig:
            return "Add Slack"
        case .existingConfig:
            return "Save Changes"
        case .newChannelInExistingWorkspace:
            return "Add Channel"
        case .existingWorkspace:
            return "Save Workspace"
        }
    }

    private var canSave: Bool {
        switch editingType {
        case .newConfig:
            return !workspaceName.isEmpty && !channelName.isEmpty && !token.isEmpty && !channelID.isEmpty
        case .existingConfig:
            return !workspaceName.isEmpty && !channelName.isEmpty && !token.isEmpty && !channelID.isEmpty
        case .newChannelInExistingWorkspace:
            // Workspace details are inherited and cannot be empty if we got here
            return !channelName.isEmpty && !channelID.isEmpty
        case .existingWorkspace:
            // Channel details are not relevant, just workspace details
            return !workspaceName.isEmpty && !token.isEmpty
        }
    }

    // loadOriginalWorkspaceConfig is no longer needed; logic moved to init
    
    private func save() {
        let currentID: String
        let currentCreatedAt: Date
        let currentIsEnabled: Bool
        
        // Determine ID, createdAt, isEnabled based on editingType
        switch editingType {
        case .newConfig, .newChannelInExistingWorkspace:
            currentID = UUID().uuidString
            currentCreatedAt = Date()
            currentIsEnabled = true
        case .existingConfig(let config):
            currentID = config.id
            currentCreatedAt = config.createdAt
            currentIsEnabled = config.isEnabled
        case .existingWorkspace(let workspaceGroup):
            // When editing a workspace, we need to create a *representative* config
            // whose ID will be the workspaceGroup.id.
            // This is primarily for `onSave` to pass a valid `SlackConfiguration`
            // that contains the updated workspace-level properties.
            // The actual updates to all related `SlackConfiguration`s will happen in SlackConfigurationView.saveConfiguration
            currentID = workspaceGroup.id // Use the group's ID for this representative config
            currentCreatedAt = Date() // Not relevant for a workspace-level update, but needed for init
            currentIsEnabled = true // Not relevant for a workspace-level update, but needed for init
        }

        let finalChannelName: String
        let finalChannelID: String
        let finalKeywords: Set<String>

        switch editingType {
        case .existingWorkspace:
            // When editing a workspace, channel-specific fields are not relevant.
            finalChannelName = ""
            finalChannelID = ""
            finalKeywords = []
        case .newConfig, .existingConfig, .newChannelInExistingWorkspace:
            finalChannelName = channelName
            finalChannelID = channelID
            finalKeywords = selectedKeywords
        }

        let newConfig = SlackConfiguration(
            id: currentID,
            name: workspaceName,
            channelName: finalChannelName,
            token: token,
            channelID: finalChannelID,
            keywords: Array(finalKeywords),
            isEnabled: currentIsEnabled,
            createdAt: currentCreatedAt,
            color: color.toHex() ?? "#808080",
            userID: userID,
            teamID: teamID
        )

        onSave(editingType, newConfig)
        dismiss()
    }
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("📋 Slack 정보 찾는 방법").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(white: 0.93))

            VStack(alignment: .leading, spacing: 16) {
                HelpSection(
                    title: "1️⃣ Slack Token 생성하기",
                    steps: [
                        "Slack 웹(slack.com) 로그인", "api.slack.com/apps 접속",
                        "'Create New App' → 'From scratch' 선택", "앱 이름 입력 후 워크스페이스 선택",
                        "'OAuth & Permissions' 메뉴 클릭", "'Bot Token Scopes'에서 권한 추가:",
                        "  - channels:history (채널 메시지 읽기)", "  - channels:read (채널 정보 읽기)",
                        "'Install to Workspace' 클릭", "'Bot User OAuth Token' 복사 (xoxb-로 시작)"
                    ]
                )

                HelpSection(
                    title: "2️⃣ Channel ID 찾기",
                    steps: [
                        "Slack 앱 또는 웹에서 채널 열기", "채널 이름 클릭 → 하단 'About' 탭",
                        "'Channel ID' 복사 (C로 시작하는 코드)", "또는 채널 우클릭 → '링크 복사'에서",
                        "마지막 부분의 C로 시작하는 코드 확인"
                    ]
                )
                
                HelpSection(
                    title: "3️⃣ User ID 찾기 (멘션 감지)",
                    steps: [
                        "Slack 앱에서 내 프로필 사진 클릭", "'View profile' 선택",
                        "프로필 사진 아래 이름 옆 '...' 버튼 클릭", "'Copy member ID' 클릭하여 ID 복사 (U로 시작)"
                    ]
                )

                Button(action: { NSWorkspace.shared.open(URL(string: "https://api.slack.com/apps")!) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 11))
                        Text("Slack API 페이지 열기").font(.system(size: 12, weight: .medium))
                    }.foregroundColor(Color.blue)
                }.buttonStyle(.plain)
            }.padding(12).background(Color.blue.opacity(0.05)).cornerRadius(8)
        }.padding(.top, 8)
    }
    
    private var keywordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEYWORD FILTER (OPTIONAL)").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Keywords").font(.system(size: 11)).foregroundColor(Color(white: 0.67))
                FlowLayout(spacing: 8) {
                    ForEach(SlackConfiguration.templateKeywords, id: \.self) { keyword in
                        KeywordChip(keyword: keyword, isSelected: selectedKeywords.contains(keyword)) {
                            if selectedKeywords.contains(keyword) { selectedKeywords.remove(keyword) } else { selectedKeywords.insert(keyword) }
                        }
                    }
                }
            }
            if !selectedKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected (\(selectedKeywords.count))").font(.system(size: 11, weight: .medium)).foregroundColor(Color(white: 0.93))
                    FlowLayout(spacing: 8) {
                        ForEach(Array(selectedKeywords).sorted(), id: \.self) { keyword in
                            HStack(spacing: 6) {
                                Text(keyword).font(.system(size: 12)).foregroundColor(Color(white: 0.93))
                                Button(action: { selectedKeywords.remove(keyword) }) {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(Color(white: 0.67))
                                }.buttonStyle(.plain)
                            }.padding(.horizontal, 10).padding(.vertical, 5).background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.15)))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
                        }
                    }
                }.padding(12).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(8)
            }
            HStack {
                TextField("Add custom keyword...", text: $customKeyword)
                    .textFieldStyle(.plain).font(.system(size: 14)).padding(10).background(Color(red: 0.09, green: 0.09, blue: 0.09)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                Button("Add") {
                    if !customKeyword.isEmpty { selectedKeywords.insert(customKeyword); customKeyword = "" }
                }.buttonStyle(DarkSecondaryButtonStyle())
            }
        }
    }
}



// MARK: - Helper Components (No changes needed here)
struct HelpSection: View {
    let title: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(white: 0.93))
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    if !step.hasPrefix("  ") { Text("•").font(.system(size: 11)).foregroundColor(Color(white: 0.67)) }
                    else { Text("").frame(width: 16) }
                    Text(step.trimmingCharacters(in: .whitespaces)).font(.system(size: 11)).foregroundColor(Color(white: 0.67))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Preview (No changes needed here)
#Preview {
    SlackConfigurationView()
}