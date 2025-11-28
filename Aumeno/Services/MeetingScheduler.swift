//
//  MeetingScheduler.swift
//  Aumeno
//
//  Created by Claude Code
//

import Foundation
import UserNotifications
import Combine

/// 회의 스케줄링 및 자동 알림/노트 오픈을 담당하는 서비스
@MainActor
final class MeetingScheduler: ObservableObject {
    static let shared = MeetingScheduler()

    private var checkTimer: Timer?
    private let checkInterval: TimeInterval = 60.0 // 1분마다 체크
    private var notifiedMeetings: Set<String> = [] // 중복 알림 방지

    // AppDelegate가 이 클로저를 설정하여 노트 창을 열 수 있게 함
    var onMeetingTime: ((Meeting) -> Void)?

    private init() {}

    // MARK: - Lifecycle

    func startScheduler() {
        stopScheduler()

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkUpcomingMeetings()
            }
        }

        // 즉시 한번 체크
        Task {
            await checkUpcomingMeetings()
        }

        print("✅ Meeting scheduler started (checking every \(Int(checkInterval))s)")
    }

    func stopScheduler() {
        checkTimer?.invalidate()
        checkTimer = nil
        print("⏸️ Meeting scheduler stopped")
    }

    // MARK: - Meeting Checks

    private func checkUpcomingMeetings() async {
        do {
            // 5분 이내 예정된 회의 가져오기
            let upcomingMeetings = try DatabaseManager.shared.fetchUpcomingMeetings(within: 5)

            for meeting in upcomingMeetings {
                // 이미 알림 보낸 회의는 스킵
                guard !notifiedMeetings.contains(meeting.id) else { continue }

                let timeUntilMeeting = meeting.scheduledTime.timeIntervalSince(Date())

                // 회의 시간이 되었거나 임박한 경우
                if timeUntilMeeting <= 0 {
                    // 회의 시작!
                    await handleMeetingStart(meeting)
                } else if timeUntilMeeting <= 300 { // 5분 이내
                    // 사전 알림
                    await sendAdvanceNotification(meeting, minutesUntil: Int(timeUntilMeeting / 60))
                }
            }
        } catch {
            print("❌ Failed to check upcoming meetings: \(error)")
        }
    }

    // MARK: - Meeting Start Handler

    private func handleMeetingStart(_ meeting: Meeting) async {
        print("🔔 Meeting starting: \(meeting.title)")

        // 1. 알림 전송
        await sendMeetingStartNotification(meeting)

        // 2. 노트 창 자동 오픈
        onMeetingTime?(meeting)

        // 3. DB에 알림 전송 표시
        do {
            try DatabaseManager.shared.markNotificationSent(id: meeting.id)
            notifiedMeetings.insert(meeting.id)
        } catch {
            print("❌ Failed to mark notification sent: \(error)")
        }
    }

    // MARK: - Notifications

    private func sendMeetingStartNotification(_ meeting: Meeting) async {
        let content = UNMutableNotificationContent()
        content.title = "회의 시작!"
        content.body = meeting.title
        content.sound = .default
        content.userInfo = ["meetingID": meeting.id]

        let request = UNNotificationRequest(
            identifier: "meeting-start-\(meeting.id)",
            content: content,
            trigger: nil // 즉시 전송
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notification sent for meeting: \(meeting.title)")
        } catch {
            print("❌ Failed to send notification: \(error)")
        }
    }

    private func sendAdvanceNotification(_ meeting: Meeting, minutesUntil: Int) async {
        // 사전 알림은 한번만 (중복 방지)
        let notificationID = "advance-\(meeting.id)-\(minutesUntil)"
        guard !notifiedMeetings.contains(notificationID) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(minutesUntil)분 후 회의"
        content.body = meeting.title
        content.sound = .default
        content.userInfo = ["meetingID": meeting.id]

        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            notifiedMeetings.insert(notificationID)
            print("✅ Advance notification sent: \(minutesUntil)min until meeting")
        } catch {
            print("❌ Failed to send advance notification: \(error)")
        }
    }

    // MARK: - Manual Scheduling

    /// 특정 회의에 대한 알림 예약 (iOS 스타일)
    func scheduleMeetingNotification(_ meeting: Meeting) async {
        let content = UNMutableNotificationContent()
        content.title = "회의 시작"
        content.body = meeting.title
        content.sound = .default
        content.userInfo = ["meetingID": meeting.id]

        // 회의 시간에 알림
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: meeting.scheduledTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "scheduled-\(meeting.id)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled notification for: \(meeting.formattedScheduledTime)")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }

    /// 회의 알림 취소
    func cancelMeetingNotification(_ meetingID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "scheduled-\(meetingID)",
                "meeting-start-\(meetingID)"
            ]
        )
        notifiedMeetings.remove(meetingID)
    }

    /// 모든 알림 상태 리셋
    func resetNotificationState() {
        notifiedMeetings.removeAll()
    }
}
