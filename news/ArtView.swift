import SwiftUI

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

// MARK: - Art View
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
