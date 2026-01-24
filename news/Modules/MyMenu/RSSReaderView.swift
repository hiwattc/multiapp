import SwiftUI
import Combine

// MARK: - RSS Feed Model
struct RSSFeed: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var category: String
    
    init(id: UUID = UUID(), name: String, url: String, category: String = "기타") {
        self.id = id
        self.name = name
        self.url = url
        self.category = category
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
    
    // 필터링된 인기 피드
    var filteredPopularFeeds: [RSSFeed] {
        if selectedCategory == "전체" {
            return popularFeeds
        } else {
            return popularFeeds.filter { $0.category == selectedCategory }
        }
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
            }
        }
    }
    
    // MARK: - Feed List View
    private var feedListView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "newspaper.fill")
                            .foregroundColor(.orange)
                        Text("RSS 피드 구독")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("RSS 피드를 추가하고 최신 뉴스를 받아보세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // My Feeds
                if !feeds.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("내 피드")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        
                        ForEach(feeds) { feed in
                            FeedCard(feed: feed) {
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
                
                // Popular Feeds
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("인기 피드")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)
                    
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
                        FeedCard(feed: feed, showDelete: false) {
                            selectedFeed = feed
                            Task {
                                await parser.fetchFeed(from: feed.url)
                            }
                        } onDelete: {}
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground))
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
}

// MARK: - Feed Card
struct FeedCard: View {
    let feed: RSSFeed
    var showDelete: Bool = true
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
    
    var body: some View {
        Button(action: {
            if let url = URL(string: item.link) {
                UIApplication.shared.open(url)
            }
        }) {
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

