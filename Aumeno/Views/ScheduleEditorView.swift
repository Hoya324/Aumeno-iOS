import SwiftUI

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: MeetingViewModel
    
    let schedule: Schedule?
    let onSave: (Schedule) -> Void
    
    @State private var title: String
    @State private var location: String
    @State private var linksString: String // For multi-line link editing
    @State private var note: String
    @State private var startDateTime: Date
    @State private var endDateTime: Date?
    @State private var selectedTagID: String?
    @State private var showingTagManager = false // New state variable

    init(schedule: Schedule?, defaultStartDate: Date? = nil, defaultEndDate: Date? = nil, onSave: @escaping (Schedule) -> Void) {
        self.schedule = schedule
        self.onSave = onSave
        
        // Initialize state from the existing schedule or set defaults
        _title = State(initialValue: schedule?.title ?? "")
        _location = State(initialValue: schedule?.location ?? "")
        _note = State(initialValue: schedule?.note ?? "")
        _linksString = State(initialValue: schedule?.links?.joined(separator: "\n") ?? "")
        
        _selectedTagID = State(initialValue: schedule?.tagID) // Initialize selectedTagID
        
        if let existingSchedule = schedule {
            _startDateTime = State(initialValue: existingSchedule.startDateTime)
            _endDateTime = State(initialValue: existingSchedule.endDateTime)
        } else {
            // Logic to set a smart default date for new schedules
                                            var initialStartDate: Date
                                            let calendar = Calendar.current
                                            
                                            if let defaultStartDate = defaultStartDate {
                    let now = Date()
                    // Get date components from defaultStartDate
                    let defaultDateComponents = calendar.dateComponents([.year, .month, .day], from: defaultStartDate)
                    
                    // Get time components from now
                    var newTimeComponents = calendar.dateComponents([.hour, .minute], from: now)
                    newTimeComponents.hour = (newTimeComponents.hour ?? 0) + 1 // Set to next hour
                    newTimeComponents.minute = 0 // Set minutes to 0
                    
                    // Combine date components from defaultStartDate with new time components
                    var combinedComponents = DateComponents()
                    combinedComponents.year = defaultDateComponents.year
                    combinedComponents.month = defaultDateComponents.month
                    combinedComponents.day = defaultDateComponents.day
                    combinedComponents.hour = newTimeComponents.hour
                    combinedComponents.minute = newTimeComponents.minute
                    
                    initialStartDate = calendar.date(from: combinedComponents) ?? defaultStartDate
                } else {
                                                let now = Date()
                                                let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
                                                let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextHour)
                                                initialStartDate = calendar.date(from: components) ?? nextHour
                                            };            _startDateTime = State(initialValue: initialStartDate)
            // Default end date to 1 hour after start date for new events
            _endDateTime = State(initialValue: initialStartDate.addingTimeInterval(3600))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(schedule == nil ? "New Schedule" : "Edit Schedule")
                .font(.title2).bold()
                .padding()
            
            Divider() 
            
            Form {
                TextField("Title", text: $title)
                
                DatePicker("Start Date", selection: $startDateTime)
                
                Toggle(isOn: Binding(
                    get: { endDateTime != nil },
                    set: { isOn in
                        if isOn {
                            // If turning on, set to startDateTime + 1 hour if currently nil
                            if endDateTime == nil {
                                endDateTime = startDateTime.addingTimeInterval(3600)
                            }
                        } else {
                            // If turning off, set to nil
                            endDateTime = nil
                        }
                    }
                )) {
                    Text("Has End Date")
                }
                
                // Only show DatePicker if endDateTime is not nil
                if endDateTime != nil {
                    DatePicker("End Date", selection: Binding(
                        get: { endDateTime ?? startDateTime.addingTimeInterval(3600) }, // Provide a default if nil
                        set: { endDateTime = $0 }
                    ), in: startDateTime...)
                }
                
                TextField("Location", text: $location)

                HStack {
                    Picker("Tag (optional)", selection: $selectedTagID) {
                        Text("None").tag(nil as String?) // Explicitly tag nil for no selection
                        ForEach(viewModel.tags) { tag in
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: tag.color) ?? .gray)
                                    .frame(width: 15, height: 15)
                                Text(tag.name)
                            }
                            .tag(tag.id as String?)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Manage Tags") {
                        showingTagManager = true
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingTagManager) {
                        TagManagerView()
                            .environmentObject(viewModel)
                            .onDisappear(perform: viewModel.fetchTags)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Links (one per line)").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $linksString)
                        .frame(minHeight: 60)
                        .border(Color.gray.opacity(0.2), width: 1)
                        .cornerRadius(8)
                }

                VStack(alignment: .leading) {
                    Text("Note").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                        .border(Color.gray.opacity(0.2), width: 1)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(DarkSecondaryButtonStyle())
                
                Spacer()
                
                Button("Save") {
                    var updatedSchedule = schedule ?? Schedule(title: "", startDateTime: Date())
                    updatedSchedule.title = title
                    updatedSchedule.startDateTime = startDateTime
                    updatedSchedule.endDateTime = endDateTime // Assign endDateTime
                    updatedSchedule.location = location.isEmpty ? nil : location
                    
                    // Split the string back into an array of links
                    let links = linksString.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    updatedSchedule.links = links.isEmpty ? nil : links

                    updatedSchedule.note = note
                    updatedSchedule.tagID = selectedTagID // Assign selected tag ID
                    
                    onSave(updatedSchedule)
                    dismiss()
                }
                .buttonStyle(DarkPrimaryButtonStyle())
                .disabled(!canSave) // Disable if title is empty
            }
            .padding()
        }
        .frame(width: 450, height: 480)
        .preferredColorScheme(.dark)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    ScheduleEditorView(schedule: nil, onSave: { _ in })
        .preferredColorScheme(.dark)
}
