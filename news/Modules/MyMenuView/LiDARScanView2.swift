import SwiftUI
import ARKit
import RealityKit
import Combine

// ARMeshGeometry extension은 LiDARScanView.swift에 정의되어 있음

// MARK: - LiDAR Scan View 2
struct LiDARScanView2: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiDARScanViewModel2()
    
    var body: some View {
        ZStack {
            // AR View
            LiDARARViewContainer2(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // UI Overlay
            VStack {
                // Top Bar
                HStack {
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                // Center Content
                VStack(spacing: 40) {
                    // Scan Button
                    Button(action: {
                        viewModel.startScanning()
                    }) {
                        Text("스캔 시작")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 200)
                            .background(
                                Circle()
                                    .fill(viewModel.isScanning ? Color.gray : Color.blue)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                            )
                    }
                    .disabled(viewModel.isScanning)
                    .padding(.top, 60)
                    
                    // Status Text
                    if viewModel.isScanning {
                        VStack(spacing: 12) {
                            Text("스캔 중...")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text("기기를 천천히 움직여\n바닥과 벽면을 스캔하세요")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                            
                            // Progress
                            HStack(spacing: 8) {
                                Text("\(Int(viewModel.scanProgress))%")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                ProgressView(value: viewModel.scanProgress, total: 100)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                    .frame(width: 200)
                            }
                            
                            Text("메시: \(viewModel.meshCount)개")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    }
                    
                    // Complete Button
                    Button(action: {
                        viewModel.completeScan()
                    }) {
                        Text("스캔 완료")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.canComplete ? Color.blue : Color.gray)
                            )
                    }
                    .disabled(!viewModel.canComplete)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    // Save and View Buttons (스캔 완료 후 표시)
                    if viewModel.isScanComplete && !viewModel.isScanning {
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.viewDirectly()
                            }) {
                                Text("3D 보기 (저장 없음)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.orange)
                                    )
                            }
                            
                            Button(action: {
                                viewModel.saveAndView()
                            }) {
                                Text("저장 후 3D 보기")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.green)
                                    )
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.checkLiDARSupport()
        }
        .sheet(item: $viewModel.savedScanInfo) { scanInfo in
            Scan3DViewer(scanInfo: scanInfo)
        }
        .sheet(isPresented: $viewModel.showDirect3DViewer) {
            Direct3DViewer(entities: viewModel.currentScanEntities)
        }
        .alert("저장 완료", isPresented: $viewModel.showSaveSuccessAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.saveMessage)
        }
        .alert("저장 실패", isPresented: $viewModel.showSaveErrorAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.saveMessage)
        }
    }
}

// MARK: - LiDAR AR View Container 2
struct LiDARARViewContainer2: UIViewRepresentable {
    @ObservedObject var viewModel: LiDARScanViewModel2
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 구성 - LiDAR 지원 (정확도 향상)
        let configuration = ARWorldTrackingConfiguration()
        
        // Scene Reconstruction 활성화 (LiDAR 필수)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            print("✅ Scene Reconstruction 활성화됨")
        } else {
            print("⚠️ Scene Reconstruction을 지원하지 않습니다 (LiDAR 필요)")
        }
        
        // 평면 감지 활성화 (바닥과 벽면 감지)
        configuration.planeDetection = [.horizontal, .vertical]
        
        // 환경 텍스처링 (더 나은 추적)
        configuration.environmentTexturing = .automatic
        
        // Scene Depth 활성화 (더 정확한 깊이 정보)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            print("✅ Scene Depth 활성화됨")
        }
        
        // 사람 옵컬션 (더 정확한 메시)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        arView.session.run(configuration)
        
        // 세션 델리게이트 설정
        arView.session.delegate = context.coordinator
        
        // ViewModel에 ARView 설정
        viewModel.setARView(arView)
        
        // 코디네이터 설정
        context.coordinator.arView = arView
        context.coordinator.viewModel = viewModel
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 메시 시각화 업데이트
        viewModel.updateMeshVisualization(in: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        weak var viewModel: LiDARScanViewModel2?
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    viewModel.addMeshAnchor(meshAnchor)
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    viewModel.updateMeshAnchor(meshAnchor)
                }
            }
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    viewModel.removeMeshAnchor(meshAnchor)
                }
            }
        }
    }
}

// MARK: - LiDAR Scan View Model 2
class LiDARScanViewModel2: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var canComplete: Bool = false
    @Published var isScanComplete: Bool = false
    @Published var meshCount: Int = 0
    @Published var totalVertices: Int = 0
    @Published var savedScanInfo: SavedScanInfo?
    @Published var showSaveSuccessAlert: Bool = false
    @Published var showSaveErrorAlert: Bool = false
    @Published var saveMessage: String = ""
    @Published var showDirect3DViewer: Bool = false
    
    weak var arView: ARView?
    private var meshAnchors: [UUID: ARMeshAnchor] = [:]
    private var meshEntities: [UUID: ModelEntity] = [:]
    private var anchorEntities: [UUID: AnchorEntity] = [:]
    var currentScanEntities: [Entity] = [] // 직접 3D 뷰어용
    private var scanStartTime: Date?
    private var scanTimer: Timer?
    private let scanDuration: TimeInterval = 20.0 // 20초 스캔 (더 정확한 스캔을 위해)
    
    func setARView(_ view: ARView) {
        self.arView = view
    }
    
    func checkLiDARSupport() {
        if !ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            print("❌ LiDAR를 지원하지 않는 기기입니다")
        }
    }
    
    func startScanning() {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = 0
        canComplete = false
        scanStartTime = Date()
        
        // 기존 메시 제거
        clearAllMeshes()
        meshAnchors.removeAll()
        meshCount = 0
        totalVertices = 0
        
        // 진행률 업데이트 타이머
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let startTime = self.scanStartTime else {
                timer.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            self.scanProgress = min((elapsed / self.scanDuration) * 100, 100)
            
            // 스캔 시간이 지나면 완료 가능
            if elapsed >= self.scanDuration {
                self.canComplete = true
                timer.invalidate()
            }
        }
        
        print("📡 스캔 시작")
    }
    
    func completeScan() {
        guard isScanning else { return }
        
        scanTimer?.invalidate()
        scanTimer = nil
        
        isScanning = false
        canComplete = false
        isScanComplete = true
        
        // 메시 표시
        updateMeshVisualization()
        
        print("✅ 스캔 완료: \(meshCount)개 메시, \(totalVertices)개 정점")
    }
    
    func saveAndView() {
        guard !meshEntities.isEmpty else {
            saveMessage = "저장할 메시가 없습니다."
            showSaveErrorAlert = true
            return
        }
        
        print("💾 스캔 저장 및 3D 보기 시작: \(meshEntities.count)개 메시")
        
        // 저장 작업
        Task { @MainActor [weak self] in
            guard let self = self, let arView = self.arView else { return }
            
            do {
                // 모든 메시를 하나의 루트 엔티티로 합치기
                let rootEntity = Entity()
                rootEntity.name = "LiDAR_Scan_Root"
                
                // 메시 엔티티를 직접 복제하여 추가 (더 안정적)
                for (id, meshEntity) in meshEntities {
                    // 메시와 재질을 새로 생성하여 추가
                    if let model = meshEntity.model {
                        let newMesh = model.mesh
                        let newMaterials = model.materials
                        let newModelEntity = ModelEntity(mesh: newMesh, materials: newMaterials)
                        rootEntity.addChild(newModelEntity)
                        print("📦 메시 추가: \(id)")
                    }
                }
                
                guard rootEntity.children.count > 0 else {
                    throw NSError(domain: "LiDARScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "저장할 메시가 없습니다"])
                }
                
                print("💾 \(rootEntity.children.count)개 메시를 USDZ로 저장 중...")
                
                // USDZ 파일로 저장
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "LiDAR_Scan2_\(timestamp).usdz"
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // 앵커 엔티티 생성하여 모든 메시 포함
                let anchorEntity = AnchorEntity()
                anchorEntity.addChild(rootEntity)
                
                // ARView의 씬에 임시로 추가
                arView.scene.addAnchor(anchorEntity)
                
                // 루트 엔티티를 USDZ로 저장
                try await rootEntity.write(to: fileURL)
                
                // 임시 앵커 제거
                arView.scene.removeAnchor(anchorEntity)
                
                // 파일 저장 확인
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    throw NSError(domain: "LiDARScan", code: 2, userInfo: [NSLocalizedDescriptionKey: "파일이 저장되지 않았습니다"])
                }
                
                // 파일 크기 확인
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📊 저장된 파일 크기: \(fileSize) bytes")
                    
                    if fileSize == 0 {
                        throw NSError(domain: "LiDARScan", code: 3, userInfo: [NSLocalizedDescriptionKey: "저장된 파일이 비어있습니다"])
                    }
                }
                
                // 저장된 파일 검증: 로드 테스트
                print("🔍 저장된 파일 검증 중...")
                let testEntity = try Entity.load(contentsOf: fileURL)
                print("✅ 파일 검증 완료: \(testEntity.children.count)개 자식")
                
                // 스캔 정보 저장
                let scanInfo = SavedScanInfo(
                    id: UUID(),
                    fileName: fileName,
                    fileURL: fileURL,
                    date: Date(),
                    meshCount: self.meshCount
                )
                
                SavedScanManager.shared.saveScanInfo(scanInfo)
                
                self.saveMessage = "스캔이 저장되었습니다: \(fileName)"
                self.showSaveSuccessAlert = true
                
                print("✅ 스캔 저장 완료: \(fileURL.path)")
                
                // 저장 완료 후 바로 3D 뷰어 표시
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.savedScanInfo = scanInfo
                }
                
            } catch {
                // 임시 앵커 제거 (에러 발생 시) - 모든 앵커 확인
                for anchor in arView.scene.anchors {
                    if anchor.children.count > 0 {
                        arView.scene.removeAnchor(anchor)
                        break
                    }
                }
                
                self.saveMessage = "저장 실패: \(error.localizedDescription)"
                self.showSaveErrorAlert = true
                print("❌ 스캔 저장 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // 저장 없이 바로 3D 뷰어로 전달
    func viewDirectly() {
        guard !meshEntities.isEmpty else {
            saveMessage = "표시할 메시가 없습니다."
            showSaveErrorAlert = true
            return
        }
        
        print("👁️ 직접 3D 뷰어 표시: \(meshEntities.count)개 메시")
        
        // 모든 메시 엔티티를 복제하여 저장
        currentScanEntities = meshEntities.values.map { entity in
            entity.clone(recursive: true)
        }
        
        showDirect3DViewer = true
    }
    
    func addMeshAnchor(_ anchor: ARMeshAnchor) {
        guard isScanning else { return }
        
        // 메시 품질 검증: 너무 작은 메시는 제외
        let vertexCount = anchor.geometry.vertices.count
        let faceCount = anchor.geometry.faces.count
        
        // 최소 크기 검증 (너무 작은 조각 제외)
        if vertexCount < 10 || faceCount < 5 {
            print("⚠️ 너무 작은 메시 제외: \(vertexCount)개 정점, \(faceCount)개 면")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.meshAnchors[anchor.identifier] = anchor
            self.meshCount = self.meshAnchors.count
            self.updateTotalVertices()
            print("✅ 메시 추가: \(vertexCount)개 정점, \(faceCount)개 면")
        }
    }
    
    func updateMeshAnchor(_ anchor: ARMeshAnchor) {
        guard isScanning else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.meshAnchors[anchor.identifier] = anchor
            self.updateTotalVertices()
        }
    }
    
    func removeMeshAnchor(_ anchor: ARMeshAnchor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.meshAnchors.removeValue(forKey: anchor.identifier)
            
            if let anchorEntity = self.anchorEntities.removeValue(forKey: anchor.identifier),
               let arView = self.arView {
                arView.scene.removeAnchor(anchorEntity)
            }
            
            self.meshEntities.removeValue(forKey: anchor.identifier)
            self.meshCount = self.meshAnchors.count
            self.updateTotalVertices()
        }
    }
    
    private func updateTotalVertices() {
        totalVertices = meshAnchors.values.reduce(0) { $0 + $1.geometry.vertices.count }
    }
    
    func updateMeshVisualization(in arView: ARView) {
        self.arView = arView
        if !isScanning {
            updateMeshVisualization()
        }
    }
    
    private func updateMeshVisualization() {
        guard let arView = arView else { return }
        
        // 점진적으로 메시 생성
        let anchorsToCreate = meshAnchors.filter { id, _ in
            meshEntities[id] == nil
        }
        
        guard !anchorsToCreate.isEmpty else { return }
        
        let batchSize = 5
        let anchorsBatch = Array(anchorsToCreate.prefix(batchSize))
        
        for (id, anchor) in anchorsBatch {
            createMeshEntity(from: anchor, in: arView)
        }
        
        // 나머지는 점진적으로 생성
        if anchorsToCreate.count > batchSize {
            let remainingAnchors = Array(anchorsToCreate.dropFirst(batchSize))
            scheduleProgressiveMeshCreation(remainingAnchors, in: arView)
        }
    }
    
    private func scheduleProgressiveMeshCreation(_ anchors: [(UUID, ARMeshAnchor)], in arView: ARView) {
        let batchSize = 3
        var currentIndex = 0
        
        func createNextBatch() {
            guard currentIndex < anchors.count else { return }
            
            let endIndex = min(currentIndex + batchSize, anchors.count)
            let batch = Array(anchors[currentIndex..<endIndex])
            
            for (id, anchor) in batch {
                createMeshEntity(from: anchor, in: arView)
            }
            
            currentIndex = endIndex
            
            if currentIndex < anchors.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    createNextBatch()
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            createNextBatch()
        }
    }
    
    private func createMeshEntity(from anchor: ARMeshAnchor, in arView: ARView) {
        do {
            let meshGeometry = anchor.geometry
            
            // 메시 품질 검증 강화
            let vertexCount = meshGeometry.vertices.count
            let faceCount = meshGeometry.faces.count
            
            // 최소 크기 검증 (너무 작은 조각 제외)
            guard vertexCount >= 20,
                  faceCount >= 10,
                  vertexCount <= 50000 else {
                print("⚠️ 메시 품질 부족: \(vertexCount)개 정점, \(faceCount)개 면 - 제외")
                return
            }
            
            // 메시 크기 검증 (너무 작은 공간은 제외)
            let meshBounds = calculateMeshBounds(geometry: meshGeometry)
            let meshVolume = meshBounds.width * meshBounds.height * meshBounds.depth
            
            // 최소 볼륨 검증 (0.01m³ 이상)
            if meshVolume < 0.01 {
                print("⚠️ 메시가 너무 작음 (볼륨: \(meshVolume)) - 제외")
                return
            }
            
            let meshResource = try createMeshResource(from: meshGeometry)
            
            let material = SimpleMaterial(
                color: .blue.withAlphaComponent(0.8),
                isMetallic: false
            )
            
            let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
            
            let anchorEntity = AnchorEntity(anchor: anchor)
            anchorEntity.addChild(modelEntity)
            arView.scene.addAnchor(anchorEntity)
            
            meshEntities[anchor.identifier] = modelEntity
            anchorEntities[anchor.identifier] = anchorEntity
            
        } catch {
            print("❌ 메시 엔티티 생성 실패: \(error.localizedDescription)")
        }
    }
    
    private func createMeshResource(from geometry: ARMeshGeometry) throws -> MeshResource {
        var meshDescriptor = MeshDescriptor(name: "lidar_mesh")
        
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount)
        
        for i in 0..<vertexCount {
            let vertex = geometry.vertex(at: UInt32(i))
            positions.append(vertex)
        }
        
        guard !positions.isEmpty else {
            throw NSError(domain: "LiDARScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "정점 데이터가 비어있습니다"])
        }
        
        meshDescriptor.positions = MeshBuffer(positions)
        
        let faces = geometry.faces
        let indexCount = faces.count
        var indices: [UInt32] = []
        indices.reserveCapacity(indexCount)
        
        let indexBuffer = faces.buffer.contents()
        let indexStride = faces.bytesPerIndex
        
        for i in 0..<indexCount {
            let indexPointer = indexBuffer.advanced(by: indexStride * Int(i))
            let indexValue: UInt32
            
            if indexStride == 2 {
                let index16 = indexPointer.assumingMemoryBound(to: UInt16.self).pointee
                indexValue = UInt32(index16)
            } else {
                indexValue = indexPointer.assumingMemoryBound(to: UInt32.self).pointee
            }
            
            if indexValue < UInt32(vertexCount) {
                indices.append(indexValue)
            }
        }
        
        guard !indices.isEmpty && indices.count >= 3 else {
            throw NSError(domain: "LiDARScan", code: 2, userInfo: [NSLocalizedDescriptionKey: "인덱스 데이터가 부족합니다"])
        }
        
        var validIndices = indices
        if indices.count % 3 != 0 {
            let remainder = indices.count % 3
            validIndices = Array(indices.dropLast(remainder))
        }
        
        guard !validIndices.isEmpty && validIndices.count >= 3 else {
            throw NSError(domain: "LiDARScan", code: 3, userInfo: [NSLocalizedDescriptionKey: "유효한 인덱스가 부족합니다"])
        }
        
        meshDescriptor.primitives = .triangles(validIndices)
        
        let normals = geometry.normals
        if normals.count > 0 && normals.count == vertexCount {
            var normalVectors: [SIMD3<Float>] = []
            normalVectors.reserveCapacity(vertexCount)
            
            for i in 0..<vertexCount {
                let normal = geometry.normal(at: UInt32(i))
                normalVectors.append(normal)
            }
            meshDescriptor.normals = MeshBuffer(normalVectors)
        }
        
        return try MeshResource.generate(from: [meshDescriptor])
    }
    
    // 메시 경계 계산
    private func calculateMeshBounds(geometry: ARMeshGeometry) -> (width: Float, height: Float, depth: Float) {
        let vertices = geometry.vertices
        guard vertices.count > 0 else {
            return (0, 0, 0)
        }
        
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        for i in 0..<vertices.count {
            let vertex = geometry.vertex(at: UInt32(i))
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
            minZ = min(minZ, vertex.z)
            maxZ = max(maxZ, vertex.z)
        }
        
        let width = maxX - minX
        let height = maxY - minY
        let depth = maxZ - minZ
        
        return (width, height, depth)
    }
    
    private func clearAllMeshes() {
        guard let arView = arView else { return }
        
        for (_, anchorEntity) in anchorEntities {
            arView.scene.removeAnchor(anchorEntity)
        }
        
        meshEntities.removeAll()
        anchorEntities.removeAll()
    }
}


