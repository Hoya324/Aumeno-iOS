//
//  SlackConfigurationView.swift
//  Aumeno
//
//  Created by Claude Code
//

import SwiftUI

struct SlackConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configurations: [SlackConfiguration] = []
    @State private var showingAddSheet = false
    @State private var editingConfig: SlackConfiguration?
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.gray.opacity(0.3))

            // Debug info
            if !configurations.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.67))

                    Text("\(configurations.count) configuration(s) loaded")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.67))

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color(red: 0.09, green: 0.09, blue: 0.09))
            }

            // Configuration List
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
        }
        .sheet(isPresented: $showingAddSheet) {
            ConfigurationEditorView(config: nil) { newConfig in
                saveConfiguration(newConfig)
            }
        }
        .sheet(item: $editingConfig) { config in
            ConfigurationEditorView(config: config) { updatedConfig in
                saveConfiguration(updatedConfig)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Slack Integrations")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(Color(white: 0.93))

            Spacer()

            HStack(spacing: 10) {
                // Refresh button
                Button(action: { loadConfigurations() }) {
                    Image(systemName: "arrow.clockwise")
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
                .help("Refresh")

                // Add button
                Button(action: { showingAddSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))

                        Text("Add")
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
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.67))
                    .frame(width: 28, height: 28)
                    .background(Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Configuration List

    private var configurationListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(configurations) { config in
                    ConfigurationRow(config: config)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Edit") {
                                editingConfig = config
                            }

                            Button(config.isEnabled ? "Disable" : "Enable") {
                                toggleConfiguration(config)
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                deleteConfiguration(config)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Color.gray.opacity(0.4))

            VStack(spacing: 6) {
                Text("No Slack Integrations")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(white: 0.93))

                Text("Add a Slack workspace to get started")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.67))
            }

            Button(action: { showingAddSheet = true }) {
                Text("Add First Slack")
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

    // MARK: - Actions

    private func loadConfigurations() {
        print("🔄 Loading Slack configurations...")
        do {
            // First cleanup any corrupted data
            try ConfigurationManager.shared.cleanupCorruptedConfigurations()

            configurations = try ConfigurationManager.shared.fetchAllConfigurations()
            print("✅ Loaded \(configurations.count) configuration(s)")

            // Debug: Print each configuration
            for config in configurations {
                print("  - \(config.name) (ID: \(config.id.prefix(8)), Enabled: \(config.isEnabled), Keywords: \(config.keywords.count))")
            }
        } catch {
            print("❌ Failed to load configurations: \(error)")
            errorMessage = "Failed to load configurations: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func saveConfiguration(_ config: SlackConfiguration) {
        print("💾 Saving configuration: \(config.name)")
        do {
            try ConfigurationManager.shared.insertConfiguration(config)
            print("✅ Configuration saved successfully")
            loadConfigurations()
        } catch {
            print("❌ Failed to save configuration: \(error)")
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func toggleConfiguration(_ config: SlackConfiguration) {
        print("🔄 Toggling configuration: \(config.name)")
        var updatedConfig = config
        updatedConfig.isEnabled.toggle()
        saveConfiguration(updatedConfig)
    }

    private func deleteConfiguration(_ config: SlackConfiguration) {
        print("🗑️ Deleting configuration: \(config.name)")
        do {
            try ConfigurationManager.shared.deleteConfiguration(id: config.id)
            print("✅ Configuration deleted successfully")
            loadConfigurations()
        } catch {
            print("❌ Failed to delete configuration: \(error)")
            errorMessage = "Failed to delete configuration: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Configuration Row

struct ConfigurationRow: View {
    let config: SlackConfiguration
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(config.isEnabled ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 6, height: 6)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(config.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.93))

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.67))

                        Text(config.channelID)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.67))
                    }

                    if !config.keywords.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.67))

                            Text("\(config.keywords.count) keywords")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.67))
                        }
                    } else {
                        Text("All messages")
                            .font(.system(size: 11))
                            .foregroundColor(Color.gray.opacity(0.5))
                            .italic()
                    }
                }
            }

            Spacer()

            // Status badge
            Text(config.isEnabled ? "Active" : "Disabled")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(config.isEnabled ? Color.green : Color.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill((config.isEnabled ? Color.green : Color.gray).opacity(0.15))
                )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.15)),
            alignment: .bottom
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Configuration Editor

struct ConfigurationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let config: SlackConfiguration?
    let onSave: (SlackConfiguration) -> Void

    @State private var workspaceName: String
    @State private var channelName: String
    @State private var token: String
    @State private var channelID: String
    @State private var selectedKeywords: Set<String>
    @State private var customKeyword = ""

    init(config: SlackConfiguration?, onSave: @escaping (SlackConfiguration) -> Void) {
        self.config = config
        self.onSave = onSave
        _workspaceName = State(initialValue: config?.name ?? "")
        _channelName = State(initialValue: config?.channelName ?? "")
        _token = State(initialValue: config?.token ?? "")
        _channelID = State(initialValue: config?.channelID ?? "")
        _selectedKeywords = State(initialValue: Set(config?.keywords ?? []))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(config == nil ? "Add Slack" : "Edit Slack")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(Color(white: 0.93))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.67))
                        .frame(width: 28, height: 28)
                        .background(Color.clear)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()
                .background(Color.gray.opacity(0.3))

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Workspace Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("워크스페이스 이름")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        TextField("예: 테스트 워크스페이스", text: $workspaceName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Channel Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("채널 이름")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        TextField("예: 일반, 회의공지", text: $channelName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Token
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SLACK TOKEN")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        TextField("xoxp-...", text: $token)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(10)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Channel ID
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHANNEL ID")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        TextField("C0000000000", text: $channelID)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(10)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Help section - expandable
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()

                        Text("📋 Slack Token 및 Channel ID 찾는 방법")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(white: 0.93))

                        VStack(alignment: .leading, spacing: 16) {
                            // Token 찾는 방법
                            HelpSection(
                                title: "1️⃣ Slack Token 생성하기",
                                steps: [
                                    "Slack 웹(slack.com) 로그인",
                                    "api.slack.com/apps 접속",
                                    "'Create New App' → 'From scratch' 선택",
                                    "앱 이름 입력 후 워크스페이스 선택",
                                    "'OAuth & Permissions' 메뉴 클릭",
                                    "'Bot Token Scopes'에서 권한 추가:",
                                    "  - channels:history (채널 메시지 읽기)",
                                    "  - channels:read (채널 정보 읽기)",
                                    "'Install to Workspace' 클릭",
                                    "'Bot User OAuth Token' 복사 (xoxb-로 시작)"
                                ]
                            )

                            // Channel ID 찾는 방법
                            HelpSection(
                                title: "2️⃣ Channel ID 찾기",
                                steps: [
                                    "Slack 앱 또는 웹에서 채널 열기",
                                    "채널 이름 클릭 → 하단 'About' 탭",
                                    "'Channel ID' 복사 (C로 시작하는 코드)",
                                    "또는 채널 우클릭 → '링크 복사'에서",
                                    "마지막 부분의 C로 시작하는 코드 확인"
                                ]
                            )

                            // Quick link
                            Button(action: {
                                NSWorkspace.shared.open(URL(string: "https://api.slack.com/apps")!)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.system(size: 11))
                                    Text("Slack API 페이지 열기")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(Color.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.top, 8)

                    // Keywords
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KEYWORD FILTER (OPTIONAL)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        // Template keywords
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Keywords")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.67))

                            FlowLayout(spacing: 8) {
                                ForEach(SlackConfiguration.templateKeywords, id: \.self) { keyword in
                                    KeywordChip(
                                        keyword: keyword,
                                        isSelected: selectedKeywords.contains(keyword)
                                    ) {
                                        if selectedKeywords.contains(keyword) {
                                            selectedKeywords.remove(keyword)
                                        } else {
                                            selectedKeywords.insert(keyword)
                                        }
                                    }
                                }
                            }
                        }

                        // Selected keywords display
                        if !selectedKeywords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected (\(selectedKeywords.count))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.93))

                                FlowLayout(spacing: 8) {
                                    ForEach(Array(selectedKeywords).sorted(), id: \.self) { keyword in
                                        HStack(spacing: 6) {
                                            Text(keyword)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(white: 0.93))

                                            Button(action: {
                                                selectedKeywords.remove(keyword)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Color(white: 0.67))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.green.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(8)
                        }

                        // Add custom keyword
                        HStack {
                            TextField("Add custom keyword...", text: $customKeyword)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )

                            Button("Add") {
                                if !customKeyword.isEmpty {
                                    selectedKeywords.insert(customKeyword)
                                    customKeyword = ""
                                }
                            }
                            .buttonStyle(DarkSecondaryButtonStyle())
                        }
                    }
                }
                .padding(24)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(DarkSecondaryButtonStyle())

                Spacer()

                Button("Save") {
                    save()
                }
                .buttonStyle(DarkPrimaryButtonStyle())
                .disabled(!canSave)
                .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(24)
        }
        .frame(width: 500, height: 600)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
    }

    private var canSave: Bool {
        !workspaceName.isEmpty && !channelName.isEmpty && !token.isEmpty && !channelID.isEmpty
    }

    private func save() {
        let newConfig = SlackConfiguration(
            id: config?.id ?? UUID().uuidString,
            name: workspaceName,
            channelName: channelName,
            token: token,
            channelID: channelID,
            keywords: Array(selectedKeywords),
            isEnabled: config?.isEnabled ?? true,
            createdAt: config?.createdAt ?? Date()
        )

        print("📝 ConfigurationEditor - Creating config:")
        print("   ID: \(newConfig.id)")
        print("   Workspace: \(newConfig.name)")
        print("   Channel: \(newConfig.channelName)")
        print("   Token: \(newConfig.token.prefix(20))...")
        print("   Channel ID: \(newConfig.channelID)")
        print("   Keywords: \(newConfig.keywords)")
        print("   Enabled: \(newConfig.isEnabled)")

        onSave(newConfig)
        dismiss()
    }
}

// MARK: - Helper Components

struct HelpSection: View {
    let title: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(white: 0.93))

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    if !step.hasPrefix("  ") {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.67))
                    } else {
                        Text("")
                            .frame(width: 16)
                    }

                    Text(step.trimmingCharacters(in: .whitespaces))
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.67))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SlackConfigurationView()
}
