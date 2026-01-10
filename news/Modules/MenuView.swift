import SwiftUI

// MARK: - Menu Item Model
struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let description: String
}

// MARK: - Menu View
struct MenuView: View {
    let menuItems = [
        MenuItem(title: "계산기", icon: "calculator", color: .blue, description: "기본 사칙연산 계산"),
        MenuItem(title: "단위 변환", icon: "arrow.left.arrow.right", color: .green, description: "길이, 무게, 온도 변환"),
        MenuItem(title: "QR 생성기", icon: "qrcode", color: .purple, description: "텍스트를 QR 코드로 변환"),
        MenuItem(title: "색상 선택", icon: "eyedropper", color: .red, description: "RGB/HEX 색상 선택"),
        MenuItem(title: "텍스트 포맷", icon: "textformat", color: .orange, description: "텍스트 정렬 및 서식"),
        MenuItem(title: "JSON 뷰어", icon: "doc.text.magnifyingglass", color: .indigo, description: "JSON 데이터 구조 확인"),
        MenuItem(title: "Base64 변환", icon: "arrow.up.arrow.down", color: .pink, description: "텍스트 Base64 인코딩/디코딩"),
        MenuItem(title: "해시 생성", icon: "lock.shield", color: .gray, description: "MD5, SHA256 해시 생성"),
        MenuItem(title: "텍스트 비교", icon: "doc.on.doc", color: .cyan, description: "두 텍스트 차이점 비교"),
        MenuItem(title: "랜덤 생성", icon: "dice", color: .mint, description: "무작위 숫자/문자열 생성")
    ]

    let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("IT 유틸리티")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("개발자를 위한 다양한 도구 모음")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Menu Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(menuItems) { item in
                            MenuItemView(item: item)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Menu Item View
struct MenuItemView: View {
    let item: MenuItem
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
                performAction()
            }
        }) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(item.color)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)

                // Title
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                // Description
                Text(item.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28)
            }
            .frame(height: 120)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(item.color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func performAction() {
        // 각 메뉴 아이템에 대한 액션 구현
        switch item.title {
        case "계산기":
            showCalculator()
        case "단위 변환":
            showUnitConverter()
        case "QR 생성기":
            showQRGenerator()
        case "색상 선택":
            showColorPicker()
        case "텍스트 포맷":
            showTextFormatter()
        case "JSON 뷰어":
            showJSONViewer()
        case "Base64 변환":
            showBase64Converter()
        case "해시 생성":
            showHashGenerator()
        case "텍스트 비교":
            showTextComparer()
        case "랜덤 생성":
            showRandomGenerator()
        default:
            break
        }
    }

    // MARK: - Action Methods (샘플 구현)
    private func showCalculator() {
        // 계산기 화면으로 이동 (미구현)
        print("계산기 열기")
    }

    private func showUnitConverter() {
        // 단위 변환기 화면으로 이동 (미구현)
        print("단위 변환기 열기")
    }

    private func showQRGenerator() {
        // QR 생성기 화면으로 이동 (미구현)
        print("QR 생성기 열기")
    }

    private func showColorPicker() {
        // 색상 선택기 화면으로 이동 (미구현)
        print("색상 선택기 열기")
    }

    private func showTextFormatter() {
        // 텍스트 포맷터 화면으로 이동 (미구현)
        print("텍스트 포맷터 열기")
    }

    private func showJSONViewer() {
        // JSON 뷰어 화면으로 이동 (미구현)
        print("JSON 뷰어 열기")
    }

    private func showBase64Converter() {
        // Base64 변환기 화면으로 이동 (미구현)
        print("Base64 변환기 열기")
    }

    private func showHashGenerator() {
        // 해시 생성기 화면으로 이동 (미구현)
        print("해시 생성기 열기")
    }

    private func showTextComparer() {
        // 텍스트 비교기 화면으로 이동 (미구현)
        print("텍스트 비교기 열기")
    }

    private func showRandomGenerator() {
        // 랜덤 생성기 화면으로 이동 (미구현)
        print("랜덤 생성기 열기")
    }
}
