//
//  AumenoApp.swift
//  Aumeno
//
//  Created by 나경호 on 11/28/25.
//

import SwiftUI

@main
struct AumenoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MeetingListView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove default "New Window" command
            CommandGroup(replacing: .newItem) {}

            // Add custom commands
            CommandGroup(after: .appInfo) {
                Button("Sync Now") {
                    NotificationCenter.default.post(name: NSNotification.Name("ManualSync"), object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
