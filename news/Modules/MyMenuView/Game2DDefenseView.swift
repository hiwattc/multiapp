import SwiftUI
import SpriteKit
import Combine

// MARK: - 2D Defense Game View
struct Game2DDefenseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = Game2DDefenseViewModel()
    
    var body: some View {
        ZStack {
            // Game Scene
            if let scene = viewModel.gameScene {
                SpriteView(scene: scene)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        viewModel.startGame()
                    }
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
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("HP: \(viewModel.playerHP)/\(viewModel.maxHP)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Wave: \(viewModel.currentWave)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.green)
                            Text("Kills: \(viewModel.kills)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.blue)
                            Text("Score: \(viewModel.score)")
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
                
                // Game Over / Start Screen
                if viewModel.isGameOver {
                    VStack(spacing: 20) {
                        Text("게임 오버!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("최종 점수: \(viewModel.score)")
                            .font(.title2)
                            .foregroundColor(.yellow)
                        
                        Text("처치한 적: \(viewModel.kills)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("웨이브: \(viewModel.currentWave)")
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
                } else if !viewModel.isGameStarted {
                    VStack(spacing: 16) {
                        Text("🛡️ 방어 게임")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("적들이 사방에서 몰려옵니다!\n화면을 탭해서 공격하세요!")
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
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - 2D Defense Game View Model
class Game2DDefenseViewModel: ObservableObject {
    @Published var playerHP: Int = 100
    @Published var maxHP: Int = 100
    @Published var currentWave: Int = 1
    @Published var kills: Int = 0
    @Published var score: Int = 0
    @Published var isGameStarted: Bool = false
    @Published var isGameOver: Bool = false
    
    var gameScene: Game2DDefenseScene?
    
    func startGame() {
        isGameStarted = true
        isGameOver = false
        playerHP = maxHP
        currentWave = 1
        kills = 0
        score = 0
        
        if gameScene == nil {
            let scene = Game2DDefenseScene(size: UIScreen.main.bounds.size)
            scene.viewModel = self
            gameScene = scene
        }
        
        gameScene?.startGame()
    }
    
    func restartGame() {
        gameScene?.restartGame()
        startGame()
    }
    
    func updateHP(_ hp: Int) {
        DispatchQueue.main.async {
            self.playerHP = hp
            if hp <= 0 {
                self.isGameOver = true
                self.isGameStarted = false
            }
        }
    }
    
    func updateWave(_ wave: Int) {
        DispatchQueue.main.async {
            self.currentWave = wave
        }
    }
    
    func addKill() {
        DispatchQueue.main.async {
            self.kills += 1
            self.score += 10
        }
    }
}

// MARK: - 2D Defense Game Scene
class Game2DDefenseScene: SKScene {
    weak var viewModel: Game2DDefenseViewModel?
    
    private var player: SKSpriteNode!
    private var enemies: [SKSpriteNode] = []
    private var bullets: [SKSpriteNode] = []
    private var enemySpawnTimer: Timer?
    private var waveTimer: Timer?
    private var autoShootTimer: Timer?
    private var currentWave: Int = 1
    private var enemiesInWave: Int = 0
    private var enemiesKilledInWave: Int = 0
    private var enemiesToSpawn: Int = 10
    
    override func didMove(to view: SKView) {
        setupScene()
    }
    
    func setupScene() {
        // 배경
        backgroundColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)
        
        // 플레이어 생성 (중앙)
        player = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        player.name = "player"
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.categoryBitMask = 1
        player.physicsBody?.contactTestBitMask = 2
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.isDynamic = false
        addChild(player)
        
        // 물리 월드 설정
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector.zero
    }
    
    func startGame() {
        currentWave = 1
        enemiesInWave = 0
        enemiesKilledInWave = 0
        enemiesToSpawn = 10
        
        // 기존 적 제거
        removeAllEnemies()
        
        // 적 스폰 시작
        startEnemySpawning()
        
        // 자동 사격 시작
        startAutoShooting()
        
        // 웨이브 타이머
        startWaveTimer()
    }
    
    func restartGame() {
        // 모든 타이머 정지
        enemySpawnTimer?.invalidate()
        waveTimer?.invalidate()
        autoShootTimer?.invalidate()
        
        // 모든 노드 제거
        removeAllChildren()
        
        // 씬 재설정
        setupScene()
    }
    
    func startEnemySpawning() {
        enemySpawnTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.enemiesInWave < self.enemiesToSpawn {
                self.spawnEnemy()
                self.enemiesInWave += 1
            } else if self.enemies.isEmpty && self.enemiesKilledInWave >= self.enemiesToSpawn {
                // 웨이브 완료
                self.nextWave()
            }
        }
    }
    
    func startAutoShooting() {
        autoShootTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.player else {
                timer.invalidate()
                return
            }
            
            // 가장 가까운 적 찾기
            if let nearestEnemy = self.findNearestEnemy() {
                self.shootBullet(from: player.position, to: nearestEnemy.position)
            }
        }
    }
    
    func startWaveTimer() {
        waveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 웨이브 정보 업데이트
            self.viewModel?.updateWave(self.currentWave)
        }
    }
    
    func spawnEnemy() {
        // 화면 밖 랜덤 위치에서 생성
        let side = Int.random(in: 0..<4) // 0: 위, 1: 오른쪽, 2: 아래, 3: 왼쪽
        var position: CGPoint
        
        switch side {
        case 0: // 위
            position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 50)
        case 1: // 오른쪽
            position = CGPoint(x: size.width + 50, y: CGFloat.random(in: 0...size.height))
        case 2: // 아래
            position = CGPoint(x: CGFloat.random(in: 0...size.width), y: -50)
        default: // 왼쪽
            position = CGPoint(x: -50, y: CGFloat.random(in: 0...size.height))
        }
        
        // 적 생성
        let enemy = SKSpriteNode(color: .red, size: CGSize(width: 30, height: 30))
        enemy.position = position
        enemy.name = "enemy"
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.categoryBitMask = 2
        enemy.physicsBody?.contactTestBitMask = 1
        enemy.physicsBody?.collisionBitMask = 0
        enemy.physicsBody?.isDynamic = true
        
        addChild(enemy)
        enemies.append(enemy)
        
        // 플레이어를 향해 이동
        if let player = player {
            let dx = player.position.x - position.x
            let dy = player.position.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            let speed: CGFloat = 50.0 + CGFloat(currentWave) * 5.0 // 웨이브마다 속도 증가
            
            enemy.physicsBody?.velocity = CGVector(
                dx: (dx / distance) * speed,
                dy: (dy / distance) * speed
            )
        }
    }
    
    func findNearestEnemy() -> SKSpriteNode? {
        guard let player = player else { return nil }
        
        var nearestEnemy: SKSpriteNode?
        var nearestDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        for enemy in enemies {
            let dx = enemy.position.x - player.position.x
            let dy = enemy.position.y - player.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < nearestDistance {
                nearestDistance = distance
                nearestEnemy = enemy
            }
        }
        
        return nearestEnemy
    }
    
    func shootBullet(from: CGPoint, to: CGPoint) {
        let bullet = SKSpriteNode(color: .yellow, size: CGSize(width: 8, height: 8))
        bullet.position = from
        bullet.name = "bullet"
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.categoryBitMask = 4
        bullet.physicsBody?.contactTestBitMask = 2
        bullet.physicsBody?.collisionBitMask = 0
        bullet.physicsBody?.isDynamic = true
        
        // 목표 지점으로 이동
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = sqrt(dx * dx + dy * dy)
        let speed: CGFloat = 500.0
        
        bullet.physicsBody?.velocity = CGVector(
            dx: (dx / distance) * speed,
            dy: (dy / distance) * speed
        )
        
        addChild(bullet)
        bullets.append(bullet)
        
        // 3초 후 자동 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            bullet.removeFromParent()
            if let index = self.bullets.firstIndex(of: bullet) {
                self.bullets.remove(at: index)
            }
        }
    }
    
    func removeAllEnemies() {
        for enemy in enemies {
            enemy.removeFromParent()
        }
        enemies.removeAll()
    }
    
    func nextWave() {
        currentWave += 1
        enemiesInWave = 0
        enemiesKilledInWave = 0
        enemiesToSpawn = 10 + currentWave * 5 // 웨이브마다 적 증가
        
        viewModel?.updateWave(currentWave)
        
        // 잠시 대기 후 다음 웨이브 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startEnemySpawning()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let player = player else { return }
        
        let location = touch.location(in: self)
        
        // 탭한 위치로 총알 발사
        shootBullet(from: player.position, to: location)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // 화면 밖으로 나간 적 제거
        for enemy in enemies {
            if enemy.position.x < -100 || enemy.position.x > size.width + 100 ||
               enemy.position.y < -100 || enemy.position.y > size.height + 100 {
                enemy.removeFromParent()
                if let index = enemies.firstIndex(of: enemy) {
                    enemies.remove(at: index)
                }
            }
        }
        
        // 화면 밖으로 나간 총알 제거
        for bullet in bullets {
            if bullet.position.x < -100 || bullet.position.x > size.width + 100 ||
               bullet.position.y < -100 || bullet.position.y > size.height + 100 {
                bullet.removeFromParent()
                if let index = bullets.firstIndex(of: bullet) {
                    bullets.remove(at: index)
                }
            }
        }
    }
}

// MARK: - Physics Contact Delegate
extension Game2DDefenseScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // 총알과 적 충돌
        if firstBody.categoryBitMask == 4 && secondBody.categoryBitMask == 2 {
            if let bullet = firstBody.node as? SKSpriteNode,
               let enemy = secondBody.node as? SKSpriteNode {
                // 총알 제거
                bullet.removeFromParent()
                if let index = bullets.firstIndex(of: bullet) {
                    bullets.remove(at: index)
                }
                
                // 적 제거
                enemy.removeFromParent()
                if let index = enemies.firstIndex(of: enemy) {
                    enemies.remove(at: index)
                }
                
                // 점수 추가
                enemiesKilledInWave += 1
                viewModel?.addKill()
                
                // 폭발 효과
                createExplosion(at: enemy.position)
            }
        }
        
        // 적과 플레이어 충돌
        if firstBody.categoryBitMask == 1 && secondBody.categoryBitMask == 2 {
            if let enemy = secondBody.node as? SKSpriteNode {
                // 적 제거
                enemy.removeFromParent()
                if let index = enemies.firstIndex(of: enemy) {
                    enemies.remove(at: index)
                }
                
                // 플레이어 데미지
                if let currentHP = viewModel?.playerHP {
                    let newHP = max(0, currentHP - 10)
                    viewModel?.updateHP(newHP)
                }
                
                // 충돌 효과
                createExplosion(at: enemy.position)
            }
        }
    }
    
    func createExplosion(at position: CGPoint) {
        // 간단한 폭발 효과
        let explosion = SKSpriteNode(color: .orange, size: CGSize(width: 20, height: 20))
        explosion.position = position
        explosion.alpha = 0.8
        addChild(explosion)
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        explosion.run(SKAction.sequence([fadeOut, remove]))
    }
}

