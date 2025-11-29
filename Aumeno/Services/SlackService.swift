//
//  SlackService.swift
//  Aumeno
//
//  Created by Hoya324
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

    private var defaultMeetingTagID: String?
    private var defaultMentionTagID: String?

    private init() {
        // Fetch default tag IDs during initialization
        do {
            let allTags = try DatabaseManager.shared.fetchAllTags()
            defaultMeetingTagID = allTags.first(where: { $0.name == "회의" })?.id
            defaultMentionTagID = allTags.first(where: { $0.name == "언급됨" })?.id
            print("✅ [SlackService] Default Meeting Tag ID: \(defaultMeetingTagID ?? "nil")")
            print("✅ [SlackService] Default Mention Tag ID: \(defaultMentionTagID ?? "nil")")
        } catch {
            print("❌ [SlackService] Error fetching default tags: \(error)")
        }
    }

    // MARK: - Fetch Messages (다중 설정 지원)

    /// 특정 Slack 설정으로 메시지 가져오기
    func fetchSchedules(for config: SlackConfiguration, limit: Int = 100) async throws -> [Schedule] {
        print("▶️ [SlackService] Starting fetch for config: \(config.name) (\(config.channelName))")
        guard config.isEnabled else {
            print("   ... ⏭️ Config is disabled. Skipping.")
            return []
        }

        guard let url = URL(string: "\(baseURL)/conversations.history") else {
            throw SlackError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let twoWeeksAgo = Date().addingTimeInterval(-14 * 24 * 60 * 60)
        let oldestTimestamp = String(twoWeeksAgo.timeIntervalSince1970)

        let body: [String: Any] = [
            "channel": config.channelID,
            "limit": limit,
            "oldest": oldestTimestamp
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("   ... ❌ Invalid HTTP Response: \(response)")
                throw SlackError.invalidResponse
            }

            let decoder = JSONDecoder()
            let slackResponse = try decoder.decode(SlackResponse.self, from: data)

            if !slackResponse.ok {
                print("   ... ❌ Slack API Error: \(slackResponse.error ?? "Unknown")")
                throw SlackError.apiError(slackResponse.error ?? "Unknown error")
            }

            guard let messages = slackResponse.messages else {
                print("   ... ✅ No messages found.")
                return []
            }

            let validMessages = messages.filter { $0.type == "message" && $0.user != nil }
            print("   ... 📬 Fetched \(validMessages.count) valid message(s) from API.")

            let schedules = validMessages.compactMap { message in
                convertToSchedule(message, config: config)
            }

            print("   ... ✅ Converted to \(schedules.count) schedule(s).")
            print("⏹️ [SlackService] Finished fetch for config: \(config.name).")
            return schedules

        } catch let error as SlackError {
            print("   ... ❌ SlackError during fetch: \(error)")
            throw error
        } catch let error as DecodingError {
            print("   ... ❌ DecodingError during fetch: \(error)")
            throw SlackError.decodingError(error)
        } catch {
            print("   ... ❌ Unknown network error during fetch: \(error)")
            throw SlackError.networkError(error)
        }
    }

    /// 모든 활성화된 설정에서 메시지 가져오기
    func fetchSchedulesFromAllConfigurations() async throws -> [Schedule] {
        let configurations = try DatabaseManager.shared.fetchEnabledConfigurations()
        print("▶️ [SlackService] Fetching from \(configurations.count) enabled configuration(s).")
        var allSchedules: [Schedule] = []

        for config in configurations {
            do {
                let schedules = try await fetchSchedules(for: config)
                allSchedules.append(contentsOf: schedules)
            } catch {
                print("⚠️ [SlackService] Failed to fetch from config '\(config.name)': \(error)")
            }
        }
        print("⏹️ [SlackService] Total schedules fetched: \(allSchedules.count).")
        return allSchedules
    }

    // MARK: - Message Parsing & Conversion

    /// Slack 메시지를 Schedule 객체로 변환
    private func convertToSchedule(_ message: SlackMessage, config: SlackConfiguration) -> Schedule? {

        // Use teamID from config if available, otherwise construct deep link without it.
        let teamParam = config.teamID.map { "team=\($0)&" } ?? ""
        let deepLink = "slack://channel?\(teamParam)id=\(config.channelID)&message=\(message.ts)"

        // 1. 멘션 확인
        if let userID = config.userID, !userID.isEmpty, message.text.contains("<@\(userID)>") {
            var allLinks = extractLinks(from: message.text) // Extract links from message text
            allLinks.insert(deepLink, at: 0) // Always include deepLink


            
            return Schedule(
                slackTimestamp: message.ts,
                messageText: message.text, // This is the 'messageText' parameter
                workspaceID: config.id,
                channelID: config.channelID,
                channelName: config.channelName,
                slackLink: deepLink,
                workspaceColor: config.color,
                links: allLinks.isEmpty ? nil : allLinks,
                tagID: defaultMentionTagID, // Use internal defaultMentionTagID
                startDateTime: Date() // Mentions happen now
            )
        }

        // 2. 키워드 필터링
        if config.shouldFilterByKeywords && !config.matchesKeywords(message.text) {
             print("   [Converter] ⏭️ SKIPPED: Does not match keywords.")
             return nil
        }

        // 3. 회의 형식 파싱
        if let parsedData = parseKoreanMeetingFormat(from: message.text) {
            var allLinks = parsedData.links ?? []
            allLinks.insert(deepLink, at: 0)
            
            print("   [Converter] ✅ SUCCESS: Parsed as a meeting titled '\(parsedData.title)'. Found \(allLinks.count) links.")
            return Schedule(
                slackTimestamp: message.ts,
                title: parsedData.title,
                startDateTime: parsedData.scheduledTime, // Use startDateTime
                endDateTime: nil, // No end time from parser
                workspaceID: config.id,
                channelID: config.channelID,
                channelName: config.channelName,
                slackLink: deepLink,
                workspaceColor: config.color,
                location: parsedData.location,
                links: allLinks,
                tagID: defaultMeetingTagID
            )
        }
        
        return nil
    }

    /// Extract all URLs from a given text
    private func extractLinks(from text: String) -> [String] {
        var links: [String] = []
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                var urlString = String(text[range])
                if urlString.starts(with: "<") { urlString.removeFirst() }
                if let pipeIndex = urlString.firstIndex(of: "|") {
                    urlString = String(urlString[..<pipeIndex])
                } else if urlString.hasSuffix(">") {
                    urlString.removeLast()
                }
                links.append(urlString)
            }
        }
        return links
    }

    /// Parse Korean meeting notice format
    private func parseKoreanMeetingFormat(from text: String) -> (title: String, scheduledTime: Date, location: String?, links: [String]?, note: String)? {
        var title: String?
        var scheduledTime: Date?
        var location: String?
        
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]"#) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) {
                    let captured = String(text[range])
                    title = captured
                        .replacingOccurrences(of: "*", with: "")
                        .replacingOccurrences(of: "_", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        if let timeRange = text.range(of: #"(시간|일시):\s*([^\n]+)"#, options: .regularExpression) {
            let timeText = String(text[timeRange])
                .replacingOccurrences(of: "시간:", with: "")
                .replacingOccurrences(of: "일시:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            scheduledTime = parseKoreanDateTime(timeText)
        }

        if let locationRange = text.range(of: #"장소:\s*([^\n]+)"#, options: .regularExpression) {
            location = String(text[locationRange])
                .replacingOccurrences(of: "장소:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let links = extractLinks(from: text)

        guard let validTitle = title, let validTime = scheduledTime else {
            return nil
        }

        return (validTitle, validTime, location, links.isEmpty ? nil : links, "")
    }

    private func parseKoreanDateTime(_ text: String) -> Date? {

        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        let cleaned = text
            .replacingOccurrences(of: "~", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Pattern 1: "MM월 dd일 (요일) 오전/오후 HH시"
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,2})월\s*(\d{1,2})일(?:\s*\([가-힣]+\))?\s*(오전|오후)?\s*(\d{1,2})시"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let month = Int((cleaned as NSString).substring(with: match.range(at: 1)))
                let day = Int((cleaned as NSString).substring(with: match.range(at: 2)))
                
                var isPM = false
                let ampmNSRange = match.range(at: 3) // Now this correctly points to AM/PM
                if ampmNSRange.location != NSNotFound, let ampmRange = Range(ampmNSRange, in: cleaned) {
                    let ampmStr = String(cleaned[ampmRange])
                    isPM = (ampmStr == "오후")
                }

                var hour = Int((cleaned as NSString).substring(with: match.range(at: 4))) ?? 0

                if isPM && hour < 12 {
                    hour += 12
                } else if !isPM && hour == 12 { // "오전 12시" is midnight (00:00)
                    hour = 0
                }

                components.month = month
                components.day = day
                components.hour = hour
                components.minute = 0

                if var potentialDate = calendar.date(from: components) {
                    if let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now),
                       potentialDate < threeMonthsAgo {
                        components.year = (components.year ?? calendar.component(.year, from: now)) + 1
                        potentialDate = calendar.date(from: components) ?? potentialDate
                    }
                    return potentialDate
                }
            }
        }

        // Pattern 2: "MM/dd (요일) 오전/오후 HH시"
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,2})/(\d{1,2})(?:\s*\([가-힣]+\))?\s*(오전|오후)?\s*(\d{1,2})시"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let month = Int((cleaned as NSString).substring(with: match.range(at: 1)))
                let day = Int((cleaned as NSString).substring(with: match.range(at: 2)))
                
                var isPM = false
                let ampmNSRange = match.range(at: 3) // Now this correctly points to AM/PM
                if ampmNSRange.location != NSNotFound, let ampmRange = Range(ampmNSRange, in: cleaned) {
                    let ampmStr = String(cleaned[ampmRange])
                    isPM = (ampmStr == "오후")
                }

                var hour = Int((cleaned as NSString).substring(with: match.range(at: 4))) ?? 0

                if isPM && hour < 12 {
                    hour += 12
                } else if !isPM && hour == 12 {
                    hour = 0
                }

                components.month = month
                components.day = day
                components.hour = hour
                components.minute = 0

                if var potentialDate = calendar.date(from: components) {
                    if let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now),
                       potentialDate < threeMonthsAgo {
                        components.year = (components.year ?? calendar.component(.year, from: now)) + 1
                        potentialDate = calendar.date(from: components) ?? potentialDate
                    }
                    return potentialDate
                }
            }
        }

        // Pattern 2: "MM/dd 오전/오후 HH시"
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,2})/(\d{1,2})[^\d]*(오전|오후)?\s*(\d{1,2})시"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let month = Int((cleaned as NSString).substring(with: match.range(at: 1)))
                let day = Int((cleaned as NSString).substring(with: match.range(at: 2)))
                
                var isPM = false
                let ampmNSRange = match.range(at: 3)
                if ampmNSRange.location != NSNotFound, let ampmRange = Range(ampmNSRange, in: cleaned) {
                    let ampmStr = String(cleaned[ampmRange])
                    isPM = (ampmStr == "오후")
                }

                var hour = Int((cleaned as NSString).substring(with: match.range(at: 4))) ?? 0

                if isPM && hour < 12 {
                    hour += 12
                } else if !isPM && hour == 12 {
                    hour = 0
                }

                components.month = month
                components.day = day
                components.hour = hour
                components.minute = 0

                if var potentialDate = calendar.date(from: components) {
                    if let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now),
                       potentialDate < threeMonthsAgo {
                        components.year = (components.year ?? calendar.component(.year, from: now)) + 1
                        potentialDate = calendar.date(from: components) ?? potentialDate
                    }
                    return potentialDate
                }
            }
        }

        // Pattern 3: "HH:mm" (assumes today)
        if let regex = try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})$"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                components.hour = Int((cleaned as NSString).substring(with: match.range(at: 1))) ?? 0
                components.minute = Int((cleaned as NSString).substring(with: match.range(at: 2))) ?? 0
                
                if let date = calendar.date(from: components) {
                    return date
                }
            }
        }

        // Pattern 4: "오전/오후 HH시" (assumes today)
        if let regex = try? NSRegularExpression(pattern: #"(오전|오후)\s*(\d{1,2})시"#) {
            if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                let isPM = (cleaned as NSString).substring(with: match.range(at: 1)) == "오후"
                var hour = Int((cleaned as NSString).substring(with: match.range(at: 2))) ?? 0

                if isPM && hour < 12 { hour += 12 }
                else if !isPM && hour == 12 { hour = 0 }

                components.hour = hour
                components.minute = 0
                
                if let date = calendar.date(from: components) {
                    return date
                }
            }
        }
        return nil
    }
}
