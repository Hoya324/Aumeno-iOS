//
//  MeetingEditorView.swift
//  Aumeno
//
//  Created by Claude Code
//

import SwiftUI

struct MeetingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let meeting: Meeting?
    let onSave: (Meeting) -> Void

    @State private var title: String
    @State private var scheduledDate: Date
    @State private var location: String
    @State private var notionLink: String
    @State private var note: String

    init(meeting: Meeting?, onSave: @escaping (Meeting) -> Void) {
        self.meeting = meeting
        self.onSave = onSave
        _title = State(initialValue: meeting?.title ?? "")
        _scheduledDate = State(initialValue: meeting?.scheduledTime ?? Date())
        _location = State(initialValue: meeting?.location ?? "")
        _notionLink = State(initialValue: meeting?.notionLink ?? "")
        _note = State(initialValue: meeting?.note ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.gray.opacity(0.3))

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        TextField("e.g. Design Review Meeting", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Scheduled Time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SCHEDULED TIME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        // Quick selection buttons
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                QuickTimeButton(title: "30m", icon: "clock") {
                                    scheduledDate = Date().addingTimeInterval(30 * 60)
                                }
                                QuickTimeButton(title: "1h", icon: "clock") {
                                    scheduledDate = Date().addingTimeInterval(60 * 60)
                                }
                                QuickTimeButton(title: "2h", icon: "clock") {
                                    scheduledDate = Date().addingTimeInterval(2 * 60 * 60)
                                }
                            }

                            HStack(spacing: 8) {
                                QuickTimeButton(title: "Tomorrow", icon: "calendar") {
                                    scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                }
                                QuickTimeButton(title: "Next Week", icon: "calendar") {
                                    scheduledDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
                                }
                                QuickTimeButton(title: "Next Month", icon: "calendar") {
                                    scheduledDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                                }
                            }
                        }

                        // Compact date/time picker
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.67))
                                    .frame(width: 20)

                                DatePicker(
                                    "",
                                    selection: $scheduledDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                            }

                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.67))
                                    .frame(width: 20)

                                DatePicker(
                                    "",
                                    selection: $scheduledDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )

                        // Selected time display
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.green.opacity(0.7))

                            Text(formattedSelectedTime)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(white: 0.93))
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LOCATION (OPTIONAL)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        TextField("e.g. 4층 회의실", text: $location)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Notion Link
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LINK (OPTIONAL)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        TextField("e.g. https://notion.so/...", text: $notionLink)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(12)
                            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES (OPTIONAL)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(white: 0.67))
                            .tracking(1.0)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $note)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(white: 0.93))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(8)

                            if note.isEmpty {
                                Text("Write notes about the meeting...")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(Color.gray.opacity(0.4))
                                    .padding(12)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // Info box
                    if meeting == nil {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color.blue.opacity(0.7))

                            Text("Manual meetings will auto-notify and open notes at scheduled time.")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.67))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(24)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Footer
            footerView
        }
        .frame(width: 500, height: 700)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting == nil ? "New Meeting" : "Edit Meeting")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundColor(Color(white: 0.93))

                if let meeting = meeting, meeting.isFromSlack {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                            .foregroundColor(Color(white: 0.67))

                        Text("Imported from Slack")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.67))
                    }
                }
            }

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
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(DarkSecondaryButtonStyle())

            Spacer()

            Text("\(title.count)/100")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.67))

            Button("Save") {
                saveMeeting()
            }
            .buttonStyle(DarkPrimaryButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1.0 : 0.4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private var formattedSelectedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: scheduledDate)
    }

    // MARK: - Validation

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count <= 100
    }

    // MARK: - Actions

    private func saveMeeting() {
        let newMeeting = Meeting(
            id: meeting?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduledTime: scheduledDate,
            note: note,
            source: .manual, // 수동 생성
            slackConfigID: nil,
            slackTimestamp: nil,
            createdAt: meeting?.createdAt ?? Date(),
            notificationSent: false,
            location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            notionLink: notionLink.isEmpty ? nil : notionLink.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        onSave(newMeeting)
        dismiss()
    }
}

// MARK: - Quick Time Button

struct QuickTimeButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))

                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color(white: 0.93))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(isPressed ? 0.5 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview

#Preview("New Meeting") {
    MeetingEditorView(meeting: nil) { _ in }
}

#Preview("Edit Meeting") {
    MeetingEditorView(
        meeting: Meeting(
            title: "디자인 리뷰",
            scheduledTime: Date().addingTimeInterval(3600),
            note: "UI/UX 개선사항 논의"
        )
    ) { _ in }
}
