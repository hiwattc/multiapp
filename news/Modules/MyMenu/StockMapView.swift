import SwiftUI
import WebKit

// MARK: - Stock Map Type
struct StockMapType: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: String
    let icon: String
    let color: Color
}

// MARK: - Stock Map View
struct StockMapView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedStock: String?
    @State private var showingStockDetail = false
    
    let stockMaps = [
        StockMapType(
            title: "S&P 500 섹터",
            subtitle: "업종별 시가총액 맵",
            url: "https://finviz.com/map.ashx?t=sec",
            icon: "chart.pie.fill",
            color: .blue
        ),
        StockMapType(
            title: "S&P 500 전체",
            subtitle: "개별 종목별 시가총액",
            url: "https://finviz.com/map.ashx?t=sec_all",
            icon: "square.grid.3x3.fill",
            color: .green
        ),
        StockMapType(
            title: "세계 시장",
            subtitle: "국가별 시장 현황",
            url: "https://finviz.com/map.ashx?t=geo",
            icon: "globe.americas.fill",
            color: .orange
        ),
        StockMapType(
            title: "ETF",
            subtitle: "상장지수펀드",
            url: "https://finviz.com/map.ashx?t=etf",
            icon: "chart.bar.doc.horizontal.fill",
            color: .purple
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.blue)
                            Text("미국 증시 맵")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text("시가총액 기준 히트맵으로 시장을 한눈에 파악하세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Maps
                    ForEach(stockMaps) { map in
                        VStack(alignment: .leading, spacing: 12) {
                            // Map Header
                            HStack {
                                Image(systemName: map.icon)
                                    .foregroundColor(map.color)
                                    .font(.system(size: 20))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(map.title)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    
                                    Text(map.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // Map WebView
                            FinvizMapWebView(
                                urlString: map.url,
                                onStockSelected: { symbol in
                                    selectedStock = symbol
                                    showingStockDetail = true
                                }
                            )
                            .frame(height: 500)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("미국증시")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingStockDetail) {
                if let symbol = selectedStock {
                    StockDetailView(symbol: symbol)
                }
            }
        }
    }
}

// MARK: - Finviz Map WebView
struct FinvizMapWebView: UIViewRepresentable {
    let urlString: String
    let onStockSelected: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onStockSelected: onStockSelected)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.backgroundColor = .white
        
        // JavaScript로 클릭 이벤트 감지
        let script = """
        document.addEventListener('click', function(e) {
            var target = e.target;
            // 티커 심볼이 포함된 요소 찾기
            while (target && target.tagName !== 'A') {
                target = target.parentElement;
            }
            if (target && target.href) {
                var url = target.href;
                // Finviz 주식 상세 페이지 패턴: /quote.ashx?t=SYMBOL
                var match = url.match(/[?&]t=([A-Z]+)/);
                if (match && match[1]) {
                    e.preventDefault();
                    window.webkit.messageHandlers.stockClick.postMessage(match[1]);
                }
            }
        }, true);
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
        webView.configuration.userContentController.add(context.coordinator, name: "stockClick")
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onStockSelected: (String) -> Void
        
        init(onStockSelected: @escaping (String) -> Void) {
            self.onStockSelected = onStockSelected
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "stockClick", let symbol = message.body as? String {
                print("📊 주식 선택됨: \(symbol)")
                onStockSelected(symbol)
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 외부 링크는 차단하고 맵 내에서만 동작하도록
            if let url = navigationAction.request.url?.absoluteString {
                if url.contains("finviz.com/map.ashx") || url.contains("about:blank") {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Stock Detail View
struct StockDetailView: View {
    let symbol: String
    @Environment(\.dismiss) var dismiss
    @State private var stockInfo: StockInfo?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 16) {
                        // Symbol Badge
                        Text(symbol)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                        
                        if let info = stockInfo {
                            VStack(spacing: 8) {
                                Text(info.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                
                                Text(info.sector)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top)
                    
                    // TradingView Chart
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                            Text("주가 차트")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        
                        StockTradingViewChart(symbol: symbol)
                            .frame(height: 400)
                            .cornerRadius(16)
                            .padding(.horizontal)
                    }
                    
                    // Stock Info
                    if let info = stockInfo {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                Text("기업 정보")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                InfoRow(label: "회사명", value: info.name, icon: "building.2.fill", color: .blue)
                                InfoRow(label: "섹터", value: info.sector, icon: "chart.pie.fill", color: .green)
                                InfoRow(label: "산업", value: info.industry, icon: "gearshape.fill", color: .orange)
                                InfoRow(label: "국가", value: info.country, icon: "globe.americas.fill", color: .purple)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Quick Links
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            Text("빠른 링크")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            QuickLinkButton(
                                title: "Finviz에서 보기",
                                icon: "chart.bar.fill",
                                url: "https://finviz.com/quote.ashx?t=\(symbol)"
                            )
                            
                            QuickLinkButton(
                                title: "Yahoo Finance에서 보기",
                                icon: "y.circle.fill",
                                url: "https://finance.yahoo.com/quote/\(symbol)"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle(symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadStockInfo()
            }
        }
    }
    
    private func loadStockInfo() async {
        isLoading = true
        
        // 실제로는 API를 호출하지만, 여기서는 기본 정보만 표시
        // Finviz API나 Yahoo Finance API를 사용할 수 있음
        
        // 간단한 예시 데이터
        let sectorMap: [String: (String, String, String)] = [
            "AAPL": ("Apple Inc.", "Technology", "Consumer Electronics"),
            "MSFT": ("Microsoft Corporation", "Technology", "Software"),
            "GOOGL": ("Alphabet Inc.", "Communication Services", "Internet Content & Information"),
            "AMZN": ("Amazon.com Inc.", "Consumer Cyclical", "Internet Retail"),
            "TSLA": ("Tesla Inc.", "Consumer Cyclical", "Auto Manufacturers"),
            "NVDA": ("NVIDIA Corporation", "Technology", "Semiconductors"),
            "META": ("Meta Platforms Inc.", "Communication Services", "Internet Content & Information"),
            "BRK.B": ("Berkshire Hathaway", "Financial Services", "Insurance"),
            "JPM": ("JPMorgan Chase & Co.", "Financial Services", "Banks"),
            "V": ("Visa Inc.", "Financial Services", "Credit Services")
        ]
        
        let info = sectorMap[symbol]
        
        await MainActor.run {
            self.stockInfo = StockInfo(
                symbol: symbol,
                name: info?.0 ?? "\(symbol) Inc.",
                sector: info?.1 ?? "Unknown",
                industry: info?.2 ?? "Unknown",
                country: "USA"
            )
            isLoading = false
        }
    }
}

// MARK: - Stock Info Model
struct StockInfo {
    let symbol: String
    let name: String
    let sector: String
    let industry: String
    let country: String
}

// MARK: - Info Row
struct InfoRow: View {
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

// MARK: - Quick Link Button
struct QuickLinkButton: View {
    let title: String
    let icon: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
}

// MARK: - Stock TradingView Chart
struct StockTradingViewChart: UIViewRepresentable {
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
              "symbol": "NASDAQ:\(symbol)",
              "interval": "D",
              "timezone": "America/New_York",
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
                "MASimple@tv-basicstudies",
                "Volume@tv-basicstudies"
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

