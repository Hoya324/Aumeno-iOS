import Foundation

enum MeetingSource: String, Codable {
    case manual = "manual"      // 사용자가 직접 생성
    case slack = "slack"        // Slack에서 동기화
}

struct Meeting: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var startDateTime: Date      // 실제 회의 예정 시간
    var note: String
    var source: MeetingSource    // 생성 출처
    var slackConfigID: String?   // Slack 설정 ID (Slack 출처인 경우)
    var slackTimestamp: String?  // 원본 Slack 타임스탬프 (Slack 출처인 경우)
    var createdAt: Date          // 생성 시간
    var notificationSent: Bool   // 알림 전송 여부
    var location: String?        // 회의 장소
    var links: [String]?         // 관련된 링크 목록

    // 수동 생성용 초기화
    init(
        id: String = UUID().uuidString,
        title: String,
        startDateTime: Date, // Renamed
        note: String = "",
        source: MeetingSource = .manual,
        slackConfigID: String? = nil,
        slackTimestamp: String? = nil,
        createdAt: Date = Date(),
        notificationSent: Bool = false,
        location: String? = nil,
        links: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.startDateTime = startDateTime // Assigned
        self.note = note
        self.source = source
        self.slackConfigID = slackConfigID
        self.slackTimestamp = slackTimestamp
        self.createdAt = createdAt
        self.notificationSent = notificationSent
        self.location = location
        self.links = links
    }

    // Slack 메시지에서 생성 (편의 초기화)
    init(
        slackTimestamp: String,
        title: String,
        startDateTime: Date, // Renamed
        slackConfigID: String,
        location: String? = nil,
        links: [String]? = nil,
        note: String = ""
    ) {
        self.id = slackTimestamp
        self.title = title
        self.startDateTime = startDateTime // Assigned
        self.note = note
        self.source = .slack
        self.slackConfigID = slackConfigID
        self.slackTimestamp = slackTimestamp
        self.createdAt = Date()
        self.notificationSent = false
        self.location = location
        self.links = links
    }
}

// Extension for display formatting
extension Meeting {
    var formattedStartDateTime: String { // Renamed
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: startDateTime)
    }

    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: createdAt)
    }

    var hasNote: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isManual: Bool {
        source == .manual
    }

    var isFromSlack: Bool {
        source == .slack
    }

    var sourceDisplayName: String {
        switch source {
        case .manual: return "수동 생성"
        case .slack: return "Slack"
        }
    }

    // 회의 시간이 임박했는지 확인 (5분 전)
    func isUpcoming(within minutes: Int = 5) -> Bool {
        let now = Date()
        let timeUntilMeeting = startDateTime.timeIntervalSince(now) // Uses startDateTime
        return timeUntilMeeting > 0 && timeUntilMeeting <= Double(minutes * 60)
    }

    // 회의 시간이 지났는지 확인
    var isPast: Bool {
        startDateTime < Date() // Uses startDateTime
    }

    // 회의가 진행 중인지 확인 (시작 후 2시간 이내)
    func isOngoing(duration: TimeInterval = 2 * 60 * 60) -> Bool {
        let now = Date()
        let endTime = startDateTime.addingTimeInterval(duration) // Uses startDateTime
        return startDateTime <= now && now <= endTime
    }
}