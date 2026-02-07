import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - AR Balloon Game View
struct GameARBalloonView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GameARBalloonViewModel()
    
    var body: some View {
        ZStack {
            // AR View
            ARBalloonViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // 십자선 (화면 중앙)
            if viewModel.isGameStarted && !viewModel.isGameOver {
                CrosshairView()
            }
            
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
                        HStack {
                            Image(systemName: "balloon.fill")
                                .foregroundColor(.pink)
                            Text("점수: \(viewModel.score)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.green)
                            Text("터트린 풍선: \(viewModel.poppedCount)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.yellow)
                            Text("시간: \(Int(viewModel.timeRemaining))초")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                // 발사 버튼
                if viewModel.isGameStarted && !viewModel.isGameOver {
                    Button(action: {
                        viewModel.shootArrow()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red.opacity(0.3)))
                    }
                    .padding(.bottom, 50)
                }
                
                // Instructions
                if !viewModel.isGameStarted {
                    VStack(spacing: 16) {
                        Text("🎈 풍선 터트리기")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("바닥을 스캔한 후\n화면을 탭해서 게임을 시작하세요!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        if viewModel.planeDetected {
                            Text("✅ 바닥이 인식되었습니다!")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else {
                            Text("바닥을 스캔하고 있습니다...")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding()
                }
                
                // Game Over
                if viewModel.isGameOver {
                    VStack(spacing: 20) {
                        Text("게임 종료!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("최종 점수: \(viewModel.score)")
                            .font(.title2)
                            .foregroundColor(.yellow)
                        
                        Text("터트린 풍선: \(viewModel.poppedCount)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            viewModel.resetGame()
                        }) {
                            Text("다시 시작")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 60)
                                .background(Color.green)
                                .cornerRadius(15)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Crosshair View
struct CrosshairView: View {
    var body: some View {
        ZStack {
            // 수평선
            Rectangle()
                .fill(Color.white)
                .frame(width: 40, height: 2)
            
            // 수직선
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 40)
            
            // 중앙 점
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            
            // 외곽 원
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)
        }
        .shadow(color: .black, radius: 2)
    }
}

// MARK: - AR Balloon View Container
struct ARBalloonViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: GameARBalloonViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 구성
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        // 세션 델리게이트 설정
        arView.session.delegate = context.coordinator
        
        // ViewModel에 ARView 설정
        viewModel.setARView(arView)
        
        // 코디네이터 설정
        context.coordinator.arView = arView
        context.coordinator.viewModel = viewModel
        
        // 탭 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 업데이트 필요시 구현
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        weak var viewModel: GameARBalloonViewModel?
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    viewModel.addPlaneAnchor(planeAnchor)
                }
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView, let viewModel = viewModel else { return }
            
            let location = gesture.location(in: arView)
            
            // 게임이 시작되지 않았으면 시작
            if !viewModel.isGameStarted {
                let raycastResults = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
                
                if let firstResult = raycastResults.first {
                    viewModel.startGame(at: firstResult.worldTransform)
                } else {
                    let estimatedResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
                    if let firstResult = estimatedResults.first {
                        viewModel.startGame(at: firstResult.worldTransform)
                    }
                }
            }
        }
    }
}

// MARK: - AR Balloon Game View Model
class GameARBalloonViewModel: ObservableObject {
    @Published var score: Int = 0
    @Published var poppedCount: Int = 0
    @Published var timeRemaining: Double = 60.0
    @Published var isGameStarted: Bool = false
    @Published var isGameOver: Bool = false
    @Published var planeDetected: Bool = false
    
    weak var arView: ARView?
    private var balloons: [UUID: ModelEntity] = [:]
    private var balloonAnchors: [UUID: AnchorEntity] = [:]
    private var balloonShadows: [UUID: ModelEntity] = [:]
    private var arrows: [ModelEntity] = []
    private var gameTimer: Timer?
    private var groundY: Float = 0.0
    private var gameStartPosition: simd_float4x4?
    
    func setARView(_ view: ARView) {
        self.arView = view
    }
    
    func addPlaneAnchor(_ anchor: ARPlaneAnchor) {
        DispatchQueue.main.async {
            self.planeDetected = true
        }
        
        // 바닥 Y 위치 저장
        let planeY = anchor.transform.columns.3.y
        if groundY == 0.0 || planeY < groundY {
            groundY = planeY
        }
    }
    
    func startGame(at transform: simd_float4x4) {
        guard let arView = arView, !isGameStarted else { return }
        
        gameStartPosition = transform
        isGameStarted = true
        isGameOver = false
        score = 0
        poppedCount = 0
        timeRemaining = 60.0
        
        // 바닥 Y 위치 설정 (게임 시작 위치를 바닥으로 설정)
        groundY = transform.columns.3.y
        print("🎮 게임 시작! 바닥 Y 위치: \(groundY)")
        
        // 100개의 풍선을 한번에 생성
        for _ in 0..<100 {
            spawnBalloon()
        }
        
        // 20개의 이모티콘 풍선 생성
        for _ in 0..<20 {
            spawnEmojiBalloon()
        }
        
        // 게임 타이머
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isGameStarted && !self.isGameOver else {
                timer.invalidate()
                return
            }
            
            self.timeRemaining -= 0.1
            
            if self.timeRemaining <= 0 {
                self.endGame()
                timer.invalidate()
            }
        }
    }
    
    func spawnBalloon() {
        guard let arView = arView else { return }
        
        // 랜덤 위치 (공중에서 시작)
        let randomX = Float.random(in: -3.0...3.0)
        let randomZ = Float.random(in: -3.0...3.0)
        let randomY = groundY + Float.random(in: 0.5...3.0) // 바닥에서 0.5m ~ 3m 높이
        
        let position = SIMD3<Float>(randomX, randomY, randomZ)
        
        // 랜덤 색상
        let colors: [UIColor] = [.red, .blue, .green, .yellow, .purple, .orange, .cyan, .magenta, .systemPink]
        let randomColor = colors.randomElement() ?? .red
        
        // 풍선 모델 생성 (구체 - 2배 크게)
        let balloonMesh = MeshResource.generateSphere(radius: 0.3)
        let material = SimpleMaterial(color: randomColor, isMetallic: false)
        let balloon = ModelEntity(mesh: balloonMesh, materials: [material])
        
        // 충돌 컴포넌트 (터치 감지용 - 2배 크게)
        let shape = ShapeResource.generateSphere(radius: 0.3)
        balloon.collision = CollisionComponent(shapes: [shape])
        
        // Input Target 추가 (터치 가능하게)
        balloon.components.set(InputTargetComponent())
        
        // 앵커 생성
        let anchor = AnchorEntity(world: position)
        anchor.addChild(balloon)
        arView.scene.addAnchor(anchor)
        
        // 그림자 생성 (원형으로 변경)
        let shadowMesh = MeshResource.generatePlane(width: 0.6, depth: 0.6)
        var shadowMaterial = SimpleMaterial(
            color: UIColor.black.withAlphaComponent(0.4),
            isMetallic: false
        )
        // 원형 그림자를 위한 텍스처 (간단히 구현)
        let shadow = ModelEntity(mesh: shadowMesh, materials: [shadowMaterial])
        
        // 원형 마스크 효과를 위해 스케일 조정
        shadow.scale = SIMD3<Float>(1.0, 1.0, 1.0)
        
        // 그림자를 바닥에 배치
        let shadowAnchor = AnchorEntity(world: SIMD3<Float>(position.x, groundY + 0.01, position.z))
        shadowAnchor.addChild(shadow)
        arView.scene.addAnchor(shadowAnchor)
        
        let balloonId = UUID()
        balloons[balloonId] = balloon
        balloonAnchors[balloonId] = anchor
        balloonShadows[balloonId] = shadow
        
        // 풍선을 공중에서 떠다니게 하는 애니메이션
        animateBalloonFloat(balloon: balloon, anchor: anchor, shadow: shadow, shadowAnchor: shadowAnchor, balloonId: balloonId)
    }
    
    func animateBalloonFloat(balloon: ModelEntity, anchor: AnchorEntity, shadow: ModelEntity, shadowAnchor: AnchorEntity, balloonId: UUID) {
        let initialPosition = anchor.position(relativeTo: nil)
        
        // 랜덤한 움직임 속도와 범위
        let speedX = Float.random(in: 0.5...2.0)
        let speedY = Float.random(in: 0.5...2.0)
        let speedZ = Float.random(in: 0.5...2.0)
        let rangeX = Float.random(in: 0.3...0.8)
        let rangeY = Float.random(in: 0.2...0.5)
        let rangeZ = Float.random(in: 0.3...0.8)
        
        // 랜덤한 시작 오프셋 (각 풍선이 다른 타이밍으로 움직이도록)
        let offsetX = Float.random(in: 0...Float.pi * 2)
        let offsetY = Float.random(in: 0...Float.pi * 2)
        let offsetZ = Float.random(in: 0...Float.pi * 2)
        
        var elapsed: Float = 0.0
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if !self.isGameStarted || self.isGameOver {
                timer.invalidate()
                return
            }
            
            elapsed += 0.016
            
            // 사인파를 사용한 부드러운 움직임
            let moveX = sin(elapsed * speedX + offsetX) * rangeX
            let moveY = sin(elapsed * speedY + offsetY) * rangeY
            let moveZ = sin(elapsed * speedZ + offsetZ) * rangeZ
            
            let newPosition = SIMD3<Float>(
                initialPosition.x + moveX,
                initialPosition.y + moveY,
                initialPosition.z + moveZ
            )
            
            anchor.position = newPosition
            
            // 그림자 위치 업데이트 (풍선 X, Z 위치에 따라)
            shadowAnchor.position = SIMD3<Float>(newPosition.x, self.groundY + 0.01, newPosition.z)
            
            // 그림자 크기 조정 (높이에 따라)
            let heightFromGround = newPosition.y - self.groundY
            let shadowScale = max(0.3, 1.0 - (heightFromGround / 5.0)) // 높을수록 작아짐
            shadow.scale = SIMD3<Float>(shadowScale, 1.0, shadowScale)
            
            // 풍선 자체도 살짝 회전
            let rotationY = sin(elapsed * 1.0) * 0.3
            balloon.orientation = simd_quatf(angle: rotationY, axis: SIMD3<Float>(0, 1, 0))
        }
    }
    
    func spawnEmojiBalloon() {
        guard let arView = arView else { return }
        
        // 랜덤 위치 (공중에서 시작)
        let randomX = Float.random(in: -3.0...3.0)
        let randomZ = Float.random(in: -3.0...3.0)
        let randomY = groundY + Float.random(in: 0.5...3.0)
        
        let position = SIMD3<Float>(randomX, randomY, randomZ)
        
        // 다양한 이모티콘
        let emojis = ["😀", "😁", "😂", "🤣", "😃", "😄", "😅", "😆", "😉", "😊", 
                      "😋", "😎", "😍", "😘", "🥰", "🤩", "🤗", "🤔", "🤪", "😜",
                      "🎈", "🎉", "🎊", "🎁", "🎀", "🌟", "⭐", "✨", "💫", "🌈",
                      "🦄", "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨",
                      "🍎", "🍌", "🍇", "🍊", "🍋", "🍉", "🍓", "🍑", "🍒", "🥝"]
        let randomEmoji = emojis.randomElement() ?? "😀"
        
        // 이모티콘 이미지 생성
        let emojiImage = createEmojiImage(emoji: randomEmoji, size: 512)
        
        // 텍스처 생성
        guard let cgImage = emojiImage.cgImage else { return }
        let textureResource = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
        
        // 구체 메시에 이모티콘 텍스처 적용 (3D 입체 풍선)
        let emojiBalloonMesh = MeshResource.generateSphere(radius: 0.3)
        var emojiBalloonMaterial = SimpleMaterial()
        if let texture = textureResource {
            emojiBalloonMaterial.color = .init(texture: .init(texture))
        } else {
            emojiBalloonMaterial.color = .init(tint: .white)
        }
        emojiBalloonMaterial.metallic = .init(floatLiteral: 0.0)
        emojiBalloonMaterial.roughness = .init(floatLiteral: 0.8)
        
        let emojiBalloon = ModelEntity(mesh: emojiBalloonMesh, materials: [emojiBalloonMaterial])
        
        // 충돌 컴포넌트 (구체)
        let shape = ShapeResource.generateSphere(radius: 0.3)
        emojiBalloon.collision = CollisionComponent(shapes: [shape])
        emojiBalloon.components.set(InputTargetComponent())
        
        // 앵커 생성
        let anchor = AnchorEntity(world: position)
        anchor.addChild(emojiBalloon)
        arView.scene.addAnchor(anchor)
        
        // 그림자 생성
        let shadowMesh = MeshResource.generatePlane(width: 0.6, depth: 0.6)
        let shadowMaterial = SimpleMaterial(
            color: UIColor.black.withAlphaComponent(0.4),
            isMetallic: false
        )
        let shadow = ModelEntity(mesh: shadowMesh, materials: [shadowMaterial])
        shadow.scale = SIMD3<Float>(1.0, 1.0, 1.0)
        shadow.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        
        let shadowAnchor = AnchorEntity(world: SIMD3<Float>(position.x, groundY + 0.01, position.z))
        shadowAnchor.addChild(shadow)
        arView.scene.addAnchor(shadowAnchor)
        
        let emojiId = UUID()
        balloons[emojiId] = emojiBalloon
        balloonAnchors[emojiId] = anchor
        balloonShadows[emojiId] = shadow
        
        // 이모티콘 풍선 애니메이션 (부유 + 회전)
        animateEmojiBalloonFloat(emojiBalloon: emojiBalloon, anchor: anchor, shadow: shadow, shadowAnchor: shadowAnchor, emojiId: emojiId)
    }
    
    func createEmojiImage(emoji: String, size: Int) -> UIImage {
        let fontSize = CGFloat(size) * 0.8
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let emojiSize = (emoji as NSString).size(withAttributes: attributes)
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            // 투명 배경
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            
            // 이모티콘 중앙에 그리기
            let x = (CGFloat(size) - emojiSize.width) / 2
            let y = (CGFloat(size) - emojiSize.height) / 2
            (emoji as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
        }
        
        return image
    }
    
    func animateEmojiBalloonFloat(emojiBalloon: ModelEntity, anchor: AnchorEntity, shadow: ModelEntity, shadowAnchor: AnchorEntity, emojiId: UUID) {
        let initialPosition = anchor.position(relativeTo: nil)
        
        // 랜덤한 움직임 속도와 범위
        let speedX = Float.random(in: 0.5...2.0)
        let speedY = Float.random(in: 0.5...2.0)
        let speedZ = Float.random(in: 0.5...2.0)
        let rangeX = Float.random(in: 0.3...0.8)
        let rangeY = Float.random(in: 0.2...0.5)
        let rangeZ = Float.random(in: 0.3...0.8)
        
        let offsetX = Float.random(in: 0...Float.pi * 2)
        let offsetY = Float.random(in: 0...Float.pi * 2)
        let offsetZ = Float.random(in: 0...Float.pi * 2)
        
        // 랜덤 회전 속도
        let rotationSpeed = Float.random(in: 0.5...1.5)
        
        var elapsed: Float = 0.0
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if !self.isGameStarted || self.isGameOver {
                timer.invalidate()
                return
            }
            
            elapsed += 0.016
            
            // 사인파를 사용한 부드러운 움직임
            let moveX = sin(elapsed * speedX + offsetX) * rangeX
            let moveY = sin(elapsed * speedY + offsetY) * rangeY
            let moveZ = sin(elapsed * speedZ + offsetZ) * rangeZ
            
            let newPosition = SIMD3<Float>(
                initialPosition.x + moveX,
                initialPosition.y + moveY,
                initialPosition.z + moveZ
            )
            
            anchor.position = newPosition
            
            // 그림자 위치 업데이트
            shadowAnchor.position = SIMD3<Float>(newPosition.x, self.groundY + 0.01, newPosition.z)
            
            // 그림자 크기 조정 (높이에 따라)
            let heightFromGround = newPosition.y - self.groundY
            let shadowScale = max(0.3, 1.0 - (heightFromGround / 5.0))
            shadow.scale = SIMD3<Float>(shadowScale, 1.0, shadowScale)
            
            // 이모티콘 풍선 자체 회전 (입체감 강조)
            let rotationY = elapsed * rotationSpeed
            let rotationX = sin(elapsed * 0.5) * 0.3
            emojiBalloon.orientation = simd_quatf(angle: rotationY, axis: SIMD3<Float>(0, 1, 0)) * 
                                       simd_quatf(angle: rotationX, axis: SIMD3<Float>(1, 0, 0))
        }
    }
    
    func shootArrow() {
        guard let arView = arView else { return }
        
        // 카메라 위치와 방향
        let cameraTransform = arView.cameraTransform.matrix
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let cameraForward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        
        // 총알 생성 (작은 구체, 빛나게)
        let bulletMesh = MeshResource.generateSphere(radius: 0.015)
        var bulletMaterial = UnlitMaterial(color: .yellow)
        bulletMaterial.color = .init(tint: .yellow)
        let bullet = ModelEntity(mesh: bulletMesh, materials: [bulletMaterial])
        
        // 총알 위치 (카메라에서 좀 더 앞에서 시작)
        let bulletStartPosition = cameraPosition + cameraForward * 0.3
        let bulletAnchor = AnchorEntity(world: bulletStartPosition)
        bulletAnchor.addChild(bullet)
        arView.scene.addAnchor(bulletAnchor)
        
        arrows.append(bullet)
        
        // 총알 발사 애니메이션 (2배 빠르게)
        animateArrow(arrow: bullet, anchor: bulletAnchor, direction: cameraForward, startPosition: bulletStartPosition)
        
        // 햅틱 피드백 (총알 발사)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    func animateArrow(arrow: ModelEntity, anchor: AnchorEntity, direction: SIMD3<Float>, startPosition: SIMD3<Float>) {
        let speed: Float = 10.0 // 초당 10m (2배 빠르게)
        var elapsed: Float = 0.0
        let maxDuration: Float = 3.0
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            elapsed += 0.016
            
            if elapsed >= maxDuration {
                // 화살이 최대 거리에 도달하면 폭발 효과 후 제거
                let finalPosition = anchor.position(relativeTo: nil)
                self.createSurfaceExplosion(at: finalPosition)
                
                // 화살 제거
                if let arView = self.arView {
                    arView.scene.removeAnchor(anchor)
                }
                self.arrows.removeAll { $0 === arrow }
                timer.invalidate()
                return
            }
            
            // 화살 이동
            let distance = speed * elapsed
            let newPosition = startPosition + direction * distance
            anchor.position = newPosition
            
            // 바닥이나 벽과의 충돌 체크
            if self.checkSurfaceCollision(arrowPosition: newPosition) {
                // 표면에 충돌하면 폭발 효과
                self.createSurfaceExplosion(at: newPosition)
                
                // 화살 제거
                if let arView = self.arView {
                    arView.scene.removeAnchor(anchor)
                }
                self.arrows.removeAll { $0 === arrow }
                timer.invalidate()
                return
            }
            
            // 풍선과 충돌 체크
            self.checkArrowCollision(arrowPosition: newPosition, arrow: arrow, anchor: anchor, timer: timer)
        }
    }
    
    func checkSurfaceCollision(arrowPosition: SIMD3<Float>) -> Bool {
        // 바닥과의 충돌 체크 (화살이 바닥 아래로 가면)
        if arrowPosition.y <= groundY + 0.05 {
            return true
        }
        
        // 벽 충돌은 ARKit의 raycast로 체크할 수 있지만, 간단히 거리로 체크
        // 시작 위치에서 너무 멀리 가면 벽에 부딪혔다고 가정
        if let startPos = gameStartPosition {
            let startPosition = SIMD3<Float>(startPos.columns.3.x, startPos.columns.3.y, startPos.columns.3.z)
            let distance = length(arrowPosition - startPosition)
            if distance > 10.0 {
                return true
            }
        }
        
        return false
    }
    
    func createSurfaceExplosion(at position: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        // 파티클 효과 (10개, 크기 2배 더 크게)
        for _ in 0..<10 {
            let fragmentMesh = MeshResource.generateSphere(radius: Float.random(in: 0.09...0.18))
            let fragmentColor = [UIColor.orange, UIColor.red, UIColor.yellow, UIColor.white].randomElement() ?? .orange
            let fragmentMaterial = UnlitMaterial(color: fragmentColor)
            let fragment = ModelEntity(mesh: fragmentMesh, materials: [fragmentMaterial])
            
            let fragmentAnchor = AnchorEntity(world: position)
            fragmentAnchor.addChild(fragment)
            arView.scene.addAnchor(fragmentAnchor)
            
            // 랜덤 방향으로 날아가기 (속도 3배)
            let velocity = SIMD3<Float>(
                Float.random(in: -3.0...3.0),
                Float.random(in: 0.5...3.0),
                Float.random(in: -3.0...3.0)
            )
            
            var currentVelocity = velocity
            let gravity: Float = -8.0
            var fragmentElapsed: Float = 0.0
            let maxDuration: Float = 1.0
            
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                fragmentElapsed += 0.016
                
                if fragmentElapsed > maxDuration {
                    fragmentAnchor.removeFromParent()
                    timer.invalidate()
                    return
                }
                
                // 중력 적용
                currentVelocity.y += gravity * 0.016
                
                // 위치 업데이트
                var fragmentPosition = fragmentAnchor.position(relativeTo: nil)
                fragmentPosition += currentVelocity * 0.016
                fragmentAnchor.position = fragmentPosition
                
                // 회전 추가
                let rotation = simd_quatf(angle: 0.3, axis: normalize(velocity))
                fragment.orientation = fragment.orientation * rotation
                
                // 페이드 아웃
                let alpha = max(0, 1.0 - fragmentElapsed / maxDuration)
                if let material = fragment.model?.materials.first as? UnlitMaterial {
                    var fadeMaterial = UnlitMaterial(color: material.color.tint)
                    fadeMaterial.color = .init(tint: material.color.tint.withAlphaComponent(CGFloat(alpha)))
                    fragment.model?.materials = [fadeMaterial]
                }
            }
        }
        
        // 햅틱 피드백 (강력하게)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    func checkArrowCollision(arrowPosition: SIMD3<Float>, arrow: ModelEntity, anchor: AnchorEntity, timer: Timer) {
        // 풍선과의 충돌 검사
        for (balloonId, balloon) in balloons {
            guard let balloonAnchor = balloonAnchors[balloonId] else { continue }
            
            let balloonPosition = balloonAnchor.position(relativeTo: nil)
            let distance = length(arrowPosition - balloonPosition)
            
            if distance < 0.4 { // 충돌 거리 (풍선이 커졌으므로 증가)
                // 풍선 터트리기
                popBalloonWithExplosion(balloonId: balloonId, position: balloonPosition)
                
                // 화살 제거
                if let arView = arView {
                    arView.scene.removeAnchor(anchor)
                }
                arrows.removeAll { $0 === arrow }
                timer.invalidate()
                return
            }
        }
        
    }
    
    func popBalloonWithExplosion(balloonId: UUID, position: SIMD3<Float>) {
        guard let balloon = balloons[balloonId],
              let arView = arView else { return }
        
        // 점수 증가
        score += 10
        poppedCount += 1
        
        // 폭발 효과 생성
        createExplosionEffect(at: position, color: balloon.model?.materials.first as? SimpleMaterial)
        
        // 풍선 제거
        removeBalloon(balloonId: balloonId)
        
        // 햅틱 피드백 (강력하게)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func createExplosionEffect(at position: SIMD3<Float>, color: SimpleMaterial?) {
        guard let arView = arView else { return }
        
        // 여러 개의 파편 생성
        for _ in 0..<20 {
            let fragmentSize = Float.random(in: 0.02...0.05)
            let fragmentMesh = MeshResource.generateSphere(radius: fragmentSize)
            
            // 원래 풍선 색상 사용
            let fragmentColor = color?.color.tint ?? .white
            let fragmentMaterial = SimpleMaterial(color: fragmentColor, isMetallic: false)
            let fragment = ModelEntity(mesh: fragmentMesh, materials: [fragmentMaterial])
            
            // 랜덤 방향으로 날아가는 효과
            let randomDirection = SIMD3<Float>(
                Float.random(in: -1...1),
                Float.random(in: -0.5...1),
                Float.random(in: -1...1)
            )
            let normalizedDirection = normalize(randomDirection)
            
            let fragmentAnchor = AnchorEntity(world: position)
            fragmentAnchor.addChild(fragment)
            arView.scene.addAnchor(fragmentAnchor)
            
            // 파편 애니메이션
            animateFragment(fragment: fragment, anchor: fragmentAnchor, direction: normalizedDirection)
        }
        
        // 중앙 폭발 효과
        let explosionMesh = MeshResource.generateSphere(radius: 0.3)
        let explosionMaterial = SimpleMaterial(
            color: UIColor.white.withAlphaComponent(0.8),
            isMetallic: false
        )
        let explosion = ModelEntity(mesh: explosionMesh, materials: [explosionMaterial])
        
        let explosionAnchor = AnchorEntity(world: position)
        explosionAnchor.addChild(explosion)
        arView.scene.addAnchor(explosionAnchor)
        
        // 폭발 확장 및 페이드 아웃
        var scale: Float = 0.1
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            scale += 0.15
            explosion.scale = SIMD3<Float>(scale, scale, scale)
            
            // 투명도 감소
            if let material = explosion.model?.materials.first as? SimpleMaterial {
                let alpha = max(0, 0.8 - scale * 0.3)
                let fadeMaterial = SimpleMaterial(
                    color: material.color.tint.withAlphaComponent(CGFloat(alpha)),
                    isMetallic: false
                )
                explosion.model?.materials = [fadeMaterial]
            }
            
            if scale > 2.0 {
                arView.scene.removeAnchor(explosionAnchor)
                timer.invalidate()
            }
        }
    }
    
    func animateFragment(fragment: ModelEntity, anchor: AnchorEntity, direction: SIMD3<Float>) {
        let initialPosition = anchor.position(relativeTo: nil)
        let speed: Float = Float.random(in: 0.5...1.5)
        var elapsed: Float = 0.0
        let maxDuration: Float = 0.8
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            elapsed += 0.016
            
            if elapsed >= maxDuration {
                if let arView = self.arView {
                    arView.scene.removeAnchor(anchor)
                }
                timer.invalidate()
                return
            }
            
            // 파편 이동 (중력 효과 포함)
            let distance = speed * elapsed
            let gravity = SIMD3<Float>(0, -2.0 * elapsed * elapsed, 0)
            let newPosition = initialPosition + direction * distance + gravity
            anchor.position = newPosition
            
            // 회전 효과
            fragment.orientation = simd_quatf(angle: elapsed * 10, axis: direction)
            
            // 페이드 아웃
            let alpha = max(0, 1.0 - elapsed / maxDuration)
            if let material = fragment.model?.materials.first as? SimpleMaterial {
                let fadeMaterial = SimpleMaterial(
                    color: material.color.tint.withAlphaComponent(CGFloat(alpha)),
                    isMetallic: false
                )
                fragment.model?.materials = [fadeMaterial]
            }
        }
    }
    
    func removeBalloon(balloonId: UUID) {
        guard let anchor = balloonAnchors[balloonId] else { return }
        
        if let arView = arView {
            arView.scene.removeAnchor(anchor)
            
            // 그림자도 제거
            if let shadow = balloonShadows[balloonId],
               let shadowParent = shadow.parent {
                if let shadowAnchor = shadowParent as? AnchorEntity {
                    arView.scene.removeAnchor(shadowAnchor)
                }
            }
        }
        
        balloons.removeValue(forKey: balloonId)
        balloonAnchors.removeValue(forKey: balloonId)
        balloonShadows.removeValue(forKey: balloonId)
    }
    
    func endGame() {
        isGameOver = true
        isGameStarted = false
        gameTimer?.invalidate()
    }
    
    func resetGame() {
        guard let arView = arView else { return }
        
        gameTimer?.invalidate()
        
        // 모든 풍선 제거
        for anchor in balloonAnchors.values {
            arView.scene.removeAnchor(anchor)
        }
        balloons.removeAll()
        balloonAnchors.removeAll()
        
        // 게임 재시작
        if let startPosition = gameStartPosition {
            startGame(at: startPosition)
        }
    }
}

