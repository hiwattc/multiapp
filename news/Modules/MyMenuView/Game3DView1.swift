import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - 3D Game View 1
struct Game3DView1: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = Game3DViewModel1()
    
    var body: some View {
        ZStack {
            // AR View
            Game3DARViewContainer(viewModel: viewModel)
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
                        Text("3D 공 터치 게임")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                        
                        Text("점수: \(viewModel.score)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 2)
                        
                        Text("시간: \(Int(viewModel.timeRemaining))초")
                            .font(.headline)
                            .foregroundColor(.cyan)
                            .shadow(color: .black, radius: 2)
                    }
                    .padding()
                    
                    Button(action: {
                        viewModel.resetGame()
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
                
                // Game Instructions
                if !viewModel.isGameStarted {
                    VStack(spacing: 16) {
                        Text("🎮 3D 공 터치 게임")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("화면을 탭해서 공을 생성하고\n공을 터치하면 점수가 올라요!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            viewModel.startGame()
                        }) {
                            Text("게임 시작")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 60)
                                .background(Color.green)
                                .cornerRadius(15)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding()
                } else if viewModel.isGameOver {
                    VStack(spacing: 16) {
                        Text("게임 종료!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("최종 점수: \(viewModel.score)")
                            .font(.title2)
                            .foregroundColor(.yellow)
                        
                        Button(action: {
                            viewModel.resetGame()
                        }) {
                            Text("다시 시작")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 60)
                                .background(Color.blue)
                                .cornerRadius(15)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        Text("화면을 탭해서 공을 생성하세요!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        
                        Text("생성된 공을 터치하면 점수가 올라요")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - 3D Game AR View Container
struct Game3DARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: Game3DViewModel1
    
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
        
        // 탭 제스처 추가 (공 생성용)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // SceneEvents를 통한 터치 이벤트 처리
        arView.scene.subscribe(to: SceneEvents.Update.self) { event in
            // 업데이트는 ViewModel에서 처리
        }
        
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
        weak var viewModel: Game3DViewModel1?
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView, let viewModel = viewModel else { return }
            
            let location = gesture.location(in: arView)
            
            // 먼저 공이 있는지 확인
            // 모든 앵커를 순회하며 공 찾기
            var hitBall: ModelEntity?
            var closestDistance: Float = Float.greatestFiniteMagnitude
            
            let cameraTransform = arView.cameraTransform.matrix
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            
            for anchor in arView.scene.anchors {
                for child in anchor.children {
                    if let ball = child as? ModelEntity, ball.name.hasPrefix("game_ball_") {
                        // 공의 월드 위치 가져오기
                        let ballWorldPosition = ball.position(relativeTo: nil)
                        
                        // 공과 카메라 사이의 거리
                        let ballDistance = length(ballWorldPosition - cameraPosition)
                        
                        // 2m 이내의 공만 체크
                        if ballDistance < 2.0 && ballDistance < closestDistance {
                            // 카메라 방향 벡터 (Z축 음수 방향)
                            let cameraForward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
                            let toBall = normalize(ballWorldPosition - cameraPosition)
                            
                            // 카메라가 공을 향하고 있는지 확인 (내적)
                            let dotProduct = dot(cameraForward, toBall)
                            
                            if dotProduct > 0.7 { // 앞쪽에 있는 공
                                hitBall = ball
                                closestDistance = ballDistance
                            }
                        }
                    }
                }
            }
            
            if let ball = hitBall {
                // 공을 터치한 경우
                viewModel.onBallTapped(ball)
                return
            }
            
            // 공이 없으면 새 공 생성
            let raycastResults = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
            
            if let firstResult = raycastResults.first {
                // 평면에서 공 생성
                viewModel.createBall(at: firstResult.worldTransform)
            } else {
                // 평면이 없으면 카메라 앞에 생성
                let cameraTransform = arView.cameraTransform.matrix
                var position = cameraTransform.columns.3
                position.z -= 1.0 // 카메라 앞 1m
                viewModel.createBall(at: simd_float4x4(
                    columns: (
                        cameraTransform.columns.0,
                        cameraTransform.columns.1,
                        cameraTransform.columns.2,
                        position
                    )
                ))
            }
        }
    }
}

// MARK: - 3D Game View Model 1
class Game3DViewModel1: ObservableObject {
    @Published var score: Int = 0
    @Published var timeRemaining: Double = 60.0
    @Published var isGameStarted: Bool = false
    @Published var isGameOver: Bool = false
    
    weak var arView: ARView?
    private var balls: [ModelEntity] = []
    private var gameTimer: Timer?
    private var ballSpawnTimer: Timer?
    private var ballTapGestures: [String: UITapGestureRecognizer] = [:]
    
    func setARView(_ view: ARView) {
        self.arView = view
    }
    
    func startGame() {
        isGameStarted = true
        isGameOver = false
        score = 0
        timeRemaining = 60.0
        
        // 게임 타이머 시작
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.timeRemaining -= 0.1
            
            if self.timeRemaining <= 0 {
                self.endGame()
                timer.invalidate()
            }
        }
        
        // 자동 공 생성 타이머
        ballSpawnTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isGameStarted && !self.isGameOver else {
                timer.invalidate()
                return
            }
            self.spawnRandomBall()
        }
    }
    
    func endGame() {
        isGameOver = true
        isGameStarted = false
        gameTimer?.invalidate()
        ballSpawnTimer?.invalidate()
        
        // 모든 공 제거
        removeAllBalls()
    }
    
    func resetGame() {
        gameTimer?.invalidate()
        ballSpawnTimer?.invalidate()
        removeAllBalls()
        
        isGameStarted = false
        isGameOver = false
        score = 0
        timeRemaining = 60.0
    }
    
    func createBall(at transform: simd_float4x4) {
        guard let arView = arView, isGameStarted && !isGameOver else { return }
        
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // 랜덤 색상의 공 생성
        let colors: [UIColor] = [.red, .blue, .green, .yellow, .purple, .orange, .cyan, .magenta]
        let randomColor = colors.randomElement() ?? .red
        
        let ballMesh = MeshResource.generateSphere(radius: 0.1)
        let material = SimpleMaterial(color: randomColor, isMetallic: false)
        let ball = ModelEntity(mesh: ballMesh, materials: [material])
        
        // 물리 컴포넌트 추가
        let shape = ShapeResource.generateSphere(radius: 0.1)
        ball.collision = CollisionComponent(shapes: [shape])
        ball.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(friction: 0.5, restitution: 0.8),
            mode: .dynamic
        )
        
        // 앵커 생성
        let anchor = AnchorEntity(world: position)
        anchor.addChild(ball)
        arView.scene.addAnchor(anchor)
        
        // 터치 이벤트 추가
        ball.components.set(InputTargetComponent())
        
        // 제스처 추가 (터치 감지용)
        arView.installGestures([.translation, .rotation, .scale], for: ball)
        
        // 공에 태그 추가 (나중에 식별용)
        let ballId = UUID().uuidString
        ball.name = "game_ball_\(ballId)"
        
        balls.append(ball)
    }
    
    func spawnRandomBall() {
        guard let arView = arView else { return }
        
        // 카메라 앞 랜덤 위치에 공 생성
        let cameraTransform = arView.cameraTransform.matrix
        let randomX = Float.random(in: -0.5...0.5)
        let randomY = Float.random(in: -0.3...0.3)
        let randomZ = Float.random(in: -1.5...(-0.8))
        
        var transform = cameraTransform
        transform.columns.3.x += randomX
        transform.columns.3.y += randomY
        transform.columns.3.z += randomZ
        
        createBall(at: transform)
    }
    
    func onBallTapped(_ ball: ModelEntity) {
        guard isGameStarted && !isGameOver else { return }
        
        // 점수 증가
        score += 10
        
        // 공 제거 애니메이션
        if let arView = arView {
            // 페이드 아웃 애니메이션
            let fadeOut = ball.move(to: Transform(scale: SIMD3<Float>(0, 0, 0), rotation: ball.transform.rotation, translation: ball.transform.translation), relativeTo: ball.parent, duration: 0.3)
            
            // 애니메이션 완료 후 제거
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                
                // 앵커에서 제거
                for anchor in arView.scene.anchors {
                    if anchor.children.contains(ball) {
                        anchor.removeChild(ball)
                        arView.scene.removeAnchor(anchor)
                        break
                    }
                }
                
                // 리스트에서 제거
                self.balls.removeAll { $0 === ball }
            }
        }
        
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func removeAllBalls() {
        guard let arView = arView else { return }
        
        for ball in balls {
            for anchor in arView.scene.anchors {
                if anchor.children.contains(ball) {
                    anchor.removeChild(ball)
                    arView.scene.removeAnchor(anchor)
                }
            }
        }
        
        balls.removeAll()
    }
}

