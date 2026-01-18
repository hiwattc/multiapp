import SwiftUI
import Combine
import WidgetKit
import UserNotifications

// MARK: - Habit Models
struct Habit: Codable, Identifiable {
    let id: UUID
    var title: String
    var completions: [String: Bool] // "yyyy-MM-dd": true/false
    var reminderTime: Date? // 알림 시간
    var isReminderEnabled: Bool // 알림 활성화 여부

    init(id: UUID = UUID(), title: String, completions: [String: Bool] = [:], reminderTime: Date? = nil, isReminderEnabled: Bool = false) {
        self.id = id
        self.title = title
        self.completions = completions
        self.reminderTime = reminderTime
        self.isReminderEnabled = isReminderEnabled
    }
}

// MARK: - Bible Verse Models
struct BibleVerse: Codable, Identifiable {
    let id: Int
    let reference: String
    let krv: String
    let niv: String
    let themes: [String]
}

struct HabitAdvice: Codable {
    let bibleVersesForHabits: [BibleVerse]
}

// MARK: - Embedded Advice Data - Temporarily removed for debugging

// MARK: - Habit View Model
@MainActor
class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var currentDate = Date()
    @Published var newHabitTitle = ""
    @Published var scrollToToday = false
    @Published var isTextFieldFocused = false

    // 명언 데이터
    var bibleVerses: [BibleVerse] {
        [
            BibleVerse(id: 1, reference: "잠언 21:5", krv: "부지런한 자의 경영은 풍부함에 이르거니와", niv: "The plans of the diligent lead to profit.", themes: ["계획", "부지런함"]),
            BibleVerse(id: 2, reference: "고린도전서 9:27", krv: "내 몸을 쳐 복종하게 함은", niv: "I discipline my body and keep it under control.", themes: ["절제", "자기관리"]),
            BibleVerse(id: 3, reference: "잠언 16:3", krv: "너의 행사를 여호와께 맡기라", niv: "Commit to the Lord whatever you do.", themes: ["계획", "신뢰"]),
            BibleVerse(id: 4, reference: "갈라디아서 6:9", krv: "선한 일을 행하다가 낙심하지 말지니", niv: "Let us not become weary in doing good.", themes: ["지속", "인내"]),
            BibleVerse(id: 5, reference: "잠언 4:23", krv: "무릇 지킬만한 것보다 네 마음을 지키라", niv: "Above all else, guard your heart.", themes: ["멘탈관리", "자기통제"]),
            BibleVerse(id: 6, reference: "전도서 9:10", krv: "무엇이든지 손이 할 일을 힘을 다하여 할지니", niv: "Whatever your hand finds to do, do it with all your might.", themes: ["몰입", "태도"]),
            BibleVerse(id: 7, reference: "시편 119:105", krv: "주의 말씀은 내 발에 등이요", niv: "Your word is a lamp for my feet.", themes: ["방향성", "삶의 기준"]),
            BibleVerse(id: 8, reference: "잠언 13:4", krv: "부지런한 자의 영혼은 풍족함을 얻느니라", niv: "The diligent are fully satisfied.", themes: ["부지런함", "보상"]),
            BibleVerse(id: 9, reference: "잠언 24:27", krv: "일을 밖에 정리하고 밭에 준비하라", niv: "Finish your outdoor work and get your fields ready.", themes: ["준비", "계획"]),
            BibleVerse(id: 10, reference: "마태복음 6:33", krv: "먼저 그의 나라와 그의 의를 구하라", niv: "Seek first his kingdom and his righteousness.", themes: ["우선순위", "신뢰"])
        ]
    }

    private let saveKey = "SavedHabits"
    private let appGroupID = "group.com.news.habit"

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    init() {
        loadHabits()
        // 앱 시작 시 모든 습관 알림 스케줄링
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.scheduleAllHabitReminders()
        }
    }

    var currentYear: Int {
        Calendar.current.component(.year, from: currentDate)
    }

    // 외부에서 접근 가능한 bibleVerses
    var accessibleBibleVerses: [BibleVerse] {
        bibleVerses
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

    func updateHabitTitle(_ habit: Habit, newTitle: String) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }),
              !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        habits[index].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        saveHabits()
    }

    func reorderHabits(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        saveHabits()
    }

    // 알림 권한 요청
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    // 습관 알림 설정
    func setHabitReminder(_ habit: Habit, time: Date) async {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }

        // 알림 권한 확인 및 요청
        let granted = await requestNotificationPermission()
        if !granted {
            print("알림 권한이 거부되었습니다")
            return
        }

        // 습관 알림 설정
        habits[index].reminderTime = time
        habits[index].isReminderEnabled = true
        saveHabits()

        // 알림 스케줄링
        scheduleHabitReminder(habit, time: time)

        print("✅ \(habit.title) 알림 설정됨: \(time.formatted(date: .omitted, time: .shortened))")
    }

    // 습관 알림 해제
    func removeHabitReminder(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }

        habits[index].reminderTime = nil
        habits[index].isReminderEnabled = false
        saveHabits()

        // 기존 알림 취소
        cancelHabitReminder(habit)

        print("❌ \(habit.title) 알림 해제됨")
    }

    // 알림 스케줄링
    private func scheduleHabitReminder(_ habit: Habit, time: Date) {
        let center = UNUserNotificationCenter.current()

        // 기존 알림 취소
        cancelHabitReminder(habit)

        // 오늘의 알림 시간 계산
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        guard let reminderDate = calendar.date(from: components) else { return }

        // 이미 지난 시간이면 내일로 설정
        let finalDate = reminderDate > now ? reminderDate : calendar.date(byAdding: .day, value: 1, to: reminderDate)!

        let content = UNMutableNotificationContent()
        content.title = "습관 알림"
        content.body = "'\(habit.title)' 습관을 체크하세요!"
        content.sound = .default
        content.badge = 1

        let componentsForTrigger = calendar.dateComponents([.hour, .minute], from: finalDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: componentsForTrigger, repeats: true)

        let request = UNNotificationRequest(identifier: "habit-\(habit.id.uuidString)", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("알림 스케줄링 실패: \(error.localizedDescription)")
            }
        }
    }

    // 알림 취소
    private func cancelHabitReminder(_ habit: Habit) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["habit-\(habit.id.uuidString)"])
    }

    // 모든 습관에 대한 알림 스케줄링 (앱 시작 시 호출)
    func scheduleAllHabitReminders() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayString = String(format: "%04d-%02d-%02d",
                                calendar.component(.year, from: today),
                                calendar.component(.month, from: today),
                                calendar.component(.day, from: today))

        for habit in habits where habit.isReminderEnabled {
            if let reminderTime = habit.reminderTime {
                // 습관 완료 여부와 상관없이 모든 습관에 대해 매일 알림 스케줄링
                scheduleHabitReminder(habit, time: reminderTime)
            }
        }
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
            userDefaults.set(encoded, forKey: saveKey)
        }

        // 위젯 업데이트
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadHabits() {
        if let data = userDefaults.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
    }
}

// MARK: - Marquee Text Component
struct MarqueeText: View {
    let text: String
    let reference: String
    let onRefresh: () -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.callout)

                Text(text)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        onRefresh()
                    }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(reference)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(.callout)
                    }
                }
                .frame(width: 60, alignment: .trailing)
            }
        }
    }
}

// MARK: - Recommended Habits
let recommendedHabits = [
    "매일 30분 독서하기", "아침 6시 기상하기", "하루 8시간 수면 유지하기", "매일 물 2L 마시기",
    "아침 스트레칭 10분 하기", "저녁 일기 쓰기", "주 3회 운동하기", "과일 하루 1개 먹기",
    "커피 대신 물 마시기", "하루 10,000보 걷기", "명상 10분 하기", "금연하기",
    "채식 하루 1끼 하기", "아침 일찍 일어나기", "저녁 산책하기", "책 읽기",
    "요가하기", "명상하기", "일찍 잠자기", "물 많이 마시기", "채소 많이 먹기",
    "달리기", "수영하기", "필라테스 하기", "헬스장 가기", "자전거 타기",
    "등산하기", "요가 자세 배우기", "스트레칭 하기", "복식호흡 하기",
    "감사 일기 쓰기", "마음챙김 명상", "자신과의 대화", "목표 설정하기",
    "계획 세우기", "시간 관리하기", "습관 트래킹하기", "자기계발 공부하기",
    "외국어 배우기", "악기 연주하기", "그림 그리기", "글쓰기",
    "요리하기", "베이킹하기", "정원 가꾸기", "사진 찍기",
    "영화 보기", "음악 듣기", "춤 추기", "노래 부르기",
    "피아노 치기", "기타 연주하기", "드럼 연주하기", "노래방 가기",
    "공원 산책하기", "자연 구경하기", "바다 보기", "별 보기"
]

// MARK: - Habit View
struct HabitView: View {
    @ObservedObject var viewModel: HabitViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var editMode: EditMode = .inactive
    @State private var showingDeleteConfirmation = false
    @State private var habitToDelete: Habit?

    // Inspiration Quote State
    @State private var bibleVerses: [BibleVerse] = []
    @State private var selectedVerse: BibleVerse?


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

                // Inspiration Quote Section
                if let verse = selectedVerse {
                    MarqueeText(text: verse.krv, reference: verse.reference, onRefresh: selectRandomVerse)
                        .frame(height: 32)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                // Add Habit Section
                addHabitSection

                // Recommended Habits Section
                if isTextFieldFocused {
                    recommendedHabitsSection
                }

                // Habits List
                if viewModel.habits.isEmpty {
                    emptyStateView
                } else {
                    habitsScrollView
                }
            }
            .onAppear {
                // Load inspiration quotes when view appears
                if bibleVerses.isEmpty {
                    bibleVerses = [
                        BibleVerse(id: 1, reference: "잠언 21:5", krv: "부지런한 자의 경영은 풍부함에 이르거니와", niv: "The plans of the diligent lead to profit.", themes: ["계획", "부지런함"]),
                        BibleVerse(id: 2, reference: "고린도전서 9:27", krv: "내 몸을 쳐 복종하게 함은", niv: "I discipline my body and keep it under control.", themes: ["절제", "자기관리"]),
                        BibleVerse(id: 3, reference: "잠언 16:3", krv: "너의 행사를 여호와께 맡기라", niv: "Commit to the Lord whatever you do.", themes: ["계획", "신뢰"]),
                        BibleVerse(id: 4, reference: "갈라디아서 6:9", krv: "선한 일을 행하다가 낙심하지 말지니", niv: "Let us not become weary in doing good.", themes: ["지속", "인내"]),
                        BibleVerse(id: 5, reference: "로마서 12:2", krv: "마음을 새롭게 함으로 변화를 받으라", niv: "Be transformed by the renewing of your mind.", themes: ["사고습관", "성찰"]),
                        BibleVerse(id: 6, reference: "잠언 4:23", krv: "무릇 지킬만한 것보다 네 마음을 지키라", niv: "Above all else, guard your heart.", themes: ["멘탈관리", "자기통제"]),
                        BibleVerse(id: 7, reference: "전도서 9:10", krv: "무엇이든지 손이 할 일을 힘을 다하여 할지니", niv: "Whatever your hand finds to do, do it with all your might.", themes: ["몰입", "태도"]),
                        BibleVerse(id: 8, reference: "시편 119:105", krv: "주의 말씀은 내 발에 등이요", niv: "Your word is a lamp for my feet.", themes: ["방향성", "삶의 기준"]),
                        BibleVerse(id: 9, reference: "잠언 13:4", krv: "부지런한 자의 영혼은 풍족함을 얻느니라", niv: "The diligent are fully satisfied.", themes: ["부지런함", "보상"]),
                        BibleVerse(id: 10, reference: "마태복음 25:21", krv: "지극히 작은 것에 충성하였으매", niv: "You have been faithful with a few things.", themes: ["작은습관", "충성"]),
                        BibleVerse(id: 11, reference: "야고보서 1:22", krv: "너희는 말씀을 행하는 자가 되라", niv: "Do not merely listen to the word, and so deceive yourselves.", themes: ["실천", "행동"]),
                        BibleVerse(id: 12, reference: "디모데전서 4:7", krv: "경건에 이르도록 네 자신을 연단하라", niv: "Train yourself to be godly.", themes: ["훈련", "자기연단"]),
                        BibleVerse(id: 13, reference: "잠언 6:6", krv: "개미에게 가서 그 부지런함을 보라", niv: "Go to the ant, you sluggard; consider its ways.", themes: ["근면", "자기학습"]),
                        BibleVerse(id: 14, reference: "시편 37:5", krv: "너의 길을 여호와께 맡기라", niv: "Commit your way to the Lord.", themes: ["의지", "신뢰"]),
                        BibleVerse(id: 15, reference: "잠언 12:1", krv: "훈계를 좋아하는 자는 지식을 좋아하느니라", niv: "Whoever loves discipline loves knowledge.", themes: ["훈계", "성장"]),
                        BibleVerse(id: 16, reference: "빌립보서 3:14", krv: "표 때를 향하여 달려가노라", niv: "I press on toward the goal.", themes: ["목표", "집중"]),
                        BibleVerse(id: 17, reference: "시편 90:12", krv: "우리에게 우리 날 계수함을 가르치사", niv: "Teach us to number our days.", themes: ["시간관리", "지혜"]),
                        BibleVerse(id: 18, reference: "골로새서 3:23", krv: "무슨 일을 하든지 마음을 다하여 주께 하듯", niv: "Whatever you do, work at it with all your heart.", themes: ["태도", "책임"]),
                        BibleVerse(id: 19, reference: "히브리서 12:11", krv: "연단은 슬퍼 보이나", niv: "No discipline seems pleasant at the time.", themes: ["훈련", "인내"]),
                        BibleVerse(id: 20, reference: "잠언 20:11", krv: "비록 아이라도 그 행실로 말미암아", niv: "Even children are known by the way they act.", themes: ["행동습관", "성품"]),
                        BibleVerse(id: 21, reference: "벤저민 프랭클린", krv: "계획 없는 삶은 실패다", niv: "Failing to plan is planning to fail.", themes: ["계획", "기록", "자기관리"]),
                        BibleVerse(id: 22, reference: "아리스토텔레스", krv: "습관이 곧 인간이다", niv: "We are what we repeatedly do.", themes: ["습관형성", "철학", "반복"]),
                        BibleVerse(id: 23, reference: "공자", krv: "날마다 자신을 반성하라", niv: "吾日三省吾身", themes: ["성찰", "자기점검"]),
                        BibleVerse(id: 24, reference: "마르쿠스 아우렐리우스", krv: "생각이 인생을 만든다", niv: "Our life is what our thoughts make it.", themes: ["멘탈관리", "기록", "사고습관"]),
                        BibleVerse(id: 25, reference: "아이작 뉴턴", krv: "집중이 발견을 낳는다", niv: "If I have seen further, it is by standing on the shoulders of giants.", themes: ["집중", "연구", "몰입"]),
                        BibleVerse(id: 26, reference: "찰스 다윈", krv: "지속이 진화를 만든다", niv: "The most responsive to change survives.", themes: ["지속성", "관찰", "루틴"]),
                        BibleVerse(id: 27, reference: "니콜라 테슬라", krv: "상상은 현실이 된다", niv: "The present is theirs; the future is mine.", themes: ["창의성", "시각화"]),
                        BibleVerse(id: 28, reference: "마리 퀴리", krv: "두려움은 극복된다", niv: "Nothing in life is to be feared, it is only to be understood.", themes: ["학습", "멘탈관리", "용기"]),
                        BibleVerse(id: 29, reference: "어니스트 헤밍웨이", krv: "매일 써라", niv: "Write drunk, edit sober.", themes: ["글쓰기", "루틴", "실천"]),
                        BibleVerse(id: 30, reference: "무라카미 하루키", krv: "계속 달리고 쓴다", niv: "I write every day and run every day.", themes: ["운동", "창작", "루틴"]),
                        BibleVerse(id: 31, reference: "베토벤", krv: "규칙이 자유를 만든다", niv: "Music is a higher revelation than philosophy.", themes: ["규칙", "창작", "집중"]),
                        BibleVerse(id: 32, reference: "빈센트 반 고흐", krv: "고통 속에 예술이 있다", niv: "I dream my painting and paint my dream.", themes: ["감정관리", "예술", "표현"]),
                        BibleVerse(id: 33, reference: "스티브 잡스", krv: "단순함은 궁극의 정교함", niv: "Simplicity is the ultimate sophistication.", themes: ["미니멀리즘", "의사결정"]),
                        BibleVerse(id: 34, reference: "일론 머스크", krv: "시간은 가장 귀하다", niv: "I work like hell.", themes: ["시간관리", "생산성"]),
                        BibleVerse(id: 35, reference: "제프 베조스", krv: "장기적으로 생각하라", niv: "Be stubborn on vision, flexible on details.", themes: ["비전", "의사결정"]),
                        BibleVerse(id: 36, reference: "워런 버핏", krv: "읽고 또 읽어라", niv: "The best investment you can make is in yourself.", themes: ["독서", "자기계발"]),
                        BibleVerse(id: 37, reference: "마이클 조던", krv: "실패가 성공을 만든다", niv: "I’ve failed over and over again, and that is why I succeed.", themes: ["훈련", "성장", "회복탄력성"]),
                        BibleVerse(id: 38, reference: "코비 브라이언트", krv: "노력은 배신하지 않는다", niv: "The moment you give up is the moment you let someone else win.", themes: ["멘탈", "훈련", "집중"]),
                        BibleVerse(id: 39, reference: "크리스티아누 호날두", krv: "재능은 관리된다", niv: "Talent without hard work is nothing.", themes: ["자기관리", "건강", "절제"]),
                        BibleVerse(id: 40, reference: "타이거 우즈", krv: "연습이 차이를 만든다", niv: "You can always get better.", themes: ["연습", "멘탈관리"])
                    ]
                    selectRandomVerse()
                }
            }
        }
        .onChange(of: isTextFieldFocused) { oldValue, newValue in
            viewModel.isTextFieldFocused = newValue
        }
        .alert("습관 삭제", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) {
                habitToDelete = nil
            }
            Button("삭제", role: .destructive) {
                if let habit = habitToDelete {
                    viewModel.deleteHabit(habit)
                    habitToDelete = nil
                }
            }
        } message: {
            if let habit = habitToDelete {
                Text("'\(habit.title)' 습관을 정말 삭제하시겠습니까?\n삭제된 습관의 모든 기록이 사라집니다.")
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

                Button(action: {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }) {
                    Text(editMode == .active ? "완료" : "순서편집")
                        .font(.caption)
                        .foregroundColor(editMode == .active ? .green : .orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background((editMode == .active ? Color.green : Color.orange).opacity(0.1))
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
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }

    private var addHabitSection: some View {
        HStack {
            TextField(habitPlaceholder, text: $viewModel.newHabitTitle)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    viewModel.addHabit()
                    viewModel.isTextFieldFocused = false
                }
                .padding(12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(12)

            Button(action: {
                viewModel.addHabit()
                viewModel.isTextFieldFocused = false
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
        List {
                ForEach(viewModel.habits) { habit in
                HabitRow(habit: habit, viewModel: viewModel, editMode: $editMode)
                }
            .onMove(perform: viewModel.reorderHabits)
            .onDelete { indexSet in
                // 스와이프 삭제 시 확인 다이얼로그 표시
                if let index = indexSet.first {
                    habitToDelete = viewModel.habits[index]
                    showingDeleteConfirmation = true
                }
            }
        }
        .environment(\.editMode, $editMode)
        .listStyle(.insetGrouped)
            .padding(.bottom, 80)
    }

    private func selectRandomVerse() {
        if !bibleVerses.isEmpty {
            selectedVerse = bibleVerses.randomElement()

            // 진동 효과
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    private var habitPlaceholder: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일"
        let todayString = formatter.string(from: Date())
        return "새 습관 추가 (\(todayString))"
    }

    private var recommendedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("추천 습관")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)

            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(recommendedHabits, id: \.self) { habit in
                            Button(action: {
                                viewModel.newHabitTitle = habit
                                // 추천 습관 선택 후에도 입력창 포커스 유지
                            }) {
                            Text(habit)
                                .font(.callout)
                                .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .frame(minHeight: geometry.size.height * 0.8) // 화면의 80% 높이 사용
                }
                .frame(height: geometry.size.height * 0.8) // ScrollView 자체 높이 설정
            }
            .frame(height: 500) // 전체 GeometryReader 높이 설정
        }
        .padding(.bottom)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .transition(.opacity)
    }
}

// MARK: - Habit Row
struct HabitRow: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @Binding var editMode: EditMode
    @State private var showingDetailView = false
    @State private var isEditingTitle = false
    @State private var editingTitle = ""
    @State private var showingTimePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Habit Title with Completion Stats and Delete Button
            if isEditingTitle {
                // 편집 모드 - 버튼 없이 TextField만, 탭으로 취소
                HStack {
                    TextField("습관 제목", text: $editingTitle)
                        .font(.title2)
                        .foregroundColor(.primary)
                        .submitLabel(.done)
                        .onSubmit {
                            saveTitleEdit()
                        }

                    Spacer()

                    Text("엔터:저장, 탭:취소")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // 편집 취소 - 원래 제목으로 복원
                    editingTitle = habit.title
                    isEditingTitle = false
                }
            } else {
                // 일반 모드 - 제스처 있음
                HStack {
                    HStack(spacing: 8) {
                        Text(habit.title)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .onTapGesture {
                                if editMode == .inactive {
                                    startTitleEdit()
                                }
                            }

                        // 알림 상태 표시
                        if habit.isReminderEnabled {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if editMode == .inactive {
                            showingDetailView = true
                        }
                    }

                    Spacer()

                    // Completion Stats
                    let completedDays = (1...viewModel.daysInMonth).filter { viewModel.isCompleted(habitId: habit.id, day: $0) }.count
                    Text("완료: \(completedDays)/\(viewModel.daysInMonth)일")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if completedDays > 0 {
                        let percentage = Int((Double(completedDays) / Double(viewModel.daysInMonth)) * 100)
                        Text("\(percentage)%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.leading, 8)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode == .inactive {
                        showingDetailView = true
                    }
                }
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
                                            .fill(viewModel.isCompleted(habitId: habit.id, day: day) ? getCompletionColor(for: day) : Color.gray.opacity(0.2))
                                            .frame(width: 36, height: 36)

                                        if viewModel.isCompleted(habitId: habit.id, day: day) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        } else if isToday(day: day) {
                                            Image(systemName: "questionmark")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.gray.opacity(0.5))
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
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .swipeActions(edge: .leading) {
            // 알림 버튼
            Button(action: {
                if habit.isReminderEnabled {
                    viewModel.removeHabitReminder(habit)
                } else {
                    showingTimePicker = true
                }
            }) {
                Label(habit.isReminderEnabled ? "알림 해제" : "알림 설정",
                      systemImage: habit.isReminderEnabled ? "bell.slash.fill" : "bell.fill")
            }
            .tint(habit.isReminderEnabled ? .orange : .blue)
        }
        .sheet(isPresented: $showingDetailView) {
            HabitDetailView(habit: habit, viewModel: viewModel)
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(habit: habit, viewModel: viewModel, isPresented: $showingTimePicker)
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

    private func getCompletionColor(for day: Int) -> Color {
        if isToday(day: day) {
            return Color.green // 오늘 날짜: 밝은 녹색
        } else {
            return Color.green.opacity(0.5) // 이전/미래 날짜: 50% 어두운 녹색
        }
    }

    private func startTitleEdit() {
        editingTitle = habit.title
        isEditingTitle = true
    }

    private func saveTitleEdit() {
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty && trimmedTitle != habit.title {
            viewModel.updateHabitTitle(habit, newTitle: trimmedTitle)
        }
        isEditingTitle = false
        editingTitle = ""
    }

    private func cancelTitleEdit() {
        isEditingTitle = false
        editingTitle = ""
    }
}

// MARK: - Habit Detail View (Calendar)
struct HabitDetailView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.dismiss) var dismiss

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    @State private var bibleVerses: [BibleVerse] = []
    @State private var selectedVerse: BibleVerse?

    init(habit: Habit, viewModel: HabitViewModel) {
        self.habit = habit
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

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
                    .onAppear {
                        // Load data when view appears
                        if bibleVerses.isEmpty {
                            bibleVerses = [
                                BibleVerse(id: 1, reference: "잠언 21:5", krv: "부지런한 자의 경영은 풍부함에 이르거니와", niv: "The plans of the diligent lead to profit.", themes: ["계획", "부지런함"]),
                                BibleVerse(id: 2, reference: "고린도전서 9:27", krv: "내 몸을 쳐 복종하게 함은", niv: "I discipline my body and keep it under control.", themes: ["절제", "자기관리"]),
                                BibleVerse(id: 3, reference: "잠언 16:3", krv: "너의 행사를 여호와께 맡기라", niv: "Commit to the Lord whatever you do.", themes: ["계획", "신뢰"]),
                                BibleVerse(id: 4, reference: "갈라디아서 6:9", krv: "선한 일을 행하다가 낙심하지 말지니", niv: "Let us not become weary in doing good.", themes: ["지속", "인내"]),
                                BibleVerse(id: 5, reference: "로마서 12:2", krv: "마음을 새롭게 함으로 변화를 받으라", niv: "Be transformed by the renewing of your mind.", themes: ["사고습관", "성찰"]),
                                BibleVerse(id: 6, reference: "잠언 4:23", krv: "무릇 지킬만한 것보다 네 마음을 지키라", niv: "Above all else, guard your heart.", themes: ["멘탈관리", "자기통제"]),
                                BibleVerse(id: 7, reference: "전도서 9:10", krv: "무엇이든지 손이 할 일을 힘을 다하여 할지니", niv: "Whatever your hand finds to do, do it with all your might.", themes: ["몰입", "태도"]),
                                BibleVerse(id: 8, reference: "시편 119:105", krv: "주의 말씀은 내 발에 등이요", niv: "Your word is a lamp for my feet.", themes: ["방향성", "삶의 기준"]),
                                BibleVerse(id: 9, reference: "잠언 13:4", krv: "부지런한 자의 영혼은 풍족함을 얻느니라", niv: "The diligent are fully satisfied.", themes: ["부지런함", "보상"]),
                                BibleVerse(id: 10, reference: "마태복음 25:21", krv: "지극히 작은 것에 충성하였으매", niv: "You have been faithful with a few things.", themes: ["작은습관", "충성"]),
                                BibleVerse(id: 11, reference: "야고보서 1:22", krv: "너희는 말씀을 행하는 자가 되라", niv: "Do not merely listen to the word, and so deceive yourselves.", themes: ["실천", "행동"]),
                                BibleVerse(id: 12, reference: "디모데전서 4:7", krv: "경건에 이르도록 네 자신을 연단하라", niv: "Train yourself to be godly.", themes: ["훈련", "자기연단"]),
                                BibleVerse(id: 13, reference: "잠언 6:6", krv: "개미에게 가서 그 부지런함을 보라", niv: "Go to the ant, you sluggard; consider its ways.", themes: ["근면", "자기학습"]),
                                BibleVerse(id: 14, reference: "시편 37:5", krv: "너의 길을 여호와께 맡기라", niv: "Commit your way to the Lord.", themes: ["의지", "신뢰"]),
                                BibleVerse(id: 15, reference: "잠언 12:1", krv: "훈계를 좋아하는 자는 지식을 좋아하느니라", niv: "Whoever loves discipline loves knowledge.", themes: ["훈계", "성장"]),
                                BibleVerse(id: 16, reference: "빌립보서 3:14", krv: "표 때를 향하여 달려가노라", niv: "I press on toward the goal.", themes: ["목표", "집중"]),
                                BibleVerse(id: 17, reference: "시편 90:12", krv: "우리에게 우리 날 계수함을 가르치사", niv: "Teach us to number our days.", themes: ["시간관리", "지혜"]),
                                BibleVerse(id: 18, reference: "골로새서 3:23", krv: "무슨 일을 하든지 마음을 다하여 주께 하듯", niv: "Whatever you do, work at it with all your heart.", themes: ["태도", "책임"]),
                                BibleVerse(id: 19, reference: "히브리서 12:11", krv: "연단은 슬퍼 보이나", niv: "No discipline seems pleasant at the time.", themes: ["훈련", "인내"]),
                                BibleVerse(id: 20, reference: "잠언 20:11", krv: "비록 아이라도 그 행실로 말미암아", niv: "Even children are known by the way they act.", themes: ["행동습관", "성품"]),
                                BibleVerse(id: 21, reference: "벤저민 프랭클린", krv: "계획 없는 삶은 실패다", niv: "Failing to plan is planning to fail.", themes: ["계획", "기록", "자기관리"]),
                                BibleVerse(id: 22, reference: "아리스토텔레스", krv: "습관이 곧 인간이다", niv: "We are what we repeatedly do.", themes: ["습관형성", "철학", "반복"]),
                                BibleVerse(id: 23, reference: "공자", krv: "날마다 자신을 반성하라", niv: "吾日三省吾身", themes: ["성찰", "자기점검"]),
                                BibleVerse(id: 24, reference: "마르쿠스 아우렐리우스", krv: "생각이 인생을 만든다", niv: "Our life is what our thoughts make it.", themes: ["멘탈관리", "기록", "사고습관"]),
                                BibleVerse(id: 25, reference: "아이작 뉴턴", krv: "집중이 발견을 낳는다", niv: "If I have seen further, it is by standing on the shoulders of giants.", themes: ["집중", "연구", "몰입"]),
                                BibleVerse(id: 26, reference: "찰스 다윈", krv: "지속이 진화를 만든다", niv: "The most responsive to change survives.", themes: ["지속성", "관찰", "루틴"]),
                                BibleVerse(id: 27, reference: "니콜라 테슬라", krv: "상상은 현실이 된다", niv: "The present is theirs; the future is mine.", themes: ["창의성", "시각화"]),
                                BibleVerse(id: 28, reference: "마리 퀴리", krv: "두려움은 극복된다", niv: "Nothing in life is to be feared, it is only to be understood.", themes: ["학습", "멘탈관리", "용기"]),
                                BibleVerse(id: 29, reference: "어니스트 헤밍웨이", krv: "매일 써라", niv: "Write drunk, edit sober.", themes: ["글쓰기", "루틴", "실천"]),
                                BibleVerse(id: 30, reference: "무라카미 하루키", krv: "계속 달리고 쓴다", niv: "I write every day and run every day.", themes: ["운동", "창작", "루틴"]),
                                BibleVerse(id: 31, reference: "베토벤", krv: "규칙이 자유를 만든다", niv: "Music is a higher revelation than philosophy.", themes: ["규칙", "창작", "집중"]),
                                BibleVerse(id: 32, reference: "빈센트 반 고흐", krv: "고통 속에 예술이 있다", niv: "I dream my painting and paint my dream.", themes: ["감정관리", "예술", "표현"]),
                                BibleVerse(id: 33, reference: "스티브 잡스", krv: "단순함은 궁극의 정교함", niv: "Simplicity is the ultimate sophistication.", themes: ["미니멀리즘", "의사결정"]),
                                BibleVerse(id: 34, reference: "일론 머스크", krv: "시간은 가장 귀하다", niv: "I work like hell.", themes: ["시간관리", "생산성"]),
                                BibleVerse(id: 35, reference: "제프 베조스", krv: "장기적으로 생각하라", niv: "Be stubborn on vision, flexible on details.", themes: ["비전", "의사결정"]),
                                BibleVerse(id: 36, reference: "워런 버핏", krv: "읽고 또 읽어라", niv: "The best investment you can make is in yourself.", themes: ["독서", "자기계발"]),
                                BibleVerse(id: 37, reference: "마이클 조던", krv: "실패가 성공을 만든다", niv: "I’ve failed over and over again, and that is why I succeed.", themes: ["훈련", "성장", "회복탄력성"]),
                                BibleVerse(id: 38, reference: "코비 브라이언트", krv: "노력은 배신하지 않는다", niv: "The moment you give up is the moment you let someone else win.", themes: ["멘탈", "훈련", "집중"]),
                                BibleVerse(id: 39, reference: "크리스티아누 호날두", krv: "재능은 관리된다", niv: "Talent without hard work is nothing.", themes: ["자기관리", "건강", "절제"]),
                                BibleVerse(id: 40, reference: "타이거 우즈", krv: "연습이 차이를 만든다", niv: "You can always get better.", themes: ["연습", "멘탈관리"])
                            ]
                            selectRandomVerse()
                        }
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
                            ForEach(0..<firstWeekday - 1) { index in
                                Color.clear
                                    .frame(height: 50)
                                    .id("empty-\(index)")
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

                    // Inspiration Quote Section
                    if let verse = selectedVerse {
                        MarqueeText(text: verse.krv, reference: verse.reference, onRefresh: selectRandomVerse)
                            .frame(height: 32)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                    }
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


    private func selectRandomVerse() {
        if !bibleVerses.isEmpty {
            selectedVerse = bibleVerses.randomElement()

            // 진동 효과
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @Binding var isPresented: Bool
    @State private var selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("알림 시간 설정")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("'\(habit.title)' 습관의 알림 시간을 설정하세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                DatePicker("알림 시간",
                          selection: $selectedTime,
                          displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()

                Spacer()
            }
            .padding(.top, 20)
            .navigationBarItems(
                leading: Button("취소") {
                    isPresented = false
                },
                trailing: Button("설정") {
                    Task {
                        await viewModel.setHabitReminder(habit, time: selectedTime)
                        isPresented = false
                    }
                }
                .fontWeight(.semibold)
            )
        }
        .presentationDetents([.medium])
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
