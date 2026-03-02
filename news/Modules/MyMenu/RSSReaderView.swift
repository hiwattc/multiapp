import SwiftUI
import Combine

// MARK: - RSS Feed Model
struct RSSFeed: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var category: String
    var isFavorite: Bool
    
    init(id: UUID = UUID(), name: String, url: String, category: String = "기타", isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.category = category
        self.isFavorite = isFavorite
    }
}

// MARK: - RSS Item Model
struct RSSItem: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let description: String
    let pubDate: String
    let author: String?
    let imageURL: String?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        
        if let date = formatter.date(from: pubDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.locale = Locale(identifier: "ko_KR")
            outputFormatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
            return outputFormatter.string(from: date)
        }
        return pubDate
    }
    
    var timeAgo: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        
        if let date = formatter.date(from: pubDate) {
            let now = Date()
            let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: now)
            
            if let days = components.day, days > 0 {
                return "\(days)일 전"
            } else if let hours = components.hour, hours > 0 {
                return "\(hours)시간 전"
            } else if let minutes = components.minute, minutes > 0 {
                return "\(minutes)분 전"
            }
        }
        return "방금 전"
    }
}

// MARK: - RSS Parser
class RSSParser: NSObject, XMLParserDelegate, ObservableObject {
    @Published var items: [RSSItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentAuthor = ""
    private var currentImageURL = ""
    
    func fetchFeed(from urlString: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            items = []
        }
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "잘못된 URL입니다"
                isLoading = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = XMLParser(data: data)
            parser.delegate = self
            
            if parser.parse() {
                await MainActor.run {
                    isLoading = false
                    print("✅ RSS 파싱 완료: \(items.count)개 항목")
                }
            } else {
                await MainActor.run {
                    errorMessage = "RSS 피드를 파싱하는데 실패했습니다"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "RSS 피드를 가져오는데 실패했습니다: \(error.localizedDescription)"
                isLoading = false
                print("❌ RSS 에러: \(error)")
            }
        }
    }
    
    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        // RSS 2.0 및 Atom 지원
        if elementName == "item" || elementName == "entry" {
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
            currentAuthor = ""
            currentImageURL = ""
        }
        
        // YouTube RSS 및 Atom 피드의 link 태그 처리
        // <link rel="alternate" href="https://www.youtube.com/watch?v=..."/>
        if elementName == "link" {
            if let href = attributeDict["href"] {
                currentLink = href
                print("🔗 Link href 발견: \(href)")
            }
        }
        
        // 이미지 URL 추출 (여러 형식 지원)
        if elementName == "enclosure" {
            if let type = attributeDict["type"], type.contains("image"),
               let url = attributeDict["url"] {
                currentImageURL = url
            }
        } else if elementName == "media:thumbnail" || elementName == "media:content" {
            if let url = attributeDict["url"] {
                currentImageURL = url
            }
        } else if elementName == "media:group" {
            // YouTube는 media:group 안에 썸네일이 있음
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link":
            currentLink += trimmed
        case "description", "summary", "content:encoded":
            currentDescription += trimmed
        case "pubDate", "published", "updated":
            currentPubDate += trimmed
        case "author", "dc:creator":
            currentAuthor += trimmed
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            print("📰 RSS 아이템 파싱 완료:")
            print("   제목: \(currentTitle)")
            print("   링크: \(currentLink)")
            print("   이미지: \(currentImageURL)")
            
            let item = RSSItem(
                title: currentTitle,
                link: currentLink,
                description: cleanHTML(currentDescription),
                pubDate: currentPubDate,
                author: currentAuthor.isEmpty ? nil : currentAuthor,
                imageURL: currentImageURL.isEmpty ? nil : currentImageURL
            )
            
            Task { @MainActor in
                items.append(item)
            }
        }
    }
    
    private func cleanHTML(_ html: String) -> String {
        var result = html
        // HTML 태그 제거
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // HTML 엔티티 디코딩
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Feed Tab Type
enum FeedTab: String, CaseIterable {
    case favorite = "즐겨찾기"
    case myFeeds = "내피드"
    case popular = "인기피드"
    
    var icon: String {
        switch self {
        case .favorite: return "star.fill"
        case .myFeeds: return "folder.fill"
        case .popular: return "flame.fill"
        }
    }
}

// MARK: - RSS Reader View
struct RSSReaderView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var parser = RSSParser()
    @State private var feeds: [RSSFeed] = []
    @State private var selectedFeed: RSSFeed?
    @State private var showingAddFeed = false
    @State private var newFeedName = ""
    @State private var newFeedURL = ""
    @State private var newFeedCategory = "기타"
    @State private var selectedCategory = "전체"
    @State private var selectedTab: FeedTab = .favorite
    
    // 인기 RSS 피드 예시
    let popularFeeds = [
        // 대한민국 정책브리핑 (www.korea.kr)
        // 뉴스
        RSSFeed(name: "🇰🇷 정책뉴스", url: "https://www.korea.kr/rss/policy.xml", category: "정책뉴스"),
        RSSFeed(name: "🇰🇷 국민이 말하는 정책", url: "https://www.korea.kr/rss/reporter.xml", category: "정책뉴스"),
        RSSFeed(name: "🇰🇷 정책칼럼", url: "https://www.korea.kr/rss/column.xml", category: "정책뉴스"),
        RSSFeed(name: "🇰🇷 이슈인사이트", url: "https://www.korea.kr/rss/insight.xml", category: "정책뉴스"),
        
        // 멀티미디어
        RSSFeed(name: "🎬 영상", url: "https://www.korea.kr/rss/media.xml", category: "정부멀티미디어"),
        RSSFeed(name: "🎬 숏폼", url: "https://www.korea.kr/rss/shorts.xml", category: "정부멀티미디어"),
        RSSFeed(name: "🎨 카드/한컷", url: "https://www.korea.kr/rss/visual.xml", category: "정부멀티미디어"),
        RSSFeed(name: "📷 사진", url: "https://www.korea.kr/rss/photo.xml", category: "정부멀티미디어"),
        RSSFeed(name: "🎨 웹툰", url: "https://www.korea.kr/rss/cartoon.xml", category: "정부멀티미디어"),
        
        // 브리핑룸
        RSSFeed(name: "📢 보도자료", url: "https://www.korea.kr/rss/pressrelease.xml", category: "정부브리핑룸"),
        RSSFeed(name: "📢 사실은 이렇습니다", url: "https://www.korea.kr/rss/fact.xml", category: "정부브리핑룸"),
        RSSFeed(name: "📢 부처 브리핑", url: "https://www.korea.kr/rss/ebriefing.xml", category: "정부브리핑룸"),
        RSSFeed(name: "📢 청와대 브리핑", url: "https://www.korea.kr/rss/president.xml", category: "정부브리핑룸"),
        RSSFeed(name: "📢 국무회의 브리핑", url: "https://www.korea.kr/rss/cabinet.xml", category: "정부브리핑룸"),
        RSSFeed(name: "📢 연설문", url: "https://www.korea.kr/rss/speech.xml", category: "정부브리핑룸"),
        
        // 정책자료
        RSSFeed(name: "📄 전문자료", url: "https://www.korea.kr/rss/expdoc.xml", category: "정책자료"),
        RSSFeed(name: "📄 K-공감 전체", url: "https://www.korea.kr/rss/archive.xml", category: "정책자료"),
        
        // 국내 언론
        RSSFeed(name: "💼 매일경제", url: "https://www.mk.co.kr/rss/30000001/", category: "국내언론"),
        RSSFeed(name: "📰 연합뉴스", url: "https://www.yna.co.kr/rss/news.xml", category: "국내언론"),
        RSSFeed(name: "📰 조선일보", url: "https://www.chosun.com/arc/outboundfeeds/rss/?outputType=xml", category: "국내언론"),
        RSSFeed(name: "📰 한겨레", url: "https://www.hani.co.kr/rss/", category: "국내언론"),
        
        // IT/테크
        RSSFeed(name: "🌐 TechCrunch", url: "https://techcrunch.com/feed/", category: "IT/테크"),
        RSSFeed(name: "🌐 Hacker News", url: "https://news.ycombinator.com/rss", category: "IT/테크"),
        RSSFeed(name: "👨‍💻 Dev.to", url: "https://dev.to/feed", category: "IT/테크"),


        // 📰 AI 뉴스 / 산업 동향
        RSSFeed(name: "📰 AI for Newsroom (All)", url: "https://aifornewsroom.in/api/rss/all", category: "AI뉴스"),
        RSSFeed(name: "📰 AI for Newsroom (News)", url: "https://aifornewsroom.in/api/rss", category: "AI뉴스"),
        RSSFeed(name: "🧰 AI for Newsroom (Resources)", url: "https://aifornewsroom.in/api/rss/resources", category: "AI뉴스"),
        RSSFeed(name: "🧠 OpenAI Blog", url: "https://openai.com/news/rss.xml", category: "AI뉴스"),
        RSSFeed(name: "🇰🇷 Unblock Media ALL", url: "https://www.unblockmedia.com/rss_ko.xml", category: "AI뉴스"), // 한국어 전체 기사 RSS :contentReference[oaicite:2]{index=2}
        RSSFeed(name: "🇰🇷 Unblock Media Tech", url: "https://www.unblockmedia.com/rss_ko_tech.xml", category: "AI뉴스"), // 기술 섹션 RSS :contentReference[oaicite:3]{index=3}
        RSSFeed(name: "🇰🇷 Unblock Media Policy", url: "https://www.unblockmedia.com/rss_ko_policy.xml", category: "AI뉴스"), // 정책/규제 뉴스 RSS :contentReference[oaicite:4]{index=4}
        // 🛡️ 한국 보안공지 (보호나라 보안공지)
        RSSFeed(name: "🇰🇷 보호나라 보안공지", url: "https://knvd.krcert.or.kr/rss/securityNotice.do", category: "보안"),
        RSSFeed(name: "🇰🇷 KISA 공지사항 RSS", url: "https://kisa.or.kr/rss/401", category: "보안"),
        RSSFeed(name: "🇰🇷 KISA 보도자료 RSS", url: "https://kisa.or.kr/rss/402", category: "보안"),

        RSSFeed(name: "일당백", url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC0LGfuBiVmPZLo5pUW0bshA", category: "youtube"),
        RSSFeed(name: "슈카", url: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsJ6RuBiTVWRX156FVbeaGg", category: "youtube"),
        RSSFeed(name: "박가네", url: "https://www.youtube.com/feeds/videos.xml?channel_id=UCpK0ae9lWdtyDi9Cdc1Fqeg", category: "youtube"),
        RSSFeed(name: "오빠두엑셀", url: "https://www.youtube.com/feeds/videos.xml?channel_id=UCZ6UHYBQFBe14WUgxlgmYfg", category: "youtube"),
        RSSFeed(name: "침착맨", url: "https://www.youtube.com/feeds/videos.xml?channel_id=UCUj6rrhMTR9pipbAWBAMvUQ", category: "youtube"),
        RSSFeed(name: "자취남", url: "https://www.youtube.com/feeds/videos.xml?channel_id=UCtYHCl8yhhvpWfcvdA_sCVg", category: "youtube"),

        RSSFeed(name: "🎨 그림", url: "https://www.reddit.com/r/painting/.rss", category: "reddit"),
        RSSFeed(name: "🎨 인공지능", url: "https://www.reddit.com/r/ArtificialInteligence/.rss", category: "reddit"),
        RSSFeed(name: "🎨 엘론 머스크", url: "https://www.reddit.com/r/elonmusk/.rss", category: "reddit"),
        RSSFeed(name: "🎨 트럼프", url: "https://www.reddit.com/r/trump/.rss", category: "reddit"),
        RSSFeed(name: "🎨 사이버 보안", url: "https://www.reddit.com/r/cybersecurity/.rss", category: "reddit")
    ]
    
    // 카테고리 목록
    var categories: [String] {
        var cats = Set(popularFeeds.map { $0.category })
        return ["전체"] + cats.sorted()
    }
    
    // 필터링된 인기 피드 (즐겨찾기 상태 반영)
    var filteredPopularFeeds: [RSSFeed] {
        let filtered = selectedCategory == "전체" 
            ? popularFeeds 
            : popularFeeds.filter { $0.category == selectedCategory }
        
        // 내 피드에서 즐겨찾기 상태 가져오기
        return filtered.map { feed in
            var updatedFeed = feed
            if let myFeed = feeds.first(where: { $0.url == feed.url }) {
                updatedFeed.isFavorite = myFeed.isFavorite
            }
            return updatedFeed
        }
    }
    
    // 즐겨찾기된 피드 목록 (내 피드만)
    var favoriteFeeds: [RSSFeed] {
        return feeds.filter { $0.isFavorite }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if selectedFeed == nil {
                    // Feed List View
                    feedListView
                } else {
                    // News List View
                    newsListView
                }
            }
            .navigationTitle(selectedFeed?.name ?? "RSS 리더")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedFeed != nil {
                        Button(action: {
                            selectedFeed = nil
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("뒤로")
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedFeed == nil {
                        Button(action: {
                            showingAddFeed = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                        }
                    } else {
                        Button("닫기") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddFeed) {
                addFeedSheet
            }
            .onAppear {
                loadFeeds()
                loadFavoriteFeedsOnStartup()
            }
        }
    }
    
    // MARK: - Feed List View
    private var feedListView: some View {
        VStack(spacing: 0) {
            // 탭 메뉴
            tabBar
            
            // 탭별 콘텐츠
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .favorite:
                        favoriteFeedsSection
                    case .myFeeds:
                        myFeedsSection
                    case .popular:
                        popularFeedsSection
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .orange : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ? Color.orange.opacity(0.1) : Color.clear
                    )
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Favorite Feeds Section
    private var favoriteFeedsSection: some View {
        VStack(spacing: 12) {
            if favoriteFeeds.isEmpty {
                emptyStateView(
                    icon: "star.slash",
                    title: "즐겨찾기된 피드가 없습니다",
                    message: "자주 보는 피드를 즐겨찾기하세요"
                )
                .padding(.top, 60)
            } else {
                ForEach(favoriteFeeds) { feed in
                    FeedCard(
                        feed: feed,
                        showDelete: feeds.contains(where: { $0.id == feed.id }),
                        showFavorite: true,
                        onToggleFavorite: {
                            toggleFavorite(feed)
                        }
                    ) {
                        selectedFeed = feed
                        Task {
                            await parser.fetchFeed(from: feed.url)
                        }
                    } onDelete: {
                        deleteFeed(feed)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - My Feeds Section
    private var myFeedsSection: some View {
        VStack(spacing: 12) {
            if feeds.isEmpty {
                emptyStateView(
                    icon: "folder.badge.plus",
                    title: "저장된 피드가 없습니다",
                    message: "새로운 RSS 피드를 추가해보세요"
                )
                .padding(.top, 60)
            } else {
                ForEach(feeds) { feed in
                    FeedCard(
                        feed: feed,
                        showFavorite: true,
                        onToggleFavorite: {
                            toggleFavorite(feed)
                        }
                    ) {
                        selectedFeed = feed
                        Task {
                            await parser.fetchFeed(from: feed.url)
                        }
                    } onDelete: {
                        deleteFeed(feed)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Popular Feeds Section
    private var popularFeedsSection: some View {
        VStack(spacing: 12) {
            // 카테고리 해시태그
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            withAnimation {
                                selectedCategory = category
                            }
                        }) {
                            Text("#\(category)")
                                .font(.subheadline)
                                .fontWeight(selectedCategory == category ? .bold : .regular)
                                .foregroundColor(selectedCategory == category ? .white : .orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategory == category ? Color.orange : Color.orange.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // 필터링된 피드 목록
            ForEach(filteredPopularFeeds) { feed in
                FeedCard(
                    feed: feed,
                    showDelete: false,
                    showFavorite: true,
                    onToggleFavorite: {
                        togglePopularFeedFavorite(feed)
                    }
                ) {
                    selectedFeed = feed
                    Task {
                        await parser.fetchFeed(from: feed.url)
                    }
                } onDelete: {}
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty State View
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - News List View
    private var newsListView: some View {
        Group {
            if parser.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("뉴스를 불러오는 중...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = parser.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("다시 시도") {
                        if let feed = selectedFeed {
                            Task {
                                await parser.fetchFeed(from: feed.url)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if parser.items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("뉴스가 없습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(parser.items) { item in
                            RSSItemCard(item: item)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    if let feed = selectedFeed {
                        await parser.fetchFeed(from: feed.url)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Add Feed Sheet
    private var addFeedSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("피드 정보")) {
                    TextField("피드 이름", text: $newFeedName)
                    TextField("RSS URL", text: $newFeedURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    
                    Picker("카테고리", selection: $newFeedCategory) {
                        ForEach(categories.filter { $0 != "전체" }, id: \.self) { category in
                            Text(category).tag(category)
                        }
                        Text("기타").tag("기타")
                    }
                }
                
                Section {
                    Button(action: addFeed) {
                        Text("추가")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.orange)
                    .disabled(newFeedName.isEmpty || newFeedURL.isEmpty)
                }
            }
            .navigationTitle("RSS 피드 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        showingAddFeed = false
                        newFeedName = ""
                        newFeedURL = ""
                        newFeedCategory = "기타"
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadFeeds() {
        if let data = UserDefaults.standard.data(forKey: "rssFeeds") {
            if let decoded = try? JSONDecoder().decode([RSSFeed].self, from: data) {
                feeds = decoded
            }
        }
    }
    
    private func saveFeeds() {
        if let encoded = try? JSONEncoder().encode(feeds) {
            UserDefaults.standard.set(encoded, forKey: "rssFeeds")
        }
    }
    
    private func addFeed() {
        let feed = RSSFeed(name: newFeedName, url: newFeedURL, category: newFeedCategory)
        feeds.append(feed)
        saveFeeds()
        
        showingAddFeed = false
        newFeedName = ""
        newFeedURL = ""
        newFeedCategory = "기타"
    }
    
    private func deleteFeed(_ feed: RSSFeed) {
        feeds.removeAll { $0.id == feed.id }
        saveFeeds()
    }
    
    // 즐겨찾기 토글 (내 피드)
    private func toggleFavorite(_ feed: RSSFeed) {
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index].isFavorite.toggle()
            saveFeeds()
            print("⭐️ 즐겨찾기 토글: \(feeds[index].name) - \(feeds[index].isFavorite ? "ON" : "OFF")")
        }
    }
    
    // 즐겨찾기 토글 (인기 피드) - 내 피드로 추가
    private func togglePopularFeedFavorite(_ feed: RSSFeed) {
        // 이미 내 피드에 있는지 확인
        if let index = feeds.firstIndex(where: { $0.url == feed.url }) {
            feeds[index].isFavorite.toggle()
            saveFeeds()
            print("⭐️ 인기 피드 즐겨찾기 토글: \(feeds[index].name) - \(feeds[index].isFavorite ? "ON" : "OFF")")
        } else {
            // 내 피드에 없으면 추가하고 즐겨찾기 설정
            var newFeed = feed
            newFeed.isFavorite = true
            feeds.append(newFeed)
            saveFeeds()
            print("⭐️ 인기 피드를 내 피드에 추가하고 즐겨찾기: \(newFeed.name)")
        }
    }
    
    // 앱 시작 시 즐겨찾기 피드 자동 조회
    private func loadFavoriteFeedsOnStartup() {
        let favorites = favoriteFeeds
        
        if favorites.isEmpty {
            print("⭐️ 즐겨찾기된 피드가 없습니다")
            // 즐겨찾기가 없으면 내피드 탭으로 이동
            if !feeds.isEmpty {
                selectedTab = .myFeeds
            } else {
                selectedTab = .popular
            }
            return
        }
        
        print("⭐️ 즐겨찾기 피드 \(favorites.count)개 자동 조회 시작")
        
        // 즐겨찾기 탭 유지
        selectedTab = .favorite
        
        // 첫 번째 즐겨찾기 피드를 선택하고 로드
        /*
        if let firstFavorite = favorites.first {
            selectedFeed = firstFavorite
            Task {
                await parser.fetchFeed(from: firstFavorite.url)
                print("⭐️ 첫 번째 즐겨찾기 피드 로드 완료: \(firstFavorite.name)")
            }
        }
        */
    }
}

// MARK: - Feed Card
struct FeedCard: View {
    let feed: RSSFeed
    var showDelete: Bool = true
    var showFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(feed.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("#\(feed.category)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(feed.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // 즐겨찾기 버튼
                    if showFavorite {
                        Button(action: {
                            onToggleFavorite?()
                        }) {
                            Image(systemName: feed.isFavorite ? "star.fill" : "star")
                                .foregroundColor(feed.isFavorite ? .yellow : .gray)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 삭제 버튼 또는 화살표
                    if showDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - RSS Item Card
struct RSSItemCard: View {
    let item: RSSItem
    
    // 링크 처리 헬퍼 함수
    private func openLink() {
        guard let url = URL(string: item.link) else {
            print("❌ URL 변환 실패: \(item.link)")
            return
        }
        
        print("🔗 클릭된 URL: \(url.absoluteString)")
        print("🔗 호스트: \(url.host ?? "없음")")
        
        // YouTube 링크 감지 및 앱으로 열기
        if isYouTubeURL(url) {
            print("🎥 YouTube URL 감지")
            openYouTubeVideo(url: url)
        }
        // Reddit 링크 감지 및 앱으로 열기
        else if isRedditURL(url) {
            print("🔴 Reddit URL 감지")
            openRedditPost(url: url)
        }
        // 일반 링크는 그냥 열기
        else {
            print("🌐 일반 URL로 Safari 실행")
            UIApplication.shared.open(url)
        }
    }
    
    // YouTube URL 감지
    private func isYouTubeURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("youtube.com") || host.contains("youtu.be")
    }
    
    // YouTube 비디오 ID 추출
    private func extractYouTubeVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString
        
        // youtube.com/watch?v=VIDEO_ID 형식
        if urlString.contains("youtube.com/watch") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoID
            }
        }
        
        // youtu.be/VIDEO_ID 형식
        if urlString.contains("youtu.be/") {
            let pathComponents = url.pathComponents
            if pathComponents.count > 1 {
                return pathComponents[1]
            }
        }
        
        return nil
    }
    
    // YouTube 앱으로 열기
    private func openYouTubeVideo(url: URL) {
        print("🎥 YouTube 비디오 열기 시도: \(url.absoluteString)")
        
        guard let videoID = extractYouTubeVideoID(from: url) else {
            print("❌ 비디오 ID 추출 실패, Safari로 열기")
            // 비디오 ID를 추출할 수 없으면 브라우저로 열기
            UIApplication.shared.open(url)
            return
        }
        
        print("✅ 비디오 ID 추출 성공: \(videoID)")
        
        // YouTube 앱 URL scheme
        let appURL = URL(string: "youtube://www.youtube.com/watch?v=\(videoID)")!
        print("🔗 YouTube 앱 URL: \(appURL.absoluteString)")
        
        // YouTube 앱이 설치되어 있으면 앱으로 열기
        if UIApplication.shared.canOpenURL(appURL) {
            print("✅ YouTube 앱 설치됨, 앱으로 열기")
            UIApplication.shared.open(appURL)
        } else {
            print("❌ YouTube 앱 미설치, Safari로 열기")
            // YouTube 앱이 없으면 브라우저로 열기
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Reddit 관련 함수
    
    // Reddit URL 감지
    private func isRedditURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("reddit.com")
    }
    
    // Reddit 앱으로 열기
    private func openRedditPost(url: URL) {
        print("🔴 Reddit 포스트 열기 시도: \(url.absoluteString)")
        
        // Reddit 원본 URL의 경로 추출
        let urlString = url.absoluteString
        
        // old.reddit.com을 reddit.com으로 변환
        let cleanedURLString = urlString
            .replacingOccurrences(of: "old.reddit.com", with: "reddit.com")
            .replacingOccurrences(of: "www.reddit.com", with: "reddit.com")
        
        print("🔗 정리된 URL: \(cleanedURLString)")
        
        // Reddit 앱 URL scheme 생성
        // reddit://reddit.com/r/subreddit/... 형식
        if let cleanedURL = URL(string: cleanedURLString),
           let components = URLComponents(url: cleanedURL, resolvingAgainstBaseURL: false) {
            
            // reddit:// scheme으로 변경
            var redditComponents = components
            redditComponents.scheme = "reddit"
            
            if let appURL = redditComponents.url {
                print("🔗 Reddit 앱 URL: \(appURL.absoluteString)")
                
                // Reddit 앱이 설치되어 있으면 앱으로 열기
                if UIApplication.shared.canOpenURL(appURL) {
                    print("✅ Reddit 앱 설치됨, 앱으로 열기")
                    UIApplication.shared.open(appURL)
                    return
                } else {
                    print("❌ Reddit 앱 미설치")
                }
            }
        }
        
        print("🌐 Safari로 열기")
        // Reddit 앱이 없거나 URL 변환 실패 시 브라우저로 열기
        UIApplication.shared.open(url)
    }
    
    var body: some View {
        Button(action: openLink) {
            VStack(alignment: .leading, spacing: 12) {
                // Image
                if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                                .cornerRadius(12)
                        case .failure, .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 180)
                                .cornerRadius(12)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Time
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(item.timeAgo)
                            .font(.caption)
                        
                        if let author = item.author {
                            Spacer()
                            Text(author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.orange)
                    
                    // Title
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Description
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

