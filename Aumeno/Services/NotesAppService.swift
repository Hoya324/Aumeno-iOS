//
//  NotesAppService.swift
//  Aumeno
//
//  Created by Claude Code
//

import Foundation
import AppKit

enum NotesAppError: Error {
    case scriptExecutionFailed(String)
    case notesAppNotAvailable
}

final class NotesAppService {
    static let shared = NotesAppService()

    private init() {}

    /// Sync a meeting note to macOS Notes app using simple AppleScript
    func syncToNotesApp(meeting: Meeting) throws {
        // Prepare note content
        let noteTitle = meeting.title
        var noteBody = ""

        // Add meeting details
        noteBody += "📅 \(meeting.formattedScheduledTime)\n"

        if let location = meeting.location, !location.isEmpty {
            noteBody += "📍 \(location)\n"
        }

        if let link = meeting.notionLink, !link.isEmpty {
            noteBody += "🔗 \(link)\n"
        }

        noteBody += "\n"
        noteBody += "--- Notes ---\n"
        noteBody += meeting.note

        // Create note in Notes app (always creates new note)
        try createNoteSimple(title: noteTitle, body: noteBody)

        print("✅ Synced to Notes app: \(noteTitle)")
    }

    /// Create a new note in Notes app using proper AppleScript format
    private func createNoteSimple(title: String, body: String) throws {
        // Convert to HTML format (Notes app uses HTML for body)
        let htmlBody = convertToHTML(title: title, body: body)

        // Escape special characters for AppleScript
        let escapedTitle = escapeForAppleScript(title)
        let escapedHTMLBody = escapeForAppleScript(htmlBody)

        // Proper AppleScript using default account
        let script = """
        tell application "Notes"
            activate
            delay 2
            tell default account
                make new note at folder "Notes" with properties {name:"\(escapedTitle)", body:"\(escapedHTMLBody)"}
            end tell
        end tell
        """

        print("🔍 Creating new note in Notes app...")
        print("   Title: \(title)")
        print("   Body length: \(body.count) characters")
        print("   HTML length: \(htmlBody.count) characters")

        // Execute AppleScript
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            print("❌ Failed to create AppleScript object")
            throw NotesAppError.scriptExecutionFailed("Failed to create AppleScript")
        }

        _ = appleScript.executeAndReturnError(&error)

        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            let errorNumber = error["NSAppleScriptErrorNumber"] as? Int ?? -1
            print("❌ AppleScript error \(errorNumber): \(errorMessage)")
            throw NotesAppError.scriptExecutionFailed("\(errorMessage) (Error \(errorNumber))")
        }

        print("✅ Note created successfully in Notes app")
    }

    /// Convert plain text to HTML format for Notes app
    private func convertToHTML(title: String, body: String) -> String {
        var html = "<div>"

        // Title as H1
        html += "<h1>\(title.htmlEscaped)</h1>"

        // Body - convert newlines to <br> tags
        let lines = body.components(separatedBy: "\n")
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                html += "<br>"
            } else {
                html += "<p>\(line.htmlEscaped)</p>"
            }
        }

        html += "</div>"
        return html
    }

    /// OLD METHOD - Create or update a note in Notes app using AppleScript
    private func createOrUpdateNote_OLD(title: String, body: String) throws {
        // Check if Notes is running using NSWorkspace (more reliable than AppleScript)
        let runningApps = NSWorkspace.shared.runningApplications
        let notesIsRunning = runningApps.contains { $0.bundleIdentifier == "com.apple.Notes" }

        print("🔍 Checking Notes app status...")
        print("   Notes is running: \(notesIsRunning)")

        // Launch Notes if not running
        if !notesIsRunning {
            print("📱 Launching Notes app...")

            if let notesURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true

                NSWorkspace.shared.openApplication(at: notesURL, configuration: configuration) { app, error in
                    if let error = error {
                        print("❌ Failed to launch Notes: \(error)")
                    } else {
                        print("✅ Notes launched successfully")
                    }
                }
            } else {
                throw NotesAppError.notesAppNotAvailable
            }

            // Wait for Notes to fully launch and become ready
            // Poll until Notes is actually running
            var attempts = 0
            let maxAttempts = 10
            var isReady = false

            while attempts < maxAttempts && !isReady {
                Thread.sleep(forTimeInterval: 0.5)
                let apps = NSWorkspace.shared.runningApplications
                if let notesApp = apps.first(where: { $0.bundleIdentifier == "com.apple.Notes" }) {
                    // Check if Notes is active and ready
                    isReady = notesApp.isActive || notesApp.activationPolicy == .regular
                    print("   Attempt \(attempts + 1): Notes ready = \(isReady)")
                }
                attempts += 1
            }

            if !isReady {
                print("⚠️ Notes may not be fully ready, but proceeding anyway...")
            } else {
                print("✅ Notes app is ready")
            }

            // Additional delay to ensure Notes is fully initialized
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Escape special characters for AppleScript
        let escapedTitle = escapeForAppleScript(title)
        let escapedBody = escapeForAppleScript(body)

        // Simplified AppleScript - Notes should be running now
        let script = """
        tell application "Notes"
            set noteFound to false
            set foundNote to missing value

            -- Try to find existing note with matching title
            repeat with aNote in notes
                if name of aNote is "\(escapedTitle)" then
                    set noteFound to true
                    set foundNote to aNote
                    exit repeat
                end if
            end repeat

            if noteFound then
                -- Update existing note
                set body of foundNote to "\(escapedBody)"
                return "updated"
            else
                -- Create new note in default account
                make new note with properties {name:"\(escapedTitle)", body:"\(escapedBody)"}
                return "created"
            end if
        end tell
        """

        print("🔍 Executing AppleScript...")
        print("   Title: \(title)")
        print("   Body length: \(body.count) characters")

        // Execute AppleScript
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            print("❌ Failed to create AppleScript object")
            throw NotesAppError.scriptExecutionFailed("Failed to create AppleScript")
        }

        let output = appleScript.executeAndReturnError(&error)

        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            let errorNumber = error["NSAppleScriptErrorNumber"] as? Int ?? -1
            print("❌ AppleScript error \(errorNumber): \(errorMessage)")
            throw NotesAppError.scriptExecutionFailed("\(errorMessage) (Error \(errorNumber))")
        }

        let result = output.stringValue ?? "unknown"
        print("✅ Notes app sync result: \(result)")
    }

    /// Escape special characters for AppleScript
    private func escapeForAppleScript(_ string: String) -> String {
        var escaped = string
        // Escape backslashes first
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        // Escape quotes
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        // Don't escape newlines for HTML content - keep them as is
        return escaped
    }

    /// Check if Notes app is available
    func isNotesAppAvailable() -> Bool {
        let notesAppPath = "/System/Applications/Notes.app"
        return FileManager.default.fileExists(atPath: notesAppPath)
    }

    /// Open Notes app
    func openNotesApp() {
        if let notesURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: notesURL, configuration: configuration) { app, error in
                if let error = error {
                    print("❌ Failed to open Notes: \(error)")
                } else {
                    print("✅ Notes app opened")
                }
            }
        }
    }
}

// MARK: - String Extension for HTML Escaping
extension String {
    var htmlEscaped: String {
        var escaped = self
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }
}
