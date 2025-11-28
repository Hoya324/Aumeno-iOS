//
//  AppDelegate.swift
//  Aumeno
//
//  Created by Claude Code
//

import Cocoa
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var floatingWindow: FloatingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // MeetingScheduler 콜백 설정 (회의 시간에 자동으로 노트 창 열기)
        Task { @MainActor in
            MeetingScheduler.shared.onMeetingTime = { [weak self] meeting in
                self?.openNoteWindow(for: meeting.id)
            }
        }

        print("✅ App delegate initialized")
    }

    // MARK: - Notification Handling

    // Called when notification is clicked
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let meetingID = userInfo["meetingID"] as? String {
            openNoteWindow(for: meetingID)
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

    private func openNoteWindow(for meetingID: String) {
        // Find meeting in database
        guard let meetings = try? DatabaseManager.shared.fetchAllMeetings(),
              let meeting = meetings.first(where: { $0.id == meetingID }) else {
            print("❌ Meeting not found: \(meetingID)")
            return
        }

        // Create view model (shared instance would be better in production)
        let viewModel = MeetingViewModel()

        // Close existing window
        floatingWindow?.close()

        // Create and show floating window
        let noteView = NotePopupView(viewModel: viewModel, meeting: meeting)
        floatingWindow = FloatingWindowController(rootView: noteView)
        floatingWindow?.show()

        print("✅ Opened note window for: \(meetingID)")
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
