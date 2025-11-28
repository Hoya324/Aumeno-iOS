//
//  MeetingViewModel.swift
//  Aumeno
//
//  Created by Claude Code
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class MeetingViewModel: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?

    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 10.0
    private var lastFetchedTimestamp: String?

    init() {
        loadMeetingsFromDatabase()
        startPolling()
        requestNotificationPermission()

        // MeetingScheduler 시작 (회의 시간 자동 알림)
        Task { @MainActor in
            MeetingScheduler.shared.startScheduler()
        }
    }

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - Polling

    func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncWithSlack()
            }
        }
        print("✅ Polling started (every \(pollingInterval)s)")
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("⏸️ Polling stopped")
    }

    // MARK: - Sync Logic

    func syncWithSlack() async {
        guard !isSyncing else { return }

        isSyncing = true
        errorMessage = nil

        do {
            // 모든 활성화된 Slack 설정에서 메시지 가져오기
            let fetchedMeetings = try await SlackService.shared.fetchMessagesFromAllConfigurations()

            // Filter new meetings only (중복 방지 + 삭제된 메시지 제외)
            let newMeetings = fetchedMeetings.filter { meeting in
                // 이미 존재하는 회의는 제외
                if (try? DatabaseManager.shared.meetingExists(id: meeting.id)) ?? false {
                    return false
                }

                // 삭제된 Slack 메시지는 제외
                if let slackTimestamp = meeting.slackTimestamp,
                   (try? DatabaseManager.shared.isDeletedSlackMessage(slackTimestamp)) ?? false {
                    print("   ⏭️ Skipping deleted message: \(meeting.title)")
                    return false
                }

                return true
            }

            print("📊 Sync stats: \(fetchedMeetings.count) fetched, \(newMeetings.count) new")

            // Save new meetings to database
            for meeting in newMeetings {
                try DatabaseManager.shared.insertMeeting(meeting)
            }

            // Reload from database
            loadMeetingsFromDatabase()

            // Slack 메시지는 MeetingScheduler가 자동으로 처리
            // (즉시 알림 대신 예정 시간에 알림)

            print("✅ Synced: \(newMeetings.count) new meeting(s)")

        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
            print("❌ Sync error: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Database Operations

    private func loadMeetingsFromDatabase() {
        do {
            meetings = try DatabaseManager.shared.fetchAllMeetings()
        } catch {
            errorMessage = "Failed to load meetings: \(error.localizedDescription)"
            print("❌ Load error: \(error)")
        }
    }

    func updateNote(for meetingID: String, note: String) {
        do {
            try DatabaseManager.shared.updateMeetingNote(id: meetingID, note: note)
            loadMeetingsFromDatabase()
            print("✅ Note updated for meeting: \(meetingID)")
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
            print("❌ Update error: \(error)")
        }
    }

    func deleteMeeting(_ meeting: Meeting) {
        do {
            try DatabaseManager.shared.deleteMeeting(id: meeting.id)
            loadMeetingsFromDatabase()
            print("✅ Meeting deleted: \(meeting.id)")
        } catch {
            errorMessage = "Failed to delete meeting: \(error.localizedDescription)"
            print("❌ Delete error: \(error)")
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Manual Actions

    func manualSync() {
        Task {
            await syncWithSlack()
        }
    }

    // MARK: - Meeting Management

    /// 회의 저장 (수동 생성 또는 수정)
    func saveMeeting(_ meeting: Meeting) {
        do {
            try DatabaseManager.shared.insertMeeting(meeting)
            loadMeetingsFromDatabase()
            print("✅ Meeting saved: \(meeting.title)")

            // 새 회의라면 스케줄러에 등록
            if !meeting.notificationSent && meeting.scheduledTime > Date() {
                Task {
                    await MeetingScheduler.shared.scheduleMeetingNotification(meeting)
                }
            }
        } catch {
            errorMessage = "Failed to save meeting: \(error.localizedDescription)"
            print("❌ Save error: \(error)")
        }
    }

    // MARK: - Onboarding

    /// 첫 실행 체크 (Slack 설정이 없으면 온보딩 필요)
    func checkFirstLaunch(completion: @escaping (Bool) -> Void) {
        do {
            let hasConfigs = try ConfigurationManager.shared.hasAnyConfiguration()
            completion(!hasConfigs)
        } catch {
            print("❌ Failed to check configurations: \(error)")
            completion(false)
        }
    }
}
