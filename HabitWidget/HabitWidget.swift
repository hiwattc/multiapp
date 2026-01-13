//
//  HabitWidget.swift
//  HabitWidget
//
//  Created by admin on 1/13/26.
//

import WidgetKit
import SwiftUI

// MARK: - Habit Model for Widget
struct WidgetHabit: Codable, Identifiable {
    let id: UUID
    var title: String
    var completions: [String: Bool]

    init(id: UUID = UUID(), title: String, completions: [String: Bool] = [:]) {
        self.id = id
        self.title = title
        self.completions = completions
    }
}

// MARK: - Widget Entry
struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
    let todayCompletions: [String: Bool]
}

// MARK: - Widget Provider
struct HabitWidgetProvider: TimelineProvider {
    private let appGroupID = "group.com.news.habit"
    private let saveKey = "SavedHabits"

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: Date(), habits: [], todayCompletions: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> ()) {
        let entry = getCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> ()) {
        let entry = getCurrentEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func getCurrentEntry() -> HabitWidgetEntry {
        let habits = loadHabits()
        let todayCompletions = getTodayCompletions(habits: habits)
        return HabitWidgetEntry(date: Date(), habits: habits, todayCompletions: todayCompletions)
    }

    private func loadHabits() -> [WidgetHabit] {
        if let data = userDefaults.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([WidgetHabit].self, from: data) {
            return decoded
        }
        return []
    }

    private func getTodayCompletions(habits: [WidgetHabit]) -> [String: Bool] {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        let todayString = String(format: "%04d-%02d-%02d", today.year!, today.month!, today.day!)

        var completions: [String: Bool] = [:]
        for habit in habits {
            completions[habit.title] = habit.completions[todayString] ?? false
        }
        return completions
    }
}

// MARK: - Widget View
struct HabitWidgetEntryView: View {
    var entry: HabitWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("오늘의 습관")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            if entry.habits.isEmpty {
                Text("습관을 추가해보세요")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            } else {
                ForEach(entry.habits.prefix(3)) { habit in
                    HStack {
                        Circle()
                            .fill((entry.todayCompletions[habit.title] ?? false) ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)

                        Text(habit.title)
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                }

                if entry.habits.count > 3 {
                    Text("+\(entry.habits.count - 3)개 더보기")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)  // ✅ 추가!
    }
}

// MARK: - Widget Configuration
@main
struct HabitWidget: Widget {
    let kind: String = "com.staroot.news.HabitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitWidgetProvider()) { entry in
            HabitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("습관 위젯")
        .description("오늘의 습관 완료 상태를 확인하세요")
        //.supportedFamilies([.systemSmall])
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])  // ✅ 크기 지정
    }
}

// MARK: - Preview
struct HabitWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleHabits = [
            WidgetHabit(title: "물 2L 마시기", completions: ["2024-01-13": true]),
            WidgetHabit(title: "30분 운동", completions: [:]),
            WidgetHabit(title: "독서 30분", completions: ["2024-01-13": false])
        ]

        HabitWidgetEntryView(entry: HabitWidgetEntry(
            date: Date(),
            habits: sampleHabits,
            todayCompletions: ["물 2L 마시기": true, "30분 운동": false, "독서 30분": false]
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
