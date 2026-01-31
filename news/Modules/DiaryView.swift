import SwiftUI
import Combine

// MARK: - Diary Models
struct DiaryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    var content: String
    var mood: String // 이모티콘
    let createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), date: Date, content: String, mood: String) {
        self.id = id
        self.date = date
        self.content = content
        self.mood = mood
        self.createdAt = Date()
        self.updatedAt = Date()
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
    
    func saveDiary(content: String, mood: String, for date: Date) {
        let calendar = Calendar.current
        
        if let existingIndex = diaries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            // 기존 일기 업데이트
            diaries[existingIndex].content = content
            diaries[existingIndex].mood = mood
            diaries[existingIndex].updatedAt = Date()
        } else {
            // 새 일기 추가
            let newDiary = DiaryEntry(date: date, content: content, mood: mood)
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
}

// MARK: - Diary List View
struct DiaryListView: View {
    @StateObject private var viewModel = DiaryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var selectedDate = Date()
    
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
                    Button(action: {
                        selectedDate = Date()
                        showingEditor = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                DiaryEditorView(date: selectedDate)
            }
            .onAppear {
                // 화면이 나타날 때마다 데이터 새로고침
                viewModel.loadDiaries()
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
                    showingEditor = true
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    viewModel.deleteDiary(viewModel.diaries[index])
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
                    Text(diary.dateString)
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
}

// MARK: - Diary Editor View
struct DiaryEditorView: View {
    @StateObject private var viewModel = DiaryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    @State private var content: String = ""
    @State private var selectedMood: String = "😊"
    @State private var showMoodPicker = false
    
    init(date: Date) {
        self.date = date
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 날짜 헤더
                dateHeader
                
                // 감성 선택
                moodSection
                
                // 일기 작성
                ScrollView {
                    TextEditor(text: $content)
                        .frame(minHeight: 300)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("일기 쓰기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        viewModel.saveDiary(content: content, mood: selectedMood, for: date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let existingDiary = viewModel.getDiary(for: date) {
                    content = existingDiary.content
                    selectedMood = existingDiary.mood
                }
            }
        }
    }
    
    private var dateHeader: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 EEEE"
        
        return VStack(spacing: 8) {
            Text(formatter.string(from: date))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(Calendar.current.isDateInToday(date) ? "오늘" : "")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Preview
#Preview {
    DiaryListView()
}

