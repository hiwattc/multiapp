import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - LiDAR Scan View 3
struct LiDARScanView3: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiDARScanView3Model()
    
    var body: some View {
        ZStack {
            // AR View
            ARScanViewContainer3(viewModel: viewModel)
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
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("LiDAR 3D 스캐닝")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.isScanning ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(viewModel.isScanning ? "스캔 중" : "대기")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        if viewModel.meshCount > 0 {
                            Text("포인트: 수집 완료")
                                .font(.caption)
                                .foregroundColor(.cyan)
                        } else {
                            Text("포인트: 수집 중...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                // Info Panel
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        VStack {
                            Image(systemName: "cube.transparent")
                                .foregroundColor(.cyan)
                            Text("스캔 영역")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("완료 후 표시")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    
                    // Progress
                    if viewModel.isScanning {
                        VStack(spacing: 4) {
                            Text("스캔 진행률")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            ProgressView(value: viewModel.scanProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                                .frame(width: 200)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    }
                }
                .padding(.bottom, 20)
                
                // Controls
                HStack(spacing: 20) {
                    // Start/Stop Scan
                    Button(action: {
                        viewModel.toggleScanning()
                    }) {
                        VStack {
                            Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                            Text(viewModel.isScanning ? "중지" : "시작")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(viewModel.isScanning ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        .cornerRadius(15)
                    }
                    
                    // Save Scan
                    Button(action: {
                        viewModel.saveScan()
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 50))
                            Text("저장")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(15)
                    }
                    .disabled(viewModel.meshCount == 0)
                    .opacity(viewModel.meshCount == 0 ? 0.5 : 1.0)
                    
                    // View Scan
                    Button(action: {
                        viewModel.viewScan()
                    }) {
                        VStack {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 50))
                            Text("보기")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(15)
                    }
                    .disabled(viewModel.meshCount == 0)
                    .opacity(viewModel.meshCount == 0 ? 0.5 : 1.0)
                }
                .padding(.bottom, 50)
            }
            
            // Save Success Alert
            if viewModel.showSaveSuccess {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title)
                        Text("스캔 저장 완료!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.bottom, 200)
                    
                    Spacer()
                }
                .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $viewModel.showViewer) {
            if let entities = viewModel.getCurrentScanEntities() {
                Direct3DViewer(entities: entities)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - AR Scan View Container
struct ARScanViewContainer3: UIViewRepresentable {
    @ObservedObject var viewModel: LiDARScanView3Model
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 구성 (성능 최적화)
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            print("✅ Mesh Reconstruction 활성화")
        }
        
        configuration.planeDetection = [.horizontal, .vertical]
        
        // 프레임 레이트 최적화 (가장 낮은 해상도와 fps)
        let videoFormats = ARWorldTrackingConfiguration.supportedVideoFormats
        configuration.videoFormat = videoFormats
            .sorted { 
                ($0.imageResolution.width * $0.imageResolution.height, $0.framesPerSecond) <
                ($1.imageResolution.width * $1.imageResolution.height, $1.framesPerSecond)
            }
            .first ?? videoFormats[0]
        
        print("📹 비디오 포맷: \(configuration.videoFormat.imageResolution.width)x\(configuration.videoFormat.imageResolution.height) @ \(configuration.videoFormat.framesPerSecond)fps")
        
        arView.session.run(configuration)
        
        // RealityKit 렌더링 최적화
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]
        arView.session.delegate = context.coordinator
        
        context.coordinator.arView = arView
        context.coordinator.viewModel = viewModel
        viewModel.setARView(arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 업데이트 로직
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        weak var viewModel: LiDARScanView3Model?
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    viewModel.processMeshAnchor(meshAnchor, isNew: true)
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    viewModel.processMeshAnchor(meshAnchor, isNew: false)
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

// MARK: - Mesh Data for File Storage
struct MeshData: Codable {
    let id: String
    let vertices: [SIMD3<Float>]
    let indices: [UInt32]
    let transform: [Float] // 4x4 matrix as flat array
}

// MARK: - LiDAR Scan View Model 3
class LiDARScanView3Model: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var meshCount: Int = 0
    @Published var scanProgress: Double = 0.0
    @Published var showSaveSuccess: Bool = false
    @Published var showViewer: Bool = false
    
    weak var arView: ARView?
    
    // 파일 기반 스토리지
    private var tempDirectory: URL?
    private var meshFileURLs: [URL] = []
    private var finalMeshEntities: [ModelEntity] = []
    
    private var scanStartTime: Date?
    private let scanDuration: TimeInterval = 20.0
    private var scanTimer: Timer?
    
    // 격자 기반 시각적 피드백
    private var gridIndicators: [String: AnchorEntity] = [:] // 키: "x,y,z" 격자 좌표
    private let gridSize: Float = 0.3 // 30cm
    private let maxGridIndicators = 500
    
    private let fileQueue = DispatchQueue(label: "com.lidar.filewriter", qos: .utility)
    
    func setARView(_ view: ARView) {
        self.arView = view
    }
    
    func toggleScanning() {
        if isScanning {
            // 스캔 중지
            print("⏸️ 사용자가 스캔 중지")
            isScanning = false
            stopScanning()
        } else {
            // 새 스캔 시작 (완전 초기화)
            print("▶️ 사용자가 스캔 시작")
            isScanning = true
            startScanning()
        }
    }
    
    func startScanning() {
        print("🟢 스캔 시작 (완전 초기화 모드)")
        
        // 1. 타이머 정리
        scanTimer?.invalidate()
        scanTimer = nil
        
        // 2. 이전 임시 디렉토리 정리
        if tempDirectory != nil {
            print("🗑️ 이전 임시 파일 정리 중...")
            cleanupTempDirectory()
        }
        
        // 3. 모든 상태 초기화
        finalMeshEntities.removeAll()
        meshFileURLs.removeAll()
        meshCount = 0
        scanProgress = 0.0
        scanStartTime = Date()
        
        print("🔄 상태 초기화 완료")
        
        // 4. 이전 격자 인디케이터 제거
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let arView = self.arView else { return }
            
            print("🧹 격자 인디케이터 제거 중: \(self.gridIndicators.count)개")
            
            for (_, anchor) in self.gridIndicators {
                arView.scene.removeAnchor(anchor)
            }
            self.gridIndicators.removeAll()
            
            print("✅ 격자 인디케이터 제거 완료")
        }
        
        // 5. 새 임시 디렉토리 생성
        setupTempDirectory()
        
        // 6. 진행률 타이머 시작
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.scanStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            self.scanProgress = min(elapsed / self.scanDuration, 1.0)
            
            if self.scanProgress >= 1.0 {
                self.stopScanning()
            }
        }
        
        print("✅ 새 스캔 세션 시작!")
    }
    
    private func setupTempDirectory() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("LiDARScan_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            tempDirectory = tempDir
            meshFileURLs.removeAll()
            print("📁 임시 디렉토리 생성: \(tempDir.path)")
        } catch {
            print("❌ 임시 디렉토리 생성 실패: \(error)")
        }
    }
    
    private func cleanupTempDirectory() {
        guard let tempDir = tempDirectory else { return }
        
        // 백그라운드에서 파일 삭제
        DispatchQueue.global(qos: .background).async {
            do {
                if FileManager.default.fileExists(atPath: tempDir.path) {
                    try FileManager.default.removeItem(at: tempDir)
                    print("🗑️ 임시 디렉토리 삭제 완료: \(tempDir.lastPathComponent)")
                }
            } catch {
                print("⚠️ 임시 디렉토리 삭제 실패: \(error)")
            }
        }
        
        tempDirectory = nil
        meshFileURLs.removeAll()
    }
    
    func stopScanning() {
        print("🔴 스캔 중지 - 데이터 수집 완료")
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        
        print("✅ 스캔 완료!")
        print("📦 수집된 데이터 파일: \(meshFileURLs.count)개")
        print("🔲 표시된 격자: \(gridIndicators.count)개")
        print("💡 '보기' 또는 '저장' 버튼을 눌러주세요")
        
        // 완료 메시지 표시
        DispatchQueue.main.async { [weak self] in
            self?.showSaveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.showSaveSuccess = false
            }
        }
        
        // 격자 인디케이터 색상 변경 (스캔 완료)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let completeMaterial = SimpleMaterial(
                color: .blue.withAlphaComponent(0.3),
                isMetallic: false
            )
            
            for (_, anchor) in self.gridIndicators {
                if let boxEntity = anchor.children.first as? ModelEntity {
                    boxEntity.model?.materials = [completeMaterial]
                }
            }
            
            print("🎨 격자 색상 변경: 녹색 → 파란색 (스캔 완료)")
        }
    }
    
    func processMeshAnchor(_ meshAnchor: ARMeshAnchor, isNew: Bool) {
        guard isScanning, let tempDir = tempDirectory else { return }
        
        let meshId = meshAnchor.identifier
        let geometry = meshAnchor.geometry
        let vertexCount = geometry.vertices.count
        let faceCount = geometry.faces.count
        
        // 품질 체크
        guard vertexCount >= 100, vertexCount <= 10000, faceCount >= 20 else {
            return
        }
        
        // 최대 파일 개수 제한 (3개)
        guard meshFileURLs.count < 3 else { return }
        
        // 백그라운드에서 파일에 저장
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 메시 데이터 추출
            let vertices = geometry.vertices
            let vertexBuffer = vertices.buffer.contents()
            var positions: [SIMD3<Float>] = []
            
            // 2개 중 1개만 샘플링 + NaN 필터링 (더 많이 수집)
            let step = 2
            for i in Swift.stride(from: 0, to: min(vertexCount, 3000), by: step) {
                let vertex = vertexBuffer.assumingMemoryBound(to: SIMD3<Float>.self)[i]
                
                // NaN, Inf 체크
                if vertex.x.isNaN || vertex.y.isNaN || vertex.z.isNaN ||
                   vertex.x.isInfinite || vertex.y.isInfinite || vertex.z.isInfinite {
                    continue // 잘못된 값 건너뛰기
                }
                
                // 합리적인 범위 체크 (-100 ~ 100m)
                if abs(vertex.x) > 100 || abs(vertex.y) > 100 || abs(vertex.z) > 100 {
                    continue
                }
                
                positions.append(vertex)
            }
            
            // 인덱스 데이터
            let faces = geometry.faces
            let faceBuffer = faces.buffer.contents()
            let bytesPerIndex = faces.bytesPerIndex
            var indices: [UInt32] = []
            
            let maxFaces = min(faceCount, 1000)
            for i in 0..<(maxFaces * 3) {
                let index: UInt32
                if bytesPerIndex == 2 {
                    let original = faceBuffer.assumingMemoryBound(to: UInt16.self)[i]
                    index = UInt32(original / UInt16(step))
                } else {
                    let original = faceBuffer.assumingMemoryBound(to: UInt32.self)[i]
                    index = original / UInt32(step)
                }
                
                if index < positions.count {
                    indices.append(index)
                }
            }
            
            guard positions.count >= 10, indices.count >= 3 else { return }
            
            // Transform을 배열로 변환 (NaN 체크)
            let transform = meshAnchor.transform
            var transformArray: [Float] = []
            var hasInvalidTransform = false
            
            for col in 0..<4 {
                for row in 0..<4 {
                    let value = transform[col][row]
                    if value.isNaN || value.isInfinite {
                        hasInvalidTransform = true
                        break
                    }
                    transformArray.append(value)
                }
                if hasInvalidTransform { break }
            }
            
            guard !hasInvalidTransform else {
                print("⚠️ 잘못된 Transform 데이터, 건너뛰기")
                return
            }
            
            // MeshData 생성
            let meshData = MeshData(
                id: meshId.uuidString,
                vertices: positions,
                indices: indices,
                transform: transformArray
            )
            
            // JSON 파일로 저장
            let fileURL = tempDir.appendingPathComponent("\(meshId.uuidString).json")
            
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(meshData)
                try data.write(to: fileURL)
                
                DispatchQueue.main.async {
                    self.meshFileURLs.append(fileURL)
                    self.meshCount = self.meshFileURLs.count
                    print("💾 메시 파일 저장 완료")
                    print("📊 수집된 정점(포인트): \(positions.count)개")
                    print("📐 생성된 인덱스: \(indices.count)개")
                }
            } catch {
                print("❌ 메시 파일 저장 실패: \(error)")
            }
        }
        
        // 격자 기반 시각적 피드백 (실시간 스캔 영역 표시)
        if isNew && gridIndicators.count < maxGridIndicators {
            showGridIndicators(for: meshAnchor)
        }
    }
    
    // 포인트 클라우드로 로딩 (메시 생성 없음)
    private func loadPointCloud() {
        guard !meshFileURLs.isEmpty else {
            print("⚠️ 로딩할 데이터가 없습니다")
            return
        }
        
        print("☁️ 포인트 클라우드 생성 중...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allVertices: [SIMD3<Float>] = []
            var combinedTransform = matrix_identity_float4x4
            
            // 모든 파일 읽기 (최대 3개)
            for (index, fileURL) in self.meshFileURLs.enumerated() {
            
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    let meshData = try decoder.decode(MeshData.self, from: data)
                    
                    print("📊 파일 \(index + 1): \(meshData.vertices.count)개 정점")
                    
                    // Transform 복원 (첫 번째 파일 것 사용)
                    if index == 0 {
                        for col in 0..<4 {
                            for row in 0..<4 {
                                combinedTransform[col][row] = meshData.transform[col * 4 + row]
                            }
                        }
                    }
                    
                    // 모든 정점 합치기
                    allVertices.append(contentsOf: meshData.vertices)
                } catch {
                    print("❌ 파일 \(index + 1) 로딩 실패: \(error)")
                }
            }
            
            print("📊 전체 수집된 정점: \(allVertices.count)개")
            print("📊 포인트 클라우드로 표시할 점: 최대 1000개")
            
            // 메인 스레드에서 포인트 클라우드 생성
            DispatchQueue.main.async {
                let pointCloudEntity = self.createPointCloudEntity(
                    vertices: allVertices,
                    transform: combinedTransform
                )
                
                self.finalMeshEntities = [pointCloudEntity]
                self.showViewer = true
                
                print("✅ 포인트 클라우드 생성 완료!")
                
                // 백그라운드에서 임시 파일 정리
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
                    self.cleanupTempDirectory()
                }
            }
        }
    }
    
    // 격자 기반 포인트 샘플링 (30cm 단위)
    private func samplePointsWithGrid(vertices: [SIMD3<Float>], gridSize: Float = 0.3) -> [SIMD3<Float>] {
        guard !vertices.isEmpty else { return [] }
        
        print("📐 격자 샘플링 시작: 격자 크기 \(gridSize)m (30cm)")
        
        // 바운딩 박스 계산
        var minBounds = vertices[0]
        var maxBounds = vertices[0]
        
        for vertex in vertices {
            minBounds.x = min(minBounds.x, vertex.x)
            minBounds.y = min(minBounds.y, vertex.y)
            minBounds.z = min(minBounds.z, vertex.z)
            
            maxBounds.x = max(maxBounds.x, vertex.x)
            maxBounds.y = max(maxBounds.y, vertex.y)
            maxBounds.z = max(maxBounds.z, vertex.z)
        }
        
        print("📦 바운딩 박스: min(\(minBounds.x), \(minBounds.y), \(minBounds.z)) ~ max(\(maxBounds.x), \(maxBounds.y), \(maxBounds.z))")
        
        // 격자 딕셔너리 (키: 격자 인덱스, 값: 해당 격자의 정점들)
        var gridMap: [String: [SIMD3<Float>]] = [:]
        
        for vertex in vertices {
            // 격자 인덱스 계산
            let gridX = Int(floor(vertex.x / gridSize))
            let gridY = Int(floor(vertex.y / gridSize))
            let gridZ = Int(floor(vertex.z / gridSize))
            
            let key = "\(gridX),\(gridY),\(gridZ)"
            
            if gridMap[key] == nil {
                gridMap[key] = []
            }
            gridMap[key]?.append(vertex)
        }
        
        print("🔲 생성된 격자 개수: \(gridMap.count)개")
        
        // 각 격자에서 대표 포인트 선택 (중앙 또는 첫 번째)
        var sampledPoints: [SIMD3<Float>] = []
        
        for (_, points) in gridMap {
            // 격자 내 모든 점의 평균 위치 (중심점)
            var center = SIMD3<Float>(0, 0, 0)
            for point in points {
                center += point
            }
            center /= Float(points.count)
            
            sampledPoints.append(center)
        }
        
        print("✅ 격자 샘플링 완료: \(sampledPoints.count)개 포인트")
        
        return sampledPoints
    }
    
    // 포인트 클라우드 엔티티 생성 (바닥은 적색, 나머지는 청록색)
    private func createPointCloudEntity(vertices: [SIMD3<Float>], transform: simd_float4x4) -> ModelEntity {
        let containerEntity = ModelEntity()
        
        print("📊 전체 정점: \(vertices.count)개")
        
        // 격자 기반 샘플링 (30cm)
        let sampledVertices = samplePointsWithGrid(vertices: vertices, gridSize: 0.3)
        
        print("🎯 샘플링 후 포인트: \(sampledVertices.count)개")
        
        // Y 좌표 분석하여 바닥 높이 추정
        let yValues = sampledVertices.map { $0.y }
        let minY = yValues.min() ?? 0
        let maxY = yValues.max() ?? 0
        let floorThreshold = minY + (maxY - minY) * 0.2 // 하위 20% 높이를 바닥으로 간주
        
        print("🏠 Y 범위: \(minY) ~ \(maxY), 바닥 임계값: \(floorThreshold)")
        
        // 작은 구체 메시 생성 (재사용)
        let pointSize: Float = 0.015
        let sphereMesh = MeshResource.generateSphere(radius: pointSize)
        
        // 바닥용 재질 (적색)
        let floorMaterial = SimpleMaterial(color: .red.withAlphaComponent(0.8), isMetallic: false)
        // 벽/천장용 재질 (청록색)
        let wallMaterial = SimpleMaterial(color: .cyan.withAlphaComponent(0.8), isMetallic: false)
        
        // 한 번에 50개씩 배치하여 순차 생성
        let batchSize = 50
        
        containerEntity.transform.matrix = transform
        
        var floorCount = 0
        var wallCount = 0
        
        print("🔨 \(sampledVertices.count)개 포인트를 순차 생성합니다...")
        
        // 순차적으로 배치 생성
        for batchIndex in stride(from: 0, to: sampledVertices.count, by: batchSize) {
            let batchEnd = min(batchIndex + batchSize, sampledVertices.count)
            let batch = Array(sampledVertices[batchIndex..<batchEnd])
            
            // 약간의 딜레이를 주고 배치 생성
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(batchIndex / batchSize) * 0.05) { [weak self] in
                for position in batch {
                    // Y 좌표로 바닥 판단
                    let isFloor = position.y <= floorThreshold
                    let material = isFloor ? floorMaterial : wallMaterial
                    
                    let pointEntity = ModelEntity(mesh: sphereMesh, materials: [material])
                    pointEntity.position = position
                    containerEntity.addChild(pointEntity)
                    
                    if isFloor {
                        floorCount += 1
                    } else {
                        wallCount += 1
                    }
                }
                
                if batchEnd == sampledVertices.count {
                    print("✨ 포인트 클라우드: \(sampledVertices.count)개 점 생성 완료")
                    print("🔴 바닥: \(floorCount)개, 🔵 벽/천장: \(wallCount)개")
                }
            }
        }
        
        return containerEntity
    }
    
    private func loadMeshesFromFiles() {
        // 이제 사용하지 않음 - 포인트 클라우드 사용
        loadPointCloud()
    }
    
    
    func removeMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        // 격자 인디케이터는 유지 (한 번 표시된 격자는 계속 표시)
    }
    
    // 격자 인디케이터 표시
    private func showGridIndicators(for meshAnchor: ARMeshAnchor) {
        let geometry = meshAnchor.geometry
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        
        guard vertexCount > 0 else { return }
        
        let vertexBuffer = vertices.buffer.contents()
        var gridKeys = Set<String>()
        
        // 샘플링하여 격자 키 수집 (10개 중 1개만)
        for i in stride(from: 0, to: min(vertexCount, 100), by: 10) {
            let vertex = vertexBuffer.assumingMemoryBound(to: SIMD3<Float>.self)[i]
            
            // NaN 체크
            guard !vertex.x.isNaN && !vertex.y.isNaN && !vertex.z.isNaN else { continue }
            
            // 격자 인덱스 계산
            let gridX = Int(floor(vertex.x / gridSize))
            let gridY = Int(floor(vertex.y / gridSize))
            let gridZ = Int(floor(vertex.z / gridSize))
            
            let key = "\(gridX),\(gridY),\(gridZ)"
            gridKeys.insert(key)
        }
        
        // 새로운 격자만 표시
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let arView = self.arView else { return }
            
            for key in gridKeys {
                // 이미 표시된 격자는 건너뛰기
                guard self.gridIndicators[key] == nil else { continue }
                
                // 최대 개수 체크
                guard self.gridIndicators.count < self.maxGridIndicators else { break }
                
                // 격자 중심 위치 계산
                let components = key.split(separator: ",").compactMap { Int($0) }
                guard components.count == 3 else { continue }
                
                let centerX = (Float(components[0]) + 0.5) * self.gridSize
                let centerY = (Float(components[1]) + 0.5) * self.gridSize
                let centerZ = (Float(components[2]) + 0.5) * self.gridSize
                
                // 작은 반투명 박스 생성
                let boxSize: Float = self.gridSize * 0.8 // 격자보다 약간 작게
                let boxMesh = MeshResource.generateBox(size: boxSize)
                let material = SimpleMaterial(
                    color: .green.withAlphaComponent(0.2),
                    isMetallic: false
                )
                
                let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
                boxEntity.position = SIMD3<Float>(centerX, centerY, centerZ)
                
                // 월드 좌표로 앵커 생성
                let anchor = AnchorEntity(world: meshAnchor.transform)
                anchor.addChild(boxEntity)
                arView.scene.addAnchor(anchor)
                
                self.gridIndicators[key] = anchor
            }
            
            // 업데이트된 격자 개수 로그
            if gridKeys.count > 0 {
                print("🔲 격자 표시: 현재 \(self.gridIndicators.count)개")
            }
        }
    }
    
    // 단순화된 메시 생성 (성능 최적화)
    private func createSimplifiedMeshEntity(from meshAnchor: ARMeshAnchor) -> ModelEntity? {
        let geometry = meshAnchor.geometry
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        
        guard vertexCount > 0 else { return nil }
        
        // 정점 간소화: 2개 중 1개만 사용
        let vertexBuffer = vertices.buffer.contents()
        var positions: [SIMD3<Float>] = []
        let vertexStep = 2 // 2개 중 1개만
        
        for i in Swift.stride(from: 0, to: vertexCount, by: vertexStep) {
            let vertex = vertexBuffer.assumingMemoryBound(to: SIMD3<Float>.self)[i]
            positions.append(vertex)
        }
        
        // 인덱스도 간소화
        let faces = geometry.faces
        let faceBuffer = faces.buffer.contents()
        let faceCount = min(faces.count, 1000) // 최대 1000개 면만 사용
        let bytesPerIndex = faces.bytesPerIndex
        
        var indices: [UInt32] = []
        let faceStep = 2 // 2개 중 1개만
        
        for i in Swift.stride(from: 0, to: faceCount * 3, by: faceStep * 3) {
            for j in 0..<3 {
                let index: UInt32
                if bytesPerIndex == 2 {
                    let originalIndex = faceBuffer.assumingMemoryBound(to: UInt16.self)[i + j]
                    index = UInt32(originalIndex / UInt16(vertexStep))
                } else {
                    let originalIndex = faceBuffer.assumingMemoryBound(to: UInt32.self)[i + j]
                    index = originalIndex / UInt32(vertexStep)
                }
                
                if index < positions.count {
                    indices.append(index)
                }
            }
        }
        
        guard !positions.isEmpty, indices.count >= 3 else { return nil }
        
        // 메시 리소스 생성
        var meshDescriptor = MeshDescriptor(name: "mesh")
        meshDescriptor.positions = MeshBuffer(positions)
        meshDescriptor.primitives = .triangles(indices)
        
        guard let meshResource = try? MeshResource.generate(from: [meshDescriptor]) else {
            return nil
        }
        
        // 단순한 색상 (회색 - 미스캔)
        let material = SimpleMaterial(color: .gray.withAlphaComponent(0.5), isMetallic: false)
        
        let meshEntity = ModelEntity(mesh: meshResource, materials: [material])
        meshEntity.name = "mesh_\(meshAnchor.identifier.uuidString)"
        
        return meshEntity
    }
    
    func createMeshEntity(from meshAnchor: ARMeshAnchor) -> ModelEntity? {
        let geometry = meshAnchor.geometry
        
        // 정점 데이터
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        
        // 정점 수 체크
        guard vertexCount > 0, vertexCount <= 10000 else {
            if vertexCount > 10000 {
                print("⚠️ 메시 정점 수 초과: \(vertexCount), 무시")
            }
            return nil
        }
        
        let vertexBuffer = vertices.buffer.contents()
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount)
        
        for i in 0..<vertexCount {
            let vertex = vertexBuffer.assumingMemoryBound(to: SIMD3<Float>.self)[i]
            positions.append(vertex)
        }
        
        // 인덱스 데이터
        let faces = geometry.faces
        let faceBuffer = faces.buffer.contents()
        let faceCount = faces.count
        let bytesPerIndex = faces.bytesPerIndex
        
        guard faceCount > 0 else { return nil }
        
        var indices: [UInt32] = []
        indices.reserveCapacity(faceCount * 3)
        
        for i in 0..<(faceCount * 3) {
            let index: UInt32
            if bytesPerIndex == 2 {
                index = UInt32(faceBuffer.assumingMemoryBound(to: UInt16.self)[i])
            } else {
                index = faceBuffer.assumingMemoryBound(to: UInt32.self)[i]
            }
            
            // 인덱스 유효성 검사
            guard index < vertexCount else {
                print("⚠️ 잘못된 인덱스: \(index), 정점 수: \(vertexCount)")
                return nil
            }
            
            indices.append(index)
        }
        
        guard !positions.isEmpty, !indices.isEmpty else { return nil }
        
        // 메시 리소스 생성
        var meshDescriptor = MeshDescriptor(name: "mesh")
        meshDescriptor.positions = MeshBuffer(positions)
        meshDescriptor.primitives = .triangles(indices)
        
        guard let meshResource = try? MeshResource.generate(from: [meshDescriptor]) else {
            print("⚠️ 메시 리소스 생성 실패")
            return nil
        }
        
        // 초기 색상 (회색 - 미스캔)
        let material = SimpleMaterial(color: .gray.withAlphaComponent(0.6), isMetallic: false)
        
        let meshEntity = ModelEntity(mesh: meshResource, materials: [material])
        meshEntity.name = "mesh_\(meshAnchor.identifier.uuidString)"
        
        return meshEntity
    }
    
    
    func saveScan() {
        // 메시가 로딩되지 않았으면 먼저 로딩
        if finalMeshEntities.isEmpty && !meshFileURLs.isEmpty {
            print("📂 저장을 위해 메시 로딩 중...")
            loadMeshesForSave()
            return
        }
        
        guard !finalMeshEntities.isEmpty else {
            print("❌ 저장할 메시가 없습니다")
            return
        }
        
        print("💾 스캔 저장 시작...")
        
        Task { @MainActor in
            do {
                // 모든 메시를 하나의 엔티티로 합치기
                let rootEntity = Entity()
                
                for meshEntity in finalMeshEntities {
                    if let mesh = meshEntity.model?.mesh,
                       let material = meshEntity.model?.materials.first {
                        let newEntity = ModelEntity(mesh: mesh, materials: [material])
                        newEntity.transform = meshEntity.transform
                        rootEntity.addChild(newEntity)
                    }
                }
                
                // 파일로 저장
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "LiDAR_Scan3_\(timestamp).usdz"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                try await rootEntity.write(to: fileURL)
                
                // 파일 크기 확인
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                
                print("✅ 스캔 저장 완료: \(fileURL.path)")
                print("📦 파일 크기: \(fileSize) bytes")
                
                // SavedScanManager에 정보 저장
                let scanInfo = SavedScanInfo(
                    id: UUID(),
                    fileName: "LiDAR Scan 3",
                    fileURL: fileURL,
                    date: Date(),
                    meshCount: finalMeshEntities.count
                )
                
                SavedScanManager.shared.saveScanInfo(scanInfo)
                
                // 성공 메시지 표시
                showSaveSuccess = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.showSaveSuccess = false
                }
                
            } catch {
                print("❌ 스캔 저장 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func viewScan() {
        print("👁️ 포인트 클라우드 보기 시작")
        
        if finalMeshEntities.isEmpty && !meshFileURLs.isEmpty {
            loadPointCloud()
        } else if !finalMeshEntities.isEmpty {
            showViewer = true
        } else {
            print("⚠️ 표시할 데이터가 없습니다")
        }
    }
    
    func getCurrentScanEntities() -> [Entity]? {
        guard !finalMeshEntities.isEmpty else { return nil }
        return finalMeshEntities.map { $0 as Entity }
    }
    
    // 저장을 위한 메시 로딩 (뷰어 표시 안 함)
    private func loadMeshesForSave() {
        guard !meshFileURLs.isEmpty else { return }
        
        print("📂 저장용 메시 로딩...")
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            var entities: [ModelEntity] = []
            
            // 최대 1개 파일 로딩
            for fileURL in self.meshFileURLs.prefix(1) {
                autoreleasepool {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let decoder = JSONDecoder()
                        let meshData = try decoder.decode(MeshData.self, from: data)
                        
                        guard meshData.vertices.count >= 10 else { return }
                        
                        var meshDescriptor = MeshDescriptor(name: "mesh")
                        meshDescriptor.positions = MeshBuffer(meshData.vertices)
                        meshDescriptor.primitives = .triangles(meshData.indices)
                        
                        if let meshResource = try? MeshResource.generate(from: [meshDescriptor]) {
                            let material = SimpleMaterial(color: .blue.withAlphaComponent(0.7), isMetallic: false)
                            let entity = ModelEntity(mesh: meshResource, materials: [material])
                            
                            var matrix = matrix_identity_float4x4
                            for col in 0..<4 {
                                for row in 0..<4 {
                                    matrix[col][row] = meshData.transform[col * 4 + row]
                                }
                            }
                            entity.transform.matrix = matrix
                            
                            entities.append(entity)
                        }
                    } catch {
                        print("⚠️ 파일 로딩 실패: \(error)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.finalMeshEntities = entities
                print("✅ 저장용 메시 로딩 완료: \(entities.count)개")
                
                // 이제 저장 실행
                self.saveScan()
            }
        }
    }
}

// MARK: - Preview
struct LiDARScanView3_Previews: PreviewProvider {
    static var previews: some View {
        LiDARScanView3()
    }
}
