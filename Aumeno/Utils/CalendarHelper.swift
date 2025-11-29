//
//  CalendarHelper.swift
//  Aumeno
//
//  Created by Hoya324
//

import Foundation

struct Day: Identifiable {
    let id = UUID()
    let date: Date
    let dayOfMonth: String
    let isToday: Bool
    let isFromCurrentMonth: Bool
}

class CalendarHelper {
    private let calendar = Calendar.current
    
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    func plusMonth(date: Date) -> Date {
        return calendar.date(byAdding: .month, value: 1, to: date) ?? date
    }
    
    func minusMonth(date: Date) -> Date {
        return calendar.date(byAdding: .month, value: -1, to: date) ?? date
    }
    
    func daysInMonth(for date: Date) -> [Day] {
        guard let monthStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }

        let monthFirstDay = calendar.startOfDay(for: monthStartDate)

        guard let firstDayOfNextMonth = calendar.date(byAdding: .month, value: 1, to: monthFirstDay) else {
            return []
        }

        let firstDayWeekday = calendar.component(.weekday, from: monthFirstDay)
        
        var days: [Day] = []
        
        // Add days from previous month for padding
        let daysToPad = firstDayWeekday - calendar.firstWeekday
        if daysToPad > 0 {
            for i in 1...daysToPad {
                if let paddedDate = calendar.date(byAdding: .day, value: -i, to: monthFirstDay) {
                    days.insert(createDay(from: paddedDate, isCurrentMonth: false), at: 0)
                }
            }
        }
        
        // Add days for the current month
        let range = calendar.range(of: .day, in: .month, for: date)!
        for day in range {
            let dayDateForCurrentMonth = calendar.date(bySetting: .day, value: day, of: monthFirstDay)!
            days.append(createDay(from: dayDateForCurrentMonth, isCurrentMonth: true))
        }
        
        // Add days from next month for padding
        let totalDays = days.count
        let daysNeeded = 42 // 6 rows * 7 days
        if totalDays < daysNeeded {
            for i in 0..<(daysNeeded - totalDays) {
                if let paddedDate = calendar.date(byAdding: .day, value: i, to: firstDayOfNextMonth) {
                    days.append(createDay(from: paddedDate, isCurrentMonth: false))
                }
            }
        }
        
        return days
    }
    
    private func createDay(from date: Date, isCurrentMonth: Bool) -> Day {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        let dayOfMonth = dayFormatter.string(from: date)
        let isToday = calendar.isDateInToday(date)
        
        return Day(date: date, dayOfMonth: dayOfMonth, isToday: isToday, isFromCurrentMonth: isCurrentMonth)
    }
}
