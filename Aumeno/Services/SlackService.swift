//
//  SlackService.swift
//  Aumeno
//
//  Created by Claude Code
//

import Foundation

enum SlackError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case decodingError(Error)
}

struct SlackMessage: Codable {
    let type: String
    let user: String?
    let text: String
    let ts: String
}

struct SlackResponse: Codable {
    let ok: Bool
    let messages: [SlackMessage]?
    let error: String?
}

final class SlackService {
    static let shared = SlackService()
    private let baseURL = "https://slack.com/api"

    private init() {}

    // MARK: - Fetch Messages (다중 설정 지원)

    /// 특정 Slack 설정으로 메시지 가져오기
    func fetchMessages(for config: SlackConfiguration, limit: Int = 100) async throws -> [Meeting] {
        guard config.isEnabled else {
            return []
        }

        guard let url = URL(string: "\(baseURL)/conversations.history") else {
            throw SlackError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Calculate timestamp for 14 days ago (2주일 전)
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 24 * 60 * 60)
        let oldestTimestamp = String(twoWeeksAgo.timeIntervalSince1970)

        let body: [String: Any] = [
            "channel": config.channelID,
            "limit": limit,
            "oldest": oldestTimestamp  // 2주일 전까지만
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SlackError.invalidResponse
            }

            let decoder = JSONDecoder()
            let slackResponse = try decoder.decode(SlackResponse.self, from: data)

            if !slackResponse.ok {
                throw SlackError.apiError(slackResponse.error ?? "Unknown error")
            }

            guard let messages = slackResponse.messages else {
                return []
            }

            // 키워드 필터링 적용
            let validMessages = messages.filter { $0.type == "message" && $0.user != nil }

            print("📬 Fetched \(validMessages.count) message(s) from Slack channel \(config.channelID)")
            print("   Config: \(config.name)")
            print("   Keywords: \(config.keywords)")
            print("   Filter enabled: \(config.shouldFilterByKeywords)")

            let filteredMessages = validMessages.filter { message in
                let matches = config.matchesKeywords(message.text)
                if config.shouldFilterByKeywords {
                    print("   Message: '\(message.text.prefix(50))...' - Matches: \(matches)")
                }
                return matches
            }

            print("✅ Filtered to \(filteredMessages.count) message(s) matching keywords")

            // Slack 메시지를 Meeting 객체로 변환
            let meetings = filteredMessages.compactMap { message in
                convertToMeeting(message, configID: config.id)
            }

            print("✅ Converted to \(meetings.count) meeting(s)")
            return meetings

        } catch let error as SlackError {
            throw error
        } catch let error as DecodingError {
            throw SlackError.decodingError(error)
        } catch {
            throw SlackError.networkError(error)
        }
    }

    /// 모든 활성화된 설정에서 메시지 가져오기
    func fetchMessagesFromAllConfigurations() async throws -> [Meeting] {
        let configurations = try ConfigurationManager.shared.fetchEnabledConfigurations()

        var allMeetings: [Meeting] = []

        for config in configurations {
            do {
                let meetings = try await fetchMessages(for: config)
                allMeetings.append(contentsOf: meetings)
            } catch {
                print("⚠️ Failed to fetch from config '\(config.name)': \(error)")
                // 하나의 설정이 실패해도 계속 진행
            }
        }

        return allMeetings
    }

    // MARK: - Message Parsing

    /// Parse Korean meeting notice format
    /// Example:
    /// [기획/디자인 회의 공지]
    /// 시간: 11/20(목) 오후 4시~
    /// 장소: 4층 어라운드 회의실
    /// 회의록: https://www.notion.so/...
    private func parseKoreanMeetingFormat(from text: String) -> (title: String, scheduledTime: Date, location: String?, notionLink: String?, note: String)? {
        var title: String?
        var scheduledTime: Date?
        var location: String?
        var notionLink: String?

        // Parse title from [...] format using capture group
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]"#) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) {
                    let captured = String(text[range])
                    title = captured
                        .replacingOccurrences(of: "*", with: "")  // Remove Slack bold formatting
                        .replacingOccurrences(of: "_", with: "")  // Remove Slack italic formatting
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Parse time from "시간:" or "일시:" format
        if let timeRange = text.range(of: #"(시간|일시):\s*([^\n]+)"#, options: .regularExpression) {
            let timeText = String(text[timeRange])
                .replacingOccurrences(of: "시간:", with: "")
                .replacingOccurrences(of: "일시:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            scheduledTime = parseKoreanDateTime(timeText)
        }

        // Parse location from "장소: ..." format
        if let locationRange = text.range(of: #"장소:\s*([^\n]+)"#, options: .regularExpression) {
            location = String(text[locationRange])
                .replacingOccurrences(of: "장소:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Parse links (flexible approach)
        // First try to find link after "회의록:", "링크:", "문서:" etc.
        let linkPrefixes = ["회의록:", "링크:", "문서:", "노션:", "notion:", "link:", "doc:"]
        for prefix in linkPrefixes {
            if let linkRange = text.range(of: #"\#(prefix)\s*(https?://[^\s]+)"#, options: .regularExpression) {
                let linkText = String(text[linkRange])
                    .replacingOccurrences(of: prefix, with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                notionLink = linkText
                break
            }
        }

        // If no labeled link found, extract any URL from the message
        if notionLink == nil {
            if let regex = try? NSRegularExpression(pattern: #"https?://[^\s]+"#, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                if let firstMatch = matches.first, let range = Range(firstMatch.range, in: text) {
                    notionLink = String(text[range])
                }
            }
        }

        // Must have at least title and time to be valid
        guard let validTitle = title, let validTime = scheduledTime else {
            return nil
        }

        return (validTitle, validTime, location, notionLink, "")
    }

    /// Parse Korean date/time format
    /// Examples: "11월 20일(목) 오후 2시~", "11/20(목) 오후 4시~", "11/28 14:00", "오늘 오후 3시"
    private func parseKoreanDateTime(_ text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        // Remove trailing ~ and whitespace
        let cleaned = text
            .replacingOccurrences(of: "~", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔍 Parsing date/time: '\(cleaned)'")

        // Parse "11월 20일(목) 오후 2시" format
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,2})월\s*(\d{1,2})일[^\d]*(오전|오후)?\s*(\d{1,2})시"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let month = Int((cleaned as NSString).substring(with: match.range(at: 1)))
                let day = Int((cleaned as NSString).substring(with: match.range(at: 2)))

                // Check if 오전/오후 group matched
                let ampmRange = match.range(at: 3)
                var isPM = false
                var ampmText = ""
                if ampmRange.location != NSNotFound {
                    ampmText = (cleaned as NSString).substring(with: ampmRange)
                    isPM = (ampmText == "오후")
                }

                var hour = Int((cleaned as NSString).substring(with: match.range(at: 4))) ?? 0

                print("   📅 Matched: \(month ?? 0)월 \(day ?? 0)일 \(ampmText.isEmpty ? "(시간 미지정)" : ampmText) \(hour)시")

                // Convert to 24-hour format
                if isPM && hour < 12 {
                    hour += 12
                } else if !isPM && hour == 12 {
                    hour = 0
                }

                components.month = month
                components.day = day
                components.hour = hour
                components.minute = 0

                // If month/day is in the past, assume next year
                if let date = calendar.date(from: components), date < now {
                    components.year = (components.year ?? 0) + 1
                }

                let result = calendar.date(from: components)
                print("   ✅ Parsed date: \(result?.description ?? "nil") (hour=\(hour))")
                return result
            }
        }

        // Parse "11/20(목) 오후 4시" format
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,2})/(\d{1,2})[^\d]*(오전|오후)?\s*(\d{1,2})시"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let month = Int((cleaned as NSString).substring(with: match.range(at: 1)))
                let day = Int((cleaned as NSString).substring(with: match.range(at: 2)))
                let isPM = match.range(at: 3).location != NSNotFound ?
                    (cleaned as NSString).substring(with: match.range(at: 3)) == "오후" : false
                var hour = Int((cleaned as NSString).substring(with: match.range(at: 4))) ?? 0

                // Convert to 24-hour format
                if isPM && hour < 12 {
                    hour += 12
                } else if !isPM && hour == 12 {
                    hour = 0
                }

                components.month = month
                components.day = day
                components.hour = hour
                components.minute = 0

                // If month/day is in the past, assume next year
                if let date = calendar.date(from: components), date < now {
                    components.year = (components.year ?? 0) + 1
                }

                return calendar.date(from: components)
            }
        }

        // Parse "14:00" or "오후 4시" format
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let hour = Int((cleaned as NSString).substring(with: match.range(at: 1))) ?? 0
                let minute = Int((cleaned as NSString).substring(with: match.range(at: 2))) ?? 0

                components.hour = hour
                components.minute = minute
                return calendar.date(from: components)
            }
        }

        // Parse "오전/오후 X시" format
        if let regex = try? NSRegularExpression(pattern: #"(오전|오후)\s*(\d{1,2})시"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let isPM = (cleaned as NSString).substring(with: match.range(at: 1)) == "오후"
                var hour = Int((cleaned as NSString).substring(with: match.range(at: 2))) ?? 0

                if isPM && hour < 12 {
                    hour += 12
                } else if !isPM && hour == 12 {
                    hour = 0
                }

                components.hour = hour
                components.minute = 0
                return calendar.date(from: components)
            }
        }

        return nil
    }

    /// Slack 메시지를 Meeting 객체로 변환
    private func convertToMeeting(_ message: SlackMessage, configID: String) -> Meeting? {
        print("📝 Converting message (ts: \(message.ts)):")
        print("   Text preview: '\(message.text.prefix(100))...'")

        // Try parsing Korean format first
        if let parsedData = parseKoreanMeetingFormat(from: message.text) {
            print("   ✅ Korean format parsed successfully")
            print("   Title: \(parsedData.title)")
            print("   Time: \(parsedData.scheduledTime)")
            print("   Location: \(parsedData.location ?? "none")")
            print("   Notion: \(parsedData.notionLink ?? "none")")

            return Meeting(
                slackTimestamp: message.ts,
                title: parsedData.title,
                scheduledTime: parsedData.scheduledTime,
                slackConfigID: configID,
                location: parsedData.location,
                notionLink: parsedData.notionLink,
                note: parsedData.note
            )
        }

        // Fallback to basic parsing
        print("   ⚠️ Falling back to basic parsing")
        let scheduledTime = parseMeetingTime(from: message.text) ?? Date()
        let title = extractTitle(from: message.text)

        return Meeting(
            slackTimestamp: message.ts,
            title: title,
            scheduledTime: scheduledTime,
            slackConfigID: configID
        )
    }

    /// 메시지에서 제목 추출
    private func extractTitle(from text: String) -> String {
        // 첫 줄 또는 100자까지
        let lines = text.components(separatedBy: .newlines)
        let firstLine = lines.first ?? text

        let cleaned = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "📅 회의:", with: "")
            .replacingOccurrences(of: "[Meeting]", with: "")
            .replacingOccurrences(of: "[미팅]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(cleaned.prefix(100))
    }

    /// 메시지에서 회의 시간 파싱
    private func parseMeetingTime(from text: String) -> Date? {
        // 여러 날짜 형식 시도
        let dateFormats = [
            // "2025-11-28 14:00"
            "yyyy-MM-dd HH:mm",
            // "2025/11/28 14:00"
            "yyyy/MM/dd HH:mm",
            // "11월 28일 14:00"
            "M월 d일 HH:mm",
            // "11/28 14:00"
            "M/d HH:mm",
            // "14:00" (오늘 날짜로 가정)
            "HH:mm"
        ]

        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ko_KR")

            // 텍스트에서 날짜 패턴 찾기
            if let dateString = extractDateString(from: text, matching: format),
               let date = formatter.date(from: dateString) {
                // "HH:mm" 형식인 경우 오늘 날짜 추가
                if format == "HH:mm" {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.hour, .minute], from: date)
                    return calendar.date(bySettingHour: components.hour ?? 0,
                                       minute: components.minute ?? 0,
                                       second: 0,
                                       of: Date())
                }
                return date
            }
        }

        // 파싱 실패 시 nil 반환 (호출자가 기본값 사용)
        return nil
    }

    /// 텍스트에서 날짜 문자열 추출
    private func extractDateString(from text: String, matching format: String) -> String? {
        // 간단한 정규식 패턴 매칭
        let patterns: [String: String] = [
            "yyyy-MM-dd HH:mm": #"\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}"#,
            "yyyy/MM/dd HH:mm": #"\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}"#,
            "M월 d일 HH:mm": #"\d{1,2}월\s+\d{1,2}일\s+\d{2}:\d{2}"#,
            "M/d HH:mm": #"\d{1,2}/\d{1,2}\s+\d{2}:\d{2}"#,
            "HH:mm": #"\d{2}:\d{2}"#
        ]

        guard let pattern = patterns[format] else { return nil }

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            return String(text[Range(match.range, in: text)!])
        }

        return nil
    }
}

// MARK: - Slack 메시지 템플릿 예시
/*
 추천 Slack 메시지 형식:

 📅 회의: 디자인 리뷰
 2025-11-28 14:00
 참석자: @team

 또는:

 [Meeting] 주간 회의
 11월 28일 14:00

 또는:

 [미팅] 스프린트 플래닝
 14:00
 */
