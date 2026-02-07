import Foundation
import SwiftUI
import Combine

// MARK: - Saved Scan Info
struct SavedScanInfo: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let fileURL: URL
    let date: Date
    let meshCount: Int
}

// MARK: - Saved Scan Manager
class SavedScanManager: ObservableObject {
    static let shared = SavedScanManager()
    
    @Published var savedScans: [SavedScanInfo] = []
    
    private let scansKey = "SavedLiDARScans"
    private let documentsPath: URL
    
    private init() {
        documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        loadSavedScans()
    }
    
    func saveScanInfo(_ scanInfo: SavedScanInfo) {
        savedScans.append(scanInfo)
        saveToDisk()
    }
    
    func deleteScan(_ scanInfo: SavedScanInfo) {
        // 파일 삭제
        try? FileManager.default.removeItem(at: scanInfo.fileURL)
        
        // 목록에서 제거
        savedScans.removeAll { $0.id == scanInfo.id }
        saveToDisk()
    }
    
    private func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(savedScans) {
            UserDefaults.standard.set(encoded, forKey: scansKey)
        }
    }
    
    private func loadSavedScans() {
        // 안전하게 데이터 로드
        guard let data = UserDefaults.standard.object(forKey: scansKey) as? Data else {
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([SavedScanInfo].self, from: data)
            // 파일이 실제로 존재하는지 확인
            savedScans = decoded.filter { 
                // URL이 유효한지 확인
                if $0.fileURL.path.isEmpty {
                    return false
                }
                return FileManager.default.fileExists(atPath: $0.fileURL.path)
            }
        } catch {
            print("❌ 저장된 스캔 로드 실패: \(error.localizedDescription)")
            // 잘못된 데이터는 제거
            UserDefaults.standard.removeObject(forKey: scansKey)
            savedScans = []
        }
    }
}

