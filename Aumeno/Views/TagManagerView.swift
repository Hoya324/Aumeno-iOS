import SwiftUI

struct TagManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tags: [Tag] = []
    
    @State private var showingAddTagSheet = false
    @State private var editingTag: Tag? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Manage Tags")
                .font(.title2).bold()
                .padding()
            
            Divider()
            
            List {
                ForEach(tags) { tag in
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: tag.color) ?? .gray)
                            .frame(width: 20, height: 20)
                        Text(tag.name)
                        Spacer()
                        Button("Edit") {
                            editingTag = tag
                            showingAddTagSheet = true
                        }
                        Button(role: .destructive) {
                            deleteTag(tag)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            
            Divider()
            
            HStack {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent) // Assuming this style exists
                
                Spacer()
                
                Button("Add Tag") {
                    editingTag = nil // Clear for new tag
                    showingAddTagSheet = true
                }
                .buttonStyle(.borderedProminent) // Assuming this style exists
            }
            .padding()
        }
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 500, minHeight: 300, idealHeight: 400, maxHeight: 500)
        .onAppear(perform: loadTags)
        .sheet(isPresented: $showingAddTagSheet) {
            EditTagView(tag: editingTag) { updatedTag in
                saveTag(updatedTag)
            }
        }
    }
    
    private func loadTags() {
        do {
            tags = try DatabaseManager.shared.fetchAllTags()
        } catch {
            print("❌ Error loading tags: \(error)")
        }
    }
    
    private func saveTag(_ tag: Tag) {
        do {
            try DatabaseManager.shared.insertTag(tag)
            loadTags() // Reload tags after saving
        } catch {
            print("❌ Error saving tag: \(error)")
        }
    }
    
    private func deleteTag(_ tag: Tag) {
        do {
            try DatabaseManager.shared.deleteTag(id: tag.id)
            loadTags() // Reload tags after deleting
        } catch {
            print("❌ Error deleting tag: \(error)")
        }
    }
}

struct EditTagView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: Color
    
    let existingTag: Tag?
    let onSave: (Tag) -> Void
    
    init(tag: Tag?, onSave: @escaping (Tag) -> Void) {
        self.existingTag = tag
        self.onSave = onSave
        _name = State(initialValue: tag?.name ?? "")
        _color = State(initialValue: (tag?.color).flatMap { Color(hex: $0) } ?? .accentColor)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(existingTag == nil ? "New Tag" : "Edit Tag")
                .font(.headline).bold()
                .padding()
            
            Divider()
            
            Form {
                TextField("Tag Name", text: $name)
                ColorPicker("Tag Color", selection: $color)
            }
            .padding()
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    let newTag = Tag(
                        id: existingTag?.id ?? UUID().uuidString,
                        name: name,
                        color: color.toHex() ?? "#808080" // toHex() helper needed
                    )
                    onSave(newTag)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400, minHeight: 200, idealHeight: 250, maxHeight: 300)
    }
}
