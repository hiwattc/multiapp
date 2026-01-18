import SwiftUI
import SpriteKit
import AudioToolbox

// MARK: - 모험 게임 뷰
struct AdventureGameView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SpriteView(scene: AdventureGameScene(size: UIScreen.main.bounds.size))
                    .edgesIgnoringSafeArea(.all)
                    .navigationTitle("🌿 모험")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("닫기") {
                                dismiss()
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - 플레이어 캐릭터
class Player: SKSpriteNode {
    enum Direction: String {
        case down, up, left, right

        var textureName: String {
            return "player_\(self.rawValue)"
        }

        var walkingTextureNames: [String] {
            return ["player_\(self.rawValue)_walk1", "player_\(self.rawValue)_walk2"]
        }
    }

    var currentDirection: Direction = .down
    var isWalking = false
    private var walkTextures: [SKTexture] = []
    private var idleTexture: SKTexture?

    init() {
        // 기본 텍스처 생성 (실제 게임에서는 이미지 에셋 사용)
        let texture = SKTexture(imageNamed: "player_down") // 임시 텍스처
        super.init(texture: texture, color: .clear, size: CGSize(width: 32, height: 32))

        setupTextures()
        setupPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTextures() {
        // 실제 구현에서는 에셋에서 텍스처 로드
        // 임시로 색상 기반 텍스처 생성
        idleTexture = createTexture(color: .systemBlue, size: size)

        // 걷기 애니메이션 텍스처
        let walk1Texture = createTexture(color: .systemBlue, size: size)
        let walk2Texture = createTexture(color: .systemCyan, size: size)
        walkTextures = [walk1Texture, walk2Texture]
    }

    private func createTexture(color: UIColor, size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // 간단한 캐릭터 모양 그리기
            UIColor.white.setFill()
            let eyeSize = CGSize(width: 4, height: 4)
            context.fill(CGRect(x: 8, y: 8, width: eyeSize.width, height: eyeSize.height))
            context.fill(CGRect(x: 20, y: 8, width: eyeSize.width, height: eyeSize.height))

            // 미소
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 12, y: 20))
            path.addQuadCurve(to: CGPoint(x: 20, y: 20), controlPoint: CGPoint(x: 16, y: 24))
            UIColor.white.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
        return SKTexture(image: image)
    }

    private func setupPhysics() {
        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.isDynamic = true
        physicsBody?.allowsRotation = false
        physicsBody?.categoryBitMask = 1
        physicsBody?.contactTestBitMask = 2 | 4 | 8 // 벽, 아이템, NPC
        physicsBody?.collisionBitMask = 2 // 벽과만 충돌
        physicsBody?.friction = 0.0
        physicsBody?.linearDamping = 0.8
    }

    func move(direction: Direction, speed: CGFloat) {
        currentDirection = direction
        isWalking = true

        var velocity = CGVector.zero
        switch direction {
        case .up:
            velocity = CGVector(dx: 0, dy: speed)
        case .down:
            velocity = CGVector(dx: 0, dy: -speed)
        case .left:
            velocity = CGVector(dx: -speed, dy: 0)
        case .right:
            velocity = CGVector(dx: speed, dy: 0)
        }

        physicsBody?.velocity = velocity

        // 걷기 애니메이션
        if !walkTextures.isEmpty {
            let walkAction = SKAction.animate(with: walkTextures, timePerFrame: 0.15)
            let repeatAction = SKAction.repeatForever(walkAction)
            run(repeatAction, withKey: "walking")
        }
    }

    func stopMoving() {
        isWalking = false
        physicsBody?.velocity = .zero

        // 애니메이션 정지
        removeAction(forKey: "walking")

        // 기본 텍스처로 복원
        if let idleTexture = idleTexture {
            texture = idleTexture
        }
    }
}

// MARK: - 게임 씬
class AdventureGameScene: SKScene, SKPhysicsContactDelegate {
    private var player: Player!
    private var tileMap: SKTileMapNode!
    private var virtualJoystick: VirtualJoystick!
    private var inventory: Inventory!
    private var gameCamera: SKCameraNode!

    private var lastUpdateTime: TimeInterval = 0
    private var isGameLoaded = false

    // 게임 상태
    private var collectedItems: [String] = []
    private var gameProgress: [String: Any] = [:]

    override init(size: CGSize) {
        super.init(size: size)
        self.scaleMode = .aspectFill
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        setupCamera()
        setupTileMap()
        setupPlayer()
        setupVirtualJoystick()
        setupInventory()
        loadGameProgress()

        // 배경 음악 시작
        playBackgroundMusic()

        isGameLoaded = true
    }

    private func setupCamera() {
        gameCamera = SKCameraNode()
        camera = gameCamera
        addChild(gameCamera)
        // 카메라 초기 위치를 플레이어 위치로 설정
        gameCamera.position = CGPoint(x: 480, y: 480)
    }

    private func setupTileMap() {
        // 타일맵 설정 (실제 구현에서는 타일셋 에셋 사용)
        let tileSize = CGSize(width: 32, height: 32)
        let columns = 30  // 크기 축소
        let rows = 30     // 크기 축소

        tileMap = SKTileMapNode(tileSet: SKTileSet(), columns: columns, rows: rows, tileSize: tileSize)
        // 맵을 (0,0)에 배치하여 좌표계를 단순화
        tileMap.position = CGPoint(x: 0, y: 0)

        // 기본 타일셋 생성 (초원)
        let grassTile = createGrassTile()
        let treeTile = createTreeTile()
        let waterTile = createWaterTile()
        let pathTile = createPathTile()

        let grassGroup = SKTileGroup(tileDefinition: grassTile)
        grassGroup.name = "grass"

        let treeGroup = SKTileGroup(tileDefinition: treeTile)
        treeGroup.name = "tree"

        let waterGroup = SKTileGroup(tileDefinition: waterTile)
        waterGroup.name = "water"

        let pathGroup = SKTileGroup(tileDefinition: pathTile)
        pathGroup.name = "path"

        let tileSet = SKTileSet(tileGroups: [grassGroup, treeGroup, waterGroup, pathGroup])

        tileMap.tileSet = tileSet

        // 맵 생성 (간단한 패턴)
        for row in 0..<rows {
            for col in 0..<columns {
                if row == 0 || row == rows-1 || col == 0 || col == columns-1 {
                    // 테두리는 나무
                    tileMap.setTileGroup(tileSet.tileGroups[1], forColumn: col, row: row)
                } else if (row + col) % 7 == 0 {
                    // 간헐적으로 나무 배치
                    tileMap.setTileGroup(tileSet.tileGroups[1], forColumn: col, row: row)
                } else if (row * col) % 13 == 0 {
                    // 물가
                    tileMap.setTileGroup(tileSet.tileGroups[2], forColumn: col, row: row)
                } else if abs(row - rows/2) < 3 && abs(col - columns/2) < 10 {
                    // 중앙 경로
                    tileMap.setTileGroup(tileSet.tileGroups[3], forColumn: col, row: row)
                } else {
                    // 기본 초원
                    tileMap.setTileGroup(tileSet.tileGroups[0], forColumn: col, row: row)
                }
            }
        }

        // 충돌 타일 설정 (나무와 물)
        setupCollisionTiles()

        addChild(tileMap)
    }

    private func createGrassTile() -> SKTileDefinition {
        let texture = createTileTexture(color: .systemGreen, size: CGSize(width: 32, height: 32))
        return SKTileDefinition(texture: texture)
    }

    private func createTreeTile() -> SKTileDefinition {
        let texture = createTileTexture(color: .systemGreen, size: CGSize(width: 32, height: 32), withTree: true)
        let tileDef = SKTileDefinition(texture: texture)
        return tileDef
    }

    private func createWaterTile() -> SKTileDefinition {
        let texture = createTileTexture(color: .systemBlue, size: CGSize(width: 32, height: 32))
        let tileDef = SKTileDefinition(texture: texture)
        return tileDef
    }

    private func createPathTile() -> SKTileDefinition {
        let texture = createTileTexture(color: .systemBrown, size: CGSize(width: 32, height: 32))
        return SKTileDefinition(texture: texture)
    }

    private func createTileTexture(color: UIColor, size: CGSize, withTree: Bool = false) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            if withTree {
                // 나무 모양 그리기
                UIColor.brown.setFill()
                context.fill(CGRect(x: 14, y: 8, width: 4, height: 16)) // 줄기

                UIColor.systemGreen.setFill()
                let leavesPath = UIBezierPath(ovalIn: CGRect(x: 8, y: 2, width: 16, height: 12))
                leavesPath.fill() // 잎사귀
            }

            // 잔잔한 텍스처 효과
            UIColor.white.withAlphaComponent(0.1).setFill()
            for _ in 0..<5 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let spotSize = CGFloat.random(in: 1..<3)
                context.fill(CGRect(x: x, y: y, width: spotSize, height: spotSize))
            }
        }
        return SKTexture(image: image)
    }

    private func setupCollisionTiles() {
        // 충돌 타일에 물리 바디 추가 (나무와 물)
        for row in 0..<tileMap.numberOfRows {
            for col in 0..<tileMap.numberOfColumns {
                if let tileGroup = tileMap.tileGroup(atColumn: col, row: row),
                   (tileGroup.name == "tree" || tileGroup.name == "water") {

                    let tileSize = tileMap.tileSize
                    let position = tileMap.centerOfTile(atColumn: col, row: row)

                    let collisionNode = SKSpriteNode(color: .clear, size: tileSize)
                    collisionNode.position = position
                    collisionNode.physicsBody = SKPhysicsBody(rectangleOf: tileSize)
                    collisionNode.physicsBody?.isDynamic = false
                    collisionNode.physicsBody?.categoryBitMask = 2
                    collisionNode.physicsBody?.collisionBitMask = 1

                    addChild(collisionNode)
                }
            }
        }
    }

    private func setupPlayer() {
        player = Player()
        // 플레이어를 맵의 중심에 배치 (30x30 타일, 각 32포인트)
        let mapCenterX = 30 * 32 / 2  // 480
        let mapCenterY = 30 * 32 / 2  // 480
        player.position = CGPoint(x: mapCenterX, y: mapCenterY)
        addChild(player)
    }

    private func setupVirtualJoystick() {
        virtualJoystick = VirtualJoystick()
        gameCamera.addChild(virtualJoystick)
        // 화면 좌측 하단에 배치
        virtualJoystick.position = CGPoint(x: -size.width/2 + 80, y: -size.height/2 + 80)
    }

    private func setupInventory() {
        inventory = Inventory()
        gameCamera.addChild(inventory)
        // 화면 우측 상단에 배치
        inventory.position = CGPoint(x: size.width/2 - 100, y: size.height/2 - 50)
    }

    private func loadGameProgress() {
        if let savedProgress = UserDefaults.standard.dictionary(forKey: "AdventureGameProgress") {
            gameProgress = savedProgress
            collectedItems = savedProgress["collectedItems"] as? [String] ?? []

            // 플레이어 위치 복원
            if let positionString = savedProgress["playerPosition"] as? String {
                player.position = pointFromString(positionString)
            }
        }
    }

    private func saveGameProgress() {
        gameProgress["collectedItems"] = collectedItems
        gameProgress["playerPosition"] = stringFromPoint(player.position)
        UserDefaults.standard.set(gameProgress, forKey: "AdventureGameProgress")
    }

    private func pointFromString(_ string: String) -> CGPoint {
        // "{x, y}" 형식의 문자열을 CGPoint로 변환
        let cleanedString = string.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        let components = cleanedString.components(separatedBy: ",")
        if components.count == 2,
           let x = Double(components[0].trimmingCharacters(in: .whitespaces)),
           let y = Double(components[1].trimmingCharacters(in: .whitespaces)) {
            return CGPoint(x: x, y: y)
        }
        return .zero
    }

    private func stringFromPoint(_ point: CGPoint) -> String {
        // CGPoint를 "{x, y}" 형식의 문자열로 변환
        return "{\(point.x), \(point.y)}"
    }

    private func playBackgroundMusic() {
        // 실제 구현에서는 음악 파일 사용
        // 현재는 시스템 사운드만 재생
        AudioServicesPlaySystemSound(1104) // 시스템 사운드
    }

    override func update(_ currentTime: TimeInterval) {
        if !isGameLoaded { return }

        // 카메라 플레이어 따라가기
        gameCamera.position = player.position

        // 조이스틱 입력 처리
        if let direction = virtualJoystick.getDirection() {
            let speed: CGFloat = 100.0
            player.move(direction: direction, speed: speed)
        } else {
            player.stopMoving()
        }

        // 주기적으로 게임 상태 저장
        if currentTime - lastUpdateTime > 5.0 {
            saveGameProgress()
            lastUpdateTime = currentTime
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let cameraLocation = convert(location, to: gameCamera)

            // 인벤토리 터치 처리
            if inventory.contains(cameraLocation) {
                inventory.handleTouch(at: cameraLocation)
                return
            }

            // 조이스틱 터치 처리
            if virtualJoystick.contains(cameraLocation) {
                virtualJoystick.handleTouch(at: cameraLocation, began: true)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let cameraLocation = convert(location, to: gameCamera)

            // 조이스틱 드래그 처리
            virtualJoystick.handleTouch(at: cameraLocation, began: false)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let cameraLocation = convert(location, to: gameCamera)

            // 조이스틱 터치 종료
            virtualJoystick.handleTouchEnd()
        }
    }
}

// MARK: - 가상 조이스틱
class VirtualJoystick: SKNode {
    private var background: SKShapeNode!
    private var stick: SKShapeNode!
    private var isActive = false
    private var startLocation: CGPoint = .zero

    override init() {
        super.init()
        setupJoystick()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupJoystick() {
        // 배경
        background = SKShapeNode(circleOfRadius: 50)
        background.fillColor = UIColor.white.withAlphaComponent(0.3)
        background.strokeColor = .white
        background.lineWidth = 2
        addChild(background)

        // 조이스틱 스틱
        stick = SKShapeNode(circleOfRadius: 20)
        stick.fillColor = .white
        stick.strokeColor = .gray
        stick.lineWidth = 2
        addChild(stick)
    }

    func handleTouch(at location: CGPoint, began: Bool) {
        if began {
            isActive = true
            startLocation = location
        }

        if isActive {
            let delta = CGPoint(x: location.x - startLocation.x, y: location.y - startLocation.y)
            let distance = hypot(delta.x, delta.y)
            let maxDistance: CGFloat = 40

            if distance <= maxDistance {
                stick.position = delta
            } else {
                let angle = atan2(delta.y, delta.x)
                stick.position = CGPoint(x: cos(angle) * maxDistance, y: sin(angle) * maxDistance)
            }
        }
    }

    func handleTouchEnd() {
        isActive = false
        let returnAction = SKAction.move(to: .zero, duration: 0.2)
        returnAction.timingMode = .easeOut
        stick.run(returnAction)
    }

    func getDirection() -> Player.Direction? {
        if !isActive { return nil }

        let delta = stick.position
        let distance = hypot(delta.x, delta.y)

        if distance < 10 { return nil } // 데드존

        let angle = atan2(delta.y, delta.x)
        let degrees = angle * 180 / .pi

        if degrees >= -45 && degrees < 45 {
            return .right
        } else if degrees >= 45 && degrees < 135 {
            return .up
        } else if degrees >= -135 && degrees < -45 {
            return .down
        } else {
            return .left
        }
    }
}

// MARK: - 인벤토리
class Inventory: SKNode {
    private var background: SKShapeNode!
    private var itemSlots: [SKShapeNode] = []
    private var items: [String] = []

    override init() {
        super.init()
        setupInventory()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupInventory() {
        // 배경
        background = SKShapeNode(rectOf: CGSize(width: 200, height: 60))
        background.fillColor = UIColor.black.withAlphaComponent(0.7)
        background.strokeColor = .white
        background.lineWidth = 2
        addChild(background)

        // 아이템 슬롯 (4개)
        for i in 0..<4 {
            let slot = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
            slot.fillColor = UIColor.gray.withAlphaComponent(0.5)
            slot.strokeColor = .white
            slot.lineWidth = 1
            slot.position = CGPoint(x: -70 + i * 50, y: 0)
            addChild(slot)
            itemSlots.append(slot)
        }

        // 인벤토리 라벨
        let label = SKLabelNode(text: "인벤토리")
        label.fontSize = 14
        label.fontColor = .white
        label.fontName = "Helvetica-Bold"
        label.position = CGPoint(x: 0, y: 25)
        addChild(label)
    }

    func addItem(_ item: String) {
        if items.count < 4 {
            items.append(item)
            updateDisplay()
        }
    }

    private func updateDisplay() {
        for (index, slot) in itemSlots.enumerated() {
            slot.removeAllChildren()

            if index < items.count {
                let itemLabel = SKLabelNode(text: items[index])
                itemLabel.fontSize = 10
                itemLabel.fontColor = .yellow
                itemLabel.fontName = "Helvetica"
                slot.addChild(itemLabel)
            }
        }
    }

    func handleTouch(at location: CGPoint) {
        // 인벤토리 터치 처리 (확장 가능)
        print("인벤토리 터치됨")
    }
}
