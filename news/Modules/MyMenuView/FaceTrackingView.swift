import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - Face Tracking View
struct FaceTrackingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FaceTrackingViewModel()
    
    var body: some View {
        ZStack {
            // AR Face Tracking View
            FaceTrackingARViewContainer(viewModel: viewModel)
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
                        Text("IR 얼굴 추적")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            Image(systemName: viewModel.isFaceDetected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(viewModel.isFaceDetected ? .green : .yellow)
                            Text(viewModel.isFaceDetected ? "얼굴 인식됨" : "얼굴 찾는 중...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                .foregroundColor(.cyan)
                            Text("정점: \(viewModel.vertexCount)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                // Control Panel
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.toggleMesh()
                        }) {
                            VStack {
                                Image(systemName: viewModel.showMesh ? "eye.fill" : "eye.slash.fill")
                                    .font(.title2)
                                Text(viewModel.showMesh ? "메시 표시" : "메시 숨김")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(viewModel.showMesh ? Color.green.opacity(0.7) : Color.gray.opacity(0.5))
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
                            viewModel.changeColor()
                        }) {
                            VStack {
                                Image(systemName: "paintpalette.fill")
                                    .font(.title2)
                                Text("색상 변경")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple.opacity(0.7))
                            .cornerRadius(12)
                        }
                    }
                    
                    Text("📸 TrueDepth 카메라로 얼굴을 3D로 그립니다")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.checkFaceTrackingSupport()
        }
    }
}

// MARK: - Face Tracking AR View Container
struct FaceTrackingARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: FaceTrackingViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Face Tracking 설정
        guard ARFaceTrackingConfiguration.isSupported else {
            print("❌ Face Tracking을 지원하지 않는 기기입니다")
            return arView
        }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
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
        viewModel.updateVisualization(in: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        weak var viewModel: FaceTrackingViewModel?
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let faceAnchor = anchor as? ARFaceAnchor {
                    print("✅ 얼굴 앵커 추가됨")
                    viewModel.addFaceAnchor(faceAnchor)
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let faceAnchor = anchor as? ARFaceAnchor {
                    viewModel.updateFaceAnchor(faceAnchor)
                }
            }
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let faceAnchor = anchor as? ARFaceAnchor {
                    viewModel.removeFaceAnchor(faceAnchor)
                }
            }
        }
    }
}

// MARK: - Face Tracking View Model
class FaceTrackingViewModel: ObservableObject {
    @Published var isFaceDetected: Bool = false
    @Published var vertexCount: Int = 0
    @Published var showMesh: Bool = true
    @Published var showWireframe: Bool = false
    
    weak var arView: ARView?
    private var faceAnchor: ARFaceAnchor?
    private var faceEntity: ModelEntity?
    private var faceAnchorEntity: AnchorEntity?
    private var currentColorIndex: Int = 0
    
    private let colors: [UIColor] = [
        .cyan, .green, .blue, .purple, .magenta, 
        .orange, .yellow, .red, .systemPink
    ]
    
    func setARView(_ view: ARView) {
        self.arView = view
    }
    
    func checkFaceTrackingSupport() {
        if !ARFaceTrackingConfiguration.isSupported {
            print("❌ Face Tracking을 지원하지 않는 기기입니다 (iPhone X 이상 필요)")
        }
    }
    
    func addFaceAnchor(_ anchor: ARFaceAnchor) {
        DispatchQueue.main.async {
            self.isFaceDetected = true
            self.faceAnchor = anchor
            self.vertexCount = anchor.geometry.vertices.count
            self.updateVisualization()
        }
    }
    
    func updateFaceAnchor(_ anchor: ARFaceAnchor) {
        self.faceAnchor = anchor
        self.vertexCount = anchor.geometry.vertices.count
        
        // 메시가 표시되어 있으면 업데이트
        if showMesh {
            updateVisualization()
        }
    }
    
    func removeFaceAnchor(_ anchor: ARFaceAnchor) {
        DispatchQueue.main.async {
            self.isFaceDetected = false
            self.clearVisualization()
        }
    }
    
    func updateVisualization() {
        guard let arView = arView, let faceAnchor = faceAnchor, showMesh else {
            clearVisualization()
            return
        }
        
        createFaceMesh(from: faceAnchor, in: arView)
    }
    
    func updateVisualization(in arView: ARView) {
        self.arView = arView
        updateVisualization()
    }
    
    func createFaceMesh(from anchor: ARFaceAnchor, in arView: ARView) {
        do {
            let faceGeometry = anchor.geometry
            
            // 메시 리소스 생성
            let meshResource = try createFaceMeshResource(from: faceGeometry)
            
            // 재질 생성
            let currentColor = colors[currentColorIndex]
            let material: RealityKit.Material
            
            if showWireframe {
                material = SimpleMaterial(
                    color: currentColor.withAlphaComponent(0.8),
                    isMetallic: false
                )
            } else {
                material = SimpleMaterial(
                    color: currentColor.withAlphaComponent(0.7),
                    isMetallic: false
                )
            }
            
            // 기존 메시 제거
            if let existingEntity = faceEntity, let existingAnchor = faceAnchorEntity {
                arView.scene.removeAnchor(existingAnchor)
            }
            
            // 새 메시 생성
            let newFaceEntity = ModelEntity(mesh: meshResource, materials: [material])
            
            // 앵커 엔티티 생성
            let newAnchorEntity = AnchorEntity(anchor: anchor)
            newAnchorEntity.addChild(newFaceEntity)
            arView.scene.addAnchor(newAnchorEntity)
            
            faceEntity = newFaceEntity
            faceAnchorEntity = newAnchorEntity
            
        } catch {
            print("❌ 얼굴 메시 생성 실패: \(error.localizedDescription)")
        }
    }
    
    func createFaceMeshResource(from geometry: ARFaceGeometry) throws -> MeshResource {
        var meshDescriptor = MeshDescriptor(name: "face_mesh")
        
        // 정점 데이터
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount)
        
        for i in 0..<vertexCount {
            let vertex = vertices[i]
            positions.append(vertex)
        }
        
        guard !positions.isEmpty else {
            throw NSError(domain: "FaceTracking", code: 1, userInfo: [NSLocalizedDescriptionKey: "정점 데이터가 비어있습니다"])
        }
        
        meshDescriptor.positions = MeshBuffer(positions)
        
        // 인덱스 데이터
        let indices = geometry.triangleIndices
        let indexCount = indices.count
        var triangleIndices: [UInt32] = []
        triangleIndices.reserveCapacity(indexCount)
        
        for i in 0..<indexCount {
            triangleIndices.append(UInt32(indices[i]))
        }
        
        guard !triangleIndices.isEmpty else {
            throw NSError(domain: "FaceTracking", code: 2, userInfo: [NSLocalizedDescriptionKey: "인덱스 데이터가 비어있습니다"])
        }
        
        meshDescriptor.primitives = .triangles(triangleIndices)
        
        // 텍스처 좌표 (ARFaceGeometry에서 지원)
        let textureCoordinates = geometry.textureCoordinates
        if textureCoordinates.count == vertexCount {
            var uvs: [SIMD2<Float>] = []
            uvs.reserveCapacity(vertexCount)
            
            for i in 0..<vertexCount {
                uvs.append(textureCoordinates[i])
            }
            meshDescriptor.textureCoordinates = MeshBuffer(uvs)
        }
        
        return try MeshResource.generate(from: [meshDescriptor])
    }
    
    func clearVisualization() {
        guard let arView = arView, let anchor = faceAnchorEntity else { return }
        arView.scene.removeAnchor(anchor)
        faceEntity = nil
        faceAnchorEntity = nil
    }
    
    func toggleMesh() {
        showMesh.toggle()
        updateVisualization()
    }
    
    func toggleWireframe() {
        showWireframe.toggle()
        updateVisualization()
    }
    
    func changeColor() {
        currentColorIndex = (currentColorIndex + 1) % colors.count
        updateVisualization()
    }
}
