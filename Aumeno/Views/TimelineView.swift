//
//  TimelineView.swift
//  Aumeno
//
//  Created by Hoya324
//

import SwiftUI

import AppKit // For NSColor



struct TimelineView: View {
    @EnvironmentObject private var viewModel: MeetingViewModel

    let selectedDate: Date

    let schedules: [Schedule]

    let onAdd: () -> Void

    let onEdit: (Schedule) -> Void

    let onDelete: (Schedule) -> Void

    

            private var schedulesForSelectedDate: [Schedule] {

    

                let startOfDay = Calendar.current.startOfDay(for: selectedDate)

    

                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

    

        

    

                return schedules.filter { schedule in

    

                    let scheduleStart = schedule.startDateTime

    

                    let scheduleEnd = schedule.endDateTime ?? schedule.startDateTime // If no end date, consider it a single day event

    

        

    

                    return (scheduleStart < endOfDay) && (scheduleEnd >= startOfDay)

    

                }

    

                .sorted(by: { s1, s2 in s1.startDateTime < s2.startDateTime })

    

            }

    

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            headerView

                .padding()



            Divider()

            

            if schedulesForSelectedDate.isEmpty {

                emptyView

            } else {

                scheduleListView

            }

        }

        .frame(minWidth: 300)

        .background(Color(NSColor.windowBackgroundColor))

    }

    

    private var headerView: some View {

        HStack {

            VStack(alignment: .leading) {

                                Text(selectedDate.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ko_KR"))))

                                    .font(.subheadline)

                                    .foregroundColor(.secondary)

                                Text(selectedDate.formatted(.dateTime.day().month().locale(Locale(identifier: "ko_KR"))))

                                    .font(.title2)

                                    .fontWeight(.bold)

                            }

                            Spacer()

                            Button(action: onAdd) {

                                Image(systemName: "plus")

                            }

                            .buttonStyle(.plain)

                        }

                    }

                    

                    private var emptyView: some View {

                        VStack {

                            Spacer()

                            Image(systemName: "moon.stars")

                                .font(.largeTitle)

                                .foregroundColor(.secondary)

                                .padding(.bottom)

                            Text("No schedules for this day.")

                                .foregroundColor(.secondary)

                            Spacer()

                        }

                        .frame(maxWidth: .infinity)

                    }

                    

                        private var scheduleListView: some View {

                    

                            List {

                    

                                ForEach(schedulesForSelectedDate) { schedule in

                    

                                    Button(action: { onEdit(schedule) }) {

                    

                                        scheduleRow(schedule)

                    

                                    }

                    

                                    .buttonStyle(.plain)

                    

                                    .contextMenu {

                    

                                        Button("Edit") {

                    

                                            onEdit(schedule)

                    

                                        }

                    

                                        Button("Delete", role: .destructive) {

                    

                                            onDelete(schedule)

                    

                                        }

                    

                                    }

                    

                                }

                    

                            }

                    

                            .listStyle(.plain)

                    

                        }

                    

                                        private func scheduleRow(_ schedule: Schedule) -> some View {

                    

                                            let fillColor: Color

                    

                                            if let tagID = schedule.tagID,

                    

                                               let tag = viewModel.tag(for: tagID),

                    

                                               let colorFromTag = Color(hex: tag.color) {

                    

                                                fillColor = colorFromTag

                    

                                            } else if let workspaceHex = schedule.workspaceColor, let nsColor = NSColor(hex: workspaceHex) {

                    

                                                fillColor = Color(nsColor)

                    

                                            } else {

                    

                                                fillColor = Color.gray

                    

                                            }

                

                        return HStack {

                            Rectangle()

                                .fill(fillColor)

                                .frame(width: 4)

                            

                            VStack(alignment: .leading) {

                                Text(schedule.title)

                                    .fontWeight(.semibold)

                                

                                HStack(spacing: 4) {

                                    Text(schedule.startDateTime.formatted(.dateTime.hour().minute().locale(Locale(identifier: "ko_KR"))))

                                    

                                    if let endDateTime = schedule.endDateTime {

                                        // Check if it's a multi-day event or just a time range on the same day

                                        if !Calendar.current.isDate(schedule.startDateTime, inSameDayAs: endDateTime) {

                                            Text("–")

                                            Text(endDateTime.formatted(.dateTime.day().hour().minute().locale(Locale(identifier: "ko_KR"))))

                                        } else {

                                            Text("–")

                                            Text(endDateTime.formatted(.dateTime.hour().minute().locale(Locale(identifier: "ko_KR"))))

                                        }

                                    }

                                }

                                .font(.subheadline)

                                .foregroundColor(.secondary)

                            }

                            

                            Spacer()

                

                            if let links = schedule.links, !links.isEmpty {

                                Menu {

                                    ForEach(links, id: \.self) { link in

                                        Button(action: {

                                            if let url = URL(string: link) {

                                                NSWorkspace.shared.open(url)

                                            }

                                        }) {

                                            // Show a shortened version for readability

                                            Text(link.prefix(50))

                                        }

                                    }

                                } label: {

                                    Image(systemName: "link")

                                }

                                .menuStyle(.borderlessButton)

                                .frame(width: 20)

                            }

                        }

                        .padding(.vertical, 4)

                    }

                

                }

                

                

                

                #Preview {



    let schedules = [



        Schedule(title: "Morning Standup", startDateTime: Date()),



        Schedule(title: "Design Review", startDateTime: Date().addingTimeInterval(3600), endDateTime: Date().addingTimeInterval(7200), type: .meeting, workspaceColor: "#FF5733"),



        Schedule(title: "Check PR comments", startDateTime: Date().addingTimeInterval(7200), type: .mention, workspaceColor: "#33CFFF")



    ]



    



    TimelineView(selectedDate: Date(), schedules: schedules, onAdd: {}, onEdit: { _ in }, onDelete: { _ in })



        .preferredColorScheme(.dark)



}


