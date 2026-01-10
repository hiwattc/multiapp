import SwiftUI
import Combine

// MARK: - Habit Models
struct Habit: Codable, Identifiable {
    let id: UUID
    var title: String
    var completions: [String: Bool] // "yyyy-MM-dd": true/false

    init(id: UUID = UUID(), title: String, completions: [String: Bool] = [:]) {
        self.id = id
        self.title = title
        self.completions = completions
    }
}

// MARK: - Habit View Model
@MainActor
class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var currentDate = Date()
    @Published var newHabitTitle = ""
    @Published var scrollToToday = false

    private let saveKey = "SavedHabits"

    init() {
        loadHabits()
    }

    var currentYear: Int {
        Calendar.current.component(.year, from: currentDate)
    }

    var currentMonth: Int {
        Calendar.current.component(.month, from: currentDate)
    }

    var daysInMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentDate)!
        return range.count
    }

    func addHabit() {
        guard !newHabitTitle.isEmpty else { return }
        let habit = Habit(title: newHabitTitle)
        habits.append(habit)
        newHabitTitle = ""
        saveHabits()

        // 진동 효과
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        saveHabits()
    }

    func toggleCompletion(habitId: UUID, day: Int) {
        guard let index = habits.firstIndex(where: { $0.id == habitId }) else { return }

        let dateString = String(format: "%04d-%02d-%02d", currentYear, currentMonth, day)
        let currentValue = habits[index].completions[dateString] ?? false
        habits[index].completions[dateString] = !currentValue
        saveHabits()

        // 진동 효과
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func isCompleted(habitId: UUID, day: Int) -> Bool {
        guard let habit = habits.first(where: { $0.id == habitId }) else { return false }
        let dateString = String(format: "%04d-%02d-%02d", currentYear, currentMonth, day)
        return habit.completions[dateString] ?? false
    }

    func getDayOfWeek(day: Int) -> Int {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: currentDate)
        components.day = day

        if let date = calendar.date(from: components) {
            return calendar.component(.weekday, from: date) // 1: 일요일, 7: 토요일
        }
        return 0
    }

    func getDayColor(day: Int) -> Color {
        let weekday = getDayOfWeek(day: day)
        if weekday == 1 { // 일요일
            return .red
        } else if weekday == 7 { // 토요일
            return .blue
        } else {
            return .secondary
        }
    }

    func previousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) {
            currentDate = newDate
        }
    }

    func nextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) {
            currentDate = newDate
        }
    }

    func goToToday() {
        currentDate = Date()
        scrollToToday = true

        // 잠시 후 플래그 리셋
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.scrollToToday = false
        }
    }

    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
    }
}

// MARK: - Habit View
struct HabitView: View {
    @StateObject private var viewModel = HabitViewModel()
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    isTextFieldFocused = false
                }

            VStack(spacing: 0) {
                // Month Navigation
                monthNavigationBar

                // Add Habit Section
                addHabitSection

                // Habits List
                if viewModel.habits.isEmpty {
                    emptyStateView
                } else {
                    habitsScrollView
                }
            }
        }
    }

    private var monthNavigationBar: some View {
        HStack {
            Button(action: {
                viewModel.previousMonth()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(String(format: "%d년 %d월", viewModel.currentYear, viewModel.currentMonth))
                    .font(.title2)
                    .fontWeight(.bold)

                Button(action: {
                    viewModel.goToToday()
                }) {
                    Text("오늘")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }

            Spacer()

            Button(action: {
                viewModel.nextMonth()
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }

    private var addHabitSection: some View {
        HStack {
            TextField("새 습관 추가", text: $viewModel.newHabitTitle)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    viewModel.addHabit()
                    isTextFieldFocused = false
                }
                .padding(12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(12)

            Button(action: {
                viewModel.addHabit()
                isTextFieldFocused = false
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.badge.questionmark.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("습관을 추가해보세요")
                .font(.headline)

            Text("매일 체크하고 싶은 습관을 입력하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var habitsScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.habits) { habit in
                    HabitRow(habit: habit, viewModel: viewModel)
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
    }
}

// MARK: - Habit Row
struct HabitRow: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @State private var showingDeleteAlert = false
    @State private var showingDetailView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Habit Title with Delete Button
            HStack {
                Text(habit.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingDetailView = true
            }

            // Days Scroll View
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(1...viewModel.daysInMonth, id: \.self) { day in
                            VStack(spacing: 4) {
                                Text("\(day)")
                                    .font(.caption2)
                                    .foregroundColor(viewModel.getDayColor(day: day))
                                    .fontWeight(viewModel.getDayOfWeek(day: day) == 1 || viewModel.getDayOfWeek(day: day) == 7 ? .semibold : .regular)

                                Button(action: {
                                    viewModel.toggleCompletion(habitId: habit.id, day: day)
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(viewModel.isCompleted(habitId: habit.id, day: day) ? Color.green : Color.gray.opacity(0.2))
                                            .frame(width: 36, height: 36)

                                        if viewModel.isCompleted(habitId: habit.id, day: day) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .id(day)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onAppear {
                    scrollToTodayIfNeeded(proxy: proxy)
                }
                .onChange(of: viewModel.scrollToToday) { oldValue, newValue in
                    if newValue {
                        scrollToTodayIfNeeded(proxy: proxy)
                    }
                }
            }

            // Completion Stats
            HStack {
                let completedDays = (1...viewModel.daysInMonth).filter { viewModel.isCompleted(habitId: habit.id, day: $0) }.count

                Text("완료: \(completedDays)/\(viewModel.daysInMonth)일")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if completedDays > 0 {
                    let percentage = Int((Double(completedDays) / Double(viewModel.daysInMonth)) * 100)
                    Text("\(percentage)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .alert("습관 삭제", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                viewModel.deleteHabit(habit)
            }
        } message: {
            Text("'\(habit.title)' 습관을 삭제하시겠습니까?")
        }
        .sheet(isPresented: $showingDetailView) {
            HabitDetailView(habit: habit, viewModel: viewModel)
        }
    }

    private func scrollToTodayIfNeeded(proxy: ScrollViewProxy) {
        let today = Calendar.current.component(.day, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        if currentYear == viewModel.currentYear && currentMonth == viewModel.currentMonth {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    proxy.scrollTo(today, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Habit Detail View (Calendar)
struct HabitDetailView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.dismiss) var dismiss

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(habit.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(String(format: "%d년 %d월", viewModel.currentYear, viewModel.currentMonth))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    // Stats
                    HStack(spacing: 20) {
                        StatBox(
                            title: "완료",
                            value: "\(completedDays)",
                            color: .green
                        )

                        StatBox(
                            title: "미완료",
                            value: "\(viewModel.daysInMonth - completedDays)",
                            color: .gray
                        )

                        StatBox(
                            title: "달성률",
                            value: "\(completionPercentage)%",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    // Calendar
                    VStack(spacing: 12) {
                        // Weekday Headers
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(0..<7) { index in
                                Text(weekdays[index])
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(index == 0 ? .red : index == 6 ? .blue : .secondary)
                                    .frame(height: 30)
                            }
                        }

                        // Calendar Days
                        LazyVGrid(columns: columns, spacing: 8) {
                            // Empty cells for first week
                            ForEach(0..<firstWeekday - 1, id: \.self) { _ in
                                Color.clear
                                    .frame(height: 50)
                            }

                            // Days
                            ForEach(1...viewModel.daysInMonth, id: \.self) { day in
                                let isCompleted = viewModel.isCompleted(habitId: habit.id, day: day)
                                let isToday = isToday(day: day)
                                let weekday = viewModel.getDayOfWeek(day: day)

                                Button(action: {
                                    viewModel.toggleCompletion(habitId: habit.id, day: day)
                                }) {
                                    VStack(spacing: 4) {
                                        Text("\(day)")
                                            .font(.system(size: 16, weight: isToday ? .bold : .regular))
                                            .foregroundColor(
                                                isToday ? .white :
                                                weekday == 1 ? .red :
                                                weekday == 7 ? .blue :
                                                .primary
                                            )

                                        if isCompleted {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                isToday ? Color.blue :
                                                isCompleted ? Color.green.opacity(0.1) :
                                                Color(UIColor.tertiarySystemGroupedBackground)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var firstWeekday: Int {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: viewModel.currentDate)
        components.day = 1

        if let date = calendar.date(from: components) {
            return calendar.component(.weekday, from: date)
        }
        return 1
    }

    private var completedDays: Int {
        (1...viewModel.daysInMonth).filter { viewModel.isCompleted(habitId: habit.id, day: $0) }.count
    }

    private var completionPercentage: Int {
        Int((Double(completedDays) / Double(viewModel.daysInMonth)) * 100)
    }

    private func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let todayDay = calendar.component(.day, from: today)
        let todayMonth = calendar.component(.month, from: today)
        let todayYear = calendar.component(.year, from: today)

        return day == todayDay &&
               viewModel.currentMonth == todayMonth &&
               viewModel.currentYear == todayYear
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
