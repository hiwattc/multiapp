import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - LiDAR Scan View 5 (Grid on Planes)
struct LiDARScanView5: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiDARScanView5Model()
    
    var body: some View {
        ZStack {
            // AR View
            ARGridPlaneViewContainer(viewModel: viewModel)
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
                        Text("LiDAR 평면 그리드")
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
                        
                        Text("평면: \(viewModel.detectedPlanes)개")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                // Controls
                VStack(spacing: 16) {
                    // Plane Type Toggle
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.showHorizontalPlanes.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "rectangle.split.3x1")
                                    .font(.title2)
                                    .foregroundColor(viewModel.showHorizontalPlanes ? .green : .gray)
                                Text("수평면")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 80, height: 70)
                            .background(viewModel.showHorizontalPlanes ? Color.green.opacity(0.3) : Color.black.opacity(0.5))
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            viewModel.showVerticalPlanes.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "rectangle.split.1x2")
                                    .font(.title2)
                                    .foregroundColor(viewModel.showVerticalPlanes ? .blue : .gray)
                                Text("수직면")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 80, height: 70)
                            .background(viewModel.showVerticalPlanes ? Color.blue.opacity(0.3) : Color.black.opacity(0.5))
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            viewModel.showGrid.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.grid.3x3")
                                    .font(.title2)
                                    .foregroundColor(viewModel.showGrid ? .cyan : .gray)
                                Text("그리드")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 80, height: 70)
                            .background(viewModel.showGrid ? Color.cyan.opacity(0.3) : Color.black.opacity(0.5))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Grid Size Control
                    VStack(spacing: 8) {
                        Text("그리드 크기: \(String(format: "%.2f", viewModel.gridSize))m")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Slider(value: $viewModel.gridSize, in: 0.05...0.5, step: 0.05)
                            .frame(width: 250)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    
                    // Control Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            viewModel.startScanning()
                        }) {
                            HStack {
                                Image(systemName: viewModel.isScanning ? "pause.circle.fill" : "play.circle.fill")
                                Text(viewModel.isScanning ? "일시정지" : "스캔 시작")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 140)
                            .background(viewModel.isScanning ? Color.orange : Color.green)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            viewModel.clearPlanes()
                        }) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                Text("초기화")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 120)
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - View Model
class LiDARScanView5Model: ObservableObject {
    @Published var isScanning = false
    @Published var detectedPlanes = 0
    @Published var showHorizontalPlanes = true
    @Published var showVerticalPlanes = true
    @Published var showGrid = true
    @Published var gridSize: Float = 0.1
    
    var onPlanesUpdate: (() -> Void)?
    var onClearPlanes: (() -> Void)?
    
    func startScanning() {
        isScanning.toggle()
    }
    
    func clearPlanes() {
        detectedPlanes = 0
        onClearPlanes?()
    }
    
    func updatePlaneCount(_ count: Int) {
        detectedPlanes = count
    }
}

// MARK: - AR View Container
struct ARGridPlaneViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: LiDARScanView5Model
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 환경 조명 설정 (그림자 최소화)
        arView.environment.lighting.intensityExponent = 1.5
        arView.environment.lighting.resource = nil
        
        // AR Session Configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Enable scene reconstruction if available (LiDAR)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        // Enable frame semantics
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        
        arView.session.run(configuration)
        
        // Set coordinator as delegate
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        
        // Enable coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateGridVisibility()
        context.coordinator.updateGridSize()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var viewModel: LiDARScanView5Model
        var arView: ARView?
        var planeAnchors: [UUID: AnchorEntity] = [:]
        var lastUpdateTime: [UUID: Date] = [:]
        let updateInterval: TimeInterval = 0.5 // 최소 0.5초 간격으로 업데이트
        
        init(viewModel: LiDARScanView5Model) {
            self.viewModel = viewModel
            super.init()
            
            viewModel.onClearPlanes = { [weak self] in
                self?.clearAllPlanes()
            }
        }
        
        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    print("✅ 평면 감지됨: \(planeAnchor.alignment == .horizontal ? "수평" : "수직")")
                    addPlane(planeAnchor)
                }
            }
            updatePlaneCount()
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    updatePlane(planeAnchor)
                }
            }
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    removePlane(planeAnchor)
                }
            }
            updatePlaneCount()
        }
        
        // MARK: - Plane Management
        private func addPlane(_ planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }
            
            // Create anchor entity
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            
            // Create grid container
            let gridContainer = Entity()
            gridContainer.name = "grid"
            
            // Create grid lines using box shapes for better visibility
            createGridLines(for: planeAnchor, parent: gridContainer)
            
            // Add grid to anchor
            anchorEntity.addChild(gridContainer)
            
            // Store anchor entity
            planeAnchors[planeAnchor.identifier] = anchorEntity
            
            arView.scene.addAnchor(anchorEntity)
            
            updateGridVisibility()
        }
        
        private func updatePlane(_ planeAnchor: ARPlaneAnchor) {
            guard let anchorEntity = planeAnchors[planeAnchor.identifier] else { return }
            
            // 업데이트 빈도 제한 (깜빡임 방지)
            let now = Date()
            if let lastUpdate = lastUpdateTime[planeAnchor.identifier],
               now.timeIntervalSince(lastUpdate) < updateInterval {
                return
            }
            lastUpdateTime[planeAnchor.identifier] = now
            
            // Remove old grid and create new one
            if let gridContainer = anchorEntity.children.first(where: { $0.name == "grid" }) {
                gridContainer.removeFromParent()
            }
            
            let newGridContainer = Entity()
            newGridContainer.name = "grid"
            createGridLines(for: planeAnchor, parent: newGridContainer)
            anchorEntity.addChild(newGridContainer)
            
            updateGridVisibility()
        }
        
        private func removePlane(_ planeAnchor: ARPlaneAnchor) {
            if let anchorEntity = planeAnchors.removeValue(forKey: planeAnchor.identifier) {
                arView?.scene.removeAnchor(anchorEntity)
            }
        }
        
        private func clearAllPlanes() {
            guard let arView = arView else { return }
            
            // Remove all plane entities
            for (_, anchorEntity) in planeAnchors {
                arView.scene.removeAnchor(anchorEntity)
            }
            planeAnchors.removeAll()
            
            updatePlaneCount()
        }
        
        private func updatePlaneCount() {
            DispatchQueue.main.async {
                self.viewModel.updatePlaneCount(self.planeAnchors.count)
            }
        }
        
        // MARK: - Grid Creation
        private func createGridLines(for planeAnchor: ARPlaneAnchor, parent: Entity) {
            let extent = planeAnchor.planeExtent
            let width = extent.width
            let height = extent.height
            let gridSize = viewModel.gridSize
            let lineThickness: Float = 0.006
            
            // 평면에 최대한 밀착 (아주 작은 오프셋만 사용)
            let yOffset: Float = 0.0005
            
            // Choose color based on plane type
            let color: UIColor = planeAnchor.alignment == .horizontal ? .systemGreen : .systemCyan
            
            var material = SimpleMaterial()
            material.color = .init(tint: color)
            material.roughness = .init(floatLiteral: 1.0)
            material.metallic = .init(floatLiteral: 0.0)
            
            // 평면의 중심점 가져오기
            let center = planeAnchor.center
            
            // Create lines along X axis
            let numLinesX = Int(width / gridSize) + 1
            for i in 0..<numLinesX {
                let x = -width / 2 + Float(i) * gridSize
                let lineMesh = MeshResource.generateBox(width: lineThickness, height: lineThickness, depth: height)
                let lineEntity = ModelEntity(mesh: lineMesh, materials: [material])
                
                // 평면의 중심점을 고려한 위치 설정
                lineEntity.position = SIMD3<Float>(x + center.x, yOffset + center.y, center.z)
                
                parent.addChild(lineEntity)
            }
            
            // Create lines along Z axis
            let numLinesZ = Int(height / gridSize) + 1
            for i in 0..<numLinesZ {
                let z = -height / 2 + Float(i) * gridSize
                let lineMesh = MeshResource.generateBox(width: width, height: lineThickness, depth: lineThickness)
                let lineEntity = ModelEntity(mesh: lineMesh, materials: [material])
                
                // 평면의 중심점을 고려한 위치 설정
                lineEntity.position = SIMD3<Float>(center.x, yOffset + center.y, z + center.z)
                
                parent.addChild(lineEntity)
            }
        }
        
        // MARK: - Grid Visibility
        func updateGridVisibility() {
            for (_, anchorEntity) in planeAnchors {
                guard let planeAnchor = anchorEntity.anchor as? ARPlaneAnchor else { continue }
                
                let shouldShowGrid: Bool
                if planeAnchor.alignment == .horizontal {
                    shouldShowGrid = viewModel.showHorizontalPlanes && viewModel.showGrid
                } else {
                    shouldShowGrid = viewModel.showVerticalPlanes && viewModel.showGrid
                }
                
                // Update grid visibility
                if let gridEntity = anchorEntity.children.first(where: { $0.name == "grid" }) {
                    gridEntity.isEnabled = shouldShowGrid
                }
            }
        }
        
        func updateGridSize() {
            // Recreate all grids with new size
            for (_, anchorEntity) in planeAnchors {
                guard let planeAnchor = anchorEntity.anchor as? ARPlaneAnchor else { continue }
                
                if let gridContainer = anchorEntity.children.first(where: { $0.name == "grid" }) {
                    gridContainer.removeFromParent()
                }
                
                let newGridContainer = Entity()
                newGridContainer.name = "grid"
                createGridLines(for: planeAnchor, parent: newGridContainer)
                anchorEntity.addChild(newGridContainer)
            }
            
            updateGridVisibility()
        }
        
    }
}

// MARK: - ARPlaneAnchor Extension
extension ARPlaneAnchor {
    var planeExtent: (width: Float, height: Float) {
        let geometry = self.geometry
        let vertices = geometry.boundaryVertices
        
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity
        
        for vertex in vertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minZ = min(minZ, vertex.z)
            maxZ = max(maxZ, vertex.z)
        }
        
        return (width: maxX - minX, height: maxZ - minZ)
    }
}

#Preview {
    LiDARScanView5()
}
