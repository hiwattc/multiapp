import SwiftUI
import UIKit
import Combine

// MARK: - Tab Type
enum TabType: String, CaseIterable {
    case habit = "해빗"
    case news = "뉴스"
    case map = "지도"
    case art = "미술"
    case ping = "핑"
    case menu = "전체"

    var icon: String {
        switch self {
        case .news: return "newspaper.fill"
        case .map: return "map.fill"
        case .art: return "paintpalette.fill"
        case .habit: return "checkmark.circle.fill"
        case .ping: return "network"
        case .menu: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - ScrollView With Offset Tracking
struct ScrollViewWithOffset<Content: View>: View {
    let onOffsetChange: (CGFloat) -> Void
    let content: () -> Content

    init(onOffsetChange: @escaping (CGFloat) -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.onOffsetChange = onOffsetChange
        self.content = content
    }

    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).minY
                )
            }
            .frame(height: 0)

            content()
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            onOffsetChange(value)
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Bottom Tab Bar
struct BottomTabBar: View {
    @Binding var selectedTab: TabType

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(TabType.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }

                        // 탭 전환 시 가벼운 진동
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 24))

                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedTab == tab ? .blue : .gray)
                    }
                }
            }
            .padding(.bottom, 0) // 홈 인디케이터 공간 확보
            .background(
                Color(UIColor.secondarySystemGroupedBackground)
                    .ignoresSafeArea(edges: .bottom)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: TabType = .habit
    @StateObject private var habitViewModel = HabitViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            Group {
                switch selectedTab {
                case .habit:
                    HabitView(viewModel: habitViewModel)
                case .news:
                    NewsView()
                case .map:
                    MapView()
                case .art:
                    ArtView()
                case .ping:
                    PingView()
                case .menu:
                    MenuView()
                }
            }

            // Bottom Tab Bar - 입력창 포커스 시 숨김
            if !habitViewModel.isTextFieldFocused {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 20) // 추가 공간 확보
                    BottomTabBar(selectedTab: $selectedTab)
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // 앱이 포그라운드로 돌아올 때마다 배지 초기화
                UIApplication.shared.applicationIconBadgeNumber = 0
                print("🔔 앱 활성화 시 알림 배지 초기화: \(UIApplication.shared.applicationIconBadgeNumber)")
            }
        }
    }
}

#Preview {
    ContentView()
}
