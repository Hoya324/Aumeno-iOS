//
//  AumenoApp.swift
//  Aumeno
//
//  Created by 나경호 on 11/28/25.
//

import SwiftUI
import AppKit

@main
struct AumenoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = MeetingViewModel()

    var body: some Scene {
        WindowGroup {
            CalendarView()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Sync Now") {
                    NotificationCenter.default.post(name: NSNotification.Name("ManualSync"), object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        
        MenuBarExtra("Aumeno", systemImage: "calendar.badge.clock") {
            menuBarContentView
                .environmentObject(viewModel)
        }
    }
    
    @ViewBuilder
    private var menuBarContentView: some View {
        let todaySchedules = viewModel.schedules.filter {
            Calendar.current.isDateInToday($0.startDateTime)
        }.sorted(by: { $0.startDateTime < $1.startDateTime })
        
        VStack(alignment: .leading) {
            if todaySchedules.isEmpty {
                Text("No schedules for today.")
                    .padding()
            } else {
                ForEach(todaySchedules) { schedule in
                    HStack {
                        if let hex = schedule.workspaceColor, let nsColor = NSColor(hex: hex) {
                            Circle()
                                .fill(Color(nsColor))
                                .frame(width: 8, height: 8)
                        }
                        VStack(alignment: .leading) {
                            Text(schedule.title)
                                .font(.headline)
                            Text(schedule.startDateTime, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            Button("Open Aumeno") {
                // Logic to open the main window
                 NSApp.activate(ignoringOtherApps: true)
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
    }
}
