//
//  SlackConfiguration.swift
//  Aumeno
//
//  Created by Claude Code
//

import Foundation

struct SlackConfiguration: Identifiable, Codable, Equatable {
    let id: String
    var name: String // Workspace name, e.g., "테스트 워크스페이스"
    var channelName: String // Channel name, e.g., "일반", "회의공지"
    var token: String
    var channelID: String
    var keywords: [String] // 필터링할 키워드들
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        channelName: String,
        token: String,
        channelID: String,
        keywords: [String] = [],
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.channelName = channelName
        self.token = token
        self.channelID = channelID
        self.keywords = keywords
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    // 키워드가 비어있으면 모든 메시지 가져오기
    var shouldFilterByKeywords: Bool {
        !keywords.isEmpty
    }

    // 메시지가 키워드를 포함하는지 확인
    func matchesKeywords(_ text: String) -> Bool {
        guard shouldFilterByKeywords else { return true }

        let lowercasedText = text.lowercased()
        return keywords.contains { keyword in
            lowercasedText.contains(keyword.lowercased())
        }
    }
}

// Default template keywords
extension SlackConfiguration {
    static let templateKeywords = [
        "📅 Meeting:",
        "[Meeting]",
        "[MEETING]",
        "Meeting Notice",
        "Conference",
        "Standup"
    ]

    static let sampleConfiguration = SlackConfiguration(
        name: "Sample Workspace",
        channelName: "general",
        token: "xoxp-your-token-here",
        channelID: "C0000000000",
        keywords: ["📅 Meeting:", "[Meeting]"]
    )
}
