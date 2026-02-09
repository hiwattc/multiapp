import SwiftUI
import SceneKit

// MARK: - OBJ File Viewer List
struct OBJFileViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var objFiles: [OBJFileInfo] = []
    @State private var selectedFile: OBJFileInfo?
    @State private var showViewer = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Safe Area Spacer
                Color.clear
                    .frame(height: 0)
                    .background(Color(UIColor.systemBackground))
                
                // Header
                ZStack {
                    // Title (Center)
                    Text("저장된 3D 스캔")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Buttons (Left & Right)
                    HStack {
                        // Close Button (Left)
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Refresh Button (Right)
                        Button(action: {
                            fetchOBJFiles()
                        }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                // File List
                if objFiles.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("저장된 3D 스캔이 없습니다")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("라이다6에서 '내보내기'를 눌러\n3D 스캔을 저장해보세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    Spacer()
                } else {
                    List {
                        ForEach(objFiles) { file in
                            Button(action: {
                                selectedFile = file
                                showViewer = true
                            }) {
                                HStack {
                                    Image(systemName: "cube.fill")
                                        .foregroundColor(.cyan)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(file.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(file.dateString)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if let size = file.fileSizeString {
                                            Text(size)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 8)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteFile(file)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .refreshable {
                        fetchOBJFiles()
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchOBJFiles()
            }
            .fullScreenCover(isPresented: $showViewer) {
                if let file = selectedFile {
                    OBJSceneViewer(objFile: file)
                }
            }
        }
    }
    
    private func fetchOBJFiles() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let folderName = "LiDAR_OBJ_FILES"
        let folderURL = documentsPath.appendingPathComponent(folderName)
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            let objFileInfos = fileURLs
                .filter { $0.pathExtension == "obj" }
                .compactMap { url -> OBJFileInfo? in
                    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attributes?[.size] as? Int64
                    let creationDate = attributes?[.creationDate] as? Date
                    
                    return OBJFileInfo(
                        name: url.lastPathComponent,
                        url: url,
                        fileSize: fileSize,
                        creationDate: creationDate ?? Date()
                    )
                }
                .sorted { $0.creationDate > $1.creationDate }
            
            objFiles = objFileInfos
            
            print("📂 OBJ 파일 \(objFiles.count)개 발견")
        } catch {
            print("⚠️ 파일 목록 로드 실패: \(error)")
            objFiles = []
        }
    }
    
    private func deleteFile(_ file: OBJFileInfo) {
        do {
            try FileManager.default.removeItem(at: file.url)
            print("🗑️ 파일 삭제: \(file.name)")
            fetchOBJFiles()
        } catch {
            print("❌ 파일 삭제 실패: \(error)")
        }
    }
}

// MARK: - OBJ File Info
struct OBJFileInfo: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let fileSize: Int64?
    let creationDate: Date
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: creationDate)
    }
    
    var fileSizeString: String? {
        guard let size = fileSize else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - View Mode
enum ViewMode {
    case orbit      // 외부에서 바라보는 뷰
    case firstPerson // 공간 내부 1인칭 뷰
    
    var icon: String {
        switch self {
        case .orbit: return "rotate.3d"
        case .firstPerson: return "figure.walk"
        }
    }
    
    var description: String {
        switch self {
        case .orbit: return "외부 뷰"
        case .firstPerson: return "내부 뷰"
        }
    }
}

// MARK: - OBJ Scene Viewer
struct OBJSceneViewer: View {
    @Environment(\.dismiss) private var dismiss
    let objFile: OBJFileInfo
    @State private var viewMode: ViewMode = .orbit
    @State private var isViewReady = false
    
    var body: some View {
        ZStack {
            // SceneKit Viewer (가장 아래 레이어)
            SceneKitViewWrapper(objFileURL: objFile.url, viewMode: $viewMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
                .zIndex(0)
                .onAppear {
                    isViewReady = true
                    print("✅ SceneKit Viewer 준비됨")
                }
            
            // UI Overlay (터치 이벤트는 버튼만 받도록, 위 레이어)
            VStack(spacing: 0) {
                
                // Top Bar
                HStack {
                    // Close Button (Left)
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    }
                    .allowsHitTesting(true)
                    
                    Spacer()
                        .allowsHitTesting(false)
                    
                    // File Info (Right)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(objFile.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(objFile.dateString)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .allowsHitTesting(false)
                }
                .padding()
                
                Spacer()
                    .allowsHitTesting(false)
                
                // View Mode Toggle Button
                Button(action: {
                    withAnimation {
                        viewMode = viewMode == .orbit ? .firstPerson : .orbit
                    }
                }) {
                    HStack {
                        Image(systemName: viewMode.icon)
                            .font(.title2)
                        Text(viewMode.description)
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(25)
                }
                .padding(.bottom, 10)
                .allowsHitTesting(true)
                
                // Instructions
                VStack(spacing: 8) {
                    if viewMode == .orbit {
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "hand.draw")
                                    .foregroundColor(.cyan)
                                Text("드래그: 회전")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            
                            HStack {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .foregroundColor(.green)
                                Text("핀치: 확대/축소")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    } else {
                        VStack(spacing: 6) {
                            HStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "hand.point.up")
                                        .foregroundColor(.cyan)
                                    Text("1손가락: 이동")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                
                                HStack {
                                    Image(systemName: "hand.point.up.left.and.text")
                                        .foregroundColor(.green)
                                    Text("2손가락: 회전")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Text("공간 내부를 걸어다니는 것처럼 탐색하세요")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    }
                }
                .padding(.bottom, 30)
                .allowsHitTesting(false)
            }
            .zIndex(1)
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }
}

// MARK: - SceneKit View Wrapper
struct SceneKitViewWrapper: UIViewRepresentable {
    let objFileURL: URL
    @Binding var viewMode: ViewMode
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewMode: $viewMode)
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = UIColor.darkGray
        
        // .obj 파일 로드
        guard let scene = try? SCNScene(url: objFileURL, options: nil) else {
            print("❌ OBJ 파일 로드 실패: \(objFileURL)")
            scnView.scene = SCNScene()
            return scnView
        }
        
        print("✅ OBJ 파일 로드 성공: \(objFileURL.lastPathComponent)")
        
        // 모든 노드를 부모 노드 아래로 병합 (중심 정렬용)
        let parentNode = SCNNode()
        scene.rootNode.childNodes.forEach { node in
            parentNode.addChildNode(node)
        }
        scene.rootNode.addChildNode(parentNode)
        
        // 재질 적용 (밝은 회색)
        parentNode.enumerateChildNodes { node, _ in
            if let geometry = node.geometry {
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.lightGray
                material.lightingModel = .physicallyBased
                material.isDoubleSided = true
                geometry.materials = [material]
            }
        }
        
        // 모델 중앙 정렬
        let (minVec, maxVec) = parentNode.boundingBox
        let centerX = (minVec.x + maxVec.x) / 2
        let centerY = (minVec.y + maxVec.y) / 2
        let centerZ = (minVec.z + maxVec.z) / 2
        parentNode.position = SCNVector3(-centerX, -centerY, -centerZ)
        
        // 바운딩 박스 정보 저장
        context.coordinator.modelBoundingBox = (minVec, maxVec)
        
        // 카메라 노드 생성
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.name = "mainCamera"
        
        // 외부 뷰용 기본 위치
        let maxDimension = max(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
        cameraNode.position = SCNVector3(0, 0, maxDimension * 2)
        
        scene.rootNode.addChildNode(cameraNode)
        context.coordinator.cameraNode = cameraNode
        
        // 방향성 조명
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 1000
        lightNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(lightNode)
        
        // 주변 조명
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.color = UIColor(white: 0.3, alpha: 1.0)
        scene.rootNode.addChildNode(ambientNode)
        
        // Scene 설정
        scnView.scene = scene
        
        // 카메라를 pointOfView로 명시적 설정
        scnView.pointOfView = cameraNode
        
        context.coordinator.sceneView = scnView
        
        print("📸 카메라 설정 완료 - 위치: \(cameraNode.position)")
        
        // First-Person 전용 제스처 생성
        context.coordinator.setupGestures()
        
        // 초기 렌더링 설정
        scnView.isPlaying = true
        scnView.loops = true
        
        // 초기 뷰 모드 설정 (약간의 지연 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateViewMode(scnView: scnView, coordinator: context.coordinator, viewMode: viewMode)
            scnView.setNeedsDisplay()
            print("🎬 SCNView 렌더링 시작")
        }
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 뷰 모드 변경 시
        if context.coordinator.currentViewMode != viewMode {
            print("🔄 뷰 모드 변경: \(viewMode)")
            
            // 기존 제스처 상태 저장
            let wasOrbit = context.coordinator.currentViewMode == .orbit
            
            // 뷰 모드 업데이트
            updateViewMode(scnView: uiView, coordinator: context.coordinator, viewMode: viewMode)
            context.coordinator.currentViewMode = viewMode
            
            // 렌더링 강제 업데이트
            DispatchQueue.main.async {
                uiView.setNeedsDisplay()
                print("✅ 뷰 모드 전환 완료: \(viewMode)")
            }
        }
    }
    
    private func updateViewMode(scnView: SCNView, coordinator: Coordinator, viewMode: ViewMode) {
        print("🎯 updateViewMode 호출: \(viewMode)")
        
        switch viewMode {
        case .orbit:
            // 외부 뷰 모드
            print("🌍 Orbit 모드 설정")
            
            // First-Person 제스처 먼저 제거
            coordinator.removeGestures(from: scnView)
            
            // SCNView 카메라 컨트롤 활성화
            scnView.allowsCameraControl = true
            
            // 카메라를 외부 위치로 재배치
            if let cameraNode = coordinator.cameraNode,
               let (minVec, maxVec) = coordinator.modelBoundingBox {
                let maxDimension = max(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
                
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                cameraNode.position = SCNVector3(0, 0, maxDimension * 2)
                cameraNode.eulerAngles = SCNVector3(0, 0, 0)
                SCNTransaction.commit()
                
                print("📸 카메라 위치: \(cameraNode.position)")
            }
            
        case .firstPerson:
            // 내부 뷰 모드
            print("🚶 First-Person 모드 설정")
            
            // SCNView 카메라 컨트롤 비활성화
            scnView.allowsCameraControl = false
            
            // 카메라를 공간 내부(바닥 높이)로 이동
            if let cameraNode = coordinator.cameraNode,
               let (minVec, _) = coordinator.modelBoundingBox {
                // 바닥보다 약간 위 (사람 눈높이)
                let eyeHeight: Float = 1.6 // 미터 단위
                
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                cameraNode.position = SCNVector3(0, minVec.y + eyeHeight, 0)
                cameraNode.eulerAngles = SCNVector3(0, 0, 0)
                SCNTransaction.commit()
                
                print("📸 카메라 위치: \(cameraNode.position)")
            }
            
            // First-Person 제스처 추가 (카메라 이동 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                coordinator.addGestures(to: scnView)
            }
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @Binding var viewMode: ViewMode
        var currentViewMode: ViewMode
        weak var sceneView: SCNView?
        var cameraNode: SCNNode?
        var modelBoundingBox: (SCNVector3, SCNVector3)?
        
        // First-Person 제스처
        private var panGesture: UIPanGestureRecognizer?
        private var twoFingerPanGesture: UIPanGestureRecognizer?
        
        // First-Person 이동 상태
        private var lastPanLocation: CGPoint?
        
        init(viewMode: Binding<ViewMode>) {
            self._viewMode = viewMode
            self.currentViewMode = viewMode.wrappedValue
        }
        
        func setupGestures() {
            // 한 손가락: 전후좌우 이동
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 1
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            pan.isEnabled = true
            panGesture = pan
            print("🔧 Pan 제스처 생성됨")
            
            // 두 손가락: 좌우 회전
            let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            twoFingerPan.delegate = self
            twoFingerPan.isEnabled = true
            twoFingerPanGesture = twoFingerPan
            print("🔧 TwoFingerPan 제스처 생성됨")
        }
        
        func addGestures(to view: SCNView) {
            // 이미 추가되어 있는지 확인
            let existingGestures = view.gestureRecognizers ?? []
            
            // 커스텀 제스처가 이미 있으면 추가하지 않음
            if let pan = panGesture, !existingGestures.contains(pan) {
                pan.isEnabled = true
                view.addGestureRecognizer(pan)
                print("✅ 이동 제스처 추가됨 (1손가락)")
            } else {
                panGesture?.isEnabled = true
                print("♻️ 이동 제스처 활성화됨")
            }
            
            if let twoFingerPan = twoFingerPanGesture, !existingGestures.contains(twoFingerPan) {
                twoFingerPan.isEnabled = true
                view.addGestureRecognizer(twoFingerPan)
                print("✅ 회전 제스처 추가됨 (2손가락)")
            } else {
                twoFingerPanGesture?.isEnabled = true
                print("♻️ 회전 제스처 활성화됨")
            }
            
            print("📱 현재 제스처: \(view.gestureRecognizers?.count ?? 0)개")
        }
        
        func removeGestures(from view: SCNView) {
            // 제스처를 제거하지 않고 비활성화만
            panGesture?.isEnabled = false
            twoFingerPanGesture?.isEnabled = false
            print("⏸️ First-Person 제스처 비활성화")
        }
        
        // UIGestureRecognizerDelegate 메서드들
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            print("👆 제스처 시작 가능: \(gestureRecognizer)")
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // 커스텀 제스처끼리는 동시 인식 허용
            if gestureRecognizer == panGesture || gestureRecognizer == twoFingerPanGesture {
                return true
            }
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            print("👆 터치 수신: \(touch.phase.rawValue)")
            return true
        }
        
        // 한 손가락: 이동
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            print("🖐️ handlePan 호출됨 - state: \(gesture.state.rawValue), touches: \(gesture.numberOfTouches)")
            
            guard viewMode == .firstPerson else {
                print("⚠️ First-Person 모드 아님")
                return
            }
            
            guard let cameraNode = cameraNode else {
                print("⚠️ 카메라 노드 없음")
                return
            }
            
            let translation = gesture.translation(in: gesture.view)
            
            switch gesture.state {
            case .began:
                lastPanLocation = gesture.location(in: gesture.view)
                print("🖐️ 이동 시작 - 위치: \(lastPanLocation!)")
                
            case .changed:
                // 이동 속도 조정 (더 빠르게)
                let moveSpeed: Float = 0.005
                
                // 카메라의 전방/우측 벡터 계산 (simd_float4 -> simd_float3)
                let cameraTransform = cameraNode.simdTransform
                let forward = simd_float3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
                let right = simd_float3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z)
                
                // 전후 이동 (Y 드래그)
                let forwardMove = forward * Float(translation.y) * moveSpeed
                
                // 좌우 이동 (X 드래그)
                let rightMove = right * Float(translation.x) * moveSpeed
                
                // 위치 업데이트 (Y축은 고정)
                let newPosition = cameraNode.simdPosition + forwardMove + rightMove
                cameraNode.simdPosition = simd_float3(newPosition.x, cameraNode.simdPosition.y, newPosition.z)
                
                print("📍 이동 중 - translation: \(translation), 새 위치: \(cameraNode.position)")
                
                gesture.setTranslation(.zero, in: gesture.view)
                
            case .ended, .cancelled:
                lastPanLocation = nil
                print("🖐️ 이동 종료")
                
            default:
                break
            }
        }
        
        // 두 손가락: 회전
        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard viewMode == .firstPerson,
                  let cameraNode = cameraNode else { return }
            
            let translation = gesture.translation(in: gesture.view)
            
            switch gesture.state {
            case .began:
                print("✌️ 회전 시작")
                
            case .changed:
                // 좌우 이동으로 Y축 회전
                let rotationSpeed: Float = 0.005
                let rotation = Float(translation.x) * rotationSpeed
                
                cameraNode.eulerAngles.y -= rotation
                
                gesture.setTranslation(.zero, in: gesture.view)
                
            case .ended, .cancelled:
                print("✌️ 회전 종료")
                
            default:
                break
            }
        }
    }
}

// MARK: - Preview
struct OBJFileViewerView_Previews: PreviewProvider {
    static var previews: some View {
        OBJFileViewerView()
    }
}
