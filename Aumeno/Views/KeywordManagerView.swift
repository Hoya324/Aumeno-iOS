//
//  KeywordManagerView.swift
//  Aumeno
//
//  Created by Claude Code
//

import SwiftUI

struct KeywordManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configurations: [SlackConfiguration] = []
    @State private var allKeywords: Set<String> = []
    @State private var newKeyword = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.gray.opacity(0.3))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Active keywords section
                    activeKeywordsSection

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // Add new keyword section
                    addKeywordSection

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // Keywords by configuration
                    keywordsByConfigSection
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 500)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
        .onAppear {
            loadKeywords()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyword Manager")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundColor(Color(white: 0.93))

                Text("Active filter keywords")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.67))
            }

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
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Active Keywords

    private var activeKeywordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Keywords (\(allKeywords.count))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(white: 0.93))

                Spacer()

                if allKeywords.isEmpty {
                    Text("All messages")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.67))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
            }

            if allKeywords.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.67))

                    Text("No keywords set - fetching all Slack messages")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.67))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                .cornerRadius(8)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(allKeywords).sorted(), id: \.self) { keyword in
                        KeywordBadge(
                            keyword: keyword,
                            usageCount: countUsage(keyword),
                            onDelete: {
                                removeKeyword(keyword)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Add Keyword

    private var addKeywordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Keyword")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(white: 0.93))

            HStack(spacing: 12) {
                TextField("e.g. 📅 Meeting, [Meeting]", text: $newKeyword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                Button(action: addKeyword) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))

                        Text("Add")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(white: 0.93))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
            }

            // Template keywords
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.67))

                FlowLayout(spacing: 8) {
                    ForEach(SlackConfiguration.templateKeywords, id: \.self) { keyword in
                        Button(action: {
                            newKeyword = keyword
                            addKeyword()
                        }) {
                            HStack(spacing: 4) {
                                Text(keyword)
                                    .font(.system(size: 11))

                                if allKeywords.contains(keyword) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 9))
                                }
                            }
                            .foregroundColor(allKeywords.contains(keyword) ? Color.gray : Color(white: 0.93))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(allKeywords.contains(keyword) ? Color.gray.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(allKeywords.contains(keyword))
                    }
                }
            }
        }
    }

    // MARK: - Keywords by Config

    private var keywordsByConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keywords by Integration")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(white: 0.93))

            if configurations.isEmpty {
                Text("No Slack integrations configured")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.67))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 12) {
                    ForEach(configurations, id: \.id) { config in
                        ConfigKeywordRow(config: config)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadKeywords() {
        do {
            let fetchedConfigs = try ConfigurationManager.shared.fetchAllConfigurations()

            // Remove duplicates by ID (just in case)
            var uniqueConfigs: [SlackConfiguration] = []
            var seenIDs: Set<String> = []

            for config in fetchedConfigs {
                if !seenIDs.contains(config.id) {
                    uniqueConfigs.append(config)
                    seenIDs.insert(config.id)
                }
            }

            configurations = uniqueConfigs

            // Collect all unique keywords
            var keywords: Set<String> = []
            for config in configurations where config.isEnabled {
                keywords.formUnion(config.keywords)
            }
            allKeywords = keywords

        } catch {
            print("❌ Failed to load keywords: \(error)")
        }
    }

    private func addKeyword() {
        let keyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        // 모든 활성화된 설정에 키워드 추가
        do {
            for var config in configurations where config.isEnabled {
                if !config.keywords.contains(keyword) {
                    config.keywords.append(keyword)
                    try ConfigurationManager.shared.updateConfiguration(config)
                }
            }

            newKeyword = ""
            loadKeywords()

        } catch {
            print("❌ Failed to add keyword: \(error)")
        }
    }

    private func removeKeyword(_ keyword: String) {
        do {
            for var config in configurations {
                if let index = config.keywords.firstIndex(of: keyword) {
                    config.keywords.remove(at: index)
                    try ConfigurationManager.shared.updateConfiguration(config)
                }
            }

            loadKeywords()

        } catch {
            print("❌ Failed to remove keyword: \(error)")
        }
    }

    private func countUsage(_ keyword: String) -> Int {
        configurations.filter { $0.keywords.contains(keyword) }.count
    }
}

// MARK: - Supporting Views

struct KeywordBadge: View {
    let keyword: String
    let usageCount: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(keyword)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.93))

            if usageCount > 1 {
                Text("×\(usageCount)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.67))
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.67))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ConfigKeywordRow: View {
    let config: SlackConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(config.isEnabled ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.93))

                Spacer()

                Text("\(config.keywords.count)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.67))
            }

            if config.keywords.isEmpty {
                Text("No keywords (all messages)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.67))
                    .italic()
                    .padding(.leading, 18)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(config.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.67))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(12)
        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    KeywordManagerView()
}
