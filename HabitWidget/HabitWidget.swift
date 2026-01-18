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

// MARK: - Bible Verse Model for Widget
struct WidgetBibleVerse: Codable {
    let id: Int
    let reference: String
    let krv: String
    let niv: String
    let themes: [String]
}

struct WidgetHabitAdvice: Codable {
    let bibleVersesForHabits: [WidgetBibleVerse]
}

// MARK: - Widget Entry
struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
    let todayCompletions: [String: Bool]
    let quote: WidgetBibleVerse?
}

// MARK: - Widget Provider
struct HabitWidgetProvider: TimelineProvider {
    private let appGroupID = "group.com.news.habit"
    private let saveKey = "SavedHabits"

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: Date(), habits: [], todayCompletions: [:], quote: nil)
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
        let quote = loadRandomQuote()
        return HabitWidgetEntry(date: Date(), habits: habits, todayCompletions: todayCompletions, quote: quote)
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
    
    private func loadRandomQuote() -> WidgetBibleVerse? {
        guard let url = Bundle.main.url(forResource: "HabitAdvice", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let advice = try? JSONDecoder().decode(WidgetHabitAdvice.self, from: data) else {
            return nil
        }
        
        return advice.bibleVersesForHabits.randomElement()
    }
}

// MARK: - Widget View
struct HabitWidgetEntryView: View {
    var entry: HabitWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    // 위젯 크기별 표시 개수
    private var maxHabitsToShow: Int {
        switch family {
        case .systemSmall:
            return 1  // 최소 1개 유지
        case .systemMedium:
            return 2
        case .systemLarge:
            return 8
        case .systemExtraLarge:
            return 13
        @unknown default:
            return 1
        }
    }
    
    // 위젯 크기별 폰트 크기
    private var fontSize: CGFloat {
        switch family {
        case .systemSmall:
            return 13
        case .systemMedium:
            return 14
        case .systemLarge, .systemExtraLarge:
            return 15
        @unknown default:
            return 14
        }
    }
    
    // 위젯 크기별 간격
    private var itemSpacing: CGFloat {
        switch family {
        case .systemSmall:
            return 6
        case .systemMedium:
            return 8
        case .systemLarge, .systemExtraLarge:
            return 10
        @unknown default:
            return 8
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            // 헤더 (메모앱 스타일)
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: family == .systemSmall ? 14 : 16))
                Text("오늘의 습관")
                    .font(family == .systemSmall ? .caption : .subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
                
                // 완료 개수 표시
                if !entry.habits.isEmpty {
                    let completedCount = entry.todayCompletions.values.filter { $0 }.count
                    Text("\(completedCount)/\(entry.habits.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(completedCount == entry.habits.count ? .white : .black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(completedCount == entry.habits.count ? Color.green : Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 1.0, green: 0.85, blue: 0.4))  // 진한 노란색
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(red: 0.9, green: 0.75, blue: 0.3).opacity(0.6), lineWidth: 1)
            )

            if entry.habits.isEmpty {
                Text("습관을 추가해보세요")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 12)
            } else {
                // 습관 리스트
                VStack(alignment: .leading, spacing: itemSpacing) {
                    let habitsToShow = entry.habits.prefix(maxHabitsToShow)
                    
                    ForEach(habitsToShow) { habit in
                        HStack(spacing: 10) {
                            Circle()
                                .fill((entry.todayCompletions[habit.title] ?? false) ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: family == .systemSmall ? 10 : 12, height: family == .systemSmall ? 10 : 12)

                            Text(habit.title)
                                .font(.system(size: fontSize))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }

                    // 더보기 표시
                    if entry.habits.count > maxHabitsToShow {
                        Text("+\(entry.habits.count - maxHabitsToShow)개 더보기")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    
                    // 명언 표시 (더보기 바로 아래)
                    if let quote = entry.quote {
                        Text("\(quote.krv) - \(quote.reference)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(family == .systemSmall ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)  // 단색 배경
        }
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
        let todayString = {
            let calendar = Calendar.current
            let today = calendar.dateComponents([.year, .month, .day], from: Date())
            return String(format: "%04d-%02d-%02d", today.year!, today.month!, today.day!)
        }()
        
        let sampleHabits = [
            WidgetHabit(title: "물 2L 마시기", completions: [todayString: true]),
            WidgetHabit(title: "30분 운동", completions: [todayString: false]),
            WidgetHabit(title: "독서 30분", completions: [todayString: true]),
            WidgetHabit(title: "명상 10분", completions: [todayString: false]),
            WidgetHabit(title: "영어 공부", completions: [todayString: true]),
            WidgetHabit(title: "일기 쓰기", completions: [todayString: false]),
            WidgetHabit(title: "스트레칭", completions: [todayString: true]),
            WidgetHabit(title: "비타민 먹기", completions: [todayString: true]),
            WidgetHabit(title: "감사일기", completions: [todayString: false]),
            WidgetHabit(title: "산책 30분", completions: [todayString: true]),
            WidgetHabit(title: "요가", completions: [todayString: false]),
            WidgetHabit(title: "기타 연습", completions: [todayString: true]),
            WidgetHabit(title: "채소 먹기", completions: [todayString: true]),
            WidgetHabit(title: "숙면 7시간", completions: [todayString: false]),
            WidgetHabit(title: "긍정 마인드", completions: [todayString: true])
        ]
        
        let todayCompletions: [String: Bool] = [
            "물 2L 마시기": true,
            "30분 운동": false,
            "독서 30분": true,
            "명상 10분": false,
            "영어 공부": true,
            "일기 쓰기": false,
            "스트레칭": true,
            "비타민 먹기": true,
            "감사일기": false,
            "산책 30분": true,
            "요가": false,
            "기타 연습": true,
            "채소 먹기": true,
            "숙면 7시간": false,
            "긍정 마인드": true
        ]
        
        let sampleQuote = WidgetBibleVerse(
            id: 1,
            reference: "잠언 21:5",
            krv: "부지런한 자의 경영은 풍부함에 이르거니와",
            niv: "The plans of the diligent lead to profit.",
            themes: ["계획", "부지런함"]
        )
        
        Group {
            // Small Widget
            HabitWidgetEntryView(entry: HabitWidgetEntry(
                date: Date(),
                habits: sampleHabits,
                todayCompletions: todayCompletions,
                quote: sampleQuote
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small")
            
            // Medium Widget
            HabitWidgetEntryView(entry: HabitWidgetEntry(
                date: Date(),
                habits: sampleHabits,
                todayCompletions: todayCompletions,
                quote: sampleQuote
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium")
            
            // Large Widget
            HabitWidgetEntryView(entry: HabitWidgetEntry(
                date: Date(),
                habits: sampleHabits,
                todayCompletions: todayCompletions,
                quote: sampleQuote
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large")
        }
    }
}
