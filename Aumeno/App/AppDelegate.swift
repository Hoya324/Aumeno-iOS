//
//  AppDelegate.swift
//  Aumeno
//
//  Created by Hoya324
//

import Cocoa
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var floatingWindow: FloatingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission denied.")
            }
        }
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // MeetingScheduler 콜백 설정 (회의 시간에 자동으로 노트 창 열기)
        Task { @MainActor in
            MeetingScheduler.shared.onScheduleTime = { [weak self] schedule in
                self?.openNoteWindow(for: schedule.id)
            }
        }
    }

    // MARK: - Notification Handling

    // Called when notification is clicked
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let scheduleID = userInfo["scheduleID"] as? String {
            openNoteWindow(for: scheduleID)
        }

        completionHandler()
    }

    // Called when notification is delivered while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is active
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Window Management

    private func openNoteWindow(for scheduleID: String) {
        // Find schedule in database
        guard let schedules = try? DatabaseManager.shared.fetchAllSchedules(),
              let schedule = schedules.first(where: { $0.id == scheduleID }) else {
            return
        }

        // Create view model (shared instance would be better in production)
        let viewModel = MeetingViewModel()

        // Close existing window
        floatingWindow?.close()

        // Create and show floating window
        let noteView = NotePopupView(viewModel: viewModel, schedule: schedule)
        floatingWindow = FloatingWindowController(rootView: noteView)
        floatingWindow?.show()
    }

    // MARK: - App Lifecycle

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even when all windows are closed
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
