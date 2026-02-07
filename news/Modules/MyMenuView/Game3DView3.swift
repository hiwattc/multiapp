import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - AR RPG Game View 3
struct Game3DView3: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = Game3DARPGViewModel()
    
    var body: some View {
        ZStack {
            // AR View
            ARRPGViewContainer(viewModel: viewModel)
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
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("HP: \(viewModel.playerHP)/\(viewModel.maxHP)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Level: \(viewModel.playerLevel)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.blue)
                            Text("EXP: \(viewModel.playerEXP)/\(viewModel.expToNextLevel)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.green)
                            Text("Kills: \(viewModel.kills)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        // 바닥 인식 상태
                        HStack {
                            Image(systemName: viewModel.planeDetected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(viewModel.planeDetected ? .green : .yellow)
                            Text(viewModel.planeDetected ? "바닥 인식됨" : "바닥 스캔 중...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                // Instructions
                if !viewModel.isGameStarted {
                    VStack(spacing: 16) {
                        Text("🎮 AR RPG 게임")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if viewModel.planeDetected {
                            Text("바닥이 인식되었습니다!\n화면을 탭해서 게임을 시작하세요!")
                                .font(.headline)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("바닥을 스캔하고 있습니다...\n기기를 천천히 움직여주세요.")
                                .font(.headline)
                                .foregroundColor(.yellow)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding()
                }
                
                // Control Buttons
                if viewModel.isGameStarted {
                    HStack {
                        Spacer()
                        
                        // Movement Joystick
                        VStack {
                            Text("이동")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 50, height: 50)
                                    .offset(
                                        x: viewModel.joystickOffset.x * 35,
                                        y: -viewModel.joystickOffset.y * 35
                                    )
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let center = CGPoint(x: 60, y: 60)
                                        let offset = CGPoint(
                                            x: (value.location.x - center.x) / 60,
                                            y: (value.location.y - center.y) / 60
                                        )
                                        
                                        // 데드존 적용 (작은 입력 무시)
                                        let magnitude = sqrt(offset.x * offset.x + offset.y * offset.y)
                                        if magnitude < 0.15 {
                                            viewModel.updateJoystick(.zero)
                                            return
                                        }
                                        
                                        // 정규화 및 클램핑
                                        let normalizedX = offset.x / max(magnitude, 1.0)
                                        let normalizedY = offset.y / max(magnitude, 1.0)
                                        
                                        let clampedOffset = CGPoint(
                                            x: max(-1, min(1, normalizedX)),
                                            y: max(-1, min(1, normalizedY))
                                        )
                                        viewModel.updateJoystick(clampedOffset)
                                    }
                                    .onEnded { _ in
                                        viewModel.updateJoystick(.zero)
                                    }
                            )
                        }
                        .padding()
                        
                        Spacer()
                        
                        // Action Buttons
                        VStack(spacing: 20) {
                            Button(action: {
                                viewModel.attack()
                            }) {
                                Image(systemName: "sword.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            
                            Button(action: {
                                viewModel.jump()
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                        }
                        .padding()
                    }
                    .padding(.bottom, 50)
                }
            }
            
            // Game Over Overlay
            if viewModel.isGameOver {
                VStack(spacing: 20) {
                    Text("게임 오버!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("최종 레벨: \(viewModel.playerLevel)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    
                    Text("처치한 적: \(viewModel.kills)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    
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
        .navigationBarHidden(true)
    }
}

// MARK: - AR RPG View Container
struct ARRPGViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: Game3DARPGViewModel
    
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
        
        // 탭 제스처 추가 (게임 시작용)
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
        weak var viewModel: Game3DARPGViewModel?
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    print("✅ 평면 감지됨: \(planeAnchor.identifier)")
                    viewModel.addPlaneAnchor(planeAnchor, arView: arView)
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    viewModel.updatePlaneAnchor(planeAnchor, arView: arView)
                }
            }
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard let viewModel = viewModel else { return }
            
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    viewModel.removePlaneAnchor(planeAnchor, arView: arView)
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
                    // 평면이 없으면 추정 평면 사용
                    let estimatedResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
                    if let firstResult = estimatedResults.first {
                        viewModel.startGame(at: firstResult.worldTransform)
                    }
                }
            }
        }
    }
}

// MARK: - AR RPG Game View Model
class Game3DARPGViewModel: ObservableObject {
    @Published var playerHP: Int = 100
    @Published var maxHP: Int = 100
    @Published var playerLevel: Int = 1
    @Published var playerEXP: Int = 0
    @Published var expToNextLevel: Int = 100
    @Published var kills: Int = 0
    @Published var joystickOffset: CGPoint = .zero
    @Published var isGameStarted: Bool = false
    @Published var isGameOver: Bool = false
    @Published var planeDetected: Bool = false
    
    weak var arView: ARView?
    private var playerEntity: ModelEntity?
    private var playerAnchor: AnchorEntity?
    private var enemies: [ModelEntity] = []
    private var enemyAnchors: [AnchorEntity] = []
    private var planeAnchors: [UUID: AnchorEntity] = [:]
    private var planeEntities: [UUID: ModelEntity] = [:]
    private var gameTimer: Timer?
    private var enemySpawnTimer: Timer?
    private var movementSpeed: Float = 0.005 // 이동 속도 더 감소
    private var isAttacking: Bool = false
    private var gameStartPosition: simd_float4x4?
    private var groundY: Float = 0.0 // 바닥 Y 위치
    private var playerStartPosition: SIMD3<Float>? // 플레이어 시작 위치 저장
    private var lastPosition: SIMD3<Float>? // 마지막 위치 저장 (이동량 제한용)
    
    func setARView(_ view: ARView) {
        self.arView = view
    }
    
    func addPlaneAnchor(_ anchor: ARPlaneAnchor, arView: ARView?) {
        guard let arView = arView else { return }
        
        DispatchQueue.main.async {
            self.planeDetected = true
        }
        
        // 평면 메시 생성
        let planeMesh = MeshResource.generatePlane(
            width: anchor.planeExtent.width,
            depth: anchor.planeExtent.height
        )
        
        // 반투명 재질 (바닥 시각화)
        let material = SimpleMaterial(
            color: UIColor.green.withAlphaComponent(0.3),
            isMetallic: false
        )
        
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
        
        // 물리 바디 추가 (정적 바닥)
        let shape = ShapeResource.generateBox(
            width: anchor.planeExtent.width,
            height: 0.01,
            depth: anchor.planeExtent.height
        )
        planeEntity.collision = CollisionComponent(shapes: [shape])
        planeEntity.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(friction: 0.9, restitution: 0.1),
            mode: .static
        )
        
        // 앵커 엔티티 생성
        let anchorEntity = AnchorEntity(anchor: anchor)
        anchorEntity.addChild(planeEntity)
        arView.scene.addAnchor(anchorEntity)
        
        planeAnchors[anchor.identifier] = anchorEntity
        planeEntities[anchor.identifier] = planeEntity
        
        // 바닥 Y 위치 업데이트
        let planeY = anchor.transform.columns.3.y
        if groundY == 0.0 || planeY < groundY {
            groundY = planeY
        }
        
        print("✅ 평면 메시 추가됨: ID=\(anchor.identifier), 크기=\(anchor.planeExtent.width)x\(anchor.planeExtent.height), Y=\(planeY)")
    }
    
    func updatePlaneAnchor(_ anchor: ARPlaneAnchor, arView: ARView?) {
        guard let arView = arView,
              let anchorEntity = planeAnchors[anchor.identifier],
              let planeEntity = planeEntities[anchor.identifier] else { return }
        
        // 평면 크기 업데이트
        let planeMesh = MeshResource.generatePlane(
            width: anchor.planeExtent.width,
            depth: anchor.planeExtent.height
        )
        
        // 기존 엔티티 제거하고 새로 생성
        anchorEntity.removeChild(planeEntity)
        
        let material = SimpleMaterial(
            color: UIColor.green.withAlphaComponent(0.3),
            isMetallic: false
        )
        let newPlaneEntity = ModelEntity(mesh: planeMesh, materials: [material])
        
        // 물리 바디 추가
        let shape = ShapeResource.generateBox(
            width: anchor.planeExtent.width,
            height: 0.01,
            depth: anchor.planeExtent.height
        )
        newPlaneEntity.collision = CollisionComponent(shapes: [shape])
        newPlaneEntity.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(friction: 0.9, restitution: 0.1),
            mode: .static
        )
        
        anchorEntity.addChild(newPlaneEntity)
        planeEntities[anchor.identifier] = newPlaneEntity
        
        // 바닥 Y 위치 업데이트
        let planeY = anchor.transform.columns.3.y
        if planeY < groundY {
            groundY = planeY
        }
        
        print("🔄 평면 메시 업데이트됨: ID=\(anchor.identifier), 크기=\(anchor.planeExtent.width)x\(anchor.planeExtent.height)")
    }
    
    func removePlaneAnchor(_ anchor: ARPlaneAnchor, arView: ARView?) {
        guard let anchorEntity = planeAnchors[anchor.identifier] else { return }
        
        if let arView = arView {
            arView.scene.removeAnchor(anchorEntity)
        }
        
        planeAnchors.removeValue(forKey: anchor.identifier)
        planeEntities.removeValue(forKey: anchor.identifier)
        
        print("🗑️ 평면 메시 제거됨: ID=\(anchor.identifier)")
        
        // 평면이 없으면 상태 업데이트
        if planeAnchors.isEmpty {
            DispatchQueue.main.async {
                self.planeDetected = false
            }
        }
    }
    
    func startGame(at transform: simd_float4x4) {
        guard let arView = arView, !isGameStarted else { return }
        
        gameStartPosition = transform
        isGameStarted = true
        isGameOver = false
        playerHP = maxHP
        playerLevel = 1
        playerEXP = 0
        expToNextLevel = 100
        kills = 0
        
        // 플레이어 생성
        createPlayer(at: transform, in: arView)
        
        // 적 스폰 타이머
        enemySpawnTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isGameStarted && !self.isGameOver else {
                timer.invalidate()
                return
            }
            self.spawnEnemy(in: arView)
        }
        
        // 게임 루프
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, self.isGameStarted && !self.isGameOver else {
                timer.invalidate()
                return
            }
            self.updateGame()
        }
    }
    
    func createPlayer(at transform: simd_float4x4, in arView: ARView) {
        // 바닥 Y 위치 사용 (평면이 감지된 경우)
        let groundLevel = groundY > 0 ? groundY : transform.columns.3.y
        let position = SIMD3<Float>(transform.columns.3.x, groundLevel + 0.15, transform.columns.3.z)
        
        // 시작 위치 저장
        playerStartPosition = position
        
        // 플레이어 모델 생성 (큐브)
        let playerMesh = MeshResource.generateBox(size: 0.3)
        let playerMaterial = SimpleMaterial(color: .blue, isMetallic: false)
        let player = ModelEntity(mesh: playerMesh, materials: [playerMaterial])
        
        // 물리 컴포넌트 - kinematic 모드로 변경 (중력 영향 받지 않음)
        let shape = ShapeResource.generateBox(size: SIMD3<Float>(0.3, 0.3, 0.3))
        player.collision = CollisionComponent(shapes: [shape])
        player.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(friction: 0.8, restitution: 0.1),
            mode: .kinematic // dynamic 대신 kinematic 사용 (중력 없음)
        )
        
        // 앵커 생성
        let anchor = AnchorEntity(world: position)
        anchor.addChild(player)
        arView.scene.addAnchor(anchor)
        
        playerEntity = player
        playerAnchor = anchor
        lastPosition = position // 초기 위치 저장
        
        print("✅ 플레이어 생성됨: 위치=\(position), 바닥 Y=\(groundLevel)")
    }
    
    func spawnEnemy(in arView: ARView) {
        guard enemies.count < 8, let playerAnchor = playerAnchor else { return }
        
        // 플레이어 주변 랜덤 위치에 적 생성
        let playerPosition = playerAnchor.position(relativeTo: nil)
        let angle = Float.random(in: 0...(2 * Float.pi))
        let distance: Float = 2.0
        let x = playerPosition.x + cos(angle) * distance
        let z = playerPosition.z + sin(angle) * distance
        // 적도 바닥 위에 생성
        let enemyHeight: Float = 0.125
        let y = groundY > 0 ? groundY + enemyHeight : playerPosition.y
        
        // 적 모델 생성
        let enemyMesh = MeshResource.generateBox(size: 0.25)
        let enemyMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let enemy = ModelEntity(mesh: enemyMesh, materials: [enemyMaterial])
        
        // 물리 컴포넌트
        let shape = ShapeResource.generateBox(size: SIMD3<Float>(0.25, 0.25, 0.25))
        enemy.collision = CollisionComponent(shapes: [shape])
        enemy.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(friction: 0.8, restitution: 0.1),
            mode: .dynamic
        )
        
        // 앵커 생성
        let anchor = AnchorEntity(world: SIMD3<Float>(x, y, z))
        anchor.addChild(enemy)
        arView.scene.addAnchor(anchor)
        
        enemies.append(enemy)
        enemyAnchors.append(anchor)
    }
    
    func updateGame() {
        guard let player = playerEntity, let playerAnchor = playerAnchor, let arView = arView else { return }
        
        // 현재 위치 가져오기 (월드 좌표계)
        let currentPosition = playerAnchor.position(relativeTo: nil)
        let playerHeight: Float = 0.15
        let targetY = groundY > 0 ? groundY + playerHeight : (playerStartPosition?.y ?? currentPosition.y)
        
        // 점프 처리
        if isJumping, let jumpStartTime = jumpStartTime {
            let elapsed = Float(Date().timeIntervalSince(jumpStartTime))
            let jumpDuration: Float = 0.6
            let jumpHeight: Float = 0.3 // 점프 높이 감소
            
            if elapsed < jumpDuration {
                // 포물선 운동 (위로 올라갔다가 내려옴)
                let progress = elapsed / jumpDuration
                let parabola = 4 * progress * (1 - progress)
                let currentY = jumpStartY + parabola * jumpHeight
                
                // 점프 중에는 시작 위치 유지 (X, Z 고정)
                playerAnchor.position = SIMD3<Float>(jumpStartX, currentY, jumpStartZ)
            } else {
                // 점프 완료 - 바닥 위로 복귀 (X, Z는 현재 위치 유지)
                playerAnchor.position = SIMD3<Float>(currentPosition.x, targetY, currentPosition.z)
                isJumping = false
                self.jumpStartTime = nil
            }
            return // 점프 중에는 이동 처리 안 함
        }
        
        // 플레이어 이동
        let joystickMagnitude = sqrt(joystickOffset.x * joystickOffset.x + joystickOffset.y * joystickOffset.y)
        
        // 데드존 추가 (작은 입력 무시)
        if joystickMagnitude > 0.1 {
            // 이동량 계산 (속도 제한 및 입력 정규화)
            let normalizedX = Float(joystickOffset.x) / Float(max(joystickMagnitude, 1.0))
            let normalizedY = Float(joystickOffset.y) / Float(max(joystickMagnitude, 1.0))
            
            let moveX = normalizedX * movementSpeed
            let moveZ = normalizedY * movementSpeed
            
            // 프레임당 최대 이동량 제한 (과도한 이동 방지)
            let maxMovePerFrame: Float = 0.01
            let actualMoveX = max(-maxMovePerFrame, min(maxMovePerFrame, moveX))
            let actualMoveZ = max(-maxMovePerFrame, min(maxMovePerFrame, moveZ))
            
            // 이동 범위 제한 (너무 멀리 가지 않도록)
            let maxDistance: Float = 5.0 // 시작 위치로부터 최대 거리 (10m -> 5m로 감소)
            if let startPos = playerStartPosition {
                let distance = sqrt(
                    pow(currentPosition.x - startPos.x, 2) +
                    pow(currentPosition.z - startPos.z, 2)
                )
                
                if distance > maxDistance {
                    // 시작 위치 방향으로 제한
                    let direction = normalize(SIMD3<Float>(
                        startPos.x - currentPosition.x,
                        0,
                        startPos.z - currentPosition.z
                    ))
                    let limitedMoveX = direction.x * movementSpeed * 0.3
                    let limitedMoveZ = direction.z * movementSpeed * 0.3
                    
                    let newPosition = SIMD3<Float>(
                        currentPosition.x + limitedMoveX,
                        targetY,
                        currentPosition.z + limitedMoveZ
                    )
                    
                    // 위치 유효성 검사
                    if newPosition.x.isFinite && newPosition.y.isFinite && newPosition.z.isFinite {
                        playerAnchor.position = newPosition
                        lastPosition = newPosition
                    }
                    return
                }
            }
            
            // 이전 위치와의 차이 제한 (갑작스러운 큰 이동 방지)
            if let lastPos = lastPosition {
                let deltaX = abs(currentPosition.x - lastPos.x)
                let deltaZ = abs(currentPosition.z - lastPos.z)
                let maxDelta: Float = 0.05 // 프레임당 최대 변화량
                
                if deltaX > maxDelta || deltaZ > maxDelta {
                    // 이전 위치로 복귀
                    playerAnchor.position = SIMD3<Float>(lastPos.x, targetY, lastPos.z)
                    return
                }
            }
            
            // 플레이어 회전
            if abs(actualMoveX) > 0.0001 || abs(actualMoveZ) > 0.0001 {
                let angle = atan2(actualMoveX, actualMoveZ)
                player.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }
            
            // 새 위치 계산 (Y는 바닥 위 고정)
            let newPosition = SIMD3<Float>(
                currentPosition.x + actualMoveX,
                targetY,
                currentPosition.z + actualMoveZ
            )
            
            // 위치 유효성 검사 (NaN이나 무한대 값 방지)
            if newPosition.x.isFinite && newPosition.y.isFinite && newPosition.z.isFinite {
                // 위치 범위 검사 (너무 큰 값 방지)
                let maxCoordinate: Float = 100.0
                if abs(newPosition.x) < maxCoordinate && abs(newPosition.z) < maxCoordinate {
                    playerAnchor.position = newPosition
                    lastPosition = newPosition
                } else {
                    print("⚠️ 위치 범위 초과: \(newPosition)")
                    if let startPos = playerStartPosition {
                        playerAnchor.position = SIMD3<Float>(startPos.x, targetY, startPos.z)
                        lastPosition = playerAnchor.position(relativeTo: nil)
                    }
                }
            } else {
                print("⚠️ 잘못된 위치 감지: \(newPosition), 시작 위치로 복귀")
                if let startPos = playerStartPosition {
                    playerAnchor.position = SIMD3<Float>(startPos.x, targetY, startPos.z)
                    lastPosition = playerAnchor.position(relativeTo: nil)
                }
            }
        } else {
            // 조이스틱이 중앙에 있을 때도 Y 위치 고정
            if abs(currentPosition.y - targetY) > 0.01 {
                let fixedPosition = SIMD3<Float>(
                    currentPosition.x,
                    targetY,
                    currentPosition.z
                )
                playerAnchor.position = fixedPosition
                lastPosition = fixedPosition
            }
        }
        
        // 적 AI 업데이트
        updateEnemies()
        
        // 충돌 체크
        checkCollisions()
    }
    
    func updateEnemies() {
        guard let player = playerEntity, let playerAnchor = playerAnchor else { return }
        
        let playerPosition = playerAnchor.position(relativeTo: nil)
        
        for (index, enemy) in enemies.enumerated() {
            guard index < enemyAnchors.count else { continue }
            
            let enemyAnchor = enemyAnchors[index]
            let enemyPosition = enemyAnchor.position(relativeTo: nil)
            
            // 적이 플레이어를 향해 이동
            let direction = enemyPosition - playerPosition
            let distance = length(direction)
            
            if distance > 0.3 && distance < 5.0 {
                let normalizedDirection = normalize(direction)
                let speed: Float = 0.01
                
                let newPosition = SIMD3<Float>(
                    enemyPosition.x - normalizedDirection.x * speed,
                    enemyPosition.y,
                    enemyPosition.z - normalizedDirection.z * speed
                )
                
                enemyAnchor.position = newPosition
                
                // 적이 플레이어를 바라보도록 회전
                let angle = atan2(normalizedDirection.x, normalizedDirection.z)
                enemy.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }
        }
    }
    
    func checkCollisions() {
        guard let player = playerEntity, let playerAnchor = playerAnchor else { return }
        
        let playerPosition = playerAnchor.position(relativeTo: nil)
        
        for enemy in enemies {
            guard let enemyIndex = enemies.firstIndex(where: { $0 === enemy }),
                  enemyIndex < enemyAnchors.count else { continue }
            
            let enemyAnchor = enemyAnchors[enemyIndex]
            let enemyPosition = enemyAnchor.position(relativeTo: nil)
            
            let distance = length(enemyPosition - playerPosition)
            
            if distance < 0.5 {
                // 플레이어에게 데미지
                takeDamage(amount: 1)
            }
        }
    }
    
    func updateJoystick(_ offset: CGPoint) {
        joystickOffset = offset
    }
    
    func attack() {
        guard !isAttacking, let player = playerEntity, let playerAnchor = playerAnchor else { return }
        
        isAttacking = true
        
        // 공격 애니메이션 (위치는 변경하지 않음)
        let originalScale = player.scale
        let attackScale = SIMD3<Float>(originalScale.x * 1.2, originalScale.y * 1.2, originalScale.z * 1.2)
        
        // 스케일만 변경 (위치는 유지)
        player.scale = attackScale
        
        // 공격 범위 내 적 제거
        let playerPosition = playerAnchor.position(relativeTo: nil)
        let attackRange: Float = 1.5
        var enemiesToRemove: [(ModelEntity, AnchorEntity)] = []
        
        for (index, enemy) in enemies.enumerated() {
            guard index < enemyAnchors.count else { continue }
            
            let enemyAnchor = enemyAnchors[index]
            let enemyPosition = enemyAnchor.position(relativeTo: nil)
            let distance = length(enemyPosition - playerPosition)
            
            if distance < attackRange {
                enemiesToRemove.append((enemy, enemyAnchor))
            }
        }
        
        for (enemy, anchor) in enemiesToRemove {
            anchor.removeChild(enemy)
            if let arView = arView {
                arView.scene.removeAnchor(anchor)
            }
            enemies.removeAll { $0 === enemy }
            enemyAnchors.removeAll { $0 === anchor }
            kills += 1
            gainEXP(amount: 20)
        }
        
        // 애니메이션 복원 (위치는 변경하지 않음)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, let player = self.playerEntity else { return }
            self.isAttacking = false
            player.scale = originalScale
        }
        
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private var isJumping: Bool = false
    private var jumpStartY: Float = 0.0
    private var jumpStartX: Float = 0.0
    private var jumpStartZ: Float = 0.0
    private var jumpStartTime: Date?
    
    func jump() {
        guard let playerAnchor = playerAnchor, !isJumping else { return }
        
        isJumping = true
        let currentPosition = playerAnchor.position(relativeTo: nil)
        jumpStartY = currentPosition.y
        jumpStartX = currentPosition.x // X, Z 위치도 저장 (점프 중 이동 방지)
        jumpStartZ = currentPosition.z
        jumpStartTime = Date()
        
        // 점프 애니메이션을 게임 루프에서 처리하도록 플래그 설정
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func takeDamage(amount: Int) {
        playerHP = max(0, playerHP - amount)
        
        if playerHP <= 0 {
            endGame()
        }
    }
    
    func gainEXP(amount: Int) {
        playerEXP += amount
        
        while playerEXP >= expToNextLevel {
            levelUp()
        }
    }
    
    func levelUp() {
        playerEXP -= expToNextLevel
        playerLevel += 1
        maxHP += 20
        playerHP = maxHP
        expToNextLevel = Int(Double(expToNextLevel) * 1.5)
        
        // 레벨업 효과
        if let player = playerEntity {
            let originalScale = player.scale
            let levelUpScale = SIMD3<Float>(originalScale.x * 1.1, originalScale.y * 1.1, originalScale.z * 1.1)
            
            player.scale = levelUpScale
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                player.scale = originalScale
            }
        }
        
        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func endGame() {
        isGameOver = true
        isGameStarted = false
        gameTimer?.invalidate()
        enemySpawnTimer?.invalidate()
    }
    
    func resetGame() {
        guard let arView = arView else { return }
        
        gameTimer?.invalidate()
        enemySpawnTimer?.invalidate()
        
        // 플레이어 제거
        if let playerAnchor = playerAnchor {
            arView.scene.removeAnchor(playerAnchor)
        }
        playerEntity = nil
        playerAnchor = nil
        
        // 적 제거
        for anchor in enemyAnchors {
            arView.scene.removeAnchor(anchor)
        }
        enemies.removeAll()
        enemyAnchors.removeAll()
        
        // 게임 재시작
        if let startPosition = gameStartPosition {
            startGame(at: startPosition)
        }
    }
}

