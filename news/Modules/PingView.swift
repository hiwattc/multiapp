import SwiftUI
import Combine
import Network

// MARK: - Models
struct PingResult: Identifiable, Codable {
    let id = UUID()
    let sequenceNumber: Int
    let latency: TimeInterval?
    let timestamp: Date
    let isSuccess: Bool
    
    var displayLatency: String {
        guard let latency = latency else { return "타임아웃" }
        return String(format: "%.1fms", latency * 1000)
    }
}

struct PingStatistics {
    var sent: Int = 0
    var received: Int = 0
    var lost: Int { sent - received }
    var lossRate: Double { sent > 0 ? Double(lost) / Double(sent) * 100 : 0 }
    var minLatency: TimeInterval?
    var maxLatency: TimeInterval?
    var avgLatency: TimeInterval?
    
    var latencies: [TimeInterval] = []
    
    mutating func addResult(_ result: PingResult) {
        sent += 1
        
        if let latency = result.latency {
            received += 1
            latencies.append(latency)
            
            if minLatency == nil || latency < minLatency! {
                minLatency = latency
            }
            if maxLatency == nil || latency > maxLatency! {
                maxLatency = latency
            }
            avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        }
    }
    
    func displayMin() -> String {
        guard let min = minLatency else { return "N/A" }
        return String(format: "%.1fms", min * 1000)
    }
    
    func displayMax() -> String {
        guard let max = maxLatency else { return "N/A" }
        return String(format: "%.1fms", max * 1000)
    }
    
    func displayAvg() -> String {
        guard let avg = avgLatency else { return "N/A" }
        return String(format: "%.1fms", avg * 1000)
    }
}

struct HistoryItem: Identifiable, Codable, Equatable {
    let id = UUID()
    let domain: String
    let timestamp: Date
    var isFavorite: Bool = false
}

// MARK: - Network Manager
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - Ping Manager (Simulated)
class PingManager: ObservableObject {
    @Published var results: [PingResult] = []
    @Published var statistics = PingStatistics()
    @Published var resolvedIP: String?
    @Published var isPinging = false
    @Published var errorMessage: String?
    
    private var pingTask: Task<Void, Never>?
    private let timeout: TimeInterval = 5.0
    
    func resolveDomain(_ domain: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo()
                hints.ai_family = AF_INET // IPv4
                hints.ai_socktype = SOCK_STREAM
                hints.ai_protocol = IPPROTO_TCP
                
                var result: UnsafeMutablePointer<addrinfo>?
                
                // getaddrinfo를 사용하여 실제 DNS 해석
                let status = getaddrinfo(domain, nil, &hints, &result)
                
                defer {
                    if result != nil {
                        freeaddrinfo(result)
                    }
                }
                
                guard status == 0, let addressInfo = result else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // sockaddr_in 구조체로 캐스팅하여 IP 주소 추출
                var addr = addressInfo.pointee.ai_addr.pointee
                var ipString = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                
                let addrIn = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                        $0.pointee
                    }
                }
                
                var inAddr = addrIn.sin_addr
                inet_ntop(AF_INET, &inAddr, &ipString, socklen_t(INET_ADDRSTRLEN))
                
                let ip = String(cString: ipString)
                continuation.resume(returning: ip)
            }
        }
    }
    
    func startPing(to domain: String, count: Int = 10) {
        guard !isPinging else { return }
        
        isPinging = true
        results = []
        statistics = PingStatistics()
        errorMessage = nil
        
        pingTask = Task {
            // DNS 해석
            guard let ip = await resolveDomain(domain) else {
                await MainActor.run {
                    errorMessage = "DNS 해석 실패"
                    isPinging = false
                }
                return
            }
            
            await MainActor.run {
                resolvedIP = ip
            }
            
            // Ping 실행
            for i in 1...count {
                guard !Task.isCancelled else { break }
                
                let result = await performSinglePing(sequence: i, to: ip)
                
                await MainActor.run {
                    results.append(result)
                    statistics.addResult(result)
                }
                
                if i < count {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
                }
            }
            
            await MainActor.run {
                isPinging = false
            }
        }
    }
    
    func stopPing() {
        pingTask?.cancel()
        isPinging = false
    }
    
    private func performSinglePing(sequence: Int, to ip: String) async -> PingResult {
        let startTime = Date()
        
        // 실제 ICMP ping 시뮬레이션
        // 실제 구현에서는 CFSocket이나 SimplePing 라이브러리 사용
        let randomDelay = Double.random(in: 0.01...0.2) // 10-200ms
        try? await Task.sleep(nanoseconds: UInt64(randomDelay * 1_000_000_000))
        
        let latency = Date().timeIntervalSince(startTime)
        let isSuccess = Double.random(in: 0...1) > 0.1 // 90% 성공률
        
        return PingResult(
            sequenceNumber: sequence,
            latency: isSuccess ? latency : nil,
            timestamp: Date(),
            isSuccess: isSuccess
        )
    }
}

// MARK: - Main View
struct PingView: View {
    @StateObject private var pingManager = PingManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var domainInput = ""
    @State private var history: [HistoryItem] = []
    @State private var showingHistory = false
    @State private var selectedPingCount = 10
    
    let pingCounts = [4, 10, 20, 50]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 네트워크 상태
                        if !networkMonitor.isConnected {
                            networkStatusBanner
                        }
                        
                        // 입력 섹션
                        inputSection
                        
                        // IP 정보
                        if let ip = pingManager.resolvedIP {
                            ipInfoCard(ip)
                        }
                        
                        // 통계
                        if !pingManager.results.isEmpty {
                            statisticsSection
                            chartSection
                        }
                        
                        // 결과 로그
                        if !pingManager.results.isEmpty {
                            resultsSection
                        }
                        
                        // 히스토리
                        if !history.isEmpty {
                            historySection
                        }
                        
                        // 하단 여유 공간 (탭바 영역 확보)
                        Color.clear
                            .frame(height: 80)
                    }
                    .padding()
                }
            }
            .navigationTitle("Network Ping")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                historySheet
            }
            .onAppear {
                loadHistory()
            }
        }
    }
    
    // MARK: - Components
    
    private var networkStatusBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
            Text("네트워크 연결 없음")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            // 도메인 입력
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.secondary)
                
                TextField("도메인 입력 (예: google.com)", text: $domainInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(pingManager.isPinging)
                
                if !domainInput.isEmpty {
                    Button(action: { domainInput = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Ping 횟수 선택
            HStack {
                Text("Ping 횟수:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Ping 횟수", selection: $selectedPingCount) {
                    ForEach(pingCounts, id: \.self) { count in
                        Text("\(count)회").tag(count)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 액션 버튼
            Button(action: performPing) {
                HStack {
                    Image(systemName: pingManager.isPinging ? "stop.fill" : "play.fill")
                    Text(pingManager.isPinging ? "중지" : "테스트 시작")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(pingManager.isPinging ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(domainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !networkMonitor.isConnected)
            
            if let error = pingManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func ipInfoCard(_ ip: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("해석된 IP 주소")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(ip)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("통계")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "전송", value: "\(pingManager.statistics.sent)", icon: "arrow.up.circle.fill", color: .blue)
                StatCard(title: "수신", value: "\(pingManager.statistics.received)", icon: "arrow.down.circle.fill", color: .green)
                StatCard(title: "손실", value: "\(pingManager.statistics.lost) (\(String(format: "%.1f%%", pingManager.statistics.lossRate)))", icon: "exclamationmark.triangle.fill", color: .red)
                StatCard(title: "평균", value: pingManager.statistics.displayAvg(), icon: "timer", color: .orange)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("최소")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(pingManager.statistics.displayMin())
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.medium)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("최대")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(pingManager.statistics.displayMax())
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("레이턴시 그래프")
                .font(.headline)
            
            LatencyChart(results: pingManager.results)
                .frame(height: 150)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10)
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("결과 로그")
                    .font(.headline)
                Spacer()
                if pingManager.isPinging {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            VStack(spacing: 8) {
                ForEach(pingManager.results.suffix(10).reversed()) { result in
                    ResultRow(result: result)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 테스트")
                    .font(.headline)
                Spacer()
                Button(action: { showingHistory = true }) {
                    Text("전체보기")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(history.prefix(5)) { item in
                        HistoryChip(item: item) {
                            domainInput = item.domain
                            performPing()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10)
    }
    
    private var historySheet: some View {
        NavigationView {
            List {
                if !history.filter({ $0.isFavorite }).isEmpty {
                    Section("즐겨찾기") {
                        ForEach(history.filter { $0.isFavorite }) { item in
                            HistoryListRow(item: item, onSelect: {
                                domainInput = item.domain
                                showingHistory = false
                                performPing()
                            }, onToggleFavorite: {
                                toggleFavorite(item)
                            }, onDelete: {
                                deleteHistoryItem(item)
                            })
                        }
                    }
                }
                
                Section("전체 기록") {
                    ForEach(history.filter { !$0.isFavorite }) { item in
                        HistoryListRow(item: item, onSelect: {
                            domainInput = item.domain
                            showingHistory = false
                            performPing()
                        }, onToggleFavorite: {
                            toggleFavorite(item)
                        }, onDelete: {
                            deleteHistoryItem(item)
                        })
                    }
                }
            }
            .navigationTitle("테스트 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        showingHistory = false
                    }
                }
                
                if !history.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(role: .destructive, action: clearHistory) {
                            Text("전체 삭제")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performPing() {
        let domain = domainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !domain.isEmpty else { return }
        
        if pingManager.isPinging {
            pingManager.stopPing()
        } else {
            pingManager.startPing(to: domain, count: selectedPingCount)
            addToHistory(domain)
        }
    }
    
    private func addToHistory(_ domain: String) {
        if let index = history.firstIndex(where: { $0.domain == domain }) {
            let item = history.remove(at: index)
            var updatedItem = item
            history.insert(updatedItem, at: 0)
        } else {
            let item = HistoryItem(domain: domain, timestamp: Date())
            history.insert(item, at: 0)
        }
        
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        saveHistory()
    }
    
    private func toggleFavorite(_ item: HistoryItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index].isFavorite.toggle()
            saveHistory()
        }
    }
    
    private func deleteHistoryItem(_ item: HistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    private func clearHistory() {
        history.removeAll()
        saveHistory()
        showingHistory = false
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "PingHistory"),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "PingHistory")
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ResultRow: View {
    let result: PingResult
    
    var body: some View {
        HStack {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.isSuccess ? .green : .red)
            
            Text("Ping #\(result.sequenceNumber)")
                .font(.system(.callout, design: .monospaced))
            
            Spacer()
            
            Text(result.displayLatency)
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(result.isSuccess ? .primary : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct LatencyChart: View {
    let results: [PingResult]
    
    var body: some View {
        GeometryReader { geometry in
            let maxLatency = results.compactMap { $0.latency }.max() ?? 0.2
            let width = geometry.size.width
            let height = geometry.size.height
            let spacing = results.count > 1 ? width / CGFloat(results.count - 1) : 0
            
            ZStack(alignment: .bottomLeading) {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        HStack {
                            Text(String(format: "%.0fms", maxLatency * 1000 * (1 - Double(i) / 4)))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                        }
                        if i < 4 {
                            Spacer()
                        }
                    }
                }
                
                // Line chart
                Path { path in
                    for (index, result) in results.enumerated() {
                        let x = CGFloat(index) * spacing + 40
                        let y = if let latency = result.latency {
                            height - (CGFloat(latency / maxLatency) * height)
                        } else {
                            height
                        }
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                .offset(x: 0, y: 0)
                
                // Data points
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    if let latency = result.latency {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .position(
                                x: CGFloat(index) * spacing + 40,
                                y: height - (CGFloat(latency / maxLatency) * height)
                            )
                    }
                }
            }
        }
        .padding(.leading, -10)
    }
}

struct HistoryChip: View {
    let item: HistoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                Text(item.domain)
                    .font(.callout)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(16)
        }
    }
}

struct HistoryListRow: View {
    let item: HistoryItem
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.domain)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .foregroundColor(item.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview
struct PingView_Previews: PreviewProvider {
    static var previews: some View {
        PingView()
    }
}