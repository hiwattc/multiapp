import SwiftUI
import ARKit
import RealityKit
import Combine
import simd

// MARK: - LiDAR Scan View 4 (AR Grid Flashlight Effect)
struct LiDARScanView4: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiDARScanView4Model()
    
    var body: some View {
        ZStack {
            // AR View
            ARGridViewContainer(viewModel: viewModel)
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
                        Text("AR 그리드 + LiDAR")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.isLiDARActive ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(viewModel.isLiDARActive ? "LiDAR 활성" : "LiDAR 대기")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        if viewModel.pointCount > 0 {
                            Text("표면 포인트: \(viewModel.pointCount)")
                                .font(.caption)
                                .foregroundColor(.cyan)
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
                    Text("📱 기기를 움직여보세요")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("그리드의 각 교차점이 실제 표면에 투영됩니다")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("10×10")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                            Text("그리드")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("10cm")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("셀 크기")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text(String(format: "%.1fm", viewModel.gridDistance))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("거리")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    
                    // Controls
                    HStack(spacing: 20) {
                        // Distance Slider
                        VStack(spacing: 8) {
                            Text("그리드 거리")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("0.3m")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                
                                Slider(value: $viewModel.gridDistance, in: 0.3...2.0, step: 0.1)
                                    .accentColor(.cyan)
                                    .frame(width: 150)
                                
                                Text("2.0m")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Show Grid Toggle
                        VStack(spacing: 4) {
                            Toggle("", isOn: $viewModel.showLiDARPoints)
                                .labelsHidden()
                            Text(viewModel.showLiDARPoints ? "그리드 ON" : "그리드 OFF")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - View Model
class LiDARScanView4Model: ObservableObject {
    @Published var gridDistance: Float = 0.5
    @Published var showLiDARPoints: Bool = true
    @Published var isLiDARActive: Bool = false
    @Published var pointCount: Int = 0
}

// MARK: - AR Grid View Container
struct ARGridViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: LiDARScanView4Model
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        
        // AR Configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Enable LiDAR depth data
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            print("✅ LiDAR sceneDepth 활성화")
        }
        
        // Video format configuration for better performance
        let videoFormats = ARWorldTrackingConfiguration.supportedVideoFormats
        if let videoFormat = videoFormats.first {
            configuration.videoFormat = videoFormat
            print("📹 비디오 포맷: \(videoFormat.imageResolution.width)x\(videoFormat.imageResolution.height)")
        }
        
        // Scene setup
        arView.autoenablesDefaultLighting = true
        arView.showsStatistics = false
        
        // ARSCNView automatically shows camera feed - don't touch scene.background!
        // The camera feed is rendered by the AR session, not by SceneKit
        
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator
        
        // Start AR session
        arView.session.run(configuration)
        
        print("🎥 ARSCNView 초기화 완료 - 카메라 피드가 배경으로 표시됩니다")
        
        // Store reference
        context.coordinator.arView = arView
        
        // Create grid
        context.coordinator.createGrid(in: arView)
        
        // Create LiDAR point cloud node
        context.coordinator.createLiDARPointCloud(in: arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.updateGridDistance(viewModel.gridDistance)
        context.coordinator.updateLiDARVisibility(viewModel.showLiDARPoints)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        var viewModel: LiDARScanView4Model
        var arView: ARSCNView?
        var gridNode: SCNNode?
        var lidarPointCloudNode: SCNNode?
        var gridPointsNode: SCNNode?
        var updateTimer: Timer?
        
        init(viewModel: LiDARScanView4Model) {
            self.viewModel = viewModel
            super.init()
        }
        
        func createGrid(in arView: ARSCNView) {
            // Create grid node
            let gridNode = SCNNode()
            self.gridNode = gridNode
            
            // Grid parameters
            let gridSize = 10 // 10x10 grid
            let cellSize: Float = 0.1 // 10cm per cell
            
            // Create grid lines
            let gridGeometry = createGridGeometry(size: gridSize, cellSize: cellSize)
            let gridMaterial = SCNMaterial()
            gridMaterial.diffuse.contents = UIColor.cyan
            gridMaterial.emission.contents = UIColor.cyan.withAlphaComponent(0.3)
            gridMaterial.isDoubleSided = true
            gridGeometry.materials = [gridMaterial]
            
            let gridMesh = SCNNode(geometry: gridGeometry)
            gridNode.addChildNode(gridMesh)
            
            // Add to scene
            arView.scene.rootNode.addChildNode(gridNode)
            
            // Start update timer (30fps for better performance)
            updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
                self?.updateGridPosition(arView: arView)
                self?.updateGridPointsOnSurfaces(arView: arView)
            }
        }
        
        func createLiDARPointCloud(in arView: ARSCNView) {
            let pointCloudNode = SCNNode()
            self.lidarPointCloudNode = pointCloudNode
            arView.scene.rootNode.addChildNode(pointCloudNode)
            
            // Create node for grid intersection points
            let gridPointsNode = SCNNode()
            self.gridPointsNode = gridPointsNode
            arView.scene.rootNode.addChildNode(gridPointsNode)
        }
        
        func createGridGeometry(size: Int, cellSize: Float) -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            
            let totalSize = Float(size) * cellSize
            let halfSize = totalSize / 2.0
            
            // Vertical lines
            for i in 0...size {
                let x = Float(i) * cellSize - halfSize
                vertices.append(SCNVector3(x, -halfSize, 0))
                vertices.append(SCNVector3(x, halfSize, 0))
                
                let baseIndex = Int32(i * 2)
                indices.append(baseIndex)
                indices.append(baseIndex + 1)
            }
            
            // Horizontal lines
            for i in 0...size {
                let y = Float(i) * cellSize - halfSize
                vertices.append(SCNVector3(-halfSize, y, 0))
                vertices.append(SCNVector3(halfSize, y, 0))
                
                let baseIndex = Int32((size + 1) * 2 + i * 2)
                indices.append(baseIndex)
                indices.append(baseIndex + 1)
            }
            
            let vertexSource = SCNGeometrySource(vertices: vertices)
            let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
            let element = SCNGeometryElement(
                data: indexData,
                primitiveType: .line,
                primitiveCount: indices.count / 2,
                bytesPerIndex: MemoryLayout<Int32>.size
            )
            
            return SCNGeometry(sources: [vertexSource], elements: [element])
        }
        
        func updateGridPosition(arView: ARSCNView) {
            guard let gridNode = gridNode,
                  let camera = arView.pointOfView else { return }
            
            // Get camera transform
            let cameraTransform = camera.transform
            let cameraPosition = SCNVector3(
                cameraTransform.m41,
                cameraTransform.m42,
                cameraTransform.m43
            )
            
            // Get camera forward direction
            let cameraForward = SCNVector3(
                -cameraTransform.m31,
                -cameraTransform.m32,
                -cameraTransform.m33
            )
            
            // Position grid in front of camera
            let distance = viewModel.gridDistance
            let gridPosition = SCNVector3(
                cameraPosition.x + cameraForward.x * distance,
                cameraPosition.y + cameraForward.y * distance,
                cameraPosition.z + cameraForward.z * distance
            )
            
            gridNode.position = gridPosition
            
            // Make grid face the camera
            gridNode.look(at: cameraPosition, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
        }
        
        func updateGridDistance(_ distance: Float) {
            // Distance is updated via the timer
        }
        
        func updateLiDARVisibility(_ visible: Bool) {
            gridNode?.isHidden = !visible
            gridPointsNode?.isHidden = !visible
        }
        
        func updateGridPointsOnSurfaces(arView: ARSCNView) {
            guard let gridPointsNode = gridPointsNode,
                  let camera = arView.pointOfView,
                  let currentFrame = arView.session.currentFrame else { return }
            
            // Remove old points
            gridPointsNode.childNodes.forEach { $0.removeFromParentNode() }
            
            // Grid parameters
            let gridSize = 10
            let cellSize: Float = 0.1
            let totalSize = Float(gridSize) * cellSize
            let halfSize = totalSize / 2.0
            
            // Get camera transform
            let cameraTransform = camera.transform
            let cameraPosition = SCNVector3(
                cameraTransform.m41,
                cameraTransform.m42,
                cameraTransform.m43
            )
            
            // Get camera orientation vectors
            let cameraForward = SCNVector3(
                -cameraTransform.m31,
                -cameraTransform.m32,
                -cameraTransform.m33
            )
            
            let cameraRight = SCNVector3(
                cameraTransform.m11,
                cameraTransform.m12,
                cameraTransform.m13
            )
            
            let cameraUp = SCNVector3(
                cameraTransform.m21,
                cameraTransform.m22,
                cameraTransform.m23
            )
            
            // Grid center position
            let distance = viewModel.gridDistance
            let gridCenter = SCNVector3(
                cameraPosition.x + cameraForward.x * distance,
                cameraPosition.y + cameraForward.y * distance,
                cameraPosition.z + cameraForward.z * distance
            )
            
            // Perform raycast for each grid intersection point
            for i in 0...gridSize {
                for j in 0...gridSize {
                    let x = Float(i) * cellSize - halfSize
                    let y = Float(j) * cellSize - halfSize
                    
                    // Calculate world position of grid point
                    let gridPoint = SCNVector3(
                        gridCenter.x + cameraRight.x * x + cameraUp.x * y,
                        gridCenter.y + cameraRight.y * x + cameraUp.y * y,
                        gridCenter.z + cameraRight.z * x + cameraUp.z * y
                    )
                    
                    // Direction from camera to grid point
                    let direction = SCNVector3(
                        gridPoint.x - cameraPosition.x,
                        gridPoint.y - cameraPosition.y,
                        gridPoint.z - cameraPosition.z
                    )
                    
                    // Normalize direction
                    let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
                    let normalizedDirection = SCNVector3(
                        direction.x / length,
                        direction.y / length,
                        direction.z / length
                    )
                    
                    // Perform ARKit raycast with multiple targets for better detection
                    let rayOrigin = simd_float3(cameraPosition.x, cameraPosition.y, cameraPosition.z)
                    let rayDirection = simd_float3(normalizedDirection.x, normalizedDirection.y, normalizedDirection.z)
                    
                    // Try existing planes first (most accurate)
                    var query = ARRaycastQuery(
                        origin: rayOrigin,
                        direction: rayDirection,
                        allowing: .existingPlaneGeometry,
                        alignment: .any
                    )
                    
                    var results = arView.session.raycast(query)
                    
                    // If no hit, try estimated planes
                    if results.isEmpty {
                        query = ARRaycastQuery(
                            origin: rayOrigin,
                            direction: rayDirection,
                            allowing: .estimatedPlane,
                            alignment: .any
                        )
                        results = arView.session.raycast(query)
                    }
                    
                    // If still no hit and LiDAR is available, try existing plane infinite
                    if results.isEmpty {
                        query = ARRaycastQuery(
                            origin: rayOrigin,
                            direction: rayDirection,
                            allowing: .existingPlaneInfinite,
                            alignment: .any
                        )
                        results = arView.session.raycast(query)
                    }
                    
                    if let result = results.first {
                        // Hit detected - place a marker at the intersection point
                        let hitPosition = result.worldTransform.columns.3
                        let markerPosition = SCNVector3(hitPosition.x, hitPosition.y, hitPosition.z)
                        
                        // Calculate distance for color
                        let hitDistance = sqrt(
                            pow(hitPosition.x - cameraPosition.x, 2) +
                            pow(hitPosition.y - cameraPosition.y, 2) +
                            pow(hitPosition.z - cameraPosition.z, 2)
                        )
                        
                        // Create marker sphere
                        let sphere = SCNSphere(radius: 0.01) // 1cm radius
                        let sphereMaterial = SCNMaterial()
                        
                        // Color based on distance
                        let normalizedDistance = min(hitDistance / 3.0, 1.0)
                        let color = depthToColor(normalizedDistance)
                        sphereMaterial.diffuse.contents = color
                        sphereMaterial.emission.contents = color.withAlphaComponent(0.5)
                        sphereMaterial.lightingModel = .constant
                        sphere.materials = [sphereMaterial]
                        
                        let sphereNode = SCNNode(geometry: sphere)
                        sphereNode.position = markerPosition
                        gridPointsNode.addChildNode(sphereNode)
                    }
                }
            }
            
            // Update point count
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.viewModel.pointCount = gridPointsNode.childNodes.count
                self.viewModel.isLiDARActive = gridPointsNode.childNodes.count > 0
            }
        }
        
        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Grid points are updated by timer, not by frame updates
            // This improves performance significantly
        }
        
        func depthToColor(_ depth: Float) -> UIColor {
            // Rainbow color mapping
            let hue = CGFloat(1.0 - depth) * 0.7 // 0.7 = blue to red
            return UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 0.8)
        }
        
        // ARSCNViewDelegate methods
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("AR Session failed: \(error.localizedDescription)")
        }
        
        func sessionWasInterrupted(_ session: ARSession) {
            print("AR Session was interrupted")
        }
        
        func sessionInterruptionEnded(_ session: ARSession) {
            print("AR Session interruption ended")
        }
    }
}

// MARK: - Preview
#Preview {
    LiDARScanView4()
}
