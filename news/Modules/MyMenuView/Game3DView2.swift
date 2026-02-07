import SwiftUI
import SceneKit
import Combine

// MARK: - RPG 3D Game View 2
struct Game3DView2: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = Game3DRPGViewModel()
    
    var body: some View {
        ZStack {
            // 3D Scene View
            SceneKitView(viewModel: viewModel)
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
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                // Control Buttons
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
                                    let clampedOffset = CGPoint(
                                        x: max(-1, min(1, offset.x)),
                                        y: max(-1, min(1, offset.y))
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
        .onAppear {
            viewModel.startGame()
        }
    }
}

// MARK: - SceneKit View
struct SceneKitView: UIViewRepresentable {
    @ObservedObject var viewModel: Game3DRPGViewModel
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = viewModel.scene
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false
        scnView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        scnView.antialiasingMode = .multisampling4X
        
        // ViewModel에 SCNView 설정
        viewModel.setSceneView(scnView)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 업데이트 필요시 구현
    }
}

// MARK: - RPG Game View Model
class Game3DRPGViewModel: ObservableObject {
    @Published var playerHP: Int = 100
    @Published var maxHP: Int = 100
    @Published var playerLevel: Int = 1
    @Published var playerEXP: Int = 0
    @Published var expToNextLevel: Int = 100
    @Published var kills: Int = 0
    @Published var joystickOffset: CGPoint = .zero
    @Published var isGameOver: Bool = false
    
    var scene: SCNScene!
    weak var sceneView: SCNView?
    
    private var playerNode: SCNNode?
    private var cameraNode: SCNNode?
    private var enemies: [SCNNode] = []
    private var gameTimer: Timer?
    private var enemySpawnTimer: Timer?
    private var movementSpeed: Float = 0.05
    private var isAttacking: Bool = false
    
    init() {
        setupScene()
    }
    
    func setSceneView(_ view: SCNView) {
        self.sceneView = view
    }
    
    func setupScene() {
        scene = SCNScene()
        
        // 조명 설정
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.white.withAlphaComponent(0.6)
        scene.rootNode.addChildNode(ambientLight)
        
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = UIColor.white
        directionalLight.position = SCNVector3(0, 10, 5)
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 4, 0, 0)
        scene.rootNode.addChildNode(directionalLight)
        
        // 바닥 생성
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.5)
        floor.firstMaterial?.specular.contents = UIColor.white
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(floorNode)
        
        // 플레이어 생성
        createPlayer()
        
        // 카메라 설정
        setupCamera()
        
        // 벽 생성
        createWalls()
    }
    
    func createPlayer() {
        // 플레이어 캐릭터 (큐브)
        let playerGeometry = SCNBox(width: 0.5, height: 1.0, length: 0.5, chamferRadius: 0.1)
        playerGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        playerGeometry.firstMaterial?.specular.contents = UIColor.white
        
        playerNode = SCNNode(geometry: playerGeometry)
        playerNode?.position = SCNVector3(0, 0.5, 0)
        playerNode?.name = "player"
        
        // 플레이어에 물리 바디 추가
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: playerGeometry, options: nil))
        physicsBody.categoryBitMask = 1
        physicsBody.contactTestBitMask = 2
        physicsBody.isAffectedByGravity = true
        playerNode?.physicsBody = physicsBody
        
        scene.rootNode.addChildNode(playerNode!)
    }
    
    func setupCamera() {
        cameraNode = SCNNode()
        cameraNode?.camera = SCNCamera()
        cameraNode?.camera?.fieldOfView = 60
        cameraNode?.position = SCNVector3(0, 5, 8)
        cameraNode?.eulerAngles = SCNVector3(-Float.pi / 6, 0, 0)
        scene.rootNode.addChildNode(cameraNode!)
    }
    
    func createWalls() {
        let wallHeight: CGFloat = 3.0
        let wallThickness: CGFloat = 0.2
        let wallLength: CGFloat = 20.0
        
        // 앞벽
        let frontWall = SCNBox(width: wallLength, height: wallHeight, length: wallThickness, chamferRadius: 0)
        frontWall.firstMaterial?.diffuse.contents = UIColor.brown
        let frontWallNode = SCNNode(geometry: frontWall)
        frontWallNode.position = SCNVector3(0, wallHeight / 2, -wallLength / 2)
        scene.rootNode.addChildNode(frontWallNode)
        
        // 뒷벽
        let backWall = SCNBox(width: wallLength, height: wallHeight, length: wallThickness, chamferRadius: 0)
        backWall.firstMaterial?.diffuse.contents = UIColor.brown
        let backWallNode = SCNNode(geometry: backWall)
        backWallNode.position = SCNVector3(0, wallHeight / 2, wallLength / 2)
        scene.rootNode.addChildNode(backWallNode)
        
        // 왼쪽벽
        let leftWall = SCNBox(width: wallThickness, height: wallHeight, length: wallLength, chamferRadius: 0)
        leftWall.firstMaterial?.diffuse.contents = UIColor.brown
        let leftWallNode = SCNNode(geometry: leftWall)
        leftWallNode.position = SCNVector3(-wallLength / 2, wallHeight / 2, 0)
        scene.rootNode.addChildNode(leftWallNode)
        
        // 오른쪽벽
        let rightWall = SCNBox(width: wallThickness, height: wallHeight, length: wallLength, chamferRadius: 0)
        rightWall.firstMaterial?.diffuse.contents = UIColor.brown
        let rightWallNode = SCNNode(geometry: rightWall)
        rightWallNode.position = SCNVector3(wallLength / 2, wallHeight / 2, 0)
        scene.rootNode.addChildNode(rightWallNode)
    }
    
    func startGame() {
        isGameOver = false
        playerHP = maxHP
        playerLevel = 1
        playerEXP = 0
        expToNextLevel = 100
        kills = 0
        
        // 플레이어 위치 리셋
        playerNode?.position = SCNVector3(0, 0.5, 0)
        
        // 기존 적 제거
        for enemy in enemies {
            enemy.removeFromParentNode()
        }
        enemies.removeAll()
        
        // 적 스폰 타이머
        enemySpawnTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self, !self.isGameOver else {
                timer.invalidate()
                return
            }
            self.spawnEnemy()
        }
        
        // 게임 루프
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, !self.isGameOver else {
                timer.invalidate()
                return
            }
            self.updateGame()
        }
    }
    
    func updateGame() {
        // 플레이어 이동
        if joystickOffset != .zero {
            let moveX = Float(joystickOffset.x) * movementSpeed
            let moveZ = Float(joystickOffset.y) * movementSpeed
            
            // 플레이어 회전
            if moveX != 0 || moveZ != 0 {
                let angle = atan2(moveX, moveZ)
                playerNode?.eulerAngles.y = angle
            }
            
            // 이동 적용
            let newPosition = SCNVector3(
                playerNode!.position.x + moveX,
                playerNode!.position.y,
                playerNode!.position.z + moveZ
            )
            
            // 경계 체크
            let boundary: Float = 8.0
            let clampedPosition = SCNVector3(
                max(-boundary, min(boundary, newPosition.x)),
                newPosition.y,
                max(-boundary, min(boundary, newPosition.z))
            )
            
            playerNode?.position = clampedPosition
        }
        
        // 적 AI 및 충돌 체크
        updateEnemies()
        
        // 카메라 따라가기
        if let player = playerNode {
            cameraNode?.position = SCNVector3(
                player.position.x,
                5,
                player.position.z + 8
            )
        }
    }
    
    func spawnEnemy() {
        guard enemies.count < 10 else { return } // 최대 10마리
        
        // 랜덤 위치에 적 생성
        let angle = Float.random(in: 0...(2 * Float.pi))
        let distance: Float = 10.0
        let x = cos(angle) * distance
        let z = sin(angle) * distance
        
        let enemyGeometry = SCNBox(width: 0.4, height: 0.8, length: 0.4, chamferRadius: 0.1)
        enemyGeometry.firstMaterial?.diffuse.contents = UIColor.red
        enemyGeometry.firstMaterial?.specular.contents = UIColor.white
        
        let enemy = SCNNode(geometry: enemyGeometry)
        enemy.position = SCNVector3(x, 0.4, z)
        enemy.name = "enemy"
        
        // 물리 바디
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: enemyGeometry, options: nil))
        physicsBody.categoryBitMask = 2
        physicsBody.contactTestBitMask = 1
        physicsBody.isAffectedByGravity = true
        enemy.physicsBody = physicsBody
        
        scene.rootNode.addChildNode(enemy)
        enemies.append(enemy)
    }
    
    func updateEnemies() {
        guard let player = playerNode else { return }
        
        for enemy in enemies {
            // 적이 플레이어를 향해 이동
            let direction = SCNVector3(
                player.position.x - enemy.position.x,
                0,
                player.position.z - enemy.position.z
            )
            let distance = sqrt(direction.x * direction.x + direction.z * direction.z)
            
            if distance > 0.1 && distance < 15.0 {
                let normalizedDirection = SCNVector3(
                    direction.x / distance,
                    0,
                    direction.z / distance
                )
                
                let speed: Float = 0.02
                enemy.position = SCNVector3(
                    enemy.position.x + normalizedDirection.x * speed,
                    enemy.position.y,
                    enemy.position.z + normalizedDirection.z * speed
                )
                
                // 적이 플레이어를 바라보도록 회전
                let angle = atan2(normalizedDirection.x, normalizedDirection.z)
                enemy.eulerAngles.y = angle
            }
            
            // 충돌 체크 (간단한 거리 기반)
            if distance < 1.5 {
                // 플레이어에게 데미지
                takeDamage(amount: 1)
            }
        }
    }
    
    func updateJoystick(_ offset: CGPoint) {
        joystickOffset = offset
    }
    
    func attack() {
        guard !isAttacking, let player = playerNode else { return }
        
        isAttacking = true
        
        // 공격 애니메이션
        let originalScale = player.scale
        let attackScale = SCNVector3(originalScale.x * 1.2, originalScale.y * 1.2, originalScale.z * 1.2)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        player.scale = attackScale
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            player.scale = originalScale
            SCNTransaction.commit()
            self.isAttacking = false
        }
        SCNTransaction.commit()
        
        // 공격 범위 내 적 제거
        let attackRange: Float = 2.0
        var enemiesToRemove: [SCNNode] = []
        
        for enemy in enemies {
            let distance = sqrt(
                pow(enemy.position.x - player.position.x, 2) +
                pow(enemy.position.z - player.position.z, 2)
            )
            
            if distance < attackRange {
                enemiesToRemove.append(enemy)
            }
        }
        
        for enemy in enemiesToRemove {
            enemy.removeFromParentNode()
            enemies.removeAll { $0 === enemy }
            kills += 1
            gainEXP(amount: 20)
        }
        
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func jump() {
        guard let player = playerNode, let physicsBody = player.physicsBody else { return }
        
        // 점프 힘 적용
        physicsBody.applyForce(SCNVector3(0, 5, 0), asImpulse: true)
        
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
        if let player = playerNode {
            let originalScale = player.scale
            let levelUpScale = SCNVector3(originalScale.x * 1.1, originalScale.y * 1.1, originalScale.z * 1.1)
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.2
            player.scale = levelUpScale
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.2
                player.scale = originalScale
                SCNTransaction.commit()
            }
            SCNTransaction.commit()
        }
        
        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func endGame() {
        isGameOver = true
        gameTimer?.invalidate()
        enemySpawnTimer?.invalidate()
    }
    
    func resetGame() {
        gameTimer?.invalidate()
        enemySpawnTimer?.invalidate()
        
        // 기존 적 제거
        for enemy in enemies {
            enemy.removeFromParentNode()
        }
        enemies.removeAll()
        
        startGame()
    }
}

