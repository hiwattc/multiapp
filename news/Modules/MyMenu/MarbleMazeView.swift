import SwiftUI
import SpriteKit
import CoreMotion

// MARK: - 구슬 미로 게임 뷰
struct MarbleMazeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SpriteView(scene: MarbleMazeScene(size: UIScreen.main.bounds.size))
                    .edgesIgnoringSafeArea(.all)
                    .navigationTitle("🎯 구슬 미로")
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

// MARK: - 미로 생성 알고리즘
class MazeGenerator {
    let width: Int
    let height: Int
    var maze: [[Bool]] // true = 벽, false = 통로

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.maze = Array(repeating: Array(repeating: true, count: width), count: height)
        generateMaze()
    }

    private func generateMaze() {
        // 재귀적 백트래킹 알고리즘으로 미로 생성
        carvePassagesFrom(x: 1, y: 1)
    }

    private func carvePassagesFrom(x: Int, y: Int) {
        let directions = [(0, -2), (0, 2), (-2, 0), (2, 0)].shuffled()

        for (dx, dy) in directions {
            let nx = x + dx
            let ny = y + dy

            if nx > 0 && nx < width - 1 && ny > 0 && ny < height - 1 && maze[ny][nx] {
                maze[ny][nx] = false
                maze[y + dy/2][x + dx/2] = false
                carvePassagesFrom(x: nx, y: ny)
            }
        }
    }

    func isWall(at position: CGPoint, cellSize: CGFloat) -> Bool {
        let x = Int(position.x / cellSize)
        let y = Int(position.y / cellSize)

        if x < 0 || x >= width || y < 0 || y >= height {
            return true // 화면 밖은 벽으로 처리
        }

        return maze[y][x]
    }
}

// MARK: - SpriteKit 게임 씬
class MarbleMazeScene: SKScene, SKPhysicsContactDelegate {
    private var marble: SKShapeNode!
    private var mazeWalls: [SKShapeNode] = []
    private var startPoint: CGPoint!
    private var endPoint: CGPoint!
    private var gameWon = false

    private let motionManager = CMMotionManager()
    private let mazeGenerator: MazeGenerator
    private let cellSize: CGFloat = 30.0
    private let marbleRadius: CGFloat = 8.0

    override init(size: CGSize) {
        // 미로 크기 계산 (화면에 맞게)
        let mazeWidth = Int(size.width / cellSize)
        let mazeHeight = Int(size.height / cellSize)
        self.mazeGenerator = MazeGenerator(width: mazeWidth, height: mazeHeight)

        super.init(size: size)
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0) // 중력 제거
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        setupMaze()
        setupMarble()
        setupStartAndEndPoints()
        startDeviceMotionUpdates()
        addInstructions()
    }

    private func setupMaze() {
        // 미로 벽 생성
        for y in 0..<mazeGenerator.height {
            for x in 0..<mazeGenerator.width {
                if mazeGenerator.maze[y][x] {
                    let wall = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize))
                    wall.fillColor = .darkGray
                    wall.strokeColor = .black
                    wall.position = CGPoint(x: CGFloat(x) * cellSize + cellSize/2,
                                          y: CGFloat(y) * cellSize + cellSize/2)
                    wall.physicsBody = SKPhysicsBody(rectangleOf: wall.frame.size)
                    wall.physicsBody?.isDynamic = false
                    wall.physicsBody?.categoryBitMask = 1
                    wall.physicsBody?.contactTestBitMask = 2
                    addChild(wall)
                    mazeWalls.append(wall)
                }
            }
        }
    }

    private func setupMarble() {
        marble = SKShapeNode(circleOfRadius: marbleRadius)
        marble.fillColor = .red
        marble.strokeColor = .black
        marble.lineWidth = 2

        // 시작점 찾기 (좌상단의 통로)
        var startX = 1
        var startY = 1
        while mazeGenerator.maze[startY][startX] {
            startX += 1
            if startX >= mazeGenerator.width - 1 {
                startX = 1
                startY += 1
            }
        }

        startPoint = CGPoint(x: CGFloat(startX) * cellSize + cellSize/2,
                           y: CGFloat(startY) * cellSize + cellSize/2)
        marble.position = startPoint

        marble.physicsBody = SKPhysicsBody(circleOfRadius: marbleRadius)
        marble.physicsBody?.isDynamic = true
        marble.physicsBody?.affectedByGravity = false
        marble.physicsBody?.allowsRotation = true
        marble.physicsBody?.restitution = 0.3
        marble.physicsBody?.friction = 0.8
        marble.physicsBody?.categoryBitMask = 2
        marble.physicsBody?.contactTestBitMask = 1

        addChild(marble)
    }

    private func setupStartAndEndPoints() {
        // 시작점 표시
        let startNode = SKShapeNode(circleOfRadius: marbleRadius)
        startNode.fillColor = .green
        startNode.strokeColor = .white
        startNode.position = startPoint
        addChild(startNode)

        // 끝점 찾기 (우하단의 통로)
        var endX = mazeGenerator.width - 2
        var endY = mazeGenerator.height - 2
        while mazeGenerator.maze[endY][endX] {
            endX -= 1
            if endX <= 1 {
                endX = mazeGenerator.width - 2
                endY -= 1
            }
        }

        endPoint = CGPoint(x: CGFloat(endX) * cellSize + cellSize/2,
                         y: CGFloat(endY) * cellSize + cellSize/2)

        // 끝점 표시
        let endNode = SKShapeNode(circleOfRadius: marbleRadius)
        endNode.fillColor = .blue
        endNode.strokeColor = .white
        endNode.position = endPoint
        addChild(endNode)
    }

    private func addInstructions() {
        let instructions = SKLabelNode(text: "휴대폰을 기울여서 파란색 출구까지 구슬을 이동시키세요!")
        instructions.fontSize = 16
        instructions.fontColor = .white
        instructions.position = CGPoint(x: size.width / 2, y: size.height - 40)
        instructions.fontName = "Helvetica-Bold"
        addChild(instructions)

        let bg = SKShapeNode(rectOf: CGSize(width: size.width, height: 50))
        bg.fillColor = UIColor.black.withAlphaComponent(0.7)
        bg.strokeColor = .clear
        bg.position = instructions.position
        bg.zPosition = -1
        addChild(bg)
    }

    private func startDeviceMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion, !self.gameWon else { return }

                // 절대적인 자세(attitude)를 물리력으로 변환
                let sensitivity: CGFloat = 25.0

                // roll: 좌/우 기울기 (수평 기준 절대 각도)
                // pitch: 상/하 기울기 (수평 기준 절대 각도)
                let forceX = CGFloat(sin(motion.attitude.roll)) * sensitivity
                let forceY = CGFloat(-sin(motion.attitude.pitch)) * sensitivity

                self.marble.physicsBody?.applyForce(CGVector(dx: forceX, dy: forceY))
            }
        }
    }

    private func stopDeviceMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func checkWinCondition() {
        let distance = hypot(marble.position.x - endPoint.x, marble.position.y - endPoint.y)
        if distance < marbleRadius + 10 {
            gameWon = true
            showWinMessage()
        }
    }

    private func showWinMessage() {
        stopDeviceMotionUpdates()

        let winLabel = SKLabelNode(text: "🎉 축하합니다! 미로 탈출 성공! 🎉")
        winLabel.fontSize = 24
        winLabel.fontColor = .yellow
        winLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        winLabel.fontName = "Helvetica-Bold"
        addChild(winLabel)

        // 재시작 버튼
        let restartLabel = SKLabelNode(text: "탭하여 다시 시작")
        restartLabel.fontSize = 18
        restartLabel.fontColor = .white
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        restartLabel.fontName = "Helvetica"
        addChild(restartLabel)
    }

    override func update(_ currentTime: TimeInterval) {
        if !gameWon {
            checkWinCondition()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameWon {
            // 게임 재시작
            let scene = MarbleMazeScene(size: self.size)
            self.view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.5))
        }
    }

    deinit {
        stopDeviceMotionUpdates()
    }
}
