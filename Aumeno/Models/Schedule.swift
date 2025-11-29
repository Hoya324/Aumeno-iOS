import Foundation

enum ScheduleType: String, Codable, CaseIterable { // Added CaseIterable
    case meeting    // 회의 (기존 Meeting과 동일)
    case mention    // 나를 언급 (@경호)
    case task       // 수동 등록 일정/할일

    var typeDisplayName: String {
        switch self {
        case .meeting: return "회의"
        case .mention: return "언급됨"
        case .task: return "할일"
        }
    }
}

enum ScheduleSource: String, Codable {
    case manual = "manual"      // 사용자가 직접 생성
    case slack = "slack"        // Slack에서 동기화
}

struct Schedule: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var startDateTime: Date      // 실제 일정 시작 시간
    var endDateTime: Date?       // 실제 일정 종료 시간 (선택 사항)
    var note: String
    var type: ScheduleType       // 일정 타입 (회의/멘션/할일)
    var source: ScheduleSource   // 생성 출처 (Slack/수동)

    // Slack 관련 필드
    var workspaceID: String?     // Slack 워크스페이스 ID (SlackConfiguration ID)
    var channelID: String?       // Slack 채널 ID
    var channelName: String?     // Slack 채널 이름
    var slackTimestamp: String?  // 원본 Slack 타임스탬프 (Slack 출처인 경우)
    var slackLink: String?       // Slack deep link (클릭 시 Slack 앱 열기)
    var slackMessageText: String? // 원본 Slack 메시지 텍스트 (멘션용)

    // UI 관련 필드
    var workspaceColor: String?  // 워크스페이스 색상 (Hex, 예: "#FF5733")

    // 기타 필드
    var createdAt: Date          // 생성 시간
    var notificationSent: Bool   // 알림 전송 여부
    var location: String?        // 회의 장소
    var links: [String]?         // 관련된 링크 목록
    var tagID: String?           // Link to Tag model -> ADDED
    var isDone: Bool             // 할일 완료 여부

    // MARK: - Initializers

    // 수동 생성용 초기화
    init(
        id: String = UUID().uuidString,
        title: String,
        startDateTime: Date,
        endDateTime: Date? = nil, // New parameter
        note: String = "",
        type: ScheduleType = .task,
        source: ScheduleSource = .manual,
        workspaceID: String? = nil,
        channelID: String? = nil,
        channelName: String? = nil,
        slackTimestamp: String? = nil,
        slackLink: String? = nil,
        slackMessageText: String? = nil,
        workspaceColor: String? = nil,
        createdAt: Date = Date(),
        notificationSent: Bool = false,
        location: String? = nil,
        links: [String]? = nil,
        tagID: String? = nil,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.note = note
        self.type = type
        self.source = source
        self.workspaceID = workspaceID
        self.channelID = channelID
        self.channelName = channelName
        self.slackTimestamp = slackTimestamp
        self.slackLink = slackLink
        self.slackMessageText = slackMessageText
        self.workspaceColor = workspaceColor
        self.createdAt = createdAt
        self.notificationSent = notificationSent
        self.location = location
        self.links = links
        self.tagID = tagID
        self.isDone = isDone
    }

    // Slack 회의 메시지에서 생성 (편의 초기화)
    init(
        slackTimestamp: String,
        title: String,
        startDateTime: Date,
        endDateTime: Date? = nil, // New parameter
        workspaceID: String,
        channelID: String? = nil,
        channelName: String? = nil,
        slackLink: String? = nil,
        workspaceColor: String? = nil,
        location: String? = nil,
        links: [String]? = nil,
        tagID: String? = nil,
        note: String = "",
        createdAt: Date = Date(),
        notificationSent: Bool = false
    ) {
        self.id = slackTimestamp
        self.title = title
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.note = note
        self.type = .meeting
        self.source = .slack
        self.workspaceID = workspaceID
        self.channelID = channelID
        self.channelName = channelName
        self.slackTimestamp = slackTimestamp
        self.slackLink = slackLink
        self.slackMessageText = nil
        self.workspaceColor = workspaceColor
        self.createdAt = createdAt
        self.notificationSent = notificationSent
        self.location = location
        self.links = links
        self.tagID = tagID
        self.isDone = false
    }


    // Slack 멘션에서 생성 (편의 초기화)
    init(
        slackTimestamp: String,
        messageText: String,
        workspaceID: String,
        channelID: String?,
        channelName: String?,
        slackLink: String?,
        workspaceColor: String? = nil,
        links: [String]? = nil,
        tagID: String? = nil,
        startDateTime: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = slackTimestamp
        self.title = "Mentioned in \(channelName ?? "Slack")"
        self.startDateTime = startDateTime
        self.endDateTime = nil // Explicitly nil for mention
        self.note = ""
        self.type = .mention
        self.source = .slack
        self.workspaceID = workspaceID
        self.channelID = channelID
        self.channelName = channelName
        self.slackTimestamp = slackTimestamp
        self.slackLink = slackLink
        self.slackMessageText = messageText
        self.workspaceColor = workspaceColor
        self.createdAt = createdAt
        self.notificationSent = false
        self.location = nil
        self.links = links
        self.tagID = tagID
        self.isDone = false
    }
}

// MARK: - Display Formatting
extension Schedule {
    var formattedStartDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: startDateTime)
    }

    var formattedEndDateTime: String? {
        guard let endDateTime = endDateTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: endDateTime)
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

    var typeDisplayName: String {
        switch type {
        case .meeting: return "회의"
        case .mention: return "언급됨"
        case .task: return "할일"
        }
    }

    var typeIcon: String {
        switch type {
        case .meeting: return "calendar"
        case .mention: return "at"
        case .task: return "checkmark.circle"
        }
    }

    // 일정 시간이 임박했는지 확인 (5분 전)
    func isUpcoming(within minutes: Int = 5) -> Bool {
        let now = Date()
        let timeUntilSchedule = startDateTime.timeIntervalSince(now)
        return timeUntilSchedule > 0 && timeUntilSchedule <= Double(minutes * 60)
    }

    // 일정 시간이 지났는지 확인
    var isPast: Bool {
        (endDateTime ?? startDateTime) < Date()
    }

    // 일정이 진행 중인지 확인 (시작 후 2시간 이내)
    func isOngoing(duration: TimeInterval = 2 * 60 * 60) -> Bool {
        let now = Date()
        let effectiveEndTime = endDateTime ?? startDateTime.addingTimeInterval(duration)
        return startDateTime <= now && now <= effectiveEndTime
    }
}

// MARK: - Backward Compatibility with Meeting
// 기존 Meeting 모델과의 호환성을 위한 확장
extension Schedule {
    // Meeting으로부터 Schedule 생성
    static func fromMeeting(_ meeting: Meeting) -> Schedule {
        return Schedule(
            id: meeting.id,
            title: meeting.title,
            startDateTime: meeting.startDateTime, // Use scheduledTime for startDateTime
            endDateTime: nil, // Meeting does not have an end time
            note: meeting.note,
            type: .meeting, // Meeting은 항상 .meeting 타입
            source: meeting.source == .manual ? .manual : .slack,
            workspaceID: meeting.slackConfigID,
            channelID: nil,
            channelName: nil,
            slackTimestamp: meeting.slackTimestamp,
            slackLink: nil,
            slackMessageText: nil,
            workspaceColor: nil,
            createdAt: meeting.createdAt,
            notificationSent: meeting.notificationSent,
            location: meeting.location,
            links: meeting.links,
            tagID: nil, // Meeting does not have a tagID field
            isDone: false
        )
    }

    // Schedule을 Meeting으로 변환 (하위 호환성)
    func toMeeting() -> Meeting {
        return Meeting(
            id: id,
            title: title,
            startDateTime: startDateTime, // Corrected to use startDateTime
            note: note,
            source: source == .manual ? .manual : .slack,
            slackConfigID: workspaceID,
            slackTimestamp: slackTimestamp,
            createdAt: createdAt,
            notificationSent: notificationSent,
            location: location,
            links: links // Meeting에는 tags 필드가 없으므로 포함하지 않음
        )
    }
}
