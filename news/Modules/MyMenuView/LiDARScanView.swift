import SwiftUI
import ARKit
import RealityKit
import Combine
import UniformTypeIdentifiers
import MetalKit
import ModelIO

// MARK: - LiDAR Scan View
struct LiDARScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiDARScanViewModel()
    
    var body: some View {
        ZStack {
            // AR View
            LiDARARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // UI Overlay
            VStack {
                // Top Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("LiDAR 공간 스캐닝")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                        
                        Text("메시: \(viewModel.meshCount)개")
                            .font(.headline)
                            .foregroundColor(.cyan)
                            .shadow(color: .black, radius: 2)
                        
                        Text("정점: \(viewModel.totalVertices)개")
                            .font(.caption)
                            .foregroundColor(.cyan)
                            .shadow(color: .black, radius: 2)
                        
                        Text("상태: \(viewModel.scanStatus)")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 2)
                    }
                    .padding()
                    
                    Button(action: {
                        viewModel.resetScan()
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.3))
                
                Spacer()
                
                // Control Panel
                VStack(spacing: 16) {
                    // Toggle Buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.toggleMeshVisualization()
                        }) {
                            VStack {
                                Image(systemName: viewModel.showMesh ? "eye.fill" : "eye.slash.fill")
                                    .font(.title2)
                                Text(viewModel.showMesh ? "메시 표시" : "메시 숨김")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(viewModel.showMesh ? Color.cyan.opacity(0.7) : Color.gray.opacity(0.5))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.toggleWireframe()
                        }) {
                            VStack {
                                Image(systemName: viewModel.showWireframe ? "grid" : "grid.circle")
                                    .font(.title2)
                                Text(viewModel.showWireframe ? "와이어프레임" : "솔리드")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(viewModel.showWireframe ? Color.cyan.opacity(0.7) : Color.gray.opacity(0.5))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.saveScan()
                        }) {
                            VStack {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title2)
                                Text("저장")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green.opacity(0.7))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.showSavedScans = true
                        }) {
                            VStack {
                                Image(systemName: "folder.fill")
                                    .font(.title2)
                                Text("저장된 스캔")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.createTestCube()
                        }) {
                            VStack {
                                Image(systemName: "cube.fill")
                                    .font(.title2)
                                Text("테스트")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange.opacity(0.7))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Instructions
                    VStack(spacing: 8) {
                        Text("📡 LiDAR로 주변 공간을 스캔합니다")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        
                        Text("기기를 천천히 움직여 공간을 스캔하세요")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.checkLiDARSupport()
        }
        .sheet(isPresented: $viewModel.showSavedScans) {
            SavedScansListView()
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

// MARK: - LiDAR AR View Container
struct LiDARARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: LiDARScanViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 구성 - LiDAR 지원
        let configuration = ARWorldTrackingConfiguration()
        
        // Scene Reconstruction 활성화 (LiDAR 필수)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            print("✅ Scene Reconstruction 활성화됨")
        } else {
            print("⚠️ Scene Reconstruction을 지원하지 않습니다 (LiDAR 필요)")
        }
        
        // 평면 감지 활성화
        configuration.planeDetection = [.horizontal, .vertical]
        
        // 환경 텍스처링
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            print("✅ Scene Depth 활성화됨")
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
        weak var viewModel: LiDARScanViewModel?
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    print("📐 메시 앵커 추가됨: \(meshAnchor.geometry.vertices.count)개 정점, \(meshAnchor.geometry.faces.count)개 인덱스")
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
                    print("🗑️ 메시 앵커 제거됨")
                }
            }
        }
    }
}

// MARK: - LiDAR Scan View Model
class LiDARScanViewModel: ObservableObject {
    @Published var meshCount: Int = 0
    @Published var totalVertices: Int = 0
    @Published var scanStatus: String = "준비 중..."
    @Published var showMesh: Bool = true
    @Published var showWireframe: Bool = false
    @Published var showSavedScans: Bool = false
    @Published var showSaveSuccessAlert: Bool = false
    @Published var showSaveErrorAlert: Bool = false
    @Published var saveMessage: String = ""
    
    weak var arView: ARView?
    private var meshAnchors: [UUID: ARMeshAnchor] = [:]
    private var meshEntities: [UUID: ModelEntity] = [:]
    private var anchorEntities: [UUID: AnchorEntity] = [:]
    private var isLiDARSupported: Bool = false
    
    // 성능 최적화를 위한 변수들
    private var lastUpdateTime: Date = Date()
    private let updateInterval: TimeInterval = 0.1 // 100ms마다 한 번만 업데이트
    private var pendingUpdates: Set<UUID> = []
    private var isUpdating = false
    private let maxMeshCount = 50 // 최대 메시 개수 제한
    
    func setARView(_ view: ARView) {
        self.arView = view
        print("🔧 ARView 설정됨")
    }
    
    func checkLiDARSupport() {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            isLiDARSupported = true
            scanStatus = "스캔 중..."
            print("✅ LiDAR 지원 확인됨")
        } else {
            isLiDARSupported = false
            scanStatus = "LiDAR 미지원"
            print("❌ LiDAR를 지원하지 않는 기기입니다")
        }
    }
    
    func addMeshAnchor(_ anchor: ARMeshAnchor) {
        // 메시 개수 제한
        guard meshAnchors.count < maxMeshCount else {
            print("⚠️ 최대 메시 개수 제한에 도달했습니다: \(maxMeshCount)")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.meshAnchors[anchor.identifier] = anchor
            self.meshCount = self.meshAnchors.count
            self.updateTotalVertices()
            self.scheduleMeshUpdate(for: anchor.identifier)
        }
    }
    
    private func updateTotalVertices() {
        totalVertices = meshAnchors.values.reduce(0) { $0 + $1.geometry.vertices.count }
    }
    
    func updateMeshAnchor(_ anchor: ARMeshAnchor) {
        // 메시 업데이트를 throttle하여 성능 최적화
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.meshAnchors[anchor.identifier] = anchor
            self.updateTotalVertices()
            // 업데이트는 스케줄링만 하고 즉시 실행하지 않음
            self.scheduleMeshUpdate(for: anchor.identifier)
        }
    }
    
    // 메시 업데이트를 스케줄링 (throttle)
    private func scheduleMeshUpdate(for id: UUID) {
        pendingUpdates.insert(id)
        
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // 업데이트 간격이 지났고, 현재 업데이트 중이 아니면 실행
        if timeSinceLastUpdate >= updateInterval && !isUpdating {
            performPendingUpdates()
        } else if !isUpdating {
            // 다음 업데이트 예약
            DispatchQueue.main.asyncAfter(deadline: .now() + updateInterval) { [weak self] in
                self?.performPendingUpdates()
            }
        }
    }
    
    // 대기 중인 업데이트 수행
    private func performPendingUpdates() {
        guard !isUpdating, !pendingUpdates.isEmpty, let arView = arView else { return }
        
        isUpdating = true
        lastUpdateTime = Date()
        
        // 백그라운드에서 메시 생성
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let updatesToProcess = self.pendingUpdates
            self.pendingUpdates.removeAll()
            
            // 업데이트할 메시들 처리
            for id in updatesToProcess {
                guard let anchor = self.meshAnchors[id] else { continue }
                
                // 기존 메시가 없으면 생성
                if self.meshEntities[id] == nil {
                    DispatchQueue.main.async {
                        self.createMeshEntity(from: anchor, in: arView)
                    }
                }
                // 기존 메시가 있으면 업데이트는 건너뛰기 (성능 최적화)
                // 메시가 크게 변경되지 않으면 업데이트하지 않음
            }
            
            DispatchQueue.main.async {
                self.isUpdating = false
            }
        }
    }
    
    func removeMeshAnchor(_ anchor: ARMeshAnchor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.meshAnchors.removeValue(forKey: anchor.identifier)
            
            // 메시 엔티티 및 앵커 엔티티 제거
            if let anchorEntity = self.anchorEntities.removeValue(forKey: anchor.identifier),
               let arView = self.arView {
                arView.scene.removeAnchor(anchorEntity)
            }
            
            self.meshEntities.removeValue(forKey: anchor.identifier)
            self.meshCount = self.meshAnchors.count
        }
    }
    
    func updateMeshVisualization() {
        guard showMesh, let arView = arView else {
            // 메시 숨기기
            hideAllMeshes()
            return
        }
        
        // 성능 최적화: 점진적으로 메시 생성 (한 번에 모두 생성하지 않음)
        let anchorsToCreate = meshAnchors.filter { id, _ in
            meshEntities[id] == nil
        }
        
        guard !anchorsToCreate.isEmpty else { return }
        
        // 한 번에 생성할 메시 개수 제한 (점진적 생성)
        let batchSize = 5
        let anchorsBatch = Array(anchorsToCreate.prefix(batchSize))
        
        // 첫 번째 배치 즉시 생성
        for (id, anchor) in anchorsBatch {
            createMeshEntity(from: anchor, in: arView)
        }
        
        // 나머지는 점진적으로 생성
        if anchorsToCreate.count > batchSize {
            let remainingAnchors = Array(anchorsToCreate.dropFirst(batchSize))
            scheduleProgressiveMeshCreation(remainingAnchors, in: arView)
        }
    }
    
    // 점진적 메시 생성 스케줄링
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
            
            // 다음 배치를 약간의 지연 후 생성 (메인 스레드 부하 방지)
            if currentIndex < anchors.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    createNextBatch()
                }
            }
        }
        
        // 첫 번째 배치 후 다음 배치 스케줄링
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            createNextBatch()
        }
    }
    
    func updateMeshVisualization(in arView: ARView) {
        self.arView = arView
        updateMeshVisualization()
    }
    
    private func createMeshEntity(from anchor: ARMeshAnchor, in arView: ARView) {
        do {
            let meshGeometry = anchor.geometry
            
            // 메시 데이터 검증
            guard meshGeometry.vertices.count > 0 else {
                print("⚠️ 메시 정점이 없습니다")
                return
            }
            
            guard meshGeometry.faces.count > 0 else {
                print("⚠️ 메시 면이 없습니다")
                return
            }
            
            // 최소 인덱스 개수 검증 (삼각형을 만들려면 최소 3개 필요)
            if meshGeometry.faces.count < 3 {
                print("⚠️ 인덱스가 너무 적습니다 (\(meshGeometry.faces.count)개), 건너뜁니다")
                return
            }
            
            // 성능 최적화: 너무 큰 메시는 건너뛰기
            if meshGeometry.vertices.count > 50000 {
                print("⚠️ 메시가 너무 큽니다 (\(meshGeometry.vertices.count)개 정점), 건너뜁니다")
                return
            }
            
            print("🔧 메시 생성 시작: \(meshGeometry.vertices.count)개 정점, \(meshGeometry.faces.count)개 인덱스")
            
            // 간단한 테스트: 복잡한 메시 대신 간단한 박스로 대체 (테스트용)
            let useSimpleBox = false // true로 변경하면 간단한 박스 사용
            
            let modelEntity: ModelEntity
            if useSimpleBox {
                // 간단한 테스트 박스 생성
                let boxMesh = MeshResource.generateBox(size: 0.1)
                let material = SimpleMaterial(
                    color: .cyan.withAlphaComponent(0.8),
                    isMetallic: false
                )
                modelEntity = ModelEntity(mesh: boxMesh, materials: [material])
                print("📦 간단한 테스트 박스 생성")
            } else {
                // 실제 메시 리소스 생성
                let meshResource = try createMeshResource(from: meshGeometry)
                
                // 재질 생성 - 파란색
                let material: RealityKit.Material
                if showWireframe {
                    // 와이어프레임 모드
                    material = SimpleMaterial(
                        color: .blue.withAlphaComponent(0.9), // 파란색
                        isMetallic: false
                    )
                } else {
                    // 솔리드 모드 - 파란색
                    material = SimpleMaterial(
                        color: .blue.withAlphaComponent(0.8), // 파란색
                        isMetallic: false
                    )
                }
                
                modelEntity = ModelEntity(mesh: meshResource, materials: [material])
            }
            
            // 앵커 엔티티 생성 및 추가
            let anchorEntity = AnchorEntity(anchor: anchor)
            anchorEntity.addChild(modelEntity)
            arView.scene.addAnchor(anchorEntity)
            
            meshEntities[anchor.identifier] = modelEntity
            anchorEntities[anchor.identifier] = anchorEntity
            
            print("✅ 메시 엔티티 생성 완료: \(meshGeometry.vertices.count)개 정점, \(meshGeometry.faces.count)개 인덱스, 앵커 ID: \(anchor.identifier)")
            print("📍 앵커 위치: \(anchor.transform.columns.3)")
            print("🎨 메시 색상: \(showWireframe ? "와이어프레임" : "솔리드")")
        } catch {
            print("❌ 메시 엔티티 생성 실패: \(error.localizedDescription)")
            print("❌ 상세 오류: \(error)")
        }
    }
    
    // 테스트용 큐브 생성
    func createTestCube() {
        guard let arView = arView else {
            print("❌ ARView가 설정되지 않았습니다")
            return
        }
        
        print("🧪 테스트 큐브 생성")
        
        // 간단한 큐브 생성
        let boxMesh = MeshResource.generateBox(size: 0.2)
        let material = SimpleMaterial(
            color: .orange.withAlphaComponent(0.8),
            isMetallic: false
        )
        let testCube = ModelEntity(mesh: boxMesh, materials: [material])
        
        // 카메라 앞에 배치
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1))
        anchor.addChild(testCube)
        arView.scene.addAnchor(anchor)
        
        // 제스처 추가
        arView.installGestures([.rotation, .scale], for: testCube)
        
        print("✅ 테스트 큐브 생성 완료 (카메라 앞 1m)")
        scanStatus = "테스트 큐브 표시됨"
    }
    
    private func updateMeshEntity(id: UUID, from anchor: ARMeshAnchor, in arView: ARView) {
        // 성능 최적화: 메시 업데이트는 건너뛰고 새 메시만 생성
        // 기존 메시가 있으면 업데이트하지 않음 (메시가 크게 변경되지 않으면)
        if meshEntities[id] != nil {
            return
        }
        
        // 새로 생성
        createMeshEntity(from: anchor, in: arView)
    }
    
    private func createMeshResource(from geometry: ARMeshGeometry) throws -> MeshResource {
        var meshDescriptor = MeshDescriptor(name: "lidar_mesh")
        
        // 정점 데이터
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount)
        
        print("📊 정점 읽기 시작: \(vertexCount)개")
        for i in 0..<vertexCount {
            let vertex = geometry.vertex(at: UInt32(i))
            positions.append(vertex)
        }
        
        guard !positions.isEmpty else {
            throw NSError(domain: "LiDARScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "정점 데이터가 비어있습니다"])
        }
        
        meshDescriptor.positions = MeshBuffer(positions)
        print("✅ 정점 데이터 설정 완료: \(positions.count)개")
        
        // 인덱스 데이터 (면)
        let faces = geometry.faces
        let indexCount = faces.count
        var indices: [UInt32] = []
        indices.reserveCapacity(indexCount)
        
        print("📊 인덱스 읽기 시작: \(indexCount)개, bytesPerIndex: \(faces.bytesPerIndex)")
        
        // faces 버퍼에서 인덱스 읽기
        let indexBuffer = faces.buffer.contents()
        let indexStride = faces.bytesPerIndex
        
        // 삼각형 인덱스 읽기
        for i in 0..<indexCount {
            let indexPointer = indexBuffer.advanced(by: indexStride * Int(i))
            let indexValue: UInt32
            
            if indexStride == 2 {
                // 16비트 인덱스
                let index16 = indexPointer.assumingMemoryBound(to: UInt16.self).pointee
                indexValue = UInt32(index16)
            } else {
                // 32비트 인덱스
                indexValue = indexPointer.assumingMemoryBound(to: UInt32.self).pointee
            }
            
            // 인덱스 범위 검증
            if indexValue < UInt32(vertexCount) {
                indices.append(indexValue)
            } else {
                print("⚠️ 인덱스 범위 초과: \(indexValue) >= \(vertexCount)")
            }
        }
        
        guard !indices.isEmpty else {
            throw NSError(domain: "LiDARScan", code: 2, userInfo: [NSLocalizedDescriptionKey: "인덱스 데이터가 비어있습니다"])
        }
        
        // 최소 인덱스 개수 검증 (삼각형을 만들려면 최소 3개 필요)
        guard indices.count >= 3 else {
            throw NSError(domain: "LiDARScan", code: 3, userInfo: [NSLocalizedDescriptionKey: "인덱스가 너무 적습니다 (최소 3개 필요): \(indices.count)"])
        }
        
        // 인덱스가 3의 배수가 아니면 가장 가까운 3의 배수로 조정
        var validIndices = indices
        if indices.count % 3 != 0 {
            print("⚠️ 인덱스 개수가 3의 배수가 아닙니다: \(indices.count), 조정합니다")
            // 나머지를 제거하여 3의 배수로 만듦
            let remainder = indices.count % 3
            validIndices = Array(indices.dropLast(remainder))
            print("✅ 인덱스 조정 완료: \(validIndices.count)개")
        }
        
        guard !validIndices.isEmpty && validIndices.count >= 3 else {
            throw NSError(domain: "LiDARScan", code: 4, userInfo: [NSLocalizedDescriptionKey: "유효한 인덱스가 부족합니다"])
        }
        
        meshDescriptor.primitives = .triangles(validIndices)
        print("✅ 인덱스 데이터 설정 완료: \(indices.count)개")
        
        // 법선 벡터 (옵션)
        let normals = geometry.normals
        if normals.count > 0 && normals.count == vertexCount {
            var normalVectors: [SIMD3<Float>] = []
            normalVectors.reserveCapacity(vertexCount)
            
            for i in 0..<vertexCount {
                let normal = geometry.normal(at: UInt32(i))
                normalVectors.append(normal)
            }
            meshDescriptor.normals = MeshBuffer(normalVectors)
            print("✅ 법선 벡터 설정 완료: \(normalVectors.count)개")
        } else {
            print("⚠️ 법선 벡터 없음 또는 개수 불일치")
        }
        
        let meshResource = try MeshResource.generate(from: [meshDescriptor])
        print("✅ MeshResource 생성 완료")
        return meshResource
    }
    
    private func hideAllMeshes() {
        guard let arView = arView else { return }
        
        // 성능 최적화: 백그라운드에서 앵커 제거
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let anchorsToRemove = Array(self.anchorEntities.values)
            
            DispatchQueue.main.async {
                // 앵커 제거는 메인 스레드에서
                for anchorEntity in anchorsToRemove {
                    arView.scene.removeAnchor(anchorEntity)
                }
                
                // 엔티티 참조만 제거 (나중에 다시 표시할 때 재사용 가능하도록)
                // meshEntities와 anchorEntities는 유지하지 않고 완전히 제거
                self.meshEntities.removeAll()
                self.anchorEntities.removeAll()
            }
        }
    }
    
    func toggleMeshVisualization() {
        showMesh.toggle()
        
        // 메시를 숨길 때는 즉시 실행
        if !showMesh {
            hideAllMeshes()
        } else {
            // 메시를 표시할 때는 약간의 지연 후 점진적으로 생성
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateMeshVisualization()
            }
        }
    }
    
    func toggleWireframe() {
        showWireframe.toggle()
        updateMeshVisualization()
    }
    
    func resetScan() {
        guard let arView = arView else { return }
        
        print("🔄 스캔 리셋 시작...")
        
        // 모든 메시 엔티티 제거
        hideAllMeshes()
        meshAnchors.removeAll()
        meshCount = 0
        
        // AR 세션 재시작
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        scanStatus = "스캔 중..."
        print("✅ 스캔 리셋 완료")
    }
    
    func saveScan() {
        guard let arView = arView else {
            saveMessage = "ARView가 설정되지 않았습니다"
            showSaveErrorAlert = true
            return
        }
        
        guard !meshEntities.isEmpty else {
            saveMessage = "저장할 메시가 없습니다. 먼저 스캔을 진행하세요."
            showSaveErrorAlert = true
            return
        }
        
        scanStatus = "저장 중..."
        print("💾 스캔 저장 시작: \(meshEntities.count)개 메시")
        
        // USDZ 파일로 저장
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "LiDAR_Scan_\(timestamp).usdz"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // 메인 스레드에서 저장 작업 수행
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            do {
                // 모든 메시를 하나의 루트 엔티티로 합치기
                let rootEntity = Entity()
                rootEntity.name = "LiDAR_Scan_Root"
                
                // 모든 메시 엔티티를 루트에 추가
                for (id, meshEntity) in meshEntities {
                    // 메시 엔티티를 복제하여 루트에 추가
                    let clonedEntity = meshEntity.clone(recursive: true)
                    rootEntity.addChild(clonedEntity)
                    print("📦 메시 추가: \(id)")
                }
                
                guard rootEntity.children.count > 0 else {
                    throw NSError(domain: "LiDARScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "저장할 메시가 없습니다"])
                }
                
                print("💾 \(rootEntity.children.count)개 메시를 USDZ로 저장 중...")
                
                // 루트 엔티티를 USDZ로 저장 (async)
                try await rootEntity.write(to: fileURL)
                
                // 파일 저장 확인
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    throw NSError(domain: "LiDARScan", code: 2, userInfo: [NSLocalizedDescriptionKey: "파일이 저장되지 않았습니다"])
                }
                
                // 파일 크기 확인
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📊 저장된 파일 크기: \(fileSize) bytes")
                }
                
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
                self.scanStatus = "저장 완료"
                
                print("✅ 스캔 저장 완료: \(fileURL.path)")
            } catch {
                self.saveMessage = "저장 실패: \(error.localizedDescription)"
                self.showSaveErrorAlert = true
                self.scanStatus = "저장 실패"
                print("❌ 스캔 저장 실패: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - ARMeshGeometry Extension
extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
    
    func normal(at index: UInt32) -> SIMD3<Float> {
        let normalPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(index)))
        let normal = normalPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return normal
    }
    
    // OBJ Export용 MDLMesh 변환
    func toMDLMesh(device: MTLDevice, camera: ARCamera, modelMatrix: simd_float4x4) -> MDLMesh {
        // 로컬 좌표를 월드 좌표로 변환
        func convertVertexLocalToWorld() {
            let verticesPointer = vertices.buffer.contents()
            for vertexIndex in 0..<vertices.count {
                let vertex = self.vertex(at: UInt32(vertexIndex))
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.x, y: vertex.y, z: vertex.z, w: 1)
                let vertexWorldPosition = (modelMatrix * vertexLocalTransform).columns.3
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x,
                                           toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y,
                                           toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z,
                                           toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
            }
        }
        
        convertVertexLocalToWorld()
        
        let allocator = MTKMeshBufferAllocator(device: device)
        let data = Data(bytes: vertices.buffer.contents(),
                        count: vertices.stride * vertices.count)
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
        
        let indexData = Data(bytes: faces.buffer.contents(),
                            count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                indexCount: faces.count * faces.indexCountPerPrimitive,
                                indexType: .uInt32,
                                geometryType: .triangles,
                                material: nil)
        
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                           format: .float3,
                                                           offset: 0,
                                                           bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride)
        
        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                          vertexCount: vertices.count,
                          descriptor: vertexDescriptor,
                          submeshes: [submesh])
        
        return mesh
    }
}

