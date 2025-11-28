//
//  NotePopupView.swift
//  Aumeno
//
//  Created by Claude Code
//

import SwiftUI

struct NotePopupView: View {
    @ObservedObject var viewModel: MeetingViewModel
    let meeting: Meeting
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String
    @State private var isSaving: Bool = false
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var saveStatus: SaveStatus = .idle
    @State private var isEditingInfo: Bool = false
    @State private var editedTitle: String
    @State private var editedScheduledTime: Date
    @State private var editedLocation: String
    @State private var editedNotionLink: String

    enum SaveStatus {
        case idle
        case saving
        case saved
    }

    init(viewModel: MeetingViewModel, meeting: Meeting) {
        self.viewModel = viewModel
        self.meeting = meeting
        _noteText = State(initialValue: meeting.note)
        _editedTitle = State(initialValue: meeting.title)
        _editedScheduledTime = State(initialValue: meeting.scheduledTime)
        _editedLocation = State(initialValue: meeting.location ?? "")
        _editedNotionLink = State(initialValue: meeting.notionLink ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.gray.opacity(0.3))

            // Meeting Info
            meetingInfoView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider()
                .background(Color.gray.opacity(0.3))

            // Note Editor
            noteEditorView
                .padding(24)

            Divider()
                .background(Color.gray.opacity(0.3))

            // Footer Actions
            footerView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 500, height: 600)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12)) // #1E1E1E
        .preferredColorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 10)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Aumeno")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(Color(white: 0.93))

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.67))
                    .frame(width: 28, height: 28)
                    .background(Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Meeting Info

    private var meetingInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MEETING INFO")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(white: 0.67))
                    .tracking(1.0)

                Spacer()

                Button(action: { isEditingInfo.toggle() }) {
                    Text(isEditingInfo ? "Done" : "Edit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.93))
                }
                .buttonStyle(.plain)
            }

            if isEditingInfo {
                editingInfoView
            } else {
                displayInfoView
            }
        }
        .padding(12)
        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var displayInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(white: 0.93))
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.67))

                Text(meeting.formattedStartTime)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.67))
            }

            if let location = meeting.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.67))

                    Text(location)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.67))
                        .lineLimit(1)
                }
            }

            if let notionLink = meeting.notionLink, !notionLink.isEmpty {
                Button(action: {
                    if let url = URL(string: notionLink) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.67))

                        Text(notionLink)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.67))
                            .underline()
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
    }

    private var editingInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            TextField("Title", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(8)
                .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                .cornerRadius(6)

            // Time
            DatePicker("Time", selection: $editedScheduledTime)
                .datePickerStyle(.compact)
                .font(.system(size: 12))
                .colorScheme(.dark)

            // Location
            TextField("Location (optional)", text: $editedLocation)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                .cornerRadius(6)

            // Link
            TextField("Link (optional)", text: $editedNotionLink)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                .cornerRadius(6)

            // Save button
            Button(action: saveEditedInfo) {
                Text("Save Changes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.93))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Note Editor

    private var noteEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NOTES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(white: 0.67))
                    .tracking(1.0)

                Spacer()

                // Auto-save status indicator
                Group {
                    switch saveStatus {
                    case .idle:
                        EmptyView()
                    case .saving:
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                            Text("Saving...")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.67))
                        }
                    case .saved:
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color.green.opacity(0.7))
                            Text("Saved")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.67))
                        }
                    }
                }
                .animation(.easeInOut, value: saveStatus)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $noteText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(white: 0.93))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .frame(maxHeight: .infinity)
                    .onChange(of: noteText) { _, newValue in
                        autoSaveNote(newValue)
                    }

                if noteText.isEmpty {
                    Text("Write your notes here...")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color.gray.opacity(0.4))
                        .padding(20)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Character count
            Text("\(noteText.count) characters")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.67))

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(DarkSecondaryButtonStyle())

                Button("Save") {
                    saveNote()
                }
                .buttonStyle(DarkPrimaryButtonStyle())
                .disabled(isSaving)
                .opacity(isSaving ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Actions

    private func saveNote() {
        isSaving = true

        // Simulate save delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.updateNote(for: meeting.id, note: noteText)
            isSaving = false
            dismiss()
        }
    }

    private func autoSaveNote(_ text: String) {
        // Cancel previous auto-save task
        autoSaveTask?.cancel()

        // Show saving indicator
        saveStatus = .saving

        // Debounce: wait 1 second after user stops typing
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            guard !Task.isCancelled else { return }

            // Auto-save to database
            await MainActor.run {
                viewModel.updateNote(for: meeting.id, note: text)
                saveStatus = .saved
                print("📝 Auto-saved note for meeting: \(meeting.title)")
            }

            // Hide "Saved" indicator after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                saveStatus = .idle
            }
        }
    }

    private func saveEditedInfo() {
        var updatedMeeting = meeting
        updatedMeeting.title = editedTitle
        updatedMeeting.scheduledTime = editedScheduledTime
        updatedMeeting.location = editedLocation.isEmpty ? nil : editedLocation
        updatedMeeting.notionLink = editedNotionLink.isEmpty ? nil : editedNotionLink

        viewModel.saveMeeting(updatedMeeting)
        isEditingInfo = false
        print("✅ Meeting info updated")
    }
}

// MARK: - Button Styles (Dark Theme)

struct DarkPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color(white: 0.93))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(configuration.isPressed ? 0.5 : 0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DarkSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(Color(white: 0.67))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(configuration.isPressed ? 0.4 : 0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Keep legacy button styles for backwards compatibility
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DarkPrimaryButtonStyle().makeBody(configuration: configuration)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DarkSecondaryButtonStyle().makeBody(configuration: configuration)
    }
}

// MARK: - Preview

#Preview {
    NotePopupView(
        viewModel: MeetingViewModel(),
        meeting: Meeting(
            title: "Design review meeting - discuss the new homepage layout and user feedback",
            scheduledTime: Date().addingTimeInterval(3600)
        )
    )
}
