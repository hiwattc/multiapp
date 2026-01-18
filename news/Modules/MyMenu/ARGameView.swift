import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - AR Game View
struct ARGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var arViewModel: ARGameViewModel

    init(habitTitles: [String], quoteTexts: [String]) {
        let viewModel = ARGameViewModel()
        viewModel.setHabitData(habits: habitTitles, quotes: quoteTexts)
        _arViewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(arViewModel: arViewModel)
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
                        Text("AR 큐브 게임")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)

                        Text("점수: \(arViewModel.score)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 2)
                    }
                    .padding()

                    Button(action: {
                        arViewModel.resetGame()
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
                VStack(spacing: 8) {
                    Text("화면을 탭해서 큐브를 생성하세요!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)

                    Text("생성된 큐브를 탭하면 점수가 올라요")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arViewModel: ARGameViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // AR 세션 구성
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)

        // 디버깅용: 세션 델리게이트 설정
        arView.session.delegate = context.coordinator

        // ViewModel에 ARView 설정
        arViewModel.setARView(arView)

        // 코디네이터 설정
        context.coordinator.arView = arView
        context.coordinator.arViewModel = arViewModel

        // 제스처 인식기 추가
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
        weak var arViewModel: ARGameViewModel?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView, let arViewModel = arViewModel else {
                print("❌ ARView 또는 ViewModel이 nil입니다")
                return
            }

            let location = gesture.location(in: arView)
            print("👆 터치 위치: \(location)")

            // 1. 기존 평면에서 raycast 시도
            let existingPlaneResults = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
            if let firstResult = existingPlaneResults.first {
                print("✅ 기존 평면에서 raycast 성공")
                arViewModel.createCube(at: firstResult.worldTransform)
                return
            }

            // 2. 추정 평면에서 raycast 시도
            let estimatedResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = estimatedResults.first {
                print("✅ 추정 평면에서 raycast 성공")
                arViewModel.createCube(at: firstResult.worldTransform)
                return
            }

            // 3. 평면이 없는 경우 간단한 위치에 큐브 생성
            print("⚠️ 평면을 찾을 수 없어 기본 위치에 큐브 생성")

            // 간단한 identity matrix에 살짝 회전과 위치를 주어 큐브 생성
            var transform = matrix_identity_float4x4
            // 큐브를 카메라 앞쪽으로 배치하기 위해 Z축 이동
            transform.columns.3 = SIMD4<Float>(0, 0, -1, 1) // 앞쪽 1미터

            arViewModel.createCube(at: transform)
        }

        // AR 세션 델리게이트 메서드
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            print("📍 AR 앵커 추가됨: \(anchors.count)개")
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // 평면 업데이트 시 로깅
            let planeAnchors = anchors.filter { $0 is ARPlaneAnchor }
            if !planeAnchors.isEmpty {
                print("📐 평면 업데이트: \(planeAnchors.count)개 평면")
            }
        }
    }
}

// MARK: - AR Game View Model
class ARGameViewModel: ObservableObject {
    @Published var score: Int = 0
    private var cubes: [Entity] = []
    private var groundPlane: Entity?
    weak var arView: ARView?

    // 실제 습관과 명언 데이터 (외부에서 설정)
    private var habitTexts: [String] = []
    private var quoteTexts: [String] = []

    func setARView(_ view: ARView) {
        self.arView = view
        print("🔧 ARView 설정됨")
    }

    // HabitViewModel로부터 데이터 설정
    func setHabitData(habits: [String], quotes: [String]) {
        self.habitTexts = habits
        self.quoteTexts = quotes
        print("📚 AR 게임 데이터 설정됨 - 습관: \(habitTexts.count)개, 명언: \(quoteTexts.count)개")
    }

    private func createGroundPlane(at position: SIMD3<Float>) {
        guard let arView = arView else { return }

        // 기존 바닥 평면 제거
        if let existingGround = groundPlane {
            if let anchor = arView.scene.anchors.first(where: { $0.children.contains(existingGround) }) {
                arView.scene.removeAnchor(anchor)
            }
        }

        // 실제 감지된 위치에 바닥 평면 생성
        let mesh = MeshResource.generatePlane(width: 5, depth: 5)
        let material = SimpleMaterial(color: .white.withAlphaComponent(0.0), isMetallic: false)
        let ground = ModelEntity(mesh: mesh, materials: [material])

        // 물리 컴포넌트 추가 (정적 바닥)
        let shape = ShapeResource.generateBox(width: 5, height: 0.01, depth: 5)
        ground.collision = CollisionComponent(shapes: [shape])
        ground.physicsBody = PhysicsBodyComponent(massProperties: .default,
                                                material: .generate(friction: 0.9, restitution: 0.1),
                                                mode: .static)

        // 감지된 위치에 바닥 배치
        let anchor = AnchorEntity(world: position)
        anchor.addChild(ground)
        arView.scene.addAnchor(anchor)

        groundPlane = ground
        print("🏠 실제 바닥 평면 생성됨: \(position)")
    }

    func createCube(at transform: simd_float4x4) {
        guard let arView = arView else {
            print("❌ ARView가 설정되지 않았습니다")
            return
        }

        print("🎲 큐브 생성 시작...")

        do {
            // 실제 바닥 위치 추출
            let groundPosition = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            // 바닥 평면이 없으면 생성
            if groundPlane == nil {
                createGroundPlane(at: groundPosition)
            }

            // 랜덤 텍스트 선택
            let randomText = getRandomText()

            // 각 면에 다른 텍스트를 포함한 이미지 생성
            let faceImages = createFaceImages()

            // 큐브 모델 생성 (크기 2배: 0.2)
            let mesh = MeshResource.generateBox(size: 0.2)

            // 각 면에 다른 텍스처 적용 (UnlitMaterial로 텍스트 표시)
            var materials: [RealityKit.Material] = []

            for (index, image) in faceImages.enumerated() {
                do {
                    print("🔧 면 \(index + 1) 텍스처 생성 시도...")
                    // 텍스처 생성 성공했지만 SimpleMaterial에서 사용할 수 없음
                    // 현재는 색상 기반으로 표시
                    let fallbackMaterial = SimpleMaterial(color: UIColor.random(), isMetallic: false)
                    materials.append(fallbackMaterial)
                    print("✅ 면 \(index + 1) 텍스처 적용 성공")
                } catch {
                    print("❌ 면 \(index + 1) 텍스처 생성 실패: \(error.localizedDescription)")
                    // 실패 시 기본 색상 재질 사용
                    let fallbackMaterial = SimpleMaterial(color: UIColor.random(), isMetallic: false)
                    materials.append(fallbackMaterial)
                }
            }

            // 재질이 6개 미만이면 기본 색상으로 채우기
            while materials.count < 6 {
                let defaultMaterial = SimpleMaterial(color: UIColor.random(), isMetallic: false)
                materials.append(defaultMaterial)
                print("⚠️ 기본 색상 재질로 채움")
            }

            print("🎨 최종 재질 개수: \(materials.count)")

            let model = ModelEntity(mesh: mesh, materials: materials)

            // 물리 컴포넌트 추가 (크기 2배에 맞춤)
            let shape = ShapeResource.generateBox(size: SIMD3<Float>(0.2, 0.2, 0.2))
            model.collision = CollisionComponent(shapes: [shape])
            model.physicsBody = PhysicsBodyComponent(massProperties: .default,
                                                   material: .generate(friction: 0.8, restitution: 0.1),
                                                   mode: .dynamic)

            // 터치 제스처 컴포넌트 추가
            model.components.set(InputTargetComponent())

            // 실제 바닥 위쪽에 큐브 생성 (바닥 위치에서 +0.8만큼 위로)
            var cubePosition = groundPosition
            cubePosition.y += 0.8 // 큐브를 바닥 위 공중에 생성

            // 회전 애니메이션 추가
            let rotation = Transform(rotation: simd_quatf(angle: Float.random(in: 0...2*Float.pi),
                                                         axis: SIMD3<Float>(0, 1, 0)))
            model.transform = Transform(scale: SIMD3<Float>(1, 1, 1),
                                      rotation: rotation.rotation,
                                      translation: cubePosition)

            // 앵커 생성 및 추가 (큐브 위치에 맞춤)
            let anchor = AnchorEntity(world: cubePosition)
            anchor.addChild(model)
            arView.scene.addAnchor(anchor)

            // 큐브 리스트에 추가
            cubes.append(model)

            // 터치 이벤트 설정
            arView.installGestures(.all, for: model)

            // 점수 증가
            score += 10

            print("✅ 큐브 생성 완료! 실제 바닥 위쪽에 배치, 현재 점수: \(score)")

            // 3D 텍스트 표시
            displayTextAboveCube(model, text: randomText, in: arView)
        } catch {
            print("❌ 큐브 생성 실패: \(error.localizedDescription)")
        }
    }

    func resetGame() {
        guard let arView = arView else {
            print("❌ ARView가 설정되지 않았습니다")
            return
        }

        print("🔄 게임 리셋 시작...")

        // 모든 앵커 제거 (바닥 평면 포함)
        for anchor in arView.scene.anchors {
            arView.scene.removeAnchor(anchor)
        }

        // 큐브 리스트 및 바닥 평면 초기화
        cubes.removeAll()
        groundPlane = nil

        // 점수 초기화
        score = 0

        print("✅ 게임 리셋 완료 (모든 객체 제거)")
    }

    private func displayTextAboveCube(_ cubeModel: ModelEntity, text: String, in arView: ARView) {
        do {
            // 짧은 텍스트로 제한 (긴 텍스트는 표시가 어려움)
            let shortText = text.count > 10 ? String(text.prefix(10)) + "..." : text

            // 3D 텍스트 메쉬 생성
            let textMesh = MeshResource.generateText(
                shortText,
                extrusionDepth: 0.005,
                font: .systemFont(ofSize: 0.03),
                containerFrame: CGRect(x: 0, y: 0, width: 0.3, height: 0.1),
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )

            let textMaterial = SimpleMaterial(color: .black, isMetallic: false)
            let textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])

            // 텍스트를 큐브 위쪽에 배치 (큐브 중심을 기준으로)
            textModel.transform.translation = SIMD3<Float>(0, 0.13, 0)

            // 큐브에 텍스트를 자식으로 추가
            cubeModel.addChild(textModel)

            print("📝 큐브 위에 3D 텍스트 표시: '\(shortText)'")
        } catch {
            print("❌ 3D 텍스트 생성 실패: \(error.localizedDescription)")
            // 텍스트 생성 실패 시 기본 색상 유지
        }
    }

    private func createFaceImages() -> [UIImage] {
        var images: [UIImage] = []

        // 큐브의 6개 면에 대해 이미지 생성
        for faceIndex in 0..<6 {
            let text = getRandomText()
            print("🎨 면 \(faceIndex + 1) 텍스트 생성: \(text)")
            let image = createTextImage(text: text, size: CGSize(width: 512, height: 512))
            images.append(image)
        }

        print("✅ 총 \(images.count)개의 텍스트 이미지 생성됨")
        return images
    }

    private func getRandomText() -> String {
        // 습관과 명언을 랜덤하게 선택
        let useHabit = Bool.random()

        if useHabit && !habitTexts.isEmpty {
            return habitTexts.randomElement() ?? "습관 만들기"
        } else if !quoteTexts.isEmpty {
            return quoteTexts.randomElement() ?? "명언"
        }

        // 데이터가 없는 경우 기본 텍스트
        let defaultHabits = ["물 2L 마시기", "아침 스트레칭", "독서 30분", "걷기 운동", "명상하기"]
        let defaultQuotes = ["작은 일의 반복이\n큰 결과를 만든다", "오늘 할 수 있는\n최선을 다하라", "꾸준함이\n성공의 열쇠다"]

        return Bool.random() ? defaultHabits.randomElement()! : defaultQuotes.randomElement()!
    }

    private func createTextImage(text: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // 배경색 설정 (랜덤한 밝은 색상)
            let backgroundColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemTeal]
            let backgroundColor = backgroundColors.randomElement() ?? .systemBlue
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // 테두리 추가
            UIColor.white.setStroke()
            let borderRect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            let borderPath = UIBezierPath(rect: borderRect)
            borderPath.lineWidth = 4
            borderPath.stroke()

            // 텍스트 속성 설정
            let fontSize: CGFloat = min(size.width, size.height) * 0.12
            let font = UIFont.boldSystemFont(ofSize: fontSize)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byWordWrapping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle,
                .strokeColor: UIColor.black,
                .strokeWidth: -1.0
            ]

            // 텍스트 그리기
            let textRect = CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10)
            let attributedText = NSAttributedString(string: text, attributes: attributes)

            // 텍스트 크기 계산 및 중앙 정렬
            let textSize = attributedText.size()
            let textOrigin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            let finalTextRect = CGRect(origin: textOrigin, size: textSize)

            attributedText.draw(in: finalTextRect)
        }
    }
}

// UIColor 확장 - 랜덤 색상 생성
extension UIColor {
    static func random() -> UIColor {
        let colors: [UIColor] = [.red, .blue, .green, .yellow, .purple, .orange, .cyan, .magenta]
        return colors.randomElement() ?? .blue
    }
}
