//
//  ScheduleViewModel.swift
//  Aumeno
//
//  Created by Hoya324
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class MeetingViewModel: ObservableObject {
    @Published var schedules: [Schedule] = []
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?
    @Published var tags: [Tag] = [] // New property

    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 10.0
    private var lastFetchedTimestamp: String?

    init() {
        loadSchedulesFromDatabase()
        fetchTags() // Call fetchTags on initialization
        startPolling()
        requestNotificationPermission()

        // MeetingScheduler를 새로운 Schedule 모델로 시작
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
        guard !isSyncing else {
            print("[ViewModel] ⚠️ Sync already in progress. Skipping.")
            return
        }

        print("▶️ [ViewModel] Starting Slack sync...")
        isSyncing = true
        errorMessage = nil
        
        defer {
            Task { @MainActor in
                isSyncing = false
                print("⏹️ [ViewModel] Sync finished.")
            }
        }

        do {
            let fetchedSchedules = try await SlackService.shared.fetchSchedulesFromAllConfigurations()
            print("   [ViewModel] Fetched \(fetchedSchedules.count) total schedules from SlackService.")

            let newSchedules = fetchedSchedules.filter { schedule in
                if (try? DatabaseManager.shared.scheduleExists(id: schedule.id)) ?? false {
                    return false
                }
                if let slackTimestamp = schedule.slackTimestamp,
                   (try? DatabaseManager.shared.isDeletedSlackMessage(slackTimestamp)) ?? false {
                    return false
                }
                return true
            }
            
            print("   [ViewModel] Found \(newSchedules.count) new schedules to be saved.")

            if !newSchedules.isEmpty {
                for schedule in newSchedules {
                    print("      [ViewModel] 💾 Saving schedule: '\(schedule.title)' for \(schedule.formattedStartDateTime)")
                    try DatabaseManager.shared.insertSchedule(schedule)
                }
                // Reload from database only if new items were added
                loadSchedulesFromDatabase()
            }

        } catch {
            let errorMsg = "Sync failed: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ [ViewModel] \(errorMsg)")
        }
    }

    // MARK: - Database Operations

    private func loadSchedulesFromDatabase() {
        print("🔄 [ViewModel] Loading schedules from database...")
        do {
            let oldSchedules = schedules
            schedules = try DatabaseManager.shared.fetchAllSchedules()
            print("   [ViewModel] ✅ Loaded \(schedules.count) schedules.")
            if oldSchedules != schedules {
                print("   [ViewModel] ⚠️ Schedule data has changed.")
            } else {
                print("   [ViewModel] No changes in schedule data.")
            }
        } catch {
            let errorMsg = "Failed to load schedules: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ [ViewModel] \(errorMsg)")
        }
    }

    func fetchTags() {
        print("🔄 [ViewModel] Loading tags from database...")
        do {
            tags = try DatabaseManager.shared.fetchAllTags()
            print("   [ViewModel] ✅ Loaded \(tags.count) tags.")
        } catch {
            let errorMsg = "Failed to load tags: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ [ViewModel] \(errorMsg)")
        }
    }

    func updateNote(for scheduleID: String, note: String) {
        guard let index = schedules.firstIndex(where: { $0.id == scheduleID }) else {
            print("❌ [ViewModel] Could not find schedule with ID \(scheduleID) to update note.")
            return
        }
        
        var scheduleToUpdate = schedules[index]
        scheduleToUpdate.note = note
        
        // Call the generic update function
        updateSchedule(schedule: scheduleToUpdate)
    }
    
    func updateSchedule(schedule: Schedule) {
        print("▶️ [ViewModel] Updating schedule: '\(schedule.title)'")
        print("  DEBUG: Schedule to update:")
        print("    ID: \(schedule.id)")
        print("    Title: \(schedule.title)")
        print("    Start Date: \(schedule.startDateTime)")
        print("    End Date: \(schedule.endDateTime ?? Date(timeIntervalSinceReferenceDate: 0))")
        print("    Tag ID: \(schedule.tagID ?? "nil")")

        do {
            try DatabaseManager.shared.updateSchedule(schedule)
            loadSchedulesFromDatabase()
            print("   [ViewModel] ✅ Successfully updated schedule.")
        } catch {
            let errorMsg = "Failed to update schedule: \(error.localizedDescription). Full error: \(error)"
            errorMessage = errorMsg
            print("   [ViewModel] ❌ \(errorMsg)")
        }
    }

    func deleteSchedule(_ schedule: Schedule) {
        print("▶️ [ViewModel] Deleting schedule: '\(schedule.title)'")
        do {
            try DatabaseManager.shared.deleteSchedule(id: schedule.id)
            schedules.removeAll { $0.id == schedule.id }
            print("   [ViewModel] ✅ Successfully deleted schedule.")
        } catch {
            let errorMsg = "Failed to delete schedule: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("   [ViewModel] ❌ \(errorMsg)")
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

    // MARK: - Schedule Management

    /// 스케줄 저장 (수동 생성 또는 수정)
    func saveSchedule(_ schedule: Schedule) {
        print("▶️ [ViewModel] Saving schedule: '\(schedule.title)'")
        print("  DEBUG: Schedule to save:")
        print("    ID: \(schedule.id)")
        print("    Title: \(schedule.title)")
        print("    Start Date: \(schedule.startDateTime)")
        print("    End Date: \(schedule.endDateTime ?? Date(timeIntervalSinceReferenceDate: 0))")
        print("    Tag ID: \(schedule.tagID ?? "nil")")

        do {
            try DatabaseManager.shared.insertSchedule(schedule)
            loadSchedulesFromDatabase()
            fetchTags()
            print("   [ViewModel] ✅ Successfully saved schedule.")

            if !schedule.notificationSent && schedule.startDateTime > Date() {
                Task {
                    await MeetingScheduler.shared.scheduleNotification(schedule)
                }
            }
        } catch {
            let errorMsg = "Failed to save schedule: \(error.localizedDescription). Full error: \(error)"
            errorMessage = errorMsg
            print("   [ViewModel] ❌ Error saving schedule: \(errorMsg)")
        }
    }

    // MARK: - Onboarding

    /// 첫 실행 체크 (Slack 설정이 없으면 온보딩 필요)
    func checkFirstLaunch(completion: @escaping (Bool) -> Void) {
        do {
            let hasConfigs = try DatabaseManager.shared.hasAnyConfiguration()
            completion(!hasConfigs)
        } catch {
            print("❌ Failed to check configurations: \(error)")
            completion(false)
        }
    }

    // MARK: - Tag Helpers
    
    /// 지정된 tagID에 해당하는 Tag 객체를 반환합니다.
    func tag(for id: String?) -> Tag? {
        guard let id = id else { return nil }
        return tags.first(where: { $0.id == id })
    }
}
