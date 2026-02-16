import SwiftUI
import ARKit
import RealityKit
import Combine
import AVFoundation
import AudioToolbox

// MARK: - Main View
struct GameARTowerDefenseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameManager = ARTowerDefenseManager()
    
    var body: some View {
        ZStack {
            // AR View
            ARTowerDefenseViewContainer(gameManager: gameManager)
                .edgesIgnoringSafeArea(.all)
            
            // UI Overlay
            VStack {
                // Top HUD
                HStack {
                    // 나가기 버튼
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // 점수 및 상태
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("처치: \(gameManager.killCount)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        
                        Text("적 수: \(gameManager.enemyCount)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Center Crosshair (조준선)
                if gameManager.gameStarted && !gameManager.isPlacingFloor {
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(color: .white, radius: 2)
                }
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 16) {
                    if !gameManager.gameStarted {
                        // 바닥 선택 안내
                        Text("바닥면을 선택하세요")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                        
                        Text("화면을 탭하여 바닥 확정")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(8)
                    } else {
                        // 발사 버튼
                        Button(action: { gameManager.fireFromTower() }) {
                            Image(systemName: "target")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
    }
}

// MARK: - AR View Container
struct ARTowerDefenseViewContainer: UIViewRepresentable {
    @ObservedObject var gameManager: ARTowerDefenseManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR Configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config)
        
        // Setup game manager
        gameManager.arView = arView
        gameManager.setupScene()
        
        // Tap gesture for floor selection and tower placement
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(gameManager: gameManager)
    }
    
    class Coordinator: NSObject {
        var gameManager: ARTowerDefenseManager
        
        init(gameManager: ARTowerDefenseManager) {
            self.gameManager = gameManager
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = gameManager.arView else { return }
            let location = sender.location(in: arView)
            
            if !gameManager.gameStarted {
                // 바닥 선택
                gameManager.selectFloor(at: location)
            }
        }
    }
}

// MARK: - Game Manager
class ARTowerDefenseManager: ObservableObject {
    var arView: ARView?
    
    @Published var gameStarted = false
    @Published var isPlacingFloor = true
    @Published var killCount = 0
    @Published var enemyCount = 0
    
    private var floorAnchor: AnchorEntity?
    private var portals: [ModelEntity] = [] // 적 스폰 포탈들 (3개)
    private var portalPositions: [SIMD3<Float>] = [] // 포탈 위치들
    private var enemies: [ModelEntity] = []
    private var bullets: [ModelEntity] = []
    
    private var enemySpawnTimer: Timer?
    private var portalRotationTimer: Timer? // 포탈 회전 애니메이션
    private var initialCameraDirection: SIMD3<Float>? // 게임 시작 시 카메라 방향 저장
    
    private let enemyEmojis = ["😈", "👾", "👹", "💀", "👻", "🤡", "🦹", "🧟", "🧛"]
    
    // Haptic Feedback Generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    // MARK: - Setup Scene
    func setupScene() {
        guard let arView = arView else { return }
        
        // Add lighting
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.look(at: [0, 0, 0], from: [0, 3, 0], relativeTo: nil)
        
        let lightAnchor = AnchorEntity(world: .zero)
        lightAnchor.addChild(light)
        arView.scene.addAnchor(lightAnchor)
        
        // Prepare haptic feedback generators
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
    }
    
    // MARK: - Floor Selection
    func selectFloor(at location: CGPoint) {
        guard let arView = arView, !gameStarted else { return }
        
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let firstResult = results.first {
            // Remove previous floor anchor if exists
            if let existingAnchor = floorAnchor {
                arView.scene.removeAnchor(existingAnchor)
            }
            
            // 카메라 방향 저장 (게임 시작 시점의 화면 방향)
            if let camera = arView.session.currentFrame?.camera {
                let cameraTransform = camera.transform
                // 카메라가 바라보는 방향 (forward vector)
                let forward = SIMD3<Float>(
                    -cameraTransform.columns.2.x,
                    -cameraTransform.columns.2.y,
                    -cameraTransform.columns.2.z
                )
                // Y축(높이)은 0으로 설정하여 수평면에서의 방향만 사용
                initialCameraDirection = normalize(SIMD3<Float>(forward.x, 0, forward.z))
            }
            
            // Create floor grid
            let anchor = AnchorEntity(world: firstResult.worldTransform)
            floorAnchor = anchor
            
            // Create grid mesh
            let gridSize: Float = 2.0
            let gridEntity = createFloorGrid(size: gridSize)
            anchor.addChild(gridEntity)
            
            arView.scene.addAnchor(anchor)
            
            // Place portals (포탈 3개 생성)
            createPortals(at: anchor)
            
            // Start game
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 게임 시작 진동
                self.lightImpact.impactOccurred()
                
                // 게임 시작 사운드
                AudioServicesPlaySystemSound(1057) // Begin recording sound
                
                self.gameStarted = true
                self.isPlacingFloor = false
                self.startEnemySpawning()
                self.startPortalAnimation()
            }
        }
    }
    
    private func createFloorGrid(size: Float) -> ModelEntity {
        // Create a thin box as grid plane
        let mesh = MeshResource.generatePlane(width: size, depth: size)
        
        var material = SimpleMaterial()
        material.color = .init(tint: .cyan.withAlphaComponent(0.3), texture: nil)
        material.metallic = 0.0
        material.roughness = 1.0
        
        let gridEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Add grid lines as separate entities
        let divisions = 10
        let step = size / Float(divisions)
        
        for i in 0...divisions {
            let offset = -size/2 + Float(i) * step
            
            // Horizontal line
            let hLine = ModelEntity(
                mesh: .generateBox(width: size, height: 0.002, depth: 0.01),
                materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
            )
            hLine.position = [0, 0.001, offset]
            gridEntity.addChild(hLine)
            
            // Vertical line
            let vLine = ModelEntity(
                mesh: .generateBox(width: 0.01, height: 0.002, depth: size),
                materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
            )
            vLine.position = [offset, 0.001, 0]
            gridEntity.addChild(vLine)
        }
        
        return gridEntity
    }
    
    // MARK: - Portal Management
    private func createPortals(at anchor: AnchorEntity) {
        guard let cameraDir = initialCameraDirection else { return }
        
        // 포탈 3개 생성: 중앙, 좌측, 우측
        let distance: Float = 2.5
        let spacing: Float = 0.8 // 포탈 간 간격
        
        // 중앙 포탈
        let centerPosition = SIMD3<Float>(
            cameraDir.x * distance,
            0.3,
            cameraDir.z * distance
        )
        
        // 좌측 포탈 (중앙에서 좌측으로 90도 회전)
        let leftOffset = SIMD3<Float>(-cameraDir.z * spacing, 0, cameraDir.x * spacing)
        let leftPosition = centerPosition + leftOffset
        
        // 우측 포탈 (중앙에서 우측으로 90도 회전)
        let rightOffset = SIMD3<Float>(cameraDir.z * spacing, 0, -cameraDir.x * spacing)
        let rightPosition = centerPosition + rightOffset
        
        let positions = [leftPosition, centerPosition, rightPosition]
        portalPositions = positions
        
        for (index, position) in positions.enumerated() {
            let portal = createPortalEntity()
            portal.position = position
            anchor.addChild(portal)
            portals.append(portal)
            
            // 포탈 주변 파티클 효과 추가
            createPortalParticles(at: position, anchor: anchor)
            
            print("🌀 포탈 \(index+1) 생성 - 위치: \(position)")
        }
    }
    
    private func createPortalParticles(at position: SIMD3<Float>, anchor: AnchorEntity) {
        // 포탈 주변에 작은 파티클 8개 배치
        for i in 0..<8 {
            let angle = Float(i) * (2 * .pi / 8)
            let radius: Float = 0.35
            
            let particle = ModelEntity(
                mesh: .generateSphere(radius: 0.02),
                materials: [SimpleMaterial(color: .purple, isMetallic: true)]
            )
            
            let particleX = position.x + cos(angle) * radius
            let particleZ = position.z + sin(angle) * radius
            particle.position = SIMD3<Float>(particleX, position.y, particleZ)
            
            anchor.addChild(particle)
            
            // 파티클 애니메이션 (위아래로 움직임)
            var transform = particle.transform
            transform.translation.y = position.y + 0.1
            particle.move(to: transform, relativeTo: anchor, duration: 1.0)
            
            // 반복 애니메이션
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak particle, weak anchor] _ in
                guard let particle = particle, let anchor = anchor else { return }
                
                var transform = particle.transform
                transform.translation.y = position.y + (transform.translation.y > position.y ? 0 : 0.1)
                particle.move(to: transform, relativeTo: anchor, duration: 1.0)
            }
        }
    }
    
    private func createPortalEntity() -> ModelEntity {
        // 외부 링 (토러스 형태)
        let outerRing = MeshResource.generateBox(size: [0.5, 0.5, 0.05])
        let middleRing = MeshResource.generateBox(size: [0.4, 0.4, 0.04])
        let innerRing = MeshResource.generateBox(size: [0.3, 0.3, 0.06])
        
        // 외부 링 (보라색 빛남)
        var outerMaterial = SimpleMaterial()
        outerMaterial.color = .init(tint: .purple, texture: nil)
        outerMaterial.metallic = 1.0
        
        // 중간 링 (마젠타)
        var middleMaterial = SimpleMaterial()
        middleMaterial.color = .init(tint: .magenta, texture: nil)
        middleMaterial.metallic = 0.8
        
        // 내부 (검은 구멍)
        var innerMaterial = SimpleMaterial()
        innerMaterial.color = .init(tint: .black.withAlphaComponent(0.95), texture: nil)
        
        // 중심 빛나는 구
        let centerSphere = MeshResource.generateSphere(radius: 0.08)
        var centerMaterial = SimpleMaterial()
        centerMaterial.color = .init(tint: .cyan, texture: nil)
        centerMaterial.metallic = 1.0
        
        let outer = ModelEntity(mesh: outerRing, materials: [outerMaterial])
        let middle = ModelEntity(mesh: middleRing, materials: [middleMaterial])
        let inner = ModelEntity(mesh: innerRing, materials: [innerMaterial])
        let center = ModelEntity(mesh: centerSphere, materials: [centerMaterial])
        
        let portalEntity = ModelEntity()
        portalEntity.addChild(outer)
        portalEntity.addChild(middle)
        portalEntity.addChild(inner)
        portalEntity.addChild(center)
        
        return portalEntity
    }
    
    private func startPortalAnimation() {
        var animationTime: Float = 0
        
        // 모든 포탈 회전 및 펄스 애니메이션
        portalRotationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            animationTime += 0.05
            
            for portal in self.portals {
                // Y축 회전
                var transform = portal.transform
                transform.rotation *= simd_quatf(angle: 0.05, axis: [0, 1, 0])
                
                // 펄스 효과 (크기 변화)
                let pulseScale = 1.0 + sin(animationTime * 2) * 0.1
                transform.scale = SIMD3<Float>(repeating: pulseScale)
                
                portal.transform = transform
            }
        }
    }
    
    // MARK: - Enemy Spawning
    private func startEnemySpawning() {
        // 5초마다 한 마리씩 스폰
        enemySpawnTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.spawnEnemyFromPortal()
        }
        
        // 첫 번째 적은 1초 후 즉시 스폰
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.spawnEnemyFromPortal()
        }
    }
    
    private func spawnEnemyFromPortal() {
        guard let floorAnchor = floorAnchor, !portalPositions.isEmpty else { return }
        
        // 랜덤 포탈에서 스폰
        let spawnPosition = portalPositions.randomElement() ?? portalPositions[0]
        
        // 포탈 스폰 효과 (약한 진동)
        lightImpact.impactOccurred(intensity: 0.3)
        
        // 스폰 사운드
        AudioServicesPlaySystemSound(1519) // Anticipate sound
        
        // 포탈 플래시 효과
        createPortalFlashEffect(at: spawnPosition)
        
        // 포탈 위치에서 적 생성
        let enemy = createEnemyEntity()
        enemy.position = spawnPosition
        floorAnchor.addChild(enemy)
        enemies.append(enemy)
        
        print("👾 적 스폰 - 포탈에서 출현: \(spawnPosition)")
        
        // 스폰 애니메이션 (작게 시작해서 커지며 회전)
        enemy.scale = SIMD3<Float>(0.01, 0.01, 0.01)
        enemy.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        
        var transform = enemy.transform
        transform.scale = SIMD3<Float>(1.0, 1.0, 1.0)
        transform.rotation = simd_quatf(angle: Float.pi * 2, axis: [0, 1, 0])
        
        enemy.move(to: transform, relativeTo: floorAnchor, duration: 0.8)
        
        // 중앙(플레이어 위치)을 향해 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.moveEnemyTowardPlayer(enemy: enemy)
        }
        
        // 적 카운트 업데이트
        enemyCount = enemies.count
    }
    
    private func createPortalFlashEffect(at position: SIMD3<Float>) {
        guard let floorAnchor = floorAnchor else { return }
        
        // 플래시 효과 (빠르게 커졌다 사라지는 구)
        let flash = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [SimpleMaterial(color: .cyan.withAlphaComponent(0.7), isMetallic: true)]
        )
        flash.position = position
        floorAnchor.addChild(flash)
        
        // 확장 애니메이션
        var transform = flash.transform
        transform.scale = SIMD3<Float>(3.0, 3.0, 3.0)
        flash.move(to: transform, relativeTo: floorAnchor, duration: 0.3)
        
        // 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            flash.removeFromParent()
        }
    }
    
    private func createEnemyEntity() -> ModelEntity {
        // 크기를 절반으로 줄임 (0.15 → 0.075)
        let mesh = MeshResource.generateSphere(radius: 0.075)
        
        // Random emoji texture
        let emoji = enemyEmojis.randomElement() ?? "😈"
        let cgImage = generateEmojiTexture(emoji: emoji)
        
        var material = SimpleMaterial()
        
        // Try to create texture resource from CGImage
        if let textureResource = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) {
            material.color = .init(tint: .white, texture: .init(textureResource))
        } else {
            // Fallback to random color if texture fails
            let colors: [UIColor] = [.red, .green, .blue, .orange, .purple, .yellow]
            material.color = .init(tint: colors.randomElement() ?? .red, texture: nil)
        }
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "enemy"
        
        // Add collision component (크기도 절반으로)
        entity.collision = CollisionComponent(shapes: [.generateSphere(radius: 0.075)])
        
        return entity
    }
    
    private func generateEmojiTexture(emoji: String) -> CGImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 200),
            ]
            let string = emoji as NSString
            let stringSize = string.size(withAttributes: attributes)
            let rect = CGRect(
                x: (size.width - stringSize.width) / 2,
                y: (size.height - stringSize.height) / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            string.draw(in: rect, withAttributes: attributes)
        }
        return image.cgImage!
    }
    
    private func moveEnemyTowardPlayer(enemy: ModelEntity) {
        let startPosition = enemy.position
        let targetPosition = SIMD3<Float>(0, 0.1, 0) // 플레이어 위치 (중앙)
        
        // 거리에 비례한 이동 시간 계산 (속도 일정하게)
        let distance = simd_distance(startPosition, targetPosition)
        let speed: Float = 0.15 // meters per second
        let duration: Double = Double(distance / speed)
        
        // Animate movement
        var transform = enemy.transform
        transform.translation = targetPosition
        
        enemy.move(to: transform, relativeTo: floorAnchor, duration: duration)
        
        // Check if reached player
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.enemyReachedPlayer(enemy)
        }
    }
    
    private func enemyReachedPlayer(_ enemy: ModelEntity) {
        if enemies.contains(where: { $0 == enemy }) {
            // 적이 플레이어에 도달 시 경고 진동
            mediumImpact.impactOccurred()
            
            // 경고 사운드
            AudioServicesPlaySystemSound(1053) // Tock sound
            
            enemy.removeFromParent()
            enemies.removeAll { $0 == enemy }
            enemyCount = enemies.count
            // Could add game over logic here
        }
    }
    
    // MARK: - Firing System
    func fireFromTower() {
        guard let arView = arView,
              let floorAnchor = floorAnchor else { return }
        
        // 발사 진동 효과 (가벼운 진동)
        mediumImpact.impactOccurred()
        
        // 발사 효과음 (총 발사음)
        AudioServicesPlaySystemSound(1105) // Peek sound
        
        // 1. 화면 중앙에서 raycast (조준선 타겟)
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let centerRaycast = arView.raycast(from: screenCenter, allowing: .estimatedPlane, alignment: .any)
        
        // 2. 화면 중앙 하단에서 raycast (총알 발사 시작점)
        let screenBottom = CGPoint(x: arView.bounds.midX, y: arView.bounds.maxY * 0.85) // 하단 85% 지점
        let bottomRaycast = arView.raycast(from: screenBottom, allowing: .estimatedPlane, alignment: .any)
        
        guard let camera = arView.session.currentFrame?.camera else { return }
        let cameraTransform = camera.transform
        let cameraPositionWorld = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraDirectionWorld = SIMD3<Float>(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        )
        
        // 발사 시작 위치 결정 (화면 하단)
        let startPositionWorld: SIMD3<Float>
        if let bottomResult = bottomRaycast.first {
            let hitTransform = bottomResult.worldTransform
            startPositionWorld = SIMD3<Float>(
                hitTransform.columns.3.x,
                hitTransform.columns.3.y,
                hitTransform.columns.3.z
            )
        } else {
            // Raycast 실패 시 카메라 앞 0.3m
            startPositionWorld = cameraPositionWorld + normalize(cameraDirectionWorld) * 0.3
        }
        
        // 타겟 위치 결정 (화면 중앙 조준선)
        let targetPositionWorld: SIMD3<Float>
        if let centerResult = centerRaycast.first {
            let hitTransform = centerResult.worldTransform
            targetPositionWorld = SIMD3<Float>(
                hitTransform.columns.3.x,
                hitTransform.columns.3.y,
                hitTransform.columns.3.z
            )
        } else {
            // Raycast 실패 시 카메라 방향으로 5m 앞
            targetPositionWorld = cameraPositionWorld + normalize(cameraDirectionWorld) * 5.0
        }
        
        // floorAnchor 좌표계로 변환
        let floorInverse = floorAnchor.transform.matrix.inverse
        
        let startPositionLocal = SIMD3<Float>(
            (floorInverse * simd_float4(startPositionWorld, 1)).x,
            (floorInverse * simd_float4(startPositionWorld, 1)).y,
            (floorInverse * simd_float4(startPositionWorld, 1)).z
        )
        
        let targetPositionLocal = SIMD3<Float>(
            (floorInverse * simd_float4(targetPositionWorld, 1)).x,
            (floorInverse * simd_float4(targetPositionWorld, 1)).y,
            (floorInverse * simd_float4(targetPositionWorld, 1)).z
        )
        
        // 정확한 발사 방향 계산 (시작점 → 타겟)
        let fireDirection = normalize(targetPositionLocal - startPositionLocal)
        
        // Create bullet (화면 하단에서 시작)
        let bullet = createBullet()
        bullet.position = startPositionLocal
        
        // floorAnchor에 총알 추가
        floorAnchor.addChild(bullet)
        bullets.append(bullet)
        
        print("🔫 총알 발사 - 시작: \(startPositionLocal), 목표: \(targetPositionLocal), 방향: \(fireDirection)")
        
        // Fire bullet toward target
        let bulletSpeed: Float = 10.0
        let bulletDuration: Double = 1.0
        var transform = bullet.transform
        transform.translation = bullet.position + fireDirection * bulletSpeed
        
        bullet.move(to: transform, relativeTo: floorAnchor, duration: bulletDuration)
        
        // Check for hits
        checkBulletCollisions(bullet: bullet, direction: fireDirection)
        
        // Remove bullet after some time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            bullet.removeFromParent()
            self?.bullets.removeAll { $0 == bullet }
        }
    }
    
    private func createBullet() -> ModelEntity {
        // 총알 크기를 더 크게 (0.06으로 증가 - 명중률 향상)
        let mesh = MeshResource.generateSphere(radius: 0.06)
        var material = SimpleMaterial()
        material.color = .init(tint: .yellow, texture: nil)
        material.metallic = 1.0
        
        // 빛나는 효과 추가
        var emissiveMaterial = SimpleMaterial()
        emissiveMaterial.color = .init(tint: .yellow, texture: nil)
        emissiveMaterial.metallic = 1.0
        
        let bullet = ModelEntity(mesh: mesh, materials: [emissiveMaterial])
        bullet.name = "bullet"
        
        return bullet
    }
    
    private func checkBulletCollisions(bullet: ModelEntity, direction: SIMD3<Float>) {
        // 총알이 날아가는 동안 여러 시점에서 충돌 체크 (0.05초 간격으로 20번 = 1초)
        for checkTime in 1...20 {
            let delay = Double(checkTime) * 0.05
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, let floorAnchor = self.floorAnchor else { return }
                
                // 총알이 이미 제거되었는지 확인
                guard self.bullets.contains(where: { $0 == bullet }), bullet.parent != nil else { return }
                
                // floorAnchor 기준으로 좌표 통일
                let bulletPosition = bullet.position(relativeTo: floorAnchor)
                
                for (index, enemy) in self.enemies.enumerated().reversed() {
                    // 적이 유효한지 확인
                    guard enemy.parent != nil else { continue }
                    
                    let enemyPosition = enemy.position(relativeTo: floorAnchor)
                    let distance = simd_distance(bulletPosition, enemyPosition)
                    
                    // 충돌 거리를 넓게 설정 (0.4로 증가 - 총알 0.06 + 적 0.075 + 여유 0.265)
                    if distance < 0.4 {
                        // Hit!
                        print("🎯 적 명중! 거리: \(distance) - 총알: \(bulletPosition), 적: \(enemyPosition)")
                        self.enemyHit(enemy, at: index)
                        
                        // 총알 제거
                        bullet.removeFromParent()
                        self.bullets.removeAll { $0 == bullet }
                        
                        return // 루프 종료
                    }
                }
            }
        }
    }
    
    private func enemyHit(_ enemy: ModelEntity, at index: Int) {
        // 이미 제거된 적인지 확인
        guard index < enemies.count, enemies[index] == enemy else { return }
        
        // 충돌 진동 효과 (강한 진동)
        heavyImpact.impactOccurred()
        
        // 폭발 효과음
        AudioServicesPlaySystemSound(1304) // Mail sent sound (폭발음 같은 효과)
        
        // Create explosion effect (floorAnchor 기준 좌표)
        if let floorAnchor = floorAnchor {
            createExplosionEffect(at: enemy.position(relativeTo: floorAnchor))
        }
        
        // Remove enemy (모든 애니메이션 중단)
        enemy.stopAllAnimations()
        enemy.removeFromParent()
        enemies.remove(at: index)
        
        // Update counts
        killCount += 1
        enemyCount = enemies.count
    }
    
    private func createExplosionEffect(at position: SIMD3<Float>) {
        guard let floorAnchor = floorAnchor else { return }
        
        // Create particles (크기와 개수 조정)
        for _ in 0..<12 {
            let particle = ModelEntity(
                mesh: .generateSphere(radius: 0.03), // 파티클 크기 축소
                materials: [SimpleMaterial(color: .orange, isMetallic: false)]
            )
            particle.position = position
            floorAnchor.addChild(particle) // floorAnchor에 추가
            
            // Random direction (범위 약간 축소)
            let randomOffset = SIMD3<Float>(
                Float.random(in: -0.2...0.2),
                Float.random(in: 0...0.3),
                Float.random(in: -0.2...0.2)
            )
            
            var transform = particle.transform
            transform.translation = position + randomOffset
            particle.move(to: transform, relativeTo: floorAnchor, duration: 0.5)
            
            // Fade and remove
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                particle.removeFromParent()
            }
        }
    }
    
    deinit {
        enemySpawnTimer?.invalidate()
        portalRotationTimer?.invalidate()
    }
}

// MARK: - Preview
#Preview {
    GameARTowerDefenseView()
}
