import SwiftUI
import Combine
import UniformTypeIdentifiers
import UIKit

// MARK: - Diary Models
struct DiaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var date: Date
    var title: String
    var content: String
    var mood: String // 이모티콘
    var activities: [String] // 활동 이모티콘 배열
    var hashtags: [String] // 해시태그 배열
    let createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), date: Date, title: String = "", content: String, mood: String, activities: [String] = [], hashtags: [String] = []) {
        self.id = id
        self.date = date
        self.title = title
        self.content = content
        self.mood = mood
        self.activities = activities
        self.hashtags = hashtags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // 기존 데이터 호환성을 위한 커스텀 디코딩
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decode(String.self, forKey: .content)
        mood = try container.decode(String.self, forKey: .mood)
        activities = try container.decodeIfPresent([String].self, forKey: .activities) ?? []
        hashtags = try container.decodeIfPresent([String].self, forKey: .hashtags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, date, title, content, mood, activities, hashtags, createdAt, updatedAt
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 EEEE"
        return formatter.string(from: date)
    }
    
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Mood Options
struct MoodOption: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let color: Color
}

let moodOptions: [MoodOption] = [
    MoodOption(emoji: "😊", label: "행복", color: .yellow),
    MoodOption(emoji: "😌", label: "평온", color: .green),
    MoodOption(emoji: "😔", label: "우울", color: .blue),
    MoodOption(emoji: "😤", label: "화남", color: .red),
    MoodOption(emoji: "😰", label: "불안", color: .purple),
    MoodOption(emoji: "🥰", label: "사랑", color: .pink),
    MoodOption(emoji: "😎", label: "자신감", color: .orange),
    MoodOption(emoji: "🤔", label: "생각", color: .gray),
    MoodOption(emoji: "😴", label: "피곤", color: .indigo),
    MoodOption(emoji: "🤗", label: "감사", color: .mint)
]

// MARK: - Activity Options
struct ActivityOption: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
}

let activityOptions: [ActivityOption] = [
    ActivityOption(emoji: "🏃", label: "런닝"),
    ActivityOption(emoji: "🚶", label: "산책"),
    ActivityOption(emoji: "📚", label: "독서"),
    ActivityOption(emoji: "🎬", label: "영화"),
    ActivityOption(emoji: "✈️", label: "여행"),
    ActivityOption(emoji: "👨‍👩‍👧‍👦", label: "가족만남"),
    ActivityOption(emoji: "👫", label: "친구만남"),
    ActivityOption(emoji: "💪", label: "운동"),
    ActivityOption(emoji: "👨‍🍳", label: "요리"),
    ActivityOption(emoji: "🛍️", label: "쇼핑"),
    ActivityOption(emoji: "🎵", label: "음악"),
    ActivityOption(emoji: "🎮", label: "게임"),
    ActivityOption(emoji: "📷", label: "사진"),
    ActivityOption(emoji: "🏊", label: "수영"),
    ActivityOption(emoji: "🚴", label: "자전거"),
    ActivityOption(emoji: "🧘", label: "요가"),
    ActivityOption(emoji: "☕", label: "카페"),
    ActivityOption(emoji: "📖", label: "공부"),
    ActivityOption(emoji: "🐕", label: "반려동물"),
    ActivityOption(emoji: "😴", label: "휴식")
]

// MARK: - Title Suggestions
let titleSuggestions: [String] = [
    "오늘 하루 주님의 은혜로 살았습니다",
    "하나님의 사랑 안에서 하루를 마쳤습니다",
    "오늘도 주님의 인도하심에 감사합니다",
    "하루를 주님과 함께 보낸 감사한 날",
    "오늘 하루 주님의 축복이 가득했습니다",
    "하나님의 은혜로 하루를 마무리합니다",
    "오늘도 주님의 평안 가운데 지냈습니다",
    "하루를 주님께 감사하며 마칩니다",
    "오늘 하루 주님의 인도하심에 감사드립니다",
    "하나님의 사랑으로 채워진 하루였습니다",
    "오늘도 주님의 은혜로 하루를 보냈습니다",
    "하루를 주님과 함께한 감사한 시간",
    "오늘 하루 주님의 축복이 함께했습니다",
    "하나님의 인도하심에 감사하며 하루를 마칩니다",
    "오늘도 주님의 평안 가운데 하루를 지냈습니다",
    "하루를 주님께 감사하며 마무리합니다",
    "오늘 하루 주님의 사랑으로 채워졌습니다",
    "하나님의 은혜로 하루를 마쳤습니다",
    "오늘도 주님의 인도하심에 감사드립니다",
    "하루를 주님과 함께 보낸 축복받은 날",
    // 문학적인 표현의 제목 추천
    "시간이 흐르는 소리를 들으며",
    "오늘의 빛과 그림자",
    "하루의 끝에서 바라본 풍경",
    "시간의 흔적을 따라",
    "오늘 하루의 조각들",
    "일상 속에서 찾은 작은 기적",
    "시간이 멈춘 순간들",
    "오늘의 기억 속으로",
    "하루의 마지막 페이지",
    "시간의 강물을 따라 흐르며",
    "오늘의 하늘과 나",
    "일상의 시와 같은 하루",
    "시간의 향기를 따라",
    "오늘 하루의 이야기",
    "하루의 마지막 노트",
    "시간이 남긴 흔적",
    "오늘의 감정과 생각들",
    "일상 속의 시적 순간",
    "하루의 끝에서 발견한 것들",
    "시간의 바다를 항해하며"
]

// MARK: - Diary View Model
@MainActor
class DiaryViewModel: ObservableObject {
    @Published var diaries: [DiaryEntry] = []
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    
    private let saveKey = "SavedDiaries"
    private let appGroupID = "group.com.news.habit"
    
    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    
    init() {
        loadDiaries()
        
        // 일기 데이터 변경 감지
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DiaryDataChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadDiaries()
            print("🔄 일기 데이터 새로고침 완료")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DiaryDataChanged"), object: nil)
    }
    
    func loadDiaries() {
        guard let data = userDefaults.data(forKey: saveKey) else {
            diaries = []
            return
        }
        
        do {
            diaries = try JSONDecoder().decode([DiaryEntry].self, from: data)
            diaries.sort { $0.date > $1.date } // 최신순
        } catch {
            print("일기 로드 실패: \(error)")
            diaries = []
        }
    }
    
    func saveDiaries() {
        do {
            let data = try JSONEncoder().encode(diaries)
            userDefaults.set(data, forKey: saveKey)
            print("✅ 일기 저장 완료")
        } catch {
            print("❌ 일기 저장 실패: \(error)")
        }
    }
    
    func getDiary(for date: Date) -> DiaryEntry? {
        let calendar = Calendar.current
        return diaries.first { diary in
            calendar.isDate(diary.date, inSameDayAs: date)
        }
    }
    
    func saveDiary(title: String, content: String, mood: String, activities: [String], hashtags: [String], for date: Date, editingDiary: DiaryEntry? = nil) {
        if let editingDiary = editingDiary {
            // 수정 모드: 기존 일기 업데이트
            if let existingIndex = diaries.firstIndex(where: { $0.id == editingDiary.id }) {
                diaries[existingIndex].title = title
                diaries[existingIndex].content = content
                diaries[existingIndex].mood = mood
                diaries[existingIndex].activities = activities
                diaries[existingIndex].hashtags = hashtags
                diaries[existingIndex].date = date
                diaries[existingIndex].updatedAt = Date()
            }
            // 날짜가 변경되었을 수 있으므로 정렬
            diaries.sort { $0.date > $1.date }
        } else {
            // 추가 모드: 항상 새 일기 추가
            let newDiary = DiaryEntry(date: date, title: title, content: content, mood: mood, activities: activities, hashtags: hashtags)
            diaries.append(newDiary)
            diaries.sort { $0.date > $1.date }
        }
        
        saveDiaries()
        
        // 다른 화면에 일기 변경 알림
        NotificationCenter.default.post(name: NSNotification.Name("DiaryDataChanged"), object: nil)
    }
    
    func deleteDiary(_ diary: DiaryEntry) {
        diaries.removeAll { $0.id == diary.id }
        saveDiaries()
        
        // 다른 화면에 일기 변경 알림
        NotificationCenter.default.post(name: NSNotification.Name("DiaryDataChanged"), object: nil)
    }
    
    func getAllHashtags() -> [String] {
        let allHashtags = diaries.flatMap { $0.hashtags }
        // 중복 제거 및 정렬
        return Array(Set(allHashtags)).sorted()
    }
}

// MARK: - Diary List View
struct DiaryListView: View {
    @StateObject private var viewModel = DiaryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var selectedDate = Date()
    @State private var editingDiary: DiaryEntry? = nil
    @State private var diaryToDelete: DiaryEntry? = nil
    @State private var showingDeleteAlert = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.diaries.isEmpty {
                    emptyStateView
                } else {
                    diaryListContent
                }
            }
            .navigationTitle("나의 일기장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape")
                        }
                        
                        Button(action: {
                            selectedDate = Date()
                            editingDiary = nil // 새로 작성
                            showingEditor = true
                        }) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                DiarySettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditor) {
                DiaryEditorView(date: selectedDate, editingDiary: editingDiary)
            }
            .onAppear {
                // 화면이 나타날 때마다 데이터 새로고침
                viewModel.loadDiaries()
            }
            .alert("일기 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) {
                    diaryToDelete = nil
                }
                Button("삭제", role: .destructive) {
                    if let diary = diaryToDelete {
                        viewModel.deleteDiary(diary)
                        diaryToDelete = nil
                    }
                }
            } message: {
                if let diary = diaryToDelete {
                    Text("'\(diary.title.isEmpty ? diary.dateString : diary.title)' 일기를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.")
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("작성된 일기가 없습니다")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("오늘의 일기를 작성해보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                selectedDate = Date()
                editingDiary = nil // 새로 작성
                showingEditor = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("일기 쓰기")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var diaryListContent: some View {
        List {
            ForEach(viewModel.diaries) { diary in
                DiaryRowView(diary: diary) {
                    selectedDate = diary.date
                    editingDiary = diary // 수정 모드
                    showingEditor = true
                }
            }
            .onDelete { indexSet in
                if let firstIndex = indexSet.first {
                    diaryToDelete = viewModel.diaries[firstIndex]
                    showingDeleteAlert = true
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Diary Row View
struct DiaryRowView: View {
    let diary: DiaryEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 날짜 카드
                VStack(spacing: 4) {
                    Text(diary.shortDateString)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Text(diary.mood)
                        .font(.system(size: 32))
                }
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                
                // 일기 내용 미리보기
                VStack(alignment: .leading, spacing: 4) {
                    Text(diary.title.isEmpty ? diary.dateString : diary.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !diary.content.isEmpty {
                        Text(diary.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("내용 없음")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.5))
                            .italic()
                    }
                    
                    // 활동 이모티콘 및 수정일시 표시
                    HStack(spacing: 6) {
                        // 활동 이모티콘
                        if !diary.activities.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(diary.activities, id: \.self) { activityEmoji in
                                    Text(activityEmoji)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // 수정일시
                        Text(formatDate(diary.updatedAt))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    
                    // 해시태그 표시 (별도 줄)
                    if !diary.hashtags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(diary.hashtags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.blue.opacity(0.7))
                            }
                            if diary.hashtags.count > 3 {
                                Text("+\(diary.hashtags.count - 3)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "오늘 \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "어제 \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Diary Editor View
struct DiaryEditorView: View {
    @StateObject private var viewModel = DiaryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    let editingDiary: DiaryEntry?
    @State private var selectedDate: Date
    @State private var title: String
    @State private var content: String
    @State private var selectedMood: String
    @State private var showMoodPicker = false
    @State private var contentHeight: CGFloat = 80
    @State private var selectedActivities: Set<String>
    @State private var showDatePicker = false
    @State private var hashtags: [String] = []
    @State private var hashtagInput: String = ""
    @State private var showTitleSuggestions = false
    @State private var existingHashtags: [String] = []
    @State private var showExistingHashtags = false
    
    init(date: Date, editingDiary: DiaryEntry? = nil) {
        self.date = date
        self.editingDiary = editingDiary
        
        // 초기값을 editingDiary에서 설정
        _selectedDate = State(initialValue: editingDiary?.date ?? date)
        _title = State(initialValue: editingDiary?.title ?? "")
        _content = State(initialValue: editingDiary?.content ?? "")
        _selectedMood = State(initialValue: editingDiary?.mood ?? "😊")
        _selectedActivities = State(initialValue: Set(editingDiary?.activities ?? []))
        _hashtags = State(initialValue: editingDiary?.hashtags ?? [])
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 날짜 선택 (수정 모드일 때만)
                    if editingDiary != nil {
                        dateSection
                    }
                    
                    // 제목 입력
                    titleSection
                    
                    // 해시태그
                    hashtagSection
                    
                    // 일기 내용 입력
                    contentSection
                    
                    // 감성 선택
                    moodSection
                    
                    // 오늘의 활동
                    activitySection
                    
                    Spacer()
                        .frame(height: 20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(editingDiary != nil ? "일기 수정" : "일기 쓰기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        viewModel.saveDiary(
                            title: title,
                            content: content,
                            mood: selectedMood,
                            activities: Array(selectedActivities),
                            hashtags: hashtags,
                            for: selectedDate,
                            editingDiary: editingDiary
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: editingDiary) { newValue in
                // editingDiary가 변경될 때 데이터 업데이트
                if let editingDiary = newValue {
                    selectedDate = editingDiary.date
                    title = editingDiary.title
                    content = editingDiary.content
                    selectedMood = editingDiary.mood
                    selectedActivities = Set(editingDiary.activities)
                    hashtags = editingDiary.hashtags
                }
            }
            .onAppear {
                // 기존 해시태그 목록 로드
                existingHashtags = viewModel.getAllHashtags()
            }
        }
    }
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("날짜")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                showDatePicker = true
            }) {
                HStack {
                    Text(formatDateString(selectedDate))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker(
                    "날짜 선택",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .navigationTitle("날짜 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("완료") {
                            showDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 EEEE"
        return formatter.string(from: date)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("제목")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showTitleSuggestions.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                        Text("추천 문장")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            TextField("일기 제목을 입력하세요", text: $title)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            
            if showTitleSuggestions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(titleSuggestions, id: \.self) { suggestion in
                            Button(action: {
                                title = suggestion
                                showTitleSuggestions = false
                            }) {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                TextEditor(text: $content)
                    .frame(height: contentHeight)
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                
                // 드래그 핸들
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 40, height: 4)
                    Spacer()
                }
                .frame(height: 12)
                .background(Color(UIColor.systemBackground))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newHeight = contentHeight + value.translation.height
                            // 최소 60pt, 최대 400pt로 제한
                            contentHeight = max(60, min(400, newHeight))
                        }
                )
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 기분")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(moodOptions) { mood in
                        MoodButton(
                            mood: mood,
                            isSelected: selectedMood == mood.emoji
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMood = mood.emoji
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 활동")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activityOptions) { activity in
                        ActivityButton(
                            activity: activity,
                            isSelected: selectedActivities.contains(activity.emoji)
                        ) {
                            if selectedActivities.contains(activity.emoji) {
                                selectedActivities.remove(activity.emoji)
                            } else {
                                selectedActivities.insert(activity.emoji)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("해시태그")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // 해시태그 입력
            HStack {
                TextField("#해시태그 입력", text: $hashtagInput)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    .onSubmit {
                        addHashtag()
                    }
                    .onTapGesture {
                        showExistingHashtags = true
                    }
                
                Button(action: {
                    addHashtag()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                if !existingHashtags.isEmpty {
                    Button(action: {
                        showExistingHashtags.toggle()
                    }) {
                        Image(systemName: showExistingHashtags ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            
            // 기존 해시태그 목록
            if showExistingHashtags && !existingHashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(existingHashtags, id: \.self) { tag in
                            Button(action: {
                                if !hashtags.contains(tag) {
                                    hashtags.append(tag)
                                }
                            }) {
                                Text("#\(tag)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }
            
            // 해시태그 목록
            if !hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hashtags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Button(action: {
                                    hashtags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private func addHashtag() {
        let trimmed = hashtagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !hashtags.contains(trimmed) {
            hashtags.append(trimmed)
            hashtagInput = ""
        }
    }
}

// MARK: - Mood Button
struct MoodButton: View {
    let mood: MoodOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 36))
                
                Text(mood.label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? mood.color : .secondary)
            }
            .frame(width: 70, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? mood.color.opacity(0.2) : Color(UIColor.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? mood.color : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity Button
struct ActivityButton: View {
    let activity: ActivityOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(activity.emoji)
                    .font(.system(size: 32))
                
                Text(activity.label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .frame(width: 60, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(UIColor.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Diary Settings View
struct DiarySettingsView: View {
    @ObservedObject var viewModel: DiaryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingBackupPicker = false
    @State private var showingRestorePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var backupDocument: BackupDocument? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        prepareBackupFile()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("iCloud로 백업")
                        }
                    }
                    
                    Button(action: {
                        showingRestorePicker = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.green)
                            Text("iCloud에서 복구")
                        }
                    }
                } header: {
                    Text("백업 및 복구")
                } footer: {
                    Text("일기 데이터를 JSON 파일로 백업하거나 복구할 수 있습니다.")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingRestorePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importFromJSON(url: url)
                    }
                case .failure(let error):
                    showAlert(title: "오류", message: "파일 선택 실패: \(error.localizedDescription)")
                }
            }
            .fileExporter(
                isPresented: $showingBackupPicker,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "diary_backup_\(Date().timeIntervalSince1970)"
            ) { result in
                switch result {
                case .success(let url):
                    showAlert(title: "백업 완료", message: "파일이 저장되었습니다: \(url.lastPathComponent)")
                    backupDocument = nil
                case .failure(let error):
                    showAlert(title: "백업 실패", message: "파일 저장 실패: \(error.localizedDescription)")
                    backupDocument = nil
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func prepareBackupFile() {
        do {
            let data = try JSONEncoder().encode(viewModel.diaries)
            let fileName = "diary_backup_\(Date().timeIntervalSince1970).json"
            
            // 임시 디렉토리에 파일 저장
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            
            backupDocument = BackupDocument(data: tempURL)
            showingBackupPicker = true
        } catch {
            showAlert(title: "백업 실패", message: "데이터 저장 중 오류가 발생했습니다: \(error.localizedDescription)")
        }
    }
    
    private func importFromJSON(url: URL) {
        do {
            // 파일 접근 권한 획득
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            let importedDiaries = try JSONDecoder().decode([DiaryEntry].self, from: data)
            
            // 기존 데이터와 병합 (중복 제거)
            var existingIds = Set(viewModel.diaries.map { $0.id })
            var newDiaries = viewModel.diaries
            
            for diary in importedDiaries {
                if !existingIds.contains(diary.id) {
                    newDiaries.append(diary)
                    existingIds.insert(diary.id)
                }
            }
            
            // 정렬 및 저장
            newDiaries.sort { $0.date > $1.date }
            viewModel.diaries = newDiaries
            viewModel.saveDiaries()
            
            showAlert(title: "복구 완료", message: "\(importedDiaries.count)개의 일기가 복구되었습니다.")
        } catch {
            showAlert(title: "복구 실패", message: "파일 읽기 중 오류가 발생했습니다: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Backup Document
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: URL?
    
    init(data: URL?) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            // 읽기용 (복구 시 사용)
            self.data = nil
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let sourceURL = data else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        let fileData = try Data(contentsOf: sourceURL)
        return FileWrapper(regularFileWithContents: fileData)
    }
}

// MARK: - Preview
#Preview {
    DiaryListView()
}

