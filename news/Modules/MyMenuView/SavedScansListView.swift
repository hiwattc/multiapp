import SwiftUI
import RealityKit
import ARKit

// MARK: - Saved Scans List View
struct SavedScansListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanManager = SavedScanManager.shared
    @State private var selectedScan: SavedScanInfo?
    @State private var show3DViewer = false
    
    var body: some View {
        NavigationStack {
            List {
                if scanManager.savedScans.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("저장된 스캔이 없습니다")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("LiDAR 스캔을 저장하면 여기에 표시됩니다")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(scanManager.savedScans.sorted(by: { $0.date > $1.date })) { scan in
                        SavedScanRow(scan: scan) {
                            selectedScan = scan
                            show3DViewer = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                scanManager.deleteScan(scan)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("저장된 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedScan) { scan in
            Scan3DViewer(scanInfo: scan)
        }
    }
}

// MARK: - Saved Scan Row
struct SavedScanRow: View {
    let scan: SavedScanInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "cube.transparent.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(scan.fileName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("메시: \(scan.meshCount)개")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(scan.date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 3D Viewer
struct Scan3DViewer: View {
    @Environment(\.dismiss) private var dismiss
    let scanInfo: SavedScanInfo
    @State private var arView: ARView?
    @State private var modelEntity: ModelEntity?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 3D 뷰
                if let arView = arView {
                    Scan3DARViewContainer(arView: arView)
                        .edgesIgnoringSafeArea(.all)
                } else if let error = errorMessage {
                    // 에러 표시
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("로드 실패")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("다시 시도") {
                            errorMessage = nil
                            isLoading = true
                            loadScan()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // 로딩 중
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("스캔 로딩 중...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 컨트롤 오버레이
                VStack {
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            resetView()
                        }) {
                            VStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                Text("리셋")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            shareScan()
                        }) {
                            VStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                Text("공유")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("3D 뷰어")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadScan()
            }
        }
    }
    
    private func loadScan() {
        print("📂 스캔 로드 시작: \(scanInfo.fileName)")
        print("📂 파일 경로: \(scanInfo.fileURL.path)")
        
        // 파일 존재 확인
        guard FileManager.default.fileExists(atPath: scanInfo.fileURL.path) else {
            print("❌ 파일이 존재하지 않습니다: \(scanInfo.fileURL.path)")
            errorMessage = "파일을 찾을 수 없습니다.\n\(scanInfo.fileName)"
            isLoading = false
            return
        }
        
        // ARView 생성
        let view = ARView(frame: .zero)
        
        // AR 세션 설정 (최소한의 설정)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        view.session.run(configuration)
        
        // 백그라운드에서 USDZ 파일 로드
        Task {
            do {
                print("🔄 Entity.load 시작...")
                print("📂 파일 경로: \(scanInfo.fileURL.path)")
                
                // 파일 크기 확인
                if let attributes = try? FileManager.default.attributesOfItem(atPath: scanInfo.fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📊 파일 크기: \(fileSize) bytes")
                    if fileSize == 0 {
                        throw NSError(domain: "LiDARScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "파일이 비어있습니다"])
                    }
                }
                
                // 동기 로드를 백그라운드 스레드에서 실행
                let loadedEntity = try await Task.detached {
                    print("🔄 백그라운드에서 Entity.load 실행...")
                    print("📂 파일 URL: \(scanInfo.fileURL)")
                    
                    // Entity.load 시도
                    do {
                        let entity = try Entity.load(contentsOf: scanInfo.fileURL)
                        print("✅ Entity.load 완료, 자식 개수: \(entity.children.count)")
                        
                        // 엔티티가 비어있는지 확인
                        if entity.children.isEmpty && !(entity is ModelEntity) {
                            throw NSError(domain: "LiDARScan", code: 4, userInfo: [NSLocalizedDescriptionKey: "로드된 엔티티가 비어있습니다"])
                        }
                        
                        return entity
                    } catch {
                        print("❌ Entity.load 실패: \(error.localizedDescription)")
                        print("❌ 에러 타입: \(type(of: error))")
                        throw error
                    }
                }.value
                
                print("✅ Entity 로드 완료, 자식 개수: \(loadedEntity.children.count)")
                
                await MainActor.run {
                    // 앵커 엔티티 생성 (카메라 앞에 배치)
                    let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1.5)) // 카메라 앞 1.5m
                    anchor.addChild(loadedEntity)
                    view.scene.addAnchor(anchor)
                    
                    // 제스처 추가 (회전, 확대/축소) - ModelEntity인 경우에만
                    if let modelEntity = loadedEntity as? ModelEntity {
                        view.installGestures([.rotation, .scale], for: modelEntity)
                        print("✅ 제스처 추가: ModelEntity")
                    } else if let firstModelEntity = findFirstModelEntity(in: loadedEntity) {
                        view.installGestures([.rotation, .scale], for: firstModelEntity)
                        print("✅ 제스처 추가: 첫 번째 ModelEntity")
                    } else {
                        // 모든 자식 엔티티에 제스처 추가 시도
                        addGesturesToChildren(in: loadedEntity, arView: view)
                    }
                    
                    self.arView = view
                    self.isLoading = false
                    print("✅ 스캔 로드 완료: \(scanInfo.fileName)")
                }
            } catch {
                print("❌ 스캔 로드 실패: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "파일을 로드할 수 없습니다.\n\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func addGesturesToChildren(in entity: Entity, arView: ARView) {
        for child in entity.children {
            if let modelEntity = child as? ModelEntity {
                arView.installGestures([.rotation, .scale], for: modelEntity)
                print("✅ 제스처 추가: 자식 ModelEntity")
            } else {
                addGesturesToChildren(in: child, arView: arView)
            }
        }
    }
    
    private func findFirstModelEntity(in entity: Entity) -> ModelEntity? {
        if let modelEntity = entity as? ModelEntity {
            return modelEntity
        }
        for child in entity.children {
            if let modelEntity = findFirstModelEntity(in: child) {
                return modelEntity
            }
        }
        return nil
    }
    
    private func resetView() {
        guard let arView = arView else { return }
        
        // 모든 앵커 제거
        for anchor in arView.scene.anchors {
            arView.scene.removeAnchor(anchor)
        }
        
        // 다시 로드
        isLoading = true
        errorMessage = nil
        loadScan()
    }
    
    private func shareScan() {
        let activityVC = UIActivityViewController(
            activityItems: [scanInfo.fileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - ARView Container for 3D Viewer
struct Scan3DARViewContainer: UIViewRepresentable {
    let arView: ARView
    
    func makeUIView(context: Context) -> ARView {
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 업데이트 불필요
    }
}

