//
//  NotePopupView.swift
//  Aumeno
//
//  Created by Hoya324
//

import SwiftUI

struct NotePopupView: View {
    @ObservedObject var viewModel: MeetingViewModel
    @State var schedule: Schedule
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isEditorFocused: Bool
    @State private var noteText: String
    @State private var isSaving: Bool = false
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var saveStatus: SaveStatus = .idle
    @State private var isEditingInfo: Bool = false
    
    // State for editing fields
    @State private var editedTitle: String
    @State private var editedStartDateTime: Date
    @State private var editedEndDateTime: Date?
    @State private var editedLocation: String
    @State private var editedLinksString: String

    enum SaveStatus: Equatable {
        case idle, saving, saved
    }

    init(viewModel: MeetingViewModel, schedule: Schedule) {
        self.viewModel = viewModel
        _schedule = State(initialValue: schedule)
        _noteText = State(initialValue: schedule.note)
        _editedTitle = State(initialValue: schedule.title)
        _editedStartDateTime = State(initialValue: schedule.startDateTime)
        _editedEndDateTime = State(initialValue: schedule.endDateTime)
        _editedLocation = State(initialValue: schedule.location ?? "")
        _editedLinksString = State(initialValue: schedule.links?.joined(separator: "\n") ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().background(Color.gray.opacity(0.3))
            meetingInfoView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            Divider().background(Color.gray.opacity(0.3))
            noteEditorView
                .padding(24)
            Divider().background(Color.gray.opacity(0.3))
            footerView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 500, height: 600)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 10)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isEditorFocused = true
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(schedule.title)
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(Color(white: 0.93))
                .lineLimit(1)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(PlainCircleButtonStyle())
            .help("Close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var meetingInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DETAILS")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                Spacer()
                Button(action: { isEditingInfo.toggle() }) {
                    Text(isEditingInfo ? "Done" : "Edit")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(Color(white: 0.93))
                }.buttonStyle(.plain)
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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    private var displayInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(schedule.title).font(.system(size: 15, weight: .semibold)).foregroundColor(Color(white: 0.93)).lineLimit(2)
            
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.system(size: 11)).foregroundColor(Color(white: 0.67))
                Text(schedule.formattedStartDateTime).font(.system(size: 12)).foregroundColor(Color(white: 0.67))
                if let formattedEndDateTime = schedule.formattedEndDateTime {
                    Text(" - ").font(.system(size: 12)).foregroundColor(Color(white: 0.67))
                    Text(formattedEndDateTime).font(.system(size: 12)).foregroundColor(Color(white: 0.67))
                }
            }

            if let location = schedule.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location").font(.system(size: 11)).foregroundColor(Color(white: 0.67))
                    Text(location).font(.system(size: 12)).foregroundColor(Color(white: 0.67)).lineLimit(1)
                }
            }

            if let links = schedule.links, !links.isEmpty {
                ForEach(links.prefix(3), id: \.self) {
                    link in
                    Button(action: { if let url = URL(string: link) { NSWorkspace.shared.open(url) } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link").font(.system(size: 11))
                            Text(link).font(.system(size: 12)).underline().lineLimit(1)
                        }
                        .foregroundColor(Color.blue)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var editingInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $editedTitle).textFieldStyle(DarkTextFieldStyle())
            
            DatePicker("Start Date", selection: $editedStartDateTime)
                .datePickerStyle(.compact)
                .font(.system(size: 12))
                .colorScheme(.dark)
            
            Toggle(isOn: Binding(
                get: { editedEndDateTime != nil },
                set: {
                    if $0 {
                        if editedEndDateTime == nil {
                            editedEndDateTime = editedStartDateTime.addingTimeInterval(3600) // Default to 1 hour after start
                        }
                    } else {
                        editedEndDateTime = nil
                    }
                }
            )) {
                Text("Has End Date")
            }
            
            if let editedEndDateTimeBinding = Binding($editedEndDateTime) {
                DatePicker("End Date", selection: editedEndDateTimeBinding, in: editedStartDateTime...)
                    .datePickerStyle(.compact)
                    .font(.system(size: 12))
                    .colorScheme(.dark)
            }
            
            TextField("Location (optional)", text: $editedLocation).textFieldStyle(DarkTextFieldStyle())
            
            VStack(alignment: .leading) {
                Text("Links (one per line)").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $editedLinksString)
                    .frame(minHeight: 40, maxHeight: 80)
                    .border(Color.gray.opacity(0.2), width: 1)
                    .cornerRadius(6)
            }

            Button(action: saveEditedInfo) {
                Text("Save Changes").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity)
            }.buttonStyle(DarkSecondaryButtonStyle())
        }
    }

    private var noteEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NOTES").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(white: 0.67)).tracking(1.0)
                Spacer()
                autoSaveStatusView
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $noteText)
                    .focused($isEditorFocused)
                    .font(.system(size: 14, design: .monospaced)).foregroundColor(Color(white: 0.93))
                    .scrollContentBackground(.hidden).padding(12)
                    .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .frame(maxHeight: .infinity)
                    .onChange(of: noteText) { _, newValue in autoSaveNote(newValue) }

                if noteText.isEmpty {
                    Text("Write your notes here...").font(.system(size: 14, design: .monospaced)).foregroundColor(Color.gray.opacity(0.4)).padding(20).allowsHitTesting(false)
                }
            }
        }
    }
    
    @ViewBuilder
    private var autoSaveStatusView: some View {
        Group {
            switch saveStatus {
            case .idle: EmptyView()
            case .saving:
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    Text("Saving...").font(.system(size: 10))
                }
            case .saved:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundColor(.green)
                    Text("Saved").font(.system(size: 10))
                }
            }
        }.foregroundColor(Color(white: 0.67)).animation(.easeInOut, value: saveStatus)
    }

    private var footerView: some View {
        HStack {
            Text("\(noteText.count) characters").font(.system(size: 11)).foregroundColor(Color(white: 0.67))
            Spacer()
            HStack(spacing: 12) {
                Button("Cancel", action: { dismiss() }).buttonStyle(DarkSecondaryButtonStyle())
                Button("Save", action: saveNote).buttonStyle(DarkPrimaryButtonStyle()).disabled(isSaving).opacity(isSaving ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Actions

    private func saveNote() {
        isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var updatedSchedule = schedule
            updatedSchedule.note = noteText
            viewModel.updateSchedule(schedule: updatedSchedule)
            isSaving = false
            dismiss()
        }
    }

    private func autoSaveNote(_ text: String) {
        autoSaveTask?.cancel()
        saveStatus = .saving
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            
            var updatedSchedule = schedule
            updatedSchedule.note = text
            
            await MainActor.run {
                viewModel.updateSchedule(schedule: updatedSchedule)
                self.schedule.note = text // Update local state
                saveStatus = .saved
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { saveStatus = .idle }
        }
    }

    private func saveEditedInfo() {
        var updatedSchedule = schedule
        updatedSchedule.title = editedTitle
        updatedSchedule.startDateTime = editedStartDateTime
        updatedSchedule.endDateTime = editedEndDateTime
        updatedSchedule.location = editedLocation.isEmpty ? nil : editedLocation
        
        let links = editedLinksString.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        updatedSchedule.links = links.isEmpty ? nil : links

        viewModel.updateSchedule(schedule: updatedSchedule)
        self.schedule = updatedSchedule // Update local state
        isEditingInfo = false
    }
}
