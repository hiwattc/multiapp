import SwiftUI
import Combine
import CoreLocation
import WebKit

// MARK: - Models
struct NewsResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [Article]
}

struct Article: Codable, Identifiable {
    let id = UUID()
    let source: Source
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case source, author, title, description, url, urlToImage, publishedAt, content
    }
}

struct Source: Codable {
    let id: String?
    let name: String
}

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
        manager.stopUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Map Type
enum MapType: String, CaseIterable {
    case openStreetMap = "OpenStreetMap"
    case esriSatellite = "ESRI 항공"
    
    var icon: String {
        switch self {
        case .openStreetMap: return "map"
        case .esriSatellite: return "globe.asia.australia.fill"
        }
    }
}

// MARK: - Art Models
struct MetSearchResponse: Codable {
    let total: Int
    let objectIDs: [Int]?
}

struct Artwork: Codable, Identifiable {
    let objectID: Int
    let title: String
    let artistDisplayName: String?
    let objectDate: String?
    let medium: String?
    let department: String?
    let culture: String?
    let primaryImage: String?
    let primaryImageSmall: String?
    let objectURL: String?
    let creditLine: String?
    let classification: String?
    let dimensions: String?
    
    var id: Int { objectID }
    
    var artist: String {
        artistDisplayName ?? "작가 미상"
    }
    
    var date: String {
        objectDate ?? "제작연도 미상"
    }
}

// MARK: - Art Service
class ArtService {
    static let shared = ArtService()
    private let baseURL = "https://collectionapi.metmuseum.org/public/collection/v1"
    
    // 캐시 추가
    private var artworkCache: [Int: Artwork] = [:]
    private var featuredCache: [Artwork]?
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 3600 // 1시간
    
    func searchArtworks(query: String = "painting") async throws -> [Int] {
        let urlString = "\(baseURL)/search?hasImages=true&q=\(query)"
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MetSearchResponse.self, from: data)
        return Array((response.objectIDs ?? []).prefix(30)) // 50개 -> 30개로 감소
    }
    
    func getArtwork(objectID: Int) async throws -> Artwork {
        // 캐시 확인
        if let cached = artworkCache[objectID] {
            return cached
        }
        
        let urlString = "\(baseURL)/objects/\(objectID)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let artwork = try JSONDecoder().decode(Artwork.self, from: data)
        
        // 캐시 저장
        artworkCache[objectID] = artwork
        return artwork
    }
    
    func getFeaturedArtworks() async throws -> [Artwork] {
        // 캐시 확인
        if let cached = featuredCache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            return cached
        }
        
        // 유명한 작품들의 Object ID (Met Museum의 하이라이트 작품들)
        let featuredIDs = [
            436535, // Monet - Water Lilies
            438817, // Van Gogh - Wheat Field with Cypresses
            437853, // Vermeer - Young Woman with a Water Pitcher
            436105, // Renoir - Madame Georges Charpentier
            437133, // Cézanne - Still Life with Apples
            436121, // Monet - The Houses of Parliament
            547802, // Picasso - Gertrude Stein
            489464, // Rembrandt - Self-Portrait
            437394, // Degas - The Dance Class
            436947, // Cassatt - Lady at the Tea Table
            437112, // Manet - Boating
            459055  // Klimt - Mäda Primavesi (12개로 축소)
        ]
        
        // 병렬 처리로 속도 개선
        let artworks = await withTaskGroup(of: Artwork?.self) { group in
            for id in featuredIDs {
                group.addTask {
                    do {
                        let artwork = try await self.getArtwork(objectID: id)
                        if artwork.primaryImage != nil && !artwork.primaryImage!.isEmpty {
                            return artwork
                        }
                    } catch {
                        print("Failed to load artwork \(id): \(error)")
                    }
                    return nil
                }
            }
            
            var results: [Artwork] = []
            for await artwork in group {
                if let artwork = artwork {
                    results.append(artwork)
                }
            }
            return results
        }
        
        // 캐시 저장
        featuredCache = artworks
        cacheTimestamp = Date()
        
        return artworks
    }
    
    func clearCache() {
        artworkCache.removeAll()
        featuredCache = nil
        cacheTimestamp = nil
    }
}

// MARK: - Art View Model
@MainActor
class ArtViewModel: ObservableObject {
    @Published var artworks: [Artwork] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var recentSearches: [String] = []
    
    private let maxRecentSearches = 10
    
    init() {
        loadRecentSearches()
        Task {
            await loadFeaturedArtworks()
        }
    }
    
    func loadFeaturedArtworks() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await ArtService.shared.getFeaturedArtworks()
            self.artworks = results
            
            // 진동 효과
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Error: \(error)")
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    func searchArtworks() async {
        guard !searchText.isEmpty else {
            await loadFeaturedArtworks()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let objectIDs = try await ArtService.shared.searchArtworks(query: searchText)
            
            // 병렬 처리로 속도 개선
            let artworks = await withTaskGroup(of: Artwork?.self) { group in
                for id in objectIDs.prefix(15) { // 20개 -> 15개로 감소
                    group.addTask {
                        do {
                            let artwork = try await ArtService.shared.getArtwork(objectID: id)
                            if artwork.primaryImage != nil && !artwork.primaryImage!.isEmpty {
                                return artwork
                            }
                        } catch {
                            return nil
                        }
                        return nil
                    }
                }
                
                var results: [Artwork] = []
                for await artwork in group {
                    if let artwork = artwork {
                        results.append(artwork)
                    }
                }
                return results
            }
            
            self.artworks = artworks
            addRecentSearch(searchText)
            
            // 진동 효과
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Error: \(error)")
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    func searchFromTag(_ query: String) async {
        searchText = query
        await searchArtworks()
    }
    
    private func addRecentSearch(_ query: String) {
        if let index = recentSearches.firstIndex(of: query) {
            recentSearches.remove(at: index)
        }
        recentSearches.insert(query, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches.removeLast()
        }
        saveRecentSearches()
    }
    
    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "artRecentSearches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "artRecentSearches") ?? []
    }
}

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

// MARK: - News Service
class NewsService {
    static let shared = NewsService()
    private let apiKey = "d1bdf41741da4f9b92fc2316cbb90bd3"
    private let baseURL = "https://newsapi.org/v2"
    
    // 캐시 추가
    private var searchCache: [String: [Article]] = [:]
    private var headlinesCache: [String: [Article]] = [:]
    private var cacheTimestamp: [String: Date] = [:]
    private let cacheValidDuration: TimeInterval = 600 // 10분
    
    func searchNews(query: String) async throws -> [Article] {
        // 캐시 확인
        let cacheKey = "search_\(query)"
        if let cached = searchCache[cacheKey],
           let timestamp = cacheTimestamp[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            return cached
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        // 3일 전 날짜 계산
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let fromDate = dateFormatter.string(from: threeDaysAgo)
        
        let urlString = "\(baseURL)/everything?q=\(query)&from=\(fromDate)&to=\(today)&sortBy=publishedAt&pageSize=30&apiKey=\(apiKey)"
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(NewsResponse.self, from: data)
        
        // 캐시 저장
        searchCache[cacheKey] = response.articles
        cacheTimestamp[cacheKey] = Date()
        
        return response.articles
    }
    
    func getTopHeadlines(category: String = "business") async throws -> [Article] {
        // 캐시 확인
        let cacheKey = "headlines_\(category)"
        if let cached = headlinesCache[cacheKey],
           let timestamp = cacheTimestamp[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            return cached
        }
        
        let urlString = "\(baseURL)/top-headlines?country=us&category=\(category)&pageSize=30&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(NewsResponse.self, from: data)
        
        // 캐시 저장
        headlinesCache[cacheKey] = response.articles
        cacheTimestamp[cacheKey] = Date()
        
        return response.articles
    }
    
    func clearCache() {
        searchCache.removeAll()
        headlinesCache.removeAll()
        cacheTimestamp.removeAll()
    }
}

// MARK: - View Model
@MainActor
class NewsViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var recentSearches: [String] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedCategory = "business"
    
    private let maxRecentSearches = 10
    
    init() {
        loadRecentSearches()
        Task {
            await loadTopHeadlines()
        }
    }
    
    func search() async {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await NewsService.shared.searchNews(query: searchText)
            self.articles = results
            addRecentSearch(searchText)
            
            // 진동 효과 추가
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Error: \(error)")
            
            // 에러 시 다른 진동
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    func loadTopHeadlines() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await NewsService.shared.getTopHeadlines(category: selectedCategory)
            self.articles = results
            
            // 진동 효과 추가
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Error: \(error)")
            
            // 에러 시 다른 진동
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    func searchFromTag(_ query: String) async {
        searchText = query
        await search()
    }
    
    private func addRecentSearch(_ query: String) {
        if let index = recentSearches.firstIndex(of: query) {
            recentSearches.remove(at: index)
        }
        recentSearches.insert(query, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches.removeLast()
        }
        saveRecentSearches()
    }
    
    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    }
}

// MARK: - Tab Type
enum TabType: String, CaseIterable {
    case habit = "해빗"
    case news = "뉴스"
    case map = "지도"
    case art = "미술"
    
    var icon: String {
        switch self {
        case .news: return "newspaper.fill"
        case .map: return "map.fill"
        case .art: return "paintpalette.fill"
        case .habit: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @State private var selectedTab: TabType = .habit
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            Group {
                switch selectedTab {
                case .habit:
                    HabitView()
                case .news:
                    NewsView()
                case .map:
                    MapView()
                case .art:
                    ArtView()
                }
            }
            
            // Bottom Tab Bar
            BottomTabBar(selectedTab: $selectedTab)
        }
    }
}

// MARK: - News View
struct NewsView: View {
    @StateObject private var viewModel = NewsViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isSearchFocused = false
                    }
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                    
                    // Recent Searches Tags
                    if !viewModel.recentSearches.isEmpty {
                        recentSearchesView
                    }
                    
                    // Articles List
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Spacer()
                    } else {
                        articlesList
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("검색어를 입력하세요", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFocused = false
                        Task {
                            await viewModel.search()
                        }
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            Button(action: {
                isSearchFocused = false
                Task {
                    await viewModel.search()
                }
            }) {
                Text("검색")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 검색어")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.recentSearches, id: \.self) { search in
                        HStack(spacing: 6) {
                            Text("#\(search)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Button(action: {
                                viewModel.removeRecentSearch(search)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .onTapGesture {
                            Task {
                                await viewModel.searchFromTag(search)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var articlesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.articles) { article in
                    ArticleCard(article: article)
                }
            }
            .padding()
            .padding(.bottom, 80) // Tab bar 공간 확보
        }
    }
}

// MARK: - ScrollView With Offset Tracking
struct ScrollViewWithOffset<Content: View>: View {
    let onOffsetChange: (CGFloat) -> Void
    let content: () -> Content
    
    init(onOffsetChange: @escaping (CGFloat) -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.onOffsetChange = onOffsetChange
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).minY
                )
            }
            .frame(height: 0)
            
            content()
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            onOffsetChange(value)
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Map View (Placeholder)
struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var selectedMapType: MapType = .esriSatellite
    @State private var mapHTML = ""
    @State private var isMeasuring = false
    @State private var mapKey = UUID()
    
    var body: some View {
        ZStack {
            // Map WebView
            MapWebView(html: mapHTML)
                .id(mapKey)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Bottom Controls
                HStack(alignment: .bottom) {
                    // Left Controls (Zoom, Measure & Map Type)
                    VStack(spacing: 12) {
                        // Zoom In Button
                        Button(action: {
                            executeMapScript("map.zoomIn();")
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        
                        // Zoom Out Button
                        Button(action: {
                            executeMapScript("map.zoomOut();")
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        
                        // Measure Distance Button
                        Button(action: {
                            isMeasuring.toggle()
                            if isMeasuring {
                                executeMapScript("startMeasuring();")
                            } else {
                                executeMapScript("stopMeasuring();")
                            }
                        }) {
                            Image(systemName: isMeasuring ? "ruler.fill" : "ruler")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(isMeasuring ? Color.orange : Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        
                        // Map Type Toggle Button
                        Button(action: {
                            selectedMapType = selectedMapType == .openStreetMap ? .esriSatellite : .openStreetMap
                            isMeasuring = false
                            updateMap()
                            mapKey = UUID()
                        }) {
                            Image(systemName: selectedMapType == .openStreetMap ? "map" : "globe.asia.australia.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.green)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Current Location Button
                    VStack(spacing: 12) {
                        Button(action: {
                            locationManager.requestLocation()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let location = locationManager.location {
                                    executeMapScript("map.setView([\(location.latitude), \(location.longitude)], 16);")
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                    }
                    .padding()
                }
                .padding(.bottom, 80) // Tab bar 공간 확보
            }
        }
        .onAppear {
            locationManager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                updateMap()
            }
        }
        .onChange(of: selectedMapType) { oldValue, newValue in
            isMeasuring = false
            updateMap()
            mapKey = UUID()
        }
        .onChange(of: locationManager.location) { oldValue, newLocation in
            if let location = newLocation {
                updateMap()
            }
        }
    }
    
    private func executeMapScript(_ script: String) {
        // 약간의 딜레이 후 실행 (지도 로딩 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("ExecuteMapScript"), object: script)
        }
    }
    
    private func updateMap() {
        let lat = locationManager.location?.latitude ?? 37.5665
        let lon = locationManager.location?.longitude ?? 126.9780
        
        let tileLayer = selectedMapType == .openStreetMap
            ? "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            : "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
        
        let attribution = selectedMapType == .openStreetMap
            ? "© OpenStreetMap contributors"
            : "© Esri"
        
        mapHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
            <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
            <style>
                body { margin: 0; padding: 0; }
                #map { width: 100vw; height: 100vh; }
                .distance-label {
                    background: white;
                    padding: 4px 8px;
                    border: 2px solid #333;
                    border-radius: 4px;
                    font-weight: bold;
                    font-size: 12px;
                    white-space: nowrap;
                }
            </style>
        </head>
        <body>
            <div id="map"></div>
            <script>
                var map = L.map('map', {
                    doubleClickZoom: false,
                    tap: true,
                    tapTolerance: 15
                }).setView([\(lat), \(lon)], 15);
                
                L.tileLayer('\(tileLayer)', {
                    attribution: '\(attribution)',
                    maxZoom: 19
                }).addTo(map);
                
                // 전역 변수로 저장 (나중에 교체하기 위해)
                window.tileLayer = L.tileLayer('\(tileLayer)', {
                    attribution: '\(attribution)',
                    maxZoom: 19
                }).addTo(map);
                
                var marker = L.marker([\(lat), \(lon)]).addTo(map);
                marker.bindPopup('<b>현재 위치</b>').openPopup();
                
                var circle = L.circle([\(lat), \(lon)], {
                    color: 'blue',
                    fillColor: '#30a3ec',
                    fillOpacity: 0.2,
                    radius: 100
                }).addTo(map);
                
                // 한 손가락 확대/축소 (더블탭 후 드래그)
                var doubleTapZoom = false;
                var lastTap = 0;
                var startY = 0;
                var startZoom = 0;
                
                map.on('touchstart', function(e) {
                    if (e.originalEvent.touches.length === 1) {
                        var now = Date.now();
                        if (now - lastTap < 300) {
                            // 더블탭 감지
                            doubleTapZoom = true;
                            startY = e.originalEvent.touches[0].clientY;
                            startZoom = map.getZoom();
                            e.originalEvent.preventDefault();
                        }
                        lastTap = now;
                    }
                });
                
                map.on('touchmove', function(e) {
                    if (doubleTapZoom && e.originalEvent.touches.length === 1) {
                        var currentY = e.originalEvent.touches[0].clientY;
                        var deltaY = startY - currentY;
                        
                        // 위로 드래그: 확대, 아래로 드래그: 축소
                        var zoomDelta = deltaY / 100;
                        var newZoom = startZoom + zoomDelta;
                        
                        // 줌 레벨 제한
                        newZoom = Math.max(1, Math.min(19, newZoom));
                        map.setZoom(newZoom, { animate: false });
                        
                        e.originalEvent.preventDefault();
                    }
                });
                
                map.on('touchend', function(e) {
                    if (doubleTapZoom) {
                        doubleTapZoom = false;
                    }
                });
                
                // Distance Measurement
                var measurePoints = [];
                var measureMarkers = [];
                var measureLines = [];
                var isMeasuring = false;
                
                window.startMeasuring = function() {
                    console.log('Start measuring');
                    isMeasuring = true;
                    clearMeasurement();
                    map.on('click', onMapClick);
                }
                
                window.stopMeasuring = function() {
                    console.log('Stop measuring');
                    isMeasuring = false;
                    map.off('click', onMapClick);
                }
                
                function clearMeasurement() {
                    measurePoints = [];
                    measureMarkers.forEach(m => map.removeLayer(m));
                    measureLines.forEach(l => map.removeLayer(l));
                    measureMarkers = [];
                    measureLines = [];
                }
                
                function onMapClick(e) {
                    console.log('Map clicked:', e.latlng);
                    if (!isMeasuring) return;
                    
                    measurePoints.push(e.latlng);
                    
                    // Add marker
                    var marker = L.circleMarker(e.latlng, {
                        radius: 6,
                        color: '#ff0000',
                        fillColor: '#ff0000',
                        fillOpacity: 1,
                        weight: 2
                    }).addTo(map);
                    measureMarkers.push(marker);
                    
                    // Draw line if more than one point
                    if (measurePoints.length > 1) {
                        var lastTwo = measurePoints.slice(-2);
                        var line = L.polyline(lastTwo, {
                            color: '#ff0000',
                            weight: 3,
                            opacity: 0.8
                        }).addTo(map);
                        measureLines.push(line);
                        
                        // Calculate distance
                        var distance = map.distance(lastTwo[0], lastTwo[1]);
                        var distanceText = distance < 1000 
                            ? distance.toFixed(0) + 'm'
                            : (distance / 1000).toFixed(2) + 'km';
                        
                        // Add label
                        var midpoint = L.latLng(
                            (lastTwo[0].lat + lastTwo[1].lat) / 2,
                            (lastTwo[0].lng + lastTwo[1].lng) / 2
                        );
                        
                        var label = L.marker(midpoint, {
                            icon: L.divIcon({
                                className: 'distance-label',
                                html: distanceText
                            })
                        }).addTo(map);
                        measureLines.push(label);
                        
                        // Total distance
                        var total = 0;
                        for (var i = 1; i < measurePoints.length; i++) {
                            total += map.distance(measurePoints[i-1], measurePoints[i]);
                        }
                        var totalText = total < 1000 
                            ? '총 거리: ' + total.toFixed(0) + 'm'
                            : '총 거리: ' + (total / 1000).toFixed(2) + 'km';
                        
                        marker.bindPopup(totalText).openPopup();
                    } else {
                        marker.bindPopup('시작점').openPopup();
                    }
                }
                
                console.log('Map initialized');
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Map WebView
struct MapWebView: UIViewRepresentable {
    let html: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isMultipleTouchEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        
        // 터치 제스처 추가
        let doubleTapGesture = DoubleTapDragGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTapDrag(_:)))
        webView.addGestureRecognizer(doubleTapGesture)
        context.coordinator.doubleTapGesture = doubleTapGesture
        
        // NotificationCenter 관찰자 등록
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.executeScript(_:)),
            name: NSNotification.Name("ExecuteMapScript"),
            object: nil
        )
        
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    class Coordinator: NSObject {
        weak var webView: WKWebView?
        var doubleTapGesture: DoubleTapDragGestureRecognizer?
        
        @objc func executeScript(_ notification: Notification) {
            guard let script = notification.object as? String else { return }
            webView?.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("JavaScript error: \(error)")
                }
            }
        }
        
        @objc func handleDoubleTapDrag(_ gesture: DoubleTapDragGestureRecognizer) {
            guard let webView = webView else { return }
            
            switch gesture.state {
            case .began:
                print("Double tap drag began")
                // 초기 줌 레벨 저장
                webView.evaluateJavaScript("map.getZoom()") { result, _ in
                    if let zoom = result as? Double {
                        gesture.startZoom = zoom
                    } else if let zoom = result as? Int {
                        gesture.startZoom = Double(zoom)
                    }
                }
            case .changed:
                let translation = gesture.translation(in: webView)
                let zoomDelta = -translation.y / 100.0 // 위로 = +, 아래로 = -
                let newZoom = gesture.startZoom + zoomDelta
                let clampedZoom = max(1, min(19, newZoom))
                
                print("Zoom: \(clampedZoom)")
                // 에러를 무시하고 줌만 실행
                webView.evaluateJavaScript("if (typeof map !== 'undefined') { map.setZoom(\(clampedZoom), { animate: false }); }", completionHandler: nil)
            case .ended, .cancelled:
                print("Double tap drag ended")
            default:
                break
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Double Tap Drag Gesture Recognizer
class DoubleTapDragGestureRecognizer: UIGestureRecognizer {
    var startZoom: Double = 13.0
    private var initialTouch: CGPoint = .zero
    private var tapCount = 0
    private var lastTapTime: TimeInterval = 0
    private var isDragging = false
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let currentTime = Date().timeIntervalSince1970
        
        if currentTime - lastTapTime < 0.3 {
            // 더블탭 감지
            tapCount += 1
            if tapCount == 2 {
                initialTouch = touch.location(in: view)
                state = .began
                isDragging = true
                print("Double tap detected!")
            }
        } else {
            tapCount = 1
        }
        
        lastTapTime = currentTime
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if isDragging {
            state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if isDragging {
            state = .ended
            isDragging = false
            tapCount = 0
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if isDragging {
            state = .cancelled
            isDragging = false
            tapCount = 0
        }
    }
    
    override func reset() {
        super.reset()
        isDragging = false
    }
    
    func translation(in view: UIView?) -> CGPoint {
        guard let touch = UITouch.allTouches?.first,
              let view = view else {
            return .zero
        }
        let currentTouch = touch.location(in: view)
        return CGPoint(x: currentTouch.x - initialTouch.x,
                      y: currentTouch.y - initialTouch.y)
    }
}

extension UITouch {
    static var allTouches: Set<UITouch>? {
        return UIApplication.shared.windows.first?.rootViewController?.view.window?.allTouches
    }
}

extension UIWindow {
    var allTouches: Set<UITouch>? {
        var touches = Set<UITouch>()
        
        func findTouches(in view: UIView) {
            for subview in view.subviews {
                if let gestureRecognizers = subview.gestureRecognizers {
                    for recognizer in gestureRecognizers {
                        if let touch = recognizer.view?.window {
                            // touches 수집
                        }
                    }
                }
                findTouches(in: subview)
            }
        }
        
        if let rootView = rootViewController?.view {
            findTouches(in: rootView)
        }
        
        return touches.isEmpty ? nil : touches
    }
}

// MARK: - Art View (Placeholder)
struct ArtView: View {
    @StateObject private var viewModel = ArtViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isSearchFocused = false
                    }
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                    
                    // Recent Searches Tags
                    if !viewModel.recentSearches.isEmpty {
                        recentSearchesView
                    }
                    
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("명화 갤러리")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("메트로폴리탄 미술관 컬렉션")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Artworks List
                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("명화를 불러오는 중...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else if viewModel.artworks.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            Text("작품을 찾을 수 없습니다")
                                .font(.headline)
                            Text("다른 검색어를 시도해보세요")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else {
                        artworksList
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("작품, 작가, 시대를 검색하세요", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFocused = false
                        Task {
                            await viewModel.searchArtworks()
                        }
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        Task {
                            await viewModel.loadFeaturedArtworks()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            Button(action: {
                isSearchFocused = false
                Task {
                    await viewModel.searchArtworks()
                }
            }) {
                Text("검색")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 검색어")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.recentSearches, id: \.self) { search in
                        HStack(spacing: 6) {
                            Text("#\(search)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Button(action: {
                                viewModel.removeRecentSearch(search)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(16)
                        .onTapGesture {
                            Task {
                                await viewModel.searchFromTag(search)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var artworksList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.artworks) { artwork in
                    ArtworkCard(artwork: artwork)
                }
            }
            .padding()
            .padding(.bottom, 80) // Tab bar 공간 확보
        }
    }
}

// MARK: - Artwork Card
struct ArtworkCard: View {
    let artwork: Artwork
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                if let imageURL = artwork.primaryImage, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(4/3, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 250)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(4/3, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.largeTitle)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Artist and Date
                    HStack {
                        Text(artwork.artist)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        Text(artwork.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Title
                    Text(artwork.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // Medium
                    if let medium = artwork.medium {
                        Text(medium)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Department
                    if let department = artwork.department {
                        HStack(spacing: 4) {
                            Image(systemName: "building.columns.fill")
                                .font(.caption)
                            Text(department)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ArtworkDetailView(artwork: artwork)
        }
    }
}

// MARK: - Artwork Detail View
struct ArtworkDetailView: View {
    let artwork: Artwork
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingShareSheet = false
    @State private var imageToShare: UIImage?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Zoomable Image
                    if let imageURL = artwork.primaryImage, let url = URL(string: imageURL) {
                        ZoomableImageView(url: url, scale: $scale, lastScale: $lastScale, offset: $offset, lastOffset: $lastOffset, imageToShare: $imageToShare)
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 0))
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Artist
                        VStack(alignment: .leading, spacing: 4) {
                            Text("작가")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(artwork.artist)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("작품명")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(artwork.title)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Divider()
                        
                        // Share Buttons
                        HStack(spacing: 12) {
                            // Save to Photos Button
                            Button(action: {
                                saveToPhotos()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                    Text("사진 저장")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            // Share Button
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up.fill")
                                    Text("공유하기")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        Divider()
                        
                        // Details Grid
                        VStack(alignment: .leading, spacing: 12) {
                            if let date = artwork.objectDate {
                                DetailRow(label: "제작연도", value: date)
                            }
                            
                            if let medium = artwork.medium {
                                DetailRow(label: "재료/기법", value: medium)
                            }
                            
                            if let dimensions = artwork.dimensions {
                                DetailRow(label: "크기", value: dimensions)
                            }
                            
                            if let culture = artwork.culture {
                                DetailRow(label: "문화권", value: culture)
                            }
                            
                            if let classification = artwork.classification {
                                DetailRow(label: "분류", value: classification)
                            }
                            
                            if let department = artwork.department {
                                DetailRow(label: "소장부서", value: department)
                            }
                            
                            if let creditLine = artwork.creditLine {
                                DetailRow(label: "소장정보", value: creditLine)
                            }
                        }
                        
                        Divider()
                        
                        // Zoom Instruction
                        HStack {
                            Image(systemName: "hand.pinch.fill")
                                .foregroundColor(.purple)
                            Text("이미지를 핀치하여 확대/축소할 수 있습니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Museum Info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "building.columns.fill")
                                    .foregroundColor(.purple)
                                Text("메트로폴리탄 미술관")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            
                            Text("The Metropolitan Museum of Art, New York")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Open in Browser Button
                        if let urlString = artwork.objectURL, let url = URL(string: urlString) {
                            Link(destination: url) {
                                HStack {
                                    Text("미술관 웹사이트에서 보기")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.up.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.top)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = imageToShare {
                    ShareSheet(items: [
                        image,
                        "\(artwork.title) - \(artwork.artist)",
                        artwork.objectURL ?? ""
                    ])
                }
            }
            .alert("알림", isPresented: $showingSaveAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(saveAlertMessage)
            }
        }
    }
    
    private func saveToPhotos() {
        guard let image = imageToShare else {
            saveAlertMessage = "이미지를 불러오는 중입니다. 잠시 후 다시 시도해주세요."
            showingSaveAlert = true
            return
        }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // 진동 효과
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        saveAlertMessage = "사진이 앨범에 저장되었습니다."
        showingSaveAlert = true
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let url: URL
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var imageToShare: UIImage?
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 5) // 1x ~ 5x
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2
                                }
                            }
                        }
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let loadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.imageToShare = loadedImage
                }
            }
        }.resume()
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Bottom Tab Bar
struct BottomTabBar: View {
    @Binding var selectedTab: TabType
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(TabType.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                        
                        // 탭 전환 시 가벼운 진동
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 24))
                            
                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(selectedTab == tab ? .blue : .gray)
                    }
                }
            }
            .padding(.bottom, 20) // 홈 인디케이터 공간 확보
            .background(
                Color(UIColor.secondarySystemGroupedBackground)
                    .ignoresSafeArea(edges: .bottom)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
        }
    }
}

// MARK: - Article Card
struct ArticleCard: View {
    let article: Article
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                if let imageURL = article.urlToImage, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 200)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.largeTitle)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Source and Time
                    HStack {
                        Text(article.source.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(formatDate(article.publishedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Title
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // Description
                    if let description = article.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ArticleDetailView(article: article)
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM월 dd일"
        return displayFormatter.string(from: date)
    }
}

// MARK: - Article Detail View
struct ArticleDetailView: View {
    let article: Article
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Image
                    if let imageURL = article.urlToImage, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxHeight: 300)
                                    .clipped()
                            default:
                                EmptyView()
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Source
                        Text(article.source.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        // Title
                        Text(article.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Author and Date
                        HStack {
                            if let author = article.author {
                                Text(author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatDate(article.publishedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Description
                        if let description = article.description {
                            Text(description)
                                .font(.body)
                        }
                        
                        // Content
                        if let content = article.content {
                            Text(content)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        // Open in Browser Button
                        if let url = URL(string: article.url) {
                            Link(destination: url) {
                                HStack {
                                    Text("전체 기사 보기")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.up.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.top)
                        }
                    }
                    .padding()
                }
            }
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
        return displayFormatter.string(from: date)
    }
}
