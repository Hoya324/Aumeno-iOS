//
//  MeetingScheduler.swift
//  Aumeno
//
//  Created by Hoya324
//

import Foundation
import UserNotifications
import Combine

struct Constants {
    static let notificationEnabledKey = "notificationEnabled"
}

extension UserDefaults {
    var areNotificationsEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Constants.notificationEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.notificationEnabledKey)
        }
    }
}

/// 스케줄링 및 자동 알림/노트 오픈을 담당하는 서비스
@MainActor
final class MeetingScheduler: ObservableObject {
    static let shared = MeetingScheduler()

    private var checkTimer: Timer?
    private let checkInterval: TimeInterval = 60.0 // 1분마다 체크
    private var notifiedSchedules: Set<String> = [] // 중복 알림 방지

    // AppDelegate가 이 클로저를 설정하여 노트 창을 열 수 있게 함
    var onScheduleTime: ((Schedule) -> Void)?

    private init() {}



    // MARK: - Lifecycle


    func startScheduler() {
        stopScheduler()

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkUpcomingSchedules()
            }
        }

        // 즉시 한번 체크
        Task {
            await checkUpcomingSchedules()
        }
    }

    func stopScheduler() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Schedule Checks

    private func checkUpcomingSchedules() async {
        do {
            let upcomingSchedules = try DatabaseManager.shared.fetchUpcomingSchedules(within: 5)

            for schedule in upcomingSchedules {
                guard !notifiedSchedules.contains(schedule.id) else {
                    print("   [Scheduler] ⏭️ Skipping already notified schedule: \(schedule.title)")
                    continue
                }

                let timeUntilSchedule = schedule.startDateTime.timeIntervalSince(Date())
                print("   [Scheduler] ⏰ '\(schedule.title)' is in \(String(format: "%.1f", timeUntilSchedule)) seconds.")

                if timeUntilSchedule <= 0 {
                    await handleScheduleStart(schedule)
                } else if timeUntilSchedule <= 300 {
                    await sendAdvanceNotification(schedule, minutesUntil: Int(timeUntilSchedule / 60))
                }
            }
        } catch {
            print("❌ [Scheduler] Failed to check upcoming schedules: \(error)")
        }
    }

    private func handleScheduleStart(_ schedule: Schedule) async {
        print("🔔 [Scheduler] Triggering start for schedule: \(schedule.title)")

        await sendScheduleStartNotification(schedule)

        if let onScheduleTime = onScheduleTime {
            print("   [Scheduler] ✅ Calling onScheduleTime callback.")
            onScheduleTime(schedule)
        } else {
            print("   [Scheduler] ⚠️ onScheduleTime callback is not set.")
        }

        do {
            try DatabaseManager.shared.markScheduleNotificationSent(id: schedule.id)
            notifiedSchedules.insert(schedule.id)
            print("   [Scheduler] ✅ Marked notification as sent in DB.")
        } catch {
            print("   [Scheduler] ❌ Failed to mark notification sent: \(error)")
        }
    }

    // MARK: - Notifications

    private func sendScheduleStartNotification(_ schedule: Schedule) async {
        guard UserDefaults.standard.areNotificationsEnabled else {
            print("🔔 [Scheduler] Notifications are disabled by user. Skipping start notification for: \(schedule.title)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "\(schedule.typeDisplayName) 시작!"
        content.body = schedule.title
        content.sound = .default
        content.userInfo = ["scheduleID": schedule.id]

        let request = UNNotificationRequest(
            identifier: "schedule-start-\(schedule.id)",
            content: content,
            trigger: nil // 즉시 전송
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notification sent for schedule: \(schedule.title)")
        } catch {
            print("❌ Failed to send notification: \(error)")
        }
    }

    private func sendAdvanceNotification(_ schedule: Schedule, minutesUntil: Int) async {
        guard UserDefaults.standard.areNotificationsEnabled else {
            print("🔔 [Scheduler] Notifications are disabled by user. Skipping advance notification for: \(schedule.title)")
            return
        }
        
        // 사전 알림은 한번만 (중복 방지)
        let notificationID = "advance-\(schedule.id)-\(minutesUntil)"
        guard !notifiedSchedules.contains(notificationID) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(minutesUntil)분 후 \(schedule.typeDisplayName)"
        content.body = schedule.title
        content.sound = .default
        content.userInfo = ["scheduleID": schedule.id]

        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            notifiedSchedules.insert(notificationID)
            print("✅ Advance notification sent: \(minutesUntil)min until schedule")
        } catch {
            print("❌ Failed to send advance notification: \(error)")
        }
    }

    // MARK: - Manual Scheduling

    /// 특정 스케줄에 대한 알림 예약 (iOS 스타일)
    func scheduleNotification(_ schedule: Schedule) async {
        let content = UNMutableNotificationContent()
        content.title = "\(schedule.typeDisplayName) 시작"
        content.body = schedule.title
        content.sound = .default
        content.userInfo = ["scheduleID": schedule.id]

        // 스케줄 시간에 알림
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: schedule.startDateTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "scheduled-\(schedule.id)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled notification for: \(schedule.formattedStartDateTime)")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }

    /// 스케줄 알림 취소
    func cancelNotification(_ scheduleID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "scheduled-\(scheduleID)",
                "schedule-start-\(scheduleID)"
            ]
        )
        notifiedSchedules.remove(scheduleID)
    }

    /// 모든 알림 상태 리셋
    func resetNotificationState() {
        notifiedSchedules.removeAll()
    }
}
