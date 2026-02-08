import SwiftUI
import GoogleSignIn
import MessageUI


// MARK: - Menu Item Model
struct MyMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let description: String
    let category: String
}

// MARK: - My Menu View
struct MyMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var habitViewModel = HabitViewModel()
    @StateObject private var mailService = MailService()
    @State private var showARGame = false
    @State private var showStepCounterView = false
    @State private var showMarbleMaze = false
    @State private var showAdventureGame = false
    @State private var showWeatherView = false
    @State private var showCryptoView = false
    @State private var showStockMapView = false
    @State private var showRSSReaderView = false
    @State private var showLiDARScanView = false
    @State private var showLiDARScanView2 = false
    @State private var showLiDARScanView3 = false
    @State private var showLiDARScanView4 = false
    @State private var showLiDARScanView5 = false
    @State private var showSavedScansView = false
    @State private var show3DGame1 = false
    @State private var show3DGame2 = false
    @State private var showRacingGame = false
    @State private var showFaceTrackingGame = false
    @State private var showDepthLayerEditor = false
    @State private var show3DGame3 = false
    @State private var show3DGame4 = false
    @State private var show3DGame5 = false

    init() {
        // MailService 초기화는 onAppear에서 수행
    }

    let menuItems = [
        // 뉴스
        MyMenuItem(title: "RSS리더", icon: "newspaper.fill", color: .orange, description: "RSS 피드 구독 및 뉴스", category: "뉴스"),
        
        // 금융
        MyMenuItem(title: "미국증시", icon: "chart.bar.fill", color: .blue, description: "미국 주식 시장 맵", category: "금융"),
        MyMenuItem(title: "암호화폐", icon: "bitcoinsign.circle.fill", color: .orange, description: "암호화폐 시세 및 뉴스", category: "금융"),
        
        // 날씨 및 환경
        MyMenuItem(title: "날씨", icon: "cloud.sun.fill", color: .blue, description: "현재 날씨 및 예보", category: "환경"),
        MyMenuItem(title: "대기질", icon: "aqi.medium", color: .green, description: "미세먼지 및 대기 상태", category: "환경"),

        // 센서 및 하드웨어
        MyMenuItem(title: "자이로스코프", icon: "gyroscope", color: .purple, description: "기기 회전 및 움직임 감지", category: "센서"),
        MyMenuItem(title: "가속도계", icon: "speedometer", color: .orange, description: "가속도 및 충격 감지", category: "센서"),
        MyMenuItem(title: "나침반", icon: "location.north.fill", color: .red, description: "방향 및 나침반", category: "센서"),

        // 통신 및 네트워크
        MyMenuItem(title: "메일", icon: "envelope.fill", color: .blue, description: "이메일 송수신", category: "통신"),
        MyMenuItem(title: "메시지", icon: "message.fill", color: .green, description: "SMS 및 메시지", category: "통신"),
        MyMenuItem(title: "전화", icon: "phone.fill", color: .purple, description: "전화 통화", category: "통신"),

        // 증강 현실 및 카메라
        MyMenuItem(title: "증강현실", icon: "arkit", color: .orange, description: "AR 콘텐츠 및 증강 현실", category: "AR/VR"),
        MyMenuItem(title: "라이다1", icon: "cube.transparent.fill", color: .cyan, description: "LiDAR로 공간 스캐닝", category: "AR/VR"),
        MyMenuItem(title: "라이다2", icon: "cube.transparent.fill", color: .blue, description: "LiDAR 스캐닝 (버튼형)", category: "AR/VR"),
        MyMenuItem(title: "라이다3", icon: "cube.transparent.fill", color: .purple, description: "컬러 구분 3D 스캐닝", category: "AR/VR"),
        MyMenuItem(title: "라이다4", icon: "grid.circle.fill", color: .green, description: "AR 그리드 손전등 효과", category: "AR/VR"),
        MyMenuItem(title: "라이다5", icon: "square.grid.3x3", color: .pink, description: "평면 그리드 표시", category: "AR/VR"),
        MyMenuItem(title: "저장된 스캔", icon: "folder.fill", color: .blue, description: "저장된 LiDAR 스캔 보기", category: "AR/VR"),
        MyMenuItem(title: "카메라", icon: "camera.fill", color: .red, description: "사진 촬영 및 동영상", category: "미디어"),
        MyMenuItem(title: "QR 스캔", icon: "qrcode.viewfinder", color: .green, description: "QR 코드 스캔", category: "도구"),

        // 도구 및 유틸리티
        MyMenuItem(title: "계산기", icon: "function", color: .blue, description: "수학 계산", category: "도구"),
        MyMenuItem(title: "단위 변환", icon: "arrow.left.arrow.right", color: .purple, description: "단위 변환기", category: "도구"),
        MyMenuItem(title: "메모장", icon: "note.text", color: .orange, description: "메모 및 노트", category: "생산성"),

        // 건강 및 피트니스
        MyMenuItem(title: "걸음 수", icon: "figure.walk", color: .green, description: "일일 걸음 수 추적", category: "건강"),
        MyMenuItem(title: "심박수", icon: "heart.fill", color: .red, description: "심박수 모니터링", category: "건강"),

        // 엔터테인먼트
        MyMenuItem(title: "음악", icon: "music.note", color: .pink, description: "음악 재생", category: "엔터"),
        MyMenuItem(title: "동영상", icon: "video.fill", color: .purple, description: "동영상 재생", category: "엔터"),

        // 게임
        MyMenuItem(title: "구슬미로", icon: "circle.grid.cross.fill", color: .blue, description: "자이로 센서로 미로 탈출", category: "게임"),
        MyMenuItem(title: "모험", icon: "figure.walk", color: .green, description: "힐링되는 자연 모험", category: "게임"),
        MyMenuItem(title: "game1", icon: "car.fill", color: .red, description: "2D 자동차 레이싱 게임", category: "게임"),
        MyMenuItem(title: "game2", icon: "face.smiling.fill", color: .cyan, description: "IR 얼굴 추적 및 그리기", category: "게임"),
        MyMenuItem(title: "game3", icon: "camera.metering.multispot", color: .purple, description: "LiDAR 깊이 레이어 편집", category: "게임"),
        
        // 3D 게임
        MyMenuItem(title: "게임1", icon: "gamecontroller.fill", color: .purple, description: "3D 공 터치 게임", category: "3D게임"),
        MyMenuItem(title: "게임2", icon: "sword.fill", color: .red, description: "RPG 스타일 3D 게임", category: "3D게임"),
        MyMenuItem(title: "게임3", icon: "arkit", color: .orange, description: "AR RPG 증강현실 게임", category: "3D게임"),
        MyMenuItem(title: "게임4", icon: "shield.fill", color: .green, description: "2D 방어 서바이벌 게임", category: "3D게임"),
        MyMenuItem(title: "게임5", icon: "balloon.fill", color: .pink, description: "AR 풍선 터트리기 게임", category: "3D게임")
    ]

    // 카테고리별로 그룹화
    var categorizedItems: [String: [MyMenuItem]] {
        Dictionary(grouping: menuItems) { $0.category }
    }

    var categories: [String] {
        ["뉴스", "금융", "환경", "센서", "통신", "AR/VR", "미디어", "도구", "생산성", "건강", "엔터", "게임", "3D게임"]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MailService 초기화
                    Color.clear.onAppear {
                        mailService.initialize(with: authViewModel, habitViewModel: habitViewModel)
                    }
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            Text("내 메뉴")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Spacer()

                            Button(action: {
                                authViewModel.signOut()
                                dismiss()
                            }) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                        }

                        Text("다양한 기능을 탐색해보세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // 카테고리별 메뉴들
                    ForEach(categories, id: \.self) { category in
                        if let items = categorizedItems[category], !items.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 16)], spacing: 16) {
                                    ForEach(items) { item in
                                        MyMenuItemView(item: item) {
                                            performAction(for: item)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $mailService.showingMailComposer) {
            mailService.createMailComposerView()
        }
        .alert("메일 주소 없음", isPresented: $mailService.showingNoEmailAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("로그인된 계정의 이메일 주소를 찾을 수 없습니다.\nGoogle 또는 Apple 계정으로 다시 로그인해주세요.")
        }
        .sheet(isPresented: $showARGame) {
            ARGameView(
                habitTitles: habitViewModel.habits.map { $0.title },
                quoteTexts: habitViewModel.accessibleBibleVerses.map { "\($0.krv)\n\($0.niv)" }
            )
        }
        .sheet(isPresented: $showStepCounterView) {
            StepCounterView()
        }
        .sheet(isPresented: $showMarbleMaze) {
            MarbleMazeView()
        }
        .sheet(isPresented: $showAdventureGame) {
            AdventureGameView()
        }
        .sheet(isPresented: $showWeatherView) {
            WeatherView()
        }
        .sheet(isPresented: $showCryptoView) {
            CryptoView()
        }
        .sheet(isPresented: $showStockMapView) {
            StockMapView()
        }
        .sheet(isPresented: $showRSSReaderView) {
            RSSReaderView()
        }
        .sheet(isPresented: $showLiDARScanView) {
            LiDARScanView()
        }
        .sheet(isPresented: $showLiDARScanView2) {
            LiDARScanView2()
        }
        .sheet(isPresented: $showLiDARScanView3) {
            LiDARScanView3()
        }
        .sheet(isPresented: $showLiDARScanView4) {
            LiDARScanView4()
        }
        .sheet(isPresented: $showLiDARScanView5) {
            LiDARScanView5()
        }
        .sheet(isPresented: $showSavedScansView) {
            SavedScansListView()
        }
        .sheet(isPresented: $show3DGame1) {
            Game3DView1()
        }
        .sheet(isPresented: $show3DGame2) {
            Game3DView2()
        }
        .sheet(isPresented: $show3DGame3) {
            Game3DView3()
        }
        .sheet(isPresented: $show3DGame4) {
            Game2DDefenseView()
        }
        .sheet(isPresented: $show3DGame5) {
            GameARBalloonView()
        }
        .sheet(isPresented: $showRacingGame) {
            RacingGameView()
        }
        .sheet(isPresented: $showFaceTrackingGame) {
            FaceTrackingView()
        }
        .sheet(isPresented: $showDepthLayerEditor) {
            DepthLayerEditorView()
        }
    }

    private func performAction(for item: MyMenuItem) {
        // 각 메뉴 아이템에 대한 액션 구현
        switch item.title {
        case "RSS리더":
            showRSSReader()
        case "미국증시":
            showStockMap()
        case "암호화폐":
            showCrypto()
        case "날씨":
            showWeather()
        case "자이로스코프":
            showGyroscope()
        case "메일":
            showMail()
        case "증강현실":
            showAugmentedReality()
        case "라이다1":
            showLiDARScan()
        case "라이다2":
            showLiDARScan2()
        case "라이다3":
            showLiDARScan3()
        case "라이다4":
            showLiDARScan4()
        case "라이다5":
            showLiDARScan5()
        case "저장된 스캔":
            showSavedScans()
        case "걸음 수":
            showStepCounter()
        case "계산기":
            showCalculator()
        case "카메라":
            showCamera()
        case "구슬미로":
            showMarbleMazeGame()
        case "모험":
            showAdventureGameView()
        case "game1":
            showRacingGameView()
        case "game2":
            showFaceTrackingGameView()
        case "game3":
            showDepthLayerEditorView()
        case "게임1":
            show3DGame1View()
        case "게임2":
            show3DGame2View()
        case "게임3":
            show3DGame3View()
        case "게임4":
            show3DGame4View()
        case "게임5":
            show3DGame5View()
        case "음악":
            showMusic()
        default:
            showDefaultAction(for: item)
        }
    }

    // MARK: - Action Methods (더미 구현)
    private func showRSSReader() {
        print("📰 RSS리더 화면 열기")
        showRSSReaderView = true
    }
    
    private func showStockMap() {
        print("📊 미국증시 화면 열기")
        showStockMapView = true
    }
    
    private func showCrypto() {
        print("💰 암호화폐 화면 열기")
        showCryptoView = true
    }
    
    private func showWeather() {
        print("🌤️ 날씨 화면 열기")
        showWeatherView = true
    }

    private func showGyroscope() {
        print("🎯 자이로스코프 화면 열기")
        // 실제로는 CoreMotion 프레임워크 사용
    }

    private func showMail() {
        mailService.sendHabitReportEmail()
    }



    private func showAugmentedReality() {
        print("🎭 AR 큐브 게임 시작")
        showARGame = true
    }
    
    private func showLiDARScan() {
        print("📡 LiDAR 스캐닝 시작")
        showLiDARScanView = true
    }
    
    private func showLiDARScan2() {
        print("📡 LiDAR 스캐닝 2 시작")
        showLiDARScanView2 = true
    }
    
    private func showLiDARScan3() {
        print("📡 LiDAR 스캐닝 3 시작 (컬러 구분)")
        showLiDARScanView3 = true
    }
    
    private func showLiDARScan4() {
        print("📡 LiDAR 스캐닝 4 시작 (AR 그리드 손전등)")
        showLiDARScanView4 = true
    }
    
    private func showLiDARScan5() {
        print("📡 LiDAR 스캐닝 5 시작 (평면 그리드)")
        showLiDARScanView5 = true
    }
    
    private func showSavedScans() {
        print("📁 저장된 스캔 목록 열기")
        showSavedScansView = true
    }
    
    private func show3DGame1View() {
        print("🎮 3D 게임1 시작")
        show3DGame1 = true
    }
    
    private func show3DGame2View() {
        print("🎮 3D 게임2 (RPG) 시작")
        show3DGame2 = true
    }
    
    private func show3DGame3View() {
        print("🎮 3D 게임3 (AR RPG) 시작")
        show3DGame3 = true
    }
    
    private func show3DGame4View() {
        print("🎮 게임4 (2D 방어 게임) 시작")
        show3DGame4 = true
    }
    
    private func show3DGame5View() {
        print("🎮 게임5 (AR 풍선 게임) 시작")
        show3DGame5 = true
    }
    
    private func showRacingGameView() {
        print("🏎️ 2D 레이싱 게임 시작")
        showRacingGame = true
    }
    
    private func showFaceTrackingGameView() {
        print("👤 얼굴 추적 게임 시작")
        showFaceTrackingGame = true
    }
    
    private func showDepthLayerEditorView() {
        print("📷 깊이 레이어 편집기 시작")
        showDepthLayerEditor = true
    }

    private func showStepCounter() {
        print("👣 걸음 수 카운터 시작")
        showStepCounterView = true
    }

    private func showMarbleMazeGame() {
        print("🎯 구슬 미로 게임 시작")
        showMarbleMaze = true
    }

    private func showAdventureGameView() {
        print("🌿 모험 게임 시작")
        showAdventureGame = true
    }

    private func showCalculator() {
        print("🧮 계산기 화면 열기")
        // 실제로는 계산 로직 구현
    }

    private func showCamera() {
        print("📷 카메라 화면 열기")
        // 실제로는 AVFoundation 사용
    }

    private func showMusic() {
        print("🎵 음악 화면 열기")
        // 실제로는 MediaPlayer 사용
    }

    private func showDefaultAction(for item: MyMenuItem) {
        print("🔧 \(item.title) 기능 실행")
        // 일반적인 액션 처리
    }
}

// MARK: - My Menu Item View
struct MyMenuItemView: View {
    let item: MyMenuItem
    let onAction: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                onAction()
            }
        }) {
            VStack(spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(item.color)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)

                // Title
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(height: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MyMenuView()
}
