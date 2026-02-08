import SwiftUI
import SpriteKit
import Combine

// MARK: - Racing Game View
struct RacingGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RacingGameViewModel()
    
    var body: some View {
        ZStack {
            // Game Scene
            if let scene = viewModel.gameScene {
                SpriteView(scene: scene)
                    .edgesIgnoringSafeArea(.all)
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
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("순위: \(viewModel.playerRank)/\(viewModel.totalCars)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.cyan)
                            Text("속도: \(Int(viewModel.speed)) km/h")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.green)
                            Text("랩: \(viewModel.lapCount)/3")
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
                
                // Control Buttons (Left/Right)
                if viewModel.isGameStarted && !viewModel.isGameOver {
                    HStack(spacing: 80) {
                        Button(action: {
                            viewModel.turnLeft()
                        }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.blue.opacity(0.3)))
                        }
                        
                        Button(action: {
                            viewModel.turnRight()
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.blue.opacity(0.3)))
                        }
                    }
                    .padding(.bottom, 80)
                }
                
                // Start Screen
                if !viewModel.isGameStarted && !viewModel.isGameOver {
                    VStack(spacing: 16) {
                        Text("🏎️ 레이싱 게임")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("5대의 차와 경쟁하세요!\n3바퀴를 가장 빨리 완주하는 사람이 승리!")
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
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding(.bottom, 100)
                }
                
                // Game Over Screen
                if viewModel.isGameOver {
                    VStack(spacing: 20) {
                        if viewModel.playerRank == 1 {
                            Text("🏆 우승!")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        } else {
                            Text("경주 종료")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("최종 순위: \(viewModel.playerRank)위")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("완주 시간: \(String(format: "%.1f", viewModel.raceTime))초")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            viewModel.restartGame()
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
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Racing Game View Model
class RacingGameViewModel: ObservableObject {
    @Published var playerRank: Int = 6
    @Published var totalCars: Int = 6
    @Published var speed: Double = 0
    @Published var lapCount: Int = 0
    @Published var isGameStarted: Bool = false
    @Published var isGameOver: Bool = false
    @Published var raceTime: Double = 0
    
    var gameScene: RacingGameScene?
    
    func startGame() {
        isGameStarted = true
        isGameOver = false
        playerRank = 6
        speed = 0
        lapCount = 0
        raceTime = 0
        
        if gameScene == nil {
            let scene = RacingGameScene(size: UIScreen.main.bounds.size)
            scene.viewModel = self
            scene.scaleMode = .resizeFill
            gameScene = scene
        }
        
        gameScene?.startGame()
    }
    
    func restartGame() {
        gameScene?.restartGame()
        startGame()
    }
    
    func turnLeft() {
        gameScene?.turnLeft()
    }
    
    func turnRight() {
        gameScene?.turnRight()
    }
    
    func updateSpeed(_ speed: Double) {
        DispatchQueue.main.async {
            self.speed = speed
        }
    }
    
    func updateRank(_ rank: Int) {
        DispatchQueue.main.async {
            self.playerRank = rank
        }
    }
    
    func updateLap(_ lap: Int) {
        DispatchQueue.main.async {
            self.lapCount = lap
        }
    }
    
    func updateTime(_ time: Double) {
        DispatchQueue.main.async {
            self.raceTime = time
        }
    }
    
    func finishRace() {
        DispatchQueue.main.async {
            self.isGameOver = true
            self.isGameStarted = false
        }
    }
}

// MARK: - Racing Game Scene
class RacingGameScene: SKScene {
    weak var viewModel: RacingGameViewModel?
    
    private var playerCar: SKSpriteNode!
    private var aiCars: [SKSpriteNode] = []
    private var roadLines: [SKSpriteNode] = []
    private var gameTimer: Timer?
    private var startTime: Date?
    
    private var playerPosition: CGFloat = 0 // 트랙 진행도 (0-1)
    private var playerSpeed: CGFloat = 5
    private var playerLane: Int = 2 // 0-4 레인 (5개 레인)
    private var playerLap: Int = 0
    
    private var aiCarPositions: [CGFloat] = []
    private var aiCarLanes: [Int] = []
    private var aiCarSpeeds: [CGFloat] = []
    private var aiCarLaps: [Int] = []
    
    private let totalLaps = 3
    private let laneCount = 5
    
    override func didMove(to view: SKView) {
        setupScene()
    }
    
    func setupScene() {
        // 배경 (도로)
        backgroundColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        
        // 도로 차선 생성
        createRoadLines()
        
        // 플레이어 차 생성
        createPlayerCar()
        
        // AI 차량 5대 생성
        createAICars()
    }
    
    func createPlayerCar() {
        playerCar = SKSpriteNode(color: .blue, size: CGSize(width: 60, height: 100))
        playerCar.position = CGPoint(x: size.width / 2, y: 200)
        playerCar.name = "player"
        playerCar.zPosition = 10
        addChild(playerCar)
        
        // 플레이어 번호 라벨
        let label = SKLabelNode(text: "P")
        label.fontSize = 24
        label.fontName = "Helvetica-Bold"
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        playerCar.addChild(label)
    }
    
    func createAICars() {
        let colors: [UIColor] = [.red, .yellow, .green, .orange, .purple]
        
        for i in 0..<5 {
            let aiCar = SKSpriteNode(color: colors[i], size: CGSize(width: 60, height: 100))
            aiCar.position = CGPoint(x: size.width / 2, y: 200)
            aiCar.name = "ai_\(i)"
            aiCar.zPosition = 9
            aiCar.alpha = 0.9
            addChild(aiCar)
            
            // AI 번호 라벨
            let label = SKLabelNode(text: "\(i + 1)")
            label.fontSize = 24
            label.fontName = "Helvetica-Bold"
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            aiCar.addChild(label)
            
            aiCars.append(aiCar)
            aiCarPositions.append(CGFloat.random(in: -0.1...0.1)) // 약간의 차이로 시작
            aiCarLanes.append(Int.random(in: 0..<laneCount))
            aiCarSpeeds.append(CGFloat.random(in: 4.5...5.5))
            aiCarLaps.append(0)
        }
    }
    
    func createRoadLines() {
        let laneWidth = size.width / CGFloat(laneCount)
        
        // 차선 점선 생성
        for i in 1..<laneCount {
            let x = laneWidth * CGFloat(i)
            
            for j in 0..<30 {
                let line = SKSpriteNode(color: .white, size: CGSize(width: 5, height: 40))
                line.position = CGPoint(x: x, y: CGFloat(j) * 80)
                line.name = "line"
                line.zPosition = 1
                addChild(line)
                roadLines.append(line)
            }
        }
    }
    
    func startGame() {
        playerPosition = 0
        playerSpeed = 5
        playerLane = 2
        playerLap = 0
        startTime = Date()
        
        // AI 초기화
        for i in 0..<aiCars.count {
            aiCarPositions[i] = CGFloat.random(in: -0.05...0.05)
            aiCarLaps[i] = 0
        }
        
        // 게임 루프 시작
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.updateGame()
        }
    }
    
    func restartGame() {
        gameTimer?.invalidate()
        removeAllChildren()
        setupScene()
    }
    
    func updateGame() {
        // 플레이어 진행
        playerPosition += playerSpeed * 0.0002
        
        // 랩 체크
        if playerPosition >= 1.0 {
            playerPosition = 0
            playerLap += 1
            viewModel?.updateLap(playerLap)
            
            if playerLap >= totalLaps {
                finishRace()
                return
            }
        }
        
        // 속도 업데이트
        viewModel?.updateSpeed(Double(playerSpeed * 20))
        
        // 도로 차선 이동 (무한 스크롤 효과)
        for line in roadLines {
            line.position.y -= playerSpeed
            
            if line.position.y < -50 {
                line.position.y += 2400
            }
        }
        
        // 플레이어 차 레인 위치 계산
        let laneWidth = size.width / CGFloat(laneCount)
        let targetX = laneWidth * CGFloat(playerLane) + laneWidth / 2
        playerCar.position.x = targetX
        
        // AI 차량 업데이트
        updateAICars()
        
        // 순위 계산
        calculateRank()
        
        // 시간 업데이트
        if let startTime = startTime {
            let elapsed = Date().timeIntervalSince(startTime)
            viewModel?.updateTime(elapsed)
        }
    }
    
    func updateAICars() {
        for i in 0..<aiCars.count {
            // AI 진행
            aiCarPositions[i] += aiCarSpeeds[i] * 0.0002
            
            // 랩 체크
            if aiCarPositions[i] >= 1.0 {
                aiCarPositions[i] = 0
                aiCarLaps[i] += 1
                
                if aiCarLaps[i] >= totalLaps {
                    // AI 완주
                    aiCars[i].alpha = 0.3
                }
            }
            
            // AI 차선 변경 (랜덤, 가끔)
            if Int.random(in: 0..<200) < 3 {
                let newLane = aiCarLanes[i] + (Bool.random() ? 1 : -1)
                aiCarLanes[i] = max(0, min(laneCount - 1, newLane))
            }
            
            // AI 차 화면 위치 계산
            let laneWidth = size.width / CGFloat(laneCount)
            let targetX = laneWidth * CGFloat(aiCarLanes[i]) + laneWidth / 2
            
            // 플레이어와의 상대 위치 계산
            let aiTotal = aiCarPositions[i] + CGFloat(aiCarLaps[i])
            let playerTotal = playerPosition + CGFloat(playerLap)
            let relativePosition = aiTotal - playerTotal
            
            // 화면에 표시할 Y 위치
            let screenY = 200 + relativePosition * 800
            
            if screenY > -100 && screenY < size.height + 100 {
                aiCars[i].position = CGPoint(x: targetX, y: screenY)
                aiCars[i].isHidden = false
            } else {
                aiCars[i].isHidden = true
            }
        }
    }
    
    func calculateRank() {
        var rank = 1
        let playerTotal = playerPosition + CGFloat(playerLap)
        
        for i in 0..<aiCars.count {
            let aiTotal = aiCarPositions[i] + CGFloat(aiCarLaps[i])
            if aiTotal > playerTotal {
                rank += 1
            }
        }
        
        viewModel?.updateRank(rank)
    }
    
    func turnLeft() {
        if playerLane > 0 {
            playerLane -= 1
            
            // 햅틱 피드백
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    func turnRight() {
        if playerLane < laneCount - 1 {
            playerLane += 1
            
            // 햅틱 피드백
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    func finishRace() {
        gameTimer?.invalidate()
        viewModel?.finishRace()
        
        // 완주 시 햅틱
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(viewModel?.playerRank == 1 ? .success : .warning)
    }
}
