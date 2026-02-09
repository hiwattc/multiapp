import SwiftUI
import ARKit
import RealityKit
import Combine
import MetalKit
import ModelIO

// MARK: - LiDAR Scan View 6 (GitHub Style - Simplified)
struct LiDARScanView6: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiDARScanView6Model()
    @State private var showOBJViewer = false
    
    var body: some View {
        ZStack {
            // AR View
            ARScanViewContainer6(viewModel: viewModel)
                .ignoresSafeArea(.all)
            
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
                        Text("LiDAR 6 - 자동 렌더링")
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
                        
                        Text("메시: \(viewModel.meshCount)개")
                            .font(.caption)
                            .foregroundColor(.cyan)
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
                            Image(systemName: "square.3.layers.3d.down.forward")
                                .foregroundColor(.cyan)
                            Text("ARKit 자동")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Image(systemName: "square.fill")
                                .foregroundColor(.green)
                            Text("지면")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Image(systemName: "square.fill")
                                .foregroundColor(.blue)
                            Text("벽면")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Image(systemName: "square.fill")
                                .foregroundColor(.orange)
                            Text("천장")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                }
                .padding(.bottom, 20)
                
                // Controls
                HStack(spacing: 15) {
                    // Start/Stop Scan
                    Button(action: {
                        viewModel.toggleScanning()
                    }) {
                        VStack {
                            Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 45))
                            Text(viewModel.isScanning ? "중지" : "시작")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(viewModel.isScanning ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        .cornerRadius(15)
                    }
                    
                    // Export to OBJ
                    Button(action: {
                        viewModel.exportToOBJ()
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 45))
                            Text("내보내기")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(15)
                    }
                    .disabled(viewModel.meshCount == 0)
                    .opacity(viewModel.meshCount == 0 ? 0.5 : 1.0)
                    
                    // View OBJ Files
                    Button(action: {
                        showOBJViewer = true
                    }) {
                        VStack {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 45))
                            Text("보기")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(15)
                    }
                    
                    // Reset Scan
                    Button(action: {
                        viewModel.resetScan()
                    }) {
                        VStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 45))
                            Text("초기화")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(15)
                    }
                }
                .padding(.bottom, 50)
            }
            
            // Success Alert
            if viewModel.showConfirmSuccess {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title)
                        Text("OBJ 파일 내보내기 완료!")
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
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showOBJViewer) {
            OBJFileViewerView()
        }
    }
}

// MARK: - AR Scan View Container (GitHub Style)
struct ARScanViewContainer6: UIViewRepresentable {
    @ObservedObject var viewModel: LiDARScanView6Model
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 카메라만 보여주는 기본 구성 (스캔 없이)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []  // 평면 감지 비활성화
        // sceneReconstruction은 설정하지 않음 (스캔 비활성화)
        
        // ARView 옵션
        arView.automaticallyConfigureSession = false
        
        // 카메라 화면 표시를 위해 기본 세션 시작
        arView.session.run(configuration)
        arView.session.delegate = context.coordinator
        
        context.coordinator.arView = arView
        context.coordinator.viewModel = viewModel
        viewModel.setARView(arView)
        
        print("📱 AR View 생성 완료 (카메라 활성화, 스캔 대기 중)")
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 스캔 상태 변화에 따라 구성 업데이트
        if viewModel.isScanning != context.coordinator.wasScanning {
            viewModel.updateScanningMode()
            context.coordinator.wasScanning = viewModel.isScanning
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        weak var viewModel: LiDARScanView6Model?
        var wasScanning: Bool = false
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let viewModel = viewModel,
                  viewModel.isScanning else { return }
            
            // 메시 카운트만 업데이트 (렌더링은 ARKit이 자동으로)
            let meshCount = anchors.filter { $0 is ARMeshAnchor }.count
            if meshCount > 0 {
                DispatchQueue.main.async {
                    viewModel.meshCount += meshCount
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // ARKit이 자동으로 처리
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard let viewModel = viewModel,
                  viewModel.isScanning else { return }
            
            let meshCount = anchors.filter { $0 is ARMeshAnchor }.count
            if meshCount > 0 {
                DispatchQueue.main.async {
                    viewModel.meshCount = max(0, viewModel.meshCount - meshCount)
                }
            }
        }
    }
}

// MARK: - LiDAR Scan View Model 6 (GitHub Style)
class LiDARScanView6Model: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var showConfirmSuccess: Bool = false
    @Published var meshCount: Int = 0
    
    weak var arView: ARView?
    
    func setARView(_ view: ARView) {
        self.arView = view
    }
    
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    func startScanning() {
        guard let arView = arView else {
            print("❌ AR View가 없습니다")
            return
        }
        
        print("🟢 스캔 시작 - GitHub 방식")
        
        // 스캔 활성화 구성
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .meshWithClassification
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        // Scene Understanding 활성화
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // 세션 재시작 (앵커는 유지)
        arView.session.run(configuration)
        
        isScanning = true
        meshCount = 0
        
        print("✅ LiDAR 스캔 활성화")
    }
    
    func stopScanning() {
        guard let arView = arView else { return }
        
        print("🔴 스캔 중지")
        
        // 스캔 비활성화 구성
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []  // 평면 감지 비활성화
        // sceneReconstruction 설정 안함 (스캔 비활성화)
        
        // Scene Understanding 비활성화
        arView.debugOptions.remove(.showSceneUnderstanding)
        
        // 카메라는 유지하되 스캔만 중지
        arView.session.run(configuration)
        
        isScanning = false
        print("📊 총 메시: \(meshCount)개")
    }
    
    func resetScan() {
        guard let arView = arView else { return }
        
        print("🔄 스캔 초기화")
        
        // 스캔 비활성화 구성
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        
        // Scene Understanding 비활성화
        arView.debugOptions.remove(.showSceneUnderstanding)
        
        // 트래킹과 앵커 모두 초기화
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        isScanning = false
        meshCount = 0
        
        print("✅ 스캔 초기화 완료")
    }
    
    func updateScanningMode() {
        // updateUIView에서 호출되는 메서드 (현재는 비어있음)
    }
    
    func exportToOBJ() {
        print("📤 OBJ 파일 내보내기 시작")
        
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame,
              let device = MTLCreateSystemDefaultDevice() else {
            print("❌ 내보내기 실패: AR 세션 또는 디바이스 없음")
            return
        }
        
        let camera = currentFrame.camera
        
        // GitHub 방식: 현재 프레임에서 모든 ARMeshAnchor 추출
        let meshAnchors = currentFrame.anchors.compactMap { $0 as? ARMeshAnchor }
        
        guard !meshAnchors.isEmpty else {
            print("❌ 내보낼 메시가 없습니다")
            return
        }
        
        print("📊 내보낼 메시: \(meshAnchors.count)개")
        
        // MDLAsset 생성
        let asset = MDLAsset()
        for anchor in meshAnchors {
            let mdlMesh = anchor.geometry.toMDLMesh(device: device, camera: camera, modelMatrix: anchor.transform)
            asset.add(mdlMesh)
        }
        
        // 파일로 저장
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderName = "LiDAR_OBJ_FILES"
        let folderURL = documentsPath.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "LiDAR_Scan_\(timestamp).obj"
            let fileURL = folderURL.appendingPathComponent(fileName)
            
            try asset.export(to: fileURL)
            
            print("✅ OBJ 파일 저장 완료: \(fileURL.path)")
            print("📂 저장 위치: \(folderURL.path)")
            
            // 성공 메시지 표시
            DispatchQueue.main.async {
                self.showConfirmSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.showConfirmSuccess = false
                }
            }
        } catch {
            print("❌ OBJ 파일 저장 실패: \(error)")
        }
    }
}

// MARK: - Preview
struct LiDARScanView6_Previews: PreviewProvider {
    static var previews: some View {
        LiDARScanView6()
    }
}
