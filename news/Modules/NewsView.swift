import SwiftUI
import Combine

// MARK: - News Models
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

// MARK: - News View Model
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
