import SwiftUI
import Combine
import WebKit

// MARK: - Crypto Models (CoinGecko API)
struct CryptoListResponse: Codable {
    let coins: [CryptoCoin]
    
    enum CodingKeys: String, CodingKey {
        case coins = "data"
    }
}

struct CryptoCoin: Codable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let image: String?
    let currentPrice: Double?
    let marketCap: Double?
    let marketCapRank: Int?
    let priceChangePercentage24h: Double?
    let priceChangePercentage7d: Double?
    let totalVolume: Double?
    let high24h: Double?
    let low24h: Double?
    let circulatingSupply: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case priceChangePercentage7d = "price_change_percentage_7d"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case circulatingSupply = "circulating_supply"
    }
    
    var priceFormatted: String {
        guard let price = currentPrice else { return "N/A" }
        if price >= 1000 {
            return String(format: "$%.0f", price)
        } else if price >= 1 {
            return String(format: "$%.2f", price)
        } else {
            return String(format: "$%.4f", price)
        }
    }
    
    var marketCapFormatted: String {
        guard let cap = marketCap else { return "N/A" }
        if cap >= 1_000_000_000_000 {
            return String(format: "$%.2fT", cap / 1_000_000_000_000)
        } else if cap >= 1_000_000_000 {
            return String(format: "$%.2fB", cap / 1_000_000_000)
        } else if cap >= 1_000_000 {
            return String(format: "$%.2fM", cap / 1_000_000)
        }
        return String(format: "$%.0f", cap)
    }
    
    var change24hColor: Color {
        guard let change = priceChangePercentage24h else { return .gray }
        return change >= 0 ? .green : .red
    }
}

// MARK: - Crypto News Models
struct CryptoNews: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let url: String
    let imageurl: String?
    let publishedOn: Int
    let source: String
    let tags: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, body, url, imageurl
        case publishedOn = "published_on"
        case source
        case tags
    }
    
    var publishedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(publishedOn))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일"
        return formatter.string(from: date)
    }
    
    var publishedTimeAgo: String {
        let date = Date(timeIntervalSince1970: TimeInterval(publishedOn))
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)일 전"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)시간 전"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)분 전"
        }
        return "방금 전"
    }
}

struct CryptoNewsResponse: Codable {
    let data: [CryptoNews]
    
    enum CodingKeys: String, CodingKey {
        case data = "Data"
    }
}

// MARK: - Crypto Service
class CryptoService: ObservableObject {
    @Published var coins: [CryptoCoin] = []
    @Published var news: [CryptoNews] = []
    @Published var isLoadingCoins = false
    @Published var isLoadingNews = false
    @Published var errorMessage: String?
    
    private let coinGeckoBaseURL = "https://api.coingecko.com/api/v3"
    private let cryptoCompareBaseURL = "https://min-api.cryptocompare.com/data/v2"
    
    func fetchTopCoins() async {
        await MainActor.run {
            isLoadingCoins = true
            errorMessage = nil
        }
        
        // CoinGecko API: Top 20 coins by market cap
        let urlString = "\(coinGeckoBaseURL)/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=20&page=1&sparkline=false&price_change_percentage=24h,7d"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "잘못된 URL"
                isLoadingCoins = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let fetchedCoins = try decoder.decode([CryptoCoin].self, from: data)
            
            await MainActor.run {
                self.coins = fetchedCoins
                isLoadingCoins = false
                print("✅ \(fetchedCoins.count)개 암호화폐 로드 완료")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "암호화폐 데이터를 불러오는데 실패했습니다: \(error.localizedDescription)"
                isLoadingCoins = false
                print("❌ 암호화폐 로드 실패: \(error)")
            }
        }
    }
    
    func fetchCryptoNews() async {
        await MainActor.run {
            isLoadingNews = true
        }
        
        // CryptoCompare News API (무료, 제한적)
        let urlString = "\(cryptoCompareBaseURL)/news/?lang=EN"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                isLoadingNews = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(CryptoNewsResponse.self, from: data)
            
            await MainActor.run {
                self.news = Array(response.data.prefix(15)) // 최대 15개만 표시
                isLoadingNews = false
                print("✅ \(self.news.count)개 뉴스 로드 완료")
            }
        } catch {
            await MainActor.run {
                isLoadingNews = false
                print("❌ 뉴스 로드 실패: \(error)")
            }
        }
    }
}

// MARK: - Crypto View
struct CryptoView: View {
    @StateObject private var service = CryptoService()
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: CryptoTab = .prices
    
    enum CryptoTab {
        case prices
        case news
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Bar
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .prices
                        }
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 16))
                                Text("시세")
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == .prices ? .semibold : .regular)
                            }
                            
                            Rectangle()
                                .fill(selectedTab == .prices ? Color.orange : Color.clear)
                                .frame(height: 2)
                        }
                        .foregroundColor(selectedTab == .prices ? .orange : .secondary)
                        .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .news
                        }
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "newspaper.fill")
                                    .font(.system(size: 16))
                                Text("뉴스")
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == .news ? .semibold : .regular)
                            }
                            
                            Rectangle()
                                .fill(selectedTab == .news ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .foregroundColor(selectedTab == .news ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color(UIColor.systemGroupedBackground))
                
                // Content
                if selectedTab == .prices {
                    cryptoPricesView
                } else {
                    cryptoNewsView
                }
            }
            .navigationTitle("암호화폐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .task {
                await service.fetchTopCoins()
                await service.fetchCryptoNews()
            }
        }
    }
    
    private var cryptoPricesView: some View {
        Group {
            if service.isLoadingCoins {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("암호화폐 데이터 로딩 중...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = service.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("다시 시도") {
                        Task {
                            await service.fetchTopCoins()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(service.coins) { coin in
                            CryptoCoinCard(coin: coin)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await service.fetchTopCoins()
                }
            }
        }
    }
    
    private var cryptoNewsView: some View {
        Group {
            if service.isLoadingNews {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("뉴스 로딩 중...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if service.news.isEmpty {
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
                        ForEach(service.news) { newsItem in
                            CryptoNewsCard(news: newsItem)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await service.fetchCryptoNews()
                }
            }
        }
    }
}

// MARK: - Crypto Coin Card
struct CryptoCoinCard: View {
    let coin: CryptoCoin
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            coinCardContent
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            CryptoDetailView(coin: coin)
        }
    }
    
    private var coinCardContent: some View {
        HStack(spacing: 12) {
            // Rank Badge
            Text("\(coin.marketCapRank ?? 0)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(14)
            
            // Coin Icon
            if let imageUrl = coin.image, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                    case .failure, .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(coin.symbol.prefix(1).uppercased())
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Coin Info
            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(coin.symbol.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Price Info
            VStack(alignment: .trailing, spacing: 4) {
                Text(coin.priceFormatted)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: coin.priceChangePercentage24h ?? 0 >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%.2f%%", abs(coin.priceChangePercentage24h ?? 0)))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(coin.change24hColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(coin.change24hColor.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Crypto Detail View
struct CryptoDetailView: View {
    let coin: CryptoCoin
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    VStack(spacing: 16) {
                        // Coin Icon & Name
                        if let imageUrl = coin.image, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80, height: 80)
                                case .failure, .empty:
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        VStack(spacing: 4) {
                            Text(coin.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(coin.symbol.uppercased())
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        // Current Price
                        VStack(spacing: 8) {
                            Text(coin.priceFormatted)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                Image(systemName: coin.priceChangePercentage24h ?? 0 >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%.2f%%", abs(coin.priceChangePercentage24h ?? 0)))
                                    .fontWeight(.semibold)
                                Text("(24h)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.headline)
                            .foregroundColor(coin.change24hColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(coin.change24hColor.opacity(0.15))
                            .cornerRadius(20)
                        }
                    }
                    .padding(.top)
                    
                    // TradingView Chart
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.orange)
                            Text("가격 차트")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        
                        TradingViewChart(symbol: coin.symbol.uppercased())
                            .frame(height: 400)
                            .cornerRadius(16)
                            .padding(.horizontal)
                    }
                    
                    // Statistics Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                            Text("상세 정보")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            StatRow(
                                label: "시가총액",
                                value: coin.marketCapFormatted,
                                icon: "dollarsign.circle.fill",
                                color: .green
                            )
                            
                            if let rank = coin.marketCapRank {
                                StatRow(
                                    label: "시총 순위",
                                    value: "#\(rank)",
                                    icon: "number.circle.fill",
                                    color: .orange
                                )
                            }
                            
                            if let volume = coin.totalVolume {
                                StatRow(
                                    label: "24시간 거래량",
                                    value: formatVolume(volume),
                                    icon: "arrow.left.arrow.right.circle.fill",
                                    color: .purple
                                )
                            }
                            
                            if let high = coin.high24h {
                                StatRow(
                                    label: "24시간 최고가",
                                    value: formatPrice(high),
                                    icon: "arrow.up.circle.fill",
                                    color: .green
                                )
                            }
                            
                            if let low = coin.low24h {
                                StatRow(
                                    label: "24시간 최저가",
                                    value: formatPrice(low),
                                    icon: "arrow.down.circle.fill",
                                    color: .red
                                )
                            }
                            
                            if let change7d = coin.priceChangePercentage7d {
                                StatRow(
                                    label: "7일 변동률",
                                    value: String(format: "%.2f%%", change7d),
                                    icon: "calendar.circle.fill",
                                    color: change7d >= 0 ? .green : .red
                                )
                            }
                            
                            if let supply = coin.circulatingSupply {
                                StatRow(
                                    label: "유통량",
                                    value: formatSupply(supply),
                                    icon: "circle.grid.cross.fill",
                                    color: .blue
                                )
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle(coin.symbol.uppercased())
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
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$%.0f", price)
        } else if price >= 1 {
            return String(format: "$%.2f", price)
        } else {
            return String(format: "$%.4f", price)
        }
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "$%.2fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "$%.2fM", volume / 1_000_000)
        }
        return String(format: "$%.0f", volume)
    }
    
    private func formatSupply(_ supply: Double) -> String {
        if supply >= 1_000_000_000 {
            return String(format: "%.2fB", supply / 1_000_000_000)
        } else if supply >= 1_000_000 {
            return String(format: "%.2fM", supply / 1_000_000)
        }
        return String(format: "%.0f", supply)
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TradingView Chart
struct TradingViewChart: UIViewRepresentable {
    let symbol: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let htmlString = """
        <!DOCTYPE html>
        <html style="height: 100%;">
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    background: transparent;
                }
                .tradingview-widget-container {
                    width: 100%;
                    height: 100%;
                }
                #tradingview_widget {
                    width: 100%;
                    height: 100%;
                }
            </style>
        </head>
        <body>
            <!-- TradingView Widget BEGIN -->
            <div class="tradingview-widget-container">
              <div id="tradingview_widget"></div>
            </div>
            <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
            <script type="text/javascript">
            new TradingView.widget({
              "autosize": true,
              "symbol": "BINANCE:\(symbol)USDT",
              "interval": "D",
              "timezone": "Asia/Seoul",
              "theme": "light",
              "style": "1",
              "locale": "kr",
              "toolbar_bg": "#f1f3f6",
              "enable_publishing": false,
              "allow_symbol_change": false,
              "container_id": "tradingview_widget",
              "hide_top_toolbar": false,
              "hide_legend": false,
              "save_image": false,
              "studies": [
                "MASimple@tv-basicstudies"
              ]
            });
            </script>
            <!-- TradingView Widget END -->
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

// MARK: - Crypto News Card
struct CryptoNewsCard: View {
    let news: CryptoNews
    @State private var showingWebView = false
    
    var body: some View {
        Button(action: {
            if let url = URL(string: news.url) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // News Image
                if let imageUrl = news.imageurl, let url = URL(string: imageUrl) {
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
                
                // News Info
                VStack(alignment: .leading, spacing: 8) {
                    // Source & Time
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.caption2)
                            Text(news.source)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(news.publishedTimeAgo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Title
                    Text(news.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Body
                    Text(news.body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
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

