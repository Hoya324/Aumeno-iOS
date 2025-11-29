import WidgetKit
import SwiftUI
import AppKit
import Foundation // Needed for Tag and Schedule (if not implicitly available)

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), schedules: [], tags: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), schedules: [], tags: [:])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        
        let schedules = (try? DatabaseManager.shared.fetchAllSchedules()) ?? []
        let allTags = (try? DatabaseManager.shared.fetchAllTags()) ?? []
        let tagMap = Dictionary(uniqueKeysWithValues: allTags.map { ($0.id, $0) })
        
        let upcomingSchedules = schedules
            .filter { $0.startDateTime > Date() && !$0.isDone }
            .sorted(by: { $0.startDateTime < $1.startDateTime })
            .prefix(5)

        let entry = SimpleEntry(date: Date(), schedules: Array(upcomingSchedules), tags: tagMap)
        entries.append(entry)

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: entries, policy: .after(nextUpdate)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let schedules: [Schedule]
    let tags: [String: Tag] // Map tagID to Tag object for quick lookup
}

struct Aumeno_widgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Upcoming")
                .font(.headline)
                .padding(.bottom, 2)
            
            if entry.schedules.isEmpty {
                Text("No upcoming schedules.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                ForEach(entry.schedules) { schedule in
                    HStack {
                        Circle()
                            .fill(color(for: schedule))
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading) {
                            Text(schedule.title)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(schedule.startDateTime, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func color(for schedule: Schedule) -> Color {
        if let tagID = schedule.tagID,
           let tag = entry.tags[tagID],
           let colorFromTag = Color(hex: tag.color) {
            return colorFromTag
        }
        if let workspaceHex = schedule.workspaceColor, let nsColor = NSColor(hex: workspaceHex) {
            return Color(nsColor)
        }
        return .gray
    }
}

struct Aumeno_widget: Widget {
    let kind = "Aumeno_widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Aumeno_widgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aumeno Schedules")
        .description("See your upcoming schedules.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Aumeno Widget", as: .systemMedium) {
    Aumeno_widget()
} timeline: {
    SimpleEntry(date: .now, schedules: [
        Schedule(title: "Design Review", startDateTime: Date().addingTimeInterval(3600), endDateTime: Date().addingTimeInterval(7200), workspaceColor: "#4A90E2"),
        Schedule(title: "Weekly Sync", startDateTime: Date().addingTimeInterval(7200), workspaceColor: "#F5A623")
    ], tags: [:]
)}
