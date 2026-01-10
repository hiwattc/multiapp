import SwiftUI

// MARK: - Main View
struct ContentView: View {
    @State private var selectedTab: TabType = .habit
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            Group {
                switch selectedTab {
                case .habit:
                    HabitView()
                case .news:
                    NewsView()
                case .map:
                    MapView()
                case .art:
                    ArtView()
                }
            }
            
            // Bottom Tab Bar
            BottomTabBar(selectedTab: $selectedTab)
        }
    }
}

#Preview {
    ContentView()
}
