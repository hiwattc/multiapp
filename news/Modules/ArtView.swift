import SwiftUI
import Combine

// MARK: - Museum Enum
enum Museum: String, CaseIterable {
    case met = "메트로폴리탄 미술관"
    case chicago = "시카고 미술관"
    case wiki = "위키피디아"
    
    var englishName: String {
        switch self {
        case .met: return "The Metropolitan Museum of Art"
        case .chicago: return "The Art Institute of Chicago"
        case .wiki: return "Wikipedia"
        }
    }
    
    var popularTags: [String] {
        switch self {
        case .met:
            return [
                "Monet", "Van Gogh", "Rembrandt", "Picasso", "Renoir",
                "Cézanne", "Vermeer", "Degas", "Manet", "Cassatt",
                "Egyptian", "Greek", "Renaissance", "Impressionism", "Modern Art",
                "Sculpture", "Portrait", "Landscape", "Still Life", "Abstract"
            ]
        case .chicago:
            return [
                "Monet", "Van Gogh", "Seurat", "Hopper", "Wood",
                "Renoir", "Picasso", "Matisse", "Pollock", "Rothko",
                "Impressionism", "Modern Art", "Contemporary", "American Art", "Asian Art",
                "Photography", "Portrait", "Landscape", "Abstract", "Expressionism"
            ]
        case .wiki:
            return [
                "Leonardo da Vinci", "Vincent van Gogh", "Pablo Picasso", "Claude Monet", "Salvador Dalí",
                "Michelangelo", "Rembrandt", "Johannes Vermeer", "Edgar Degas", "Pierre-Auguste Renoir",
                "Paul Cézanne", "Henri Matisse", "Wassily Kandinsky", "Jackson Pollock", "Andy Warhol",
                "Frida Kahlo", "Georgia O'Keeffe", "Gustav Klimt", "Edvard Munch", "Paul Gauguin",
                "Henri de Toulouse-Lautrec", "Amedeo Modigliani", "Marc Chagall", "Joan Miró", "René Magritte",
                "Francisco Goya", "Diego Velázquez", "Caravaggio", "Titian", "Raphael",
                "Jan van Eyck", "Hieronymus Bosch", "Albrecht Dürer", "Peter Paul Rubens", "Jan Vermeer",
                "Édouard Manet", "Mary Cassatt", "Berthe Morisot", "Camille Pissarro", "Alfred Sisley",
                "Paul Signac", "Georges Seurat", "Henri Rousseau", "Gustave Courbet", "Jean-François Millet",
                "Winslow Homer", "Edward Hopper", "Grant Wood", "Norman Rockwell", "Roy Lichtenstein"
            ]
        }
    }
}

// MARK: - Art Models (Met Museum)
struct MetSearchResponse: Codable {
    let total: Int
    let objectIDs: [Int]?
}

struct Artwork: Identifiable {
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
    let museum: Museum
    
    var id: Int { objectID }
    
    var artist: String {
        artistDisplayName ?? "작가 미상"
    }
    
    var date: String {
        objectDate ?? "제작연도 미상"
    }
}

// Met Museum API response
struct MetArtwork: Codable {
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
    
    func toArtwork() -> Artwork {
        return Artwork(
            objectID: objectID,
            title: title,
            artistDisplayName: artistDisplayName,
            objectDate: objectDate,
            medium: medium,
            department: department,
            culture: culture,
            primaryImage: primaryImage,
            primaryImageSmall: primaryImageSmall,
            objectURL: objectURL,
            creditLine: creditLine,
            classification: classification,
            dimensions: dimensions,
            museum: .met
        )
    }
}

// MARK: - Chicago Art Institute Models
struct ChicagoSearchResponse: Codable {
    let data: [ChicagoArtwork]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let total: Int
        let limit: Int
        let offset: Int
    }
}

struct ChicagoArtworkDetail: Codable {
    let data: ChicagoArtwork
}

struct ChicagoArtwork: Codable, Identifiable {
    let id: Int
    let title: String
    let artistDisplay: String?
    let dateDisplay: String?
    let mediumDisplay: String?
    let departmentTitle: String?
    let placeOfOrigin: String?
    let imageId: String?
    let creditLine: String?
    let classification: String?
    let dimensions: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artistDisplay = "artist_display"
        case dateDisplay = "date_display"
        case mediumDisplay = "medium_display"
        case departmentTitle = "department_title"
        case placeOfOrigin = "place_of_origin"
        case imageId = "image_id"
        case creditLine = "credit_line"
        case classification = "classification_title"
        case dimensions
    }
    
    var imageURL: String? {
        guard let imageId = imageId else { return nil }
        return "https://www.artic.edu/iiif/2/\(imageId)/full/843,/0/default.jpg"
    }
    
    var artist: String {
        artistDisplay ?? "작가 미상"
    }
    
    var date: String {
        dateDisplay ?? "제작연도 미상"
    }
    
    // Convert to Artwork for unified display
    func toArtwork() -> Artwork {
        return Artwork(
            objectID: id,
            title: title,
            artistDisplayName: artistDisplay,
            objectDate: dateDisplay,
            medium: mediumDisplay,
            department: departmentTitle,
            culture: placeOfOrigin,
            primaryImage: imageURL,
            primaryImageSmall: imageURL,
            objectURL: "https://www.artic.edu/artworks/\(id)",
            creditLine: creditLine,
            classification: classification,
            dimensions: dimensions,
            museum: .chicago
        )
    }
}

// MARK: - Wikipedia Models
struct WikipediaSearchResponse: Codable {
    let query: WikipediaQuery
    
    struct WikipediaQuery: Codable {
        let search: [WikipediaSearchResult]
        let pages: [String: WikipediaPage]?
    }
}

struct WikipediaSearchResult: Codable {
    let title: String
    let pageid: Int
}

struct WikipediaPage: Codable {
    let pageid: Int
    let title: String
    let thumbnail: WikipediaThumbnail?
    let extract: String?
    let fullurl: String?
    
    struct WikipediaThumbnail: Codable {
        let source: String
        let width: Int
        let height: Int
    }
}

struct WikipediaPageInfoResponse: Codable {
    let query: WikipediaPageInfoQuery
    
    struct WikipediaPageInfoQuery: Codable {
        let pages: [String: WikipediaPage]
    }
}

// MARK: - Art Service
class ArtService {
    static let shared = ArtService()
    private let metBaseURL = "https://collectionapi.metmuseum.org/public/collection/v1"
    private let chicagoBaseURL = "https://api.artic.edu/api/v1"
    private let wikipediaBaseURL = "https://en.wikipedia.org/w/api.php"
    
    // 캐시 추가
    private var artworkCache: [String: Artwork] = [:] // Changed to String key for museum+id
    private var featuredCacheMet: [Artwork]?
    private var featuredCacheChicago: [Artwork]?
    private var featuredCacheWiki: [Artwork]?
    private var cacheTimestampMet: Date?
    private var cacheTimestampChicago: Date?
    private var cacheTimestampWiki: Date?
    private let cacheValidDuration: TimeInterval = 3600 // 1시간
    
    // MARK: - Met Museum Methods
    func searchMetArtworks(query: String = "painting") async throws -> [Int] {
        let urlString = "\(metBaseURL)/search?hasImages=true&q=\(query)"
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MetSearchResponse.self, from: data)
        return Array((response.objectIDs ?? []).prefix(30))
    }
    
    func getMetArtwork(objectID: Int) async throws -> Artwork {
        let cacheKey = "met_\(objectID)"
        if let cached = artworkCache[cacheKey] {
            return cached
        }
        
        let urlString = "\(metBaseURL)/objects/\(objectID)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let metArtwork = try JSONDecoder().decode(MetArtwork.self, from: data)
        let artwork = metArtwork.toArtwork()
        
        artworkCache[cacheKey] = artwork
        return artwork
    }
    
    // MARK: - Chicago Museum Methods
    func searchChicagoArtworks(query: String = "painting") async throws -> [Int] {
        let urlString = "\(chicagoBaseURL)/artworks/search?q=\(query)&limit=30&fields=id,title,artist_display,date_display,medium_display,department_title,place_of_origin,image_id,credit_line,classification_title,dimensions"
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ChicagoSearchResponse.self, from: data)
        return response.data.map { $0.id }
    }
    
    func getChicagoArtwork(objectID: Int) async throws -> Artwork {
        let cacheKey = "chicago_\(objectID)"
        if let cached = artworkCache[cacheKey] {
            return cached
        }
        
        let urlString = "\(chicagoBaseURL)/artworks/\(objectID)?fields=id,title,artist_display,date_display,medium_display,department_title,place_of_origin,image_id,credit_line,classification_title,dimensions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ChicagoArtworkDetail.self, from: data)
        let artwork = response.data.toArtwork()
        
        artworkCache[cacheKey] = artwork
        return artwork
    }
    
    func getFeaturedArtworks(museum: Museum) async throws -> [Artwork] {
        switch museum {
        case .met:
            return try await getFeaturedMetArtworks()
        case .chicago:
            return try await getFeaturedChicagoArtworks()
        case .wiki:
            return try await getFeaturedWikiArtworks()
        }
    }
    
    private func getFeaturedMetArtworks() async throws -> [Artwork] {
        // 캐시 확인
        if let cached = featuredCacheMet,
           let timestamp = cacheTimestampMet,
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
            459055  // Klimt - Mäda Primavesi
        ]
        
        let artworks = await withTaskGroup(of: Artwork?.self) { group in
            for id in featuredIDs {
                group.addTask {
                    do {
                        let artwork = try await self.getMetArtwork(objectID: id)
                        if artwork.primaryImage != nil && !artwork.primaryImage!.isEmpty {
                            return artwork
                        }
                    } catch {
                        print("Failed to load Met artwork \(id): \(error)")
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
        
        featuredCacheMet = artworks
        cacheTimestampMet = Date()
        return artworks
    }
    
    private func getFeaturedChicagoArtworks() async throws -> [Artwork] {
        // 캐시 확인
        if let cached = featuredCacheChicago,
           let timestamp = cacheTimestampChicago,
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            return cached
        }
        
        // 시카고 미술관의 유명한 작품들 ID
        let featuredIDs = [
            27992,  // A Sunday on La Grande Jatte by Seurat
            28560,  // The Bedroom by Van Gogh
            16568,  // American Gothic by Grant Wood
            111628, // Nighthawks by Edward Hopper
            16571,  // Paris Street; Rainy Day by Caillebotte
            14598,  // The Child's Bath by Mary Cassatt
            80607,  // Stacks of Wheat by Monet
            16487,  // Water Lilies by Monet
            28067,  // Self-Portrait by Van Gogh
            81558,  // The Old Guitarist by Picasso
            109275, // Greyed Rainbow by Pollock
            184372  // Untitled by Rothko
        ]
        
        let artworks = await withTaskGroup(of: Artwork?.self) { group in
            for id in featuredIDs {
                group.addTask {
                    do {
                        let artwork = try await self.getChicagoArtwork(objectID: id)
                        if artwork.primaryImage != nil && !artwork.primaryImage!.isEmpty {
                            return artwork
                        }
                    } catch {
                        print("Failed to load Chicago artwork \(id): \(error)")
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
        
        featuredCacheChicago = artworks
        cacheTimestampChicago = Date()
        return artworks
    }
    
    // MARK: - Wikipedia Methods
    func searchWikiArtworks(query: String = "famous painting") async throws -> [String] {
        var searchQuery = query.isEmpty ? "famous painting" : query.trimmingCharacters(in: .whitespaces)
        
        // 작가명으로 검색하는 경우 "paintings" 키워드 추가
        // 작품명이 아닌 것 같으면 (일반적인 작품명 키워드가 없으면) paintings 추가
        let lowerQuery = searchQuery.lowercased()
        let isArtworkTitle = lowerQuery.contains("painting") || 
                            lowerQuery.contains("artwork") ||
                            lowerQuery.contains("mona lisa") ||
                            lowerQuery.contains("starry night") ||
                            lowerQuery.contains("scream") ||
                            lowerQuery.contains("guernica") ||
                            lowerQuery.contains("last supper") ||
                            lowerQuery.contains("birth of venus") ||
                            lowerQuery.contains("sunflowers") ||
                            lowerQuery.contains("water lilies") ||
                            lowerQuery.contains("by ") // "작품명 by 작가명" 형식
        
        if !isArtworkTitle && !searchQuery.isEmpty {
            // 작가명으로 보이면 "paintings" 추가
            searchQuery = "\(searchQuery) paintings"
        }
        
        let urlString = "\(wikipediaBaseURL)?action=query&format=json&list=search&srsearch=\(searchQuery)&srnamespace=0&srlimit=50&srprop=size"
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WikipediaSearchResponse.self, from: data)
        
        // 필터링 조건 완화: 작품명, 작가명, 또는 명화 관련 키워드 포함
        let paintingTitles = response.query.search
            .filter { result in
                let title = result.title.lowercased()
                // 작품명 관련 키워드
                let hasArtworkKeyword = title.contains("painting") || 
                                       title.contains("artwork") || 
                                       title.contains("art") ||
                                       title.contains("mona lisa") ||
                                       title.contains("starry night") ||
                                       title.contains("scream") ||
                                       title.contains("guernica") ||
                                       title.contains("last supper") ||
                                       title.contains("birth of venus") ||
                                       title.contains("sunflowers") ||
                                       title.contains("water lilies") ||
                                       title.contains("by ") // "작품명 by 작가명" 형식
                
                // 작가명이 검색어에 포함되어 있고, 제목에도 포함되는 경우
                let queryWords = lowerQuery.lowercased().components(separatedBy: " ").filter { $0.count > 2 }
                let hasArtistName = queryWords.contains { word in
                    title.contains(word.lowercased())
                }
                
                // "List of paintings by" 형식의 페이지도 포함
                let isListOfPaintings = title.contains("list of paintings") || 
                                       title.contains("list of works")
                
                return hasArtworkKeyword || hasArtistName || isListOfPaintings
            }
            .map { $0.title }
        
        return Array(paintingTitles.prefix(20))
    }
    
    func getWikiArtwork(title: String) async throws -> Artwork {
        let cacheKey = "wiki_\(title)"
        if let cached = artworkCache[cacheKey] {
            return cached
        }
        
        // 페이지 정보 가져오기 (이미지 포함)
        let urlString = "\(wikipediaBaseURL)?action=query&format=json&titles=\(title)&prop=pageimages|extracts|info&pithumbsize=800&exintro=true&explaintext=true&inprop=url"
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WikipediaPageInfoResponse.self, from: data)
        
        guard let page = response.query.pages.values.first else {
            throw URLError(.badServerResponse)
        }
        
        // 제목에서 작가와 작품명 추출
        let titleParts = page.title.components(separatedBy: " by ")
        let artworkTitle = titleParts.first ?? page.title
        let artistName = titleParts.count > 1 ? titleParts.last : nil
        
        // Extract에서 날짜 추출 시도
        var dateString: String? = nil
        if let extract = page.extract {
            let datePattern = #"\b\d{4}\b"#
            if let regex = try? NSRegularExpression(pattern: datePattern),
               let match = regex.firstMatch(in: extract, range: NSRange(extract.startIndex..., in: extract)),
               let range = Range(match.range, in: extract) {
                dateString = String(extract[range])
            }
        }
        
        let artwork = Artwork(
            objectID: page.pageid,
            title: artworkTitle,
            artistDisplayName: artistName,
            objectDate: dateString,
            medium: nil,
            department: nil,
            culture: nil,
            primaryImage: page.thumbnail?.source,
            primaryImageSmall: page.thumbnail?.source,
            objectURL: page.fullurl,
            creditLine: nil,
            classification: nil,
            dimensions: nil,
            museum: .wiki
        )
        
        artworkCache[cacheKey] = artwork
        return artwork
    }
    
    private func getFeaturedWikiArtworks() async throws -> [Artwork] {
        // 캐시 확인
        if let cached = featuredCacheWiki,
           let timestamp = cacheTimestampWiki,
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            return cached
        }
        
        // 위키피디아의 유명한 명화들
        let featuredTitles = [
            "Mona Lisa",
            "The Starry Night",
            "The Scream",
            "Guernica (Picasso)",
            "The Last Supper (Leonardo da Vinci)",
            "Girl with a Pearl Earring",
            "The Birth of Venus (Botticelli)",
            "Sunflowers (Van Gogh series)",
            "Water Lilies (Monet series)",
            "The Persistence of Memory",
            "The Night Watch",
            "Las Meninas"
        ]
        
        let artworks = await withTaskGroup(of: Artwork?.self) { group in
            for title in featuredTitles {
                group.addTask {
                    do {
                        let artwork = try await self.getWikiArtwork(title: title)
                        if artwork.primaryImage != nil && !artwork.primaryImage!.isEmpty {
                            return artwork
                        }
                    } catch {
                        print("Failed to load Wiki artwork \(title): \(error)")
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
        
        featuredCacheWiki = artworks
        cacheTimestampWiki = Date()
        return artworks
    }
    
    func clearCache() {
        artworkCache.removeAll()
        featuredCacheMet = nil
        featuredCacheChicago = nil
        featuredCacheWiki = nil
        cacheTimestampMet = nil
        cacheTimestampChicago = nil
        cacheTimestampWiki = nil
    }
}

// MARK: - Art View Model
@MainActor
class ArtViewModel: ObservableObject {
    @Published var artworks: [Artwork] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreResults = false
    @Published var searchText = ""
    @Published var recentSearches: [String] = []
    @Published var selectedMuseum: Museum = .wiki
    
    private let maxRecentSearches = 10
    private let itemsPerPage = 15
    private var currentSearchIDs: [Int] = [] // Met, Chicago용
    private var currentSearchTitles: [String] = [] // Wiki용
    private var currentOffset = 0
    
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
            let results = try await ArtService.shared.getFeaturedArtworks(museum: selectedMuseum)
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
        
        // 초기화
        currentOffset = 0
        currentSearchIDs = []
        currentSearchTitles = []
        
        do {
            let museum = selectedMuseum
            let artworks: [Artwork]
            
            switch museum {
            case .met:
                let objectIDs = try await ArtService.shared.searchMetArtworks(query: searchText)
                currentSearchIDs = objectIDs
                hasMoreResults = objectIDs.count > itemsPerPage
                
                artworks = await loadArtworksFromIDs(objectIDs.prefix(itemsPerPage).map { $0 }, museum: museum)
                
            case .chicago:
                let objectIDs = try await ArtService.shared.searchChicagoArtworks(query: searchText)
                currentSearchIDs = objectIDs
                hasMoreResults = objectIDs.count > itemsPerPage
                
                artworks = await loadArtworksFromIDs(objectIDs.prefix(itemsPerPage).map { $0 }, museum: museum)
                
            case .wiki:
                let titles = try await ArtService.shared.searchWikiArtworks(query: searchText)
                currentSearchTitles = titles
                hasMoreResults = titles.count > itemsPerPage
                
                artworks = await loadArtworksFromTitles(titles.prefix(itemsPerPage).map { $0 })
            }
            
            self.artworks = artworks
            currentOffset = artworks.count
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
    
    func loadMoreArtworks() async {
        guard !isLoadingMore && hasMoreResults else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let museum = selectedMuseum
            let newArtworks: [Artwork]
            
            switch museum {
            case .met, .chicago:
                let remainingIDs = Array(currentSearchIDs.dropFirst(currentOffset))
                guard !remainingIDs.isEmpty else {
                    hasMoreResults = false
                    return
                }
                
                let idsToLoad = remainingIDs.prefix(itemsPerPage).map { $0 }
                newArtworks = await loadArtworksFromIDs(idsToLoad, museum: museum)
                
            case .wiki:
                let remainingTitles = Array(currentSearchTitles.dropFirst(currentOffset))
                guard !remainingTitles.isEmpty else {
                    hasMoreResults = false
                    return
                }
                
                let titlesToLoad = remainingTitles.prefix(itemsPerPage).map { $0 }
                newArtworks = await loadArtworksFromTitles(titlesToLoad)
            }
            
            self.artworks.append(contentsOf: newArtworks)
            currentOffset += newArtworks.count
            
            // 더 이상 로드할 항목이 없으면
            switch museum {
            case .met, .chicago:
                hasMoreResults = currentOffset < currentSearchIDs.count
            case .wiki:
                hasMoreResults = currentOffset < currentSearchTitles.count
            }
            
            // 진동 효과
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Error loading more: \(error)")
        }
    }
    
    private func loadArtworksFromIDs(_ ids: [Int], museum: Museum) async -> [Artwork] {
        return await withTaskGroup(of: Artwork?.self) { group in
            for id in ids {
                group.addTask {
                    do {
                        let artwork: Artwork
                        switch museum {
                        case .met:
                            artwork = try await ArtService.shared.getMetArtwork(objectID: id)
                        case .chicago:
                            artwork = try await ArtService.shared.getChicagoArtwork(objectID: id)
                        case .wiki:
                            return nil
                        }
                        
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
    }
    
    private func loadArtworksFromTitles(_ titles: [String]) async -> [Artwork] {
        return await withTaskGroup(of: Artwork?.self) { group in
            for title in titles {
                group.addTask {
                    do {
                        let artwork = try await ArtService.shared.getWikiArtwork(title: title)
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
    }
    
    func searchFromTag(_ query: String) async {
        searchText = query
        await searchArtworks()
    }
    
    func changeMuseum(_ museum: Museum) async {
        selectedMuseum = museum
        searchText = ""
        currentSearchIDs = []
        currentSearchTitles = []
        currentOffset = 0
        hasMoreResults = false
        await loadFeaturedArtworks()
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

// MARK: - Tag Type Enum
enum TagType {
    case popular
    case recent
}

// MARK: - Art View
struct ArtView: View {
    @StateObject private var viewModel = ArtViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTagType: TagType = .popular
    
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
                    
                    // Museum Selection Tabs
                    museumSelectionView
                    
                    // Tag Type Selection & Tags (탭으로 통합)
                    tagSectionView
                    
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
    
    private var museumSelectionView: some View {
        HStack(spacing: 12) {
            ForEach(Museum.allCases, id: \.self) { museum in
                Button(action: {
                    Task {
                        await viewModel.changeMuseum(museum)
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 16))
                            Text(museum.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        if viewModel.selectedMuseum == museum {
                            Rectangle()
                                .fill(Color.purple)
                                .frame(height: 3)
                                .cornerRadius(1.5)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .foregroundColor(viewModel.selectedMuseum == museum ? .purple : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var tagSectionView: some View {
        VStack(spacing: 0) {
            // 탭 선택 버튼
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTagType = .popular
                    }
                }) {
                    VStack(spacing: 6) {
                        Text("인기 작품 추천")
                            .font(.subheadline)
                            .fontWeight(selectedTagType == .popular ? .semibold : .regular)
                        
                        Rectangle()
                            .fill(selectedTagType == .popular ? Color.orange : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundColor(selectedTagType == .popular ? .orange : .secondary)
                    .frame(maxWidth: .infinity)
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTagType = .recent
                    }
                }) {
                    VStack(spacing: 6) {
                        Text("최근 검색어")
                            .font(.subheadline)
                            .fontWeight(selectedTagType == .recent ? .semibold : .regular)
                        
                        Rectangle()
                            .fill(selectedTagType == .recent ? Color.purple : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundColor(selectedTagType == .recent ? .purple : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(UIColor.systemGroupedBackground))
            
            // 태그 목록 (선택된 타입에 따라)
            if selectedTagType == .popular {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.selectedMuseum.popularTags, id: \.self) { tag in
                            Button(action: {
                                Task {
                                    await viewModel.searchFromTag(tag)
                                }
                            }) {
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            } else {
                if !viewModel.recentSearches.isEmpty {
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
                                .foregroundColor(.purple)
                                .cornerRadius(16)
                                .onTapGesture {
                                    Task {
                                        await viewModel.searchFromTag(search)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("최근 검색어가 없습니다")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var artworksList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.artworks) { artwork in
                    ArtworkCard(artwork: artwork)
                }
                
                // 더보기 버튼
                if viewModel.hasMoreResults {
                    Button(action: {
                        Task {
                            await viewModel.loadMoreArtworks()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("더보기")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoadingMore)
                    .padding(.horizontal)
                    .padding(.top, 8)
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
                                Text(artwork.museum.rawValue)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            
                            Text(artwork.museum.englishName)
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
