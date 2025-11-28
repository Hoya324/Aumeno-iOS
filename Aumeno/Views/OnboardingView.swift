//
//  OnboardingView.swift
//  Aumeno
//
//  Created by Claude Code
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var workspaceName = ""
    @State private var channelName = ""
    @State private var token = ""
    @State private var channelID = ""
    @State private var selectedKeywords: Set<String> = []
    @State private var customKeyword = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.primary.opacity(0.1))

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if currentStep == 0 {
                        welcomeStep
                    } else if currentStep == 1 {
                        slackTokenStep
                    } else if currentStep == 2 {
                        keywordStep
                    }
                }
                .padding(32)
            }

            Divider()
                .background(Color.primary.opacity(0.1))

            // Footer
            footerView
        }
        .frame(width: 600, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Aumeno 설정")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.primary.opacity(0.6))

            Text("Aumeno에 오신 것을 환영합니다!")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text("Slack 회의 메시지를 자동으로 관리하고\n회의 시간에 노트를 바로 열 수 있습니다.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "checkmark.circle", text: "여러 Slack 워크스페이스 연동")
                FeatureRow(icon: "checkmark.circle", text: "키워드 기반 메시지 필터링")
                FeatureRow(icon: "checkmark.circle", text: "회의 시간 자동 알림 + 노트 오픈")
                FeatureRow(icon: "checkmark.circle", text: "수동 회의 생성 및 관리")
            }
            .padding(.top, 8)
        }
    }

    private var slackTokenStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Slack 연동 설정")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Slack 워크스페이스에서 토큰과 채널 ID를 가져와주세요.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Workspace Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("워크스페이스 이름")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("예: 테스트 워크스페이스", text: $workspaceName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }

                // Channel Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("채널 이름")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("예: 일반, 회의공지", text: $channelName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }

                // Token
                VStack(alignment: .leading, spacing: 6) {
                    Text("Slack Token")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("xoxp-...", text: $token)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }

                // Channel ID
                VStack(alignment: .leading, spacing: 6) {
                    Text("Channel ID")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("C0000000000", text: $channelID)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
            }

            // Help section - expandable
            VStack(alignment: .leading, spacing: 12) {
                Divider()

                Text("📋 Slack Token 및 Channel ID 찾는 방법")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

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
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            .padding(.top, 8)
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
                    .foregroundColor(.primary)

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        if !step.hasPrefix("  ") {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("")
                                .frame(width: 16)
                        }

                        Text(step.trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var keywordStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("키워드 필터 설정")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text("특정 키워드가 포함된 메시지만 가져옵니다. (선택사항)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Template keywords
            VStack(alignment: .leading, spacing: 12) {
                Text("추천 키워드")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

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

            // Custom keyword input
            VStack(alignment: .leading, spacing: 8) {
                Text("커스텀 키워드 추가")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("키워드 입력...", text: $customKeyword)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )

                    Button("추가") {
                        if !customKeyword.isEmpty {
                            selectedKeywords.insert(customKeyword)
                            customKeyword = ""
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            // Selected keywords
            if !selectedKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("선택된 키워드 (\(selectedKeywords.count))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(Array(selectedKeywords), id: \.self) { keyword in
                            KeywordChip(keyword: keyword, isSelected: true) {
                                selectedKeywords.remove(keyword)
                            }
                        }
                    }
                }
            }

            // Note
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("키워드를 선택하지 않으면 모든 메시지를 가져옵니다.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if currentStep > 0 {
                Button("이전") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Spacer()

            if currentStep < 2 {
                Button("다음") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceedToNextStep)
            } else {
                Button(isSaving ? "저장 중..." : "완료") {
                    saveConfiguration()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || !canProceedToNextStep)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    // MARK: - Validation

    private var canProceedToNextStep: Bool {
        switch currentStep {
        case 0:
            return true
        case 1:
            return !workspaceName.isEmpty && !channelName.isEmpty && !token.isEmpty && !channelID.isEmpty
        case 2:
            return true
        default:
            return false
        }
    }

    // MARK: - Actions

    private func saveConfiguration() {
        isSaving = true

        let config = SlackConfiguration(
            name: workspaceName,
            channelName: channelName,
            token: token,
            channelID: channelID,
            keywords: Array(selectedKeywords)
        )

        do {
            try ConfigurationManager.shared.insertConfiguration(config)
            print("✅ Configuration saved: \(config.name) / \(config.channelName)")

            // Complete onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
                dismiss()
            }
        } catch {
            errorMessage = "설정 저장 실패: \(error.localizedDescription)"
            showError = true
            isSaving = false
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct KeywordChip: View {
    let keyword: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(keyword)
                    .font(.system(size: 13))

                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                }
            }
            .foregroundColor(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.primary.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for wrapping chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if x + subviewSize.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, subviewSize.height)
                x += subviewSize.width + spacing
                size.width = max(size.width, x - spacing)
            }

            size.height = y + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
