import SwiftUI
import UserNotifications
import Combine
import WidgetKit

// MARK: - Notification Info Models
struct ScheduledNotification: Identifiable {
    let id: String
    let habitId: UUID?
    let habitTitle: String
    let scheduledDate: Date
    let scheduleHour: Int
    let scheduleMinute: Int
    let body: String
    let isOrphaned: Bool // 습관 데이터에는 없지만 시스템에 등록된 알림
    
    var formattedTime: String {
        return String(format: "%02d:%02d", scheduleHour, scheduleMinute)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: scheduledDate)
    }
    
    // 시간 비교용 (시:분을 분으로 변환)
    var timeInMinutes: Int {
        return scheduleHour * 60 + scheduleMinute
    }
}

// MARK: - Notification Manager View Model
@MainActor
class NotificationManagerViewModel: ObservableObject {
    @Published var scheduledNotifications: [ScheduledNotification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var showDeleteConfirmation = false
    @Published var notificationToDelete: ScheduledNotification?
    
    private let appGroupID = "group.com.news.habit"
    private let saveKey = "SavedHabits"
    
    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    
    func loadAllNotifications() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. 시스템에 등록된 알림 가져오기
            let center = UNUserNotificationCenter.current()
            let pendingRequests = await center.pendingNotificationRequests()
            
            // 2. 저장된 습관 데이터 가져오기
            let savedHabits = loadHabits()
            
            // 3. 알림 데이터 구성
            var notifications: [ScheduledNotification] = []
            
            for request in pendingRequests {
                // 습관 알림만 필터링 (identifier가 "habit-"로 시작하는 것들)
                guard request.identifier.hasPrefix("habit-") else { continue }
                
                // identifier 파싱: "habit-{UUID}-{HH:mm}"
                // 예: "habit-550e8400-e29b-41d4-a716-446655440000-09:00"
                let identifierString = request.identifier
                let habitPrefix = "habit-"
                
                guard let habitStartIndex = identifierString.range(of: habitPrefix)?.upperBound else { continue }
                let afterPrefix = String(identifierString[habitStartIndex...])
                
                // UUID는 8-4-4-4-12 형식이므로 36자
                // UUID 부분만 추출
                guard afterPrefix.count > 36 else { continue }
                let habitIdString = String(afterPrefix.prefix(36))
                guard let habitId = UUID(uuidString: habitIdString) else { continue }
                
                // 해당 습관 찾기
                let habit = savedHabits.first { $0.id == habitId }
                
                // 트리거에서 날짜 정보 추출
                var scheduledDate = Date()
                var scheduleHour = 0
                var scheduleMinute = 0
                
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    scheduleHour = trigger.dateComponents.hour ?? 0
                    scheduleMinute = trigger.dateComponents.minute ?? 0
                    
                    if let nextTriggerDate = trigger.nextTriggerDate() {
                        scheduledDate = nextTriggerDate
                    }
                }
                
                // 유령 알림 판별 (습관이 삭제되었거나 해당 알림 시간이 습관에 없는 경우)
                let isOrphaned: Bool
                if let habit = habit {
                    // 습관은 있지만 해당 알림 시간이 습관의 reminderTimes에 없는 경우
                    let calendar = Calendar.current
                    let hasMatchingTime = habit.reminderTimes.contains { reminderTime in
                        let hour = calendar.component(.hour, from: reminderTime)
                        let minute = calendar.component(.minute, from: reminderTime)
                        return hour == scheduleHour && minute == scheduleMinute
                    }
                    isOrphaned = !hasMatchingTime
                } else {
                    // 습관이 삭제된 경우
                    isOrphaned = true
                }
                
                let notification = ScheduledNotification(
                    id: request.identifier,
                    habitId: habitId,
                    habitTitle: habit?.title ?? "삭제된 습관",
                    scheduledDate: scheduledDate,
                    scheduleHour: scheduleHour,
                    scheduleMinute: scheduleMinute,
                    body: request.content.body,
                    isOrphaned: isOrphaned
                )
                
                notifications.append(notification)
            }
            
            // 알림 시간순 정렬 (시:분 기준)
            self.scheduledNotifications = notifications.sorted { 
                if $0.timeInMinutes != $1.timeInMinutes {
                    return $0.timeInMinutes < $1.timeInMinutes
                } else {
                    // 같은 시간이면 습관 이름순
                    return $0.habitTitle < $1.habitTitle
                }
            }
            
        } catch {
            errorMessage = "알림 로드 실패: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func removeOrphanedNotifications() async {
        let orphanedNotifications = scheduledNotifications.filter { $0.isOrphaned }
        guard !orphanedNotifications.isEmpty else { return }
        
        let identifiers = orphanedNotifications.map { $0.id }
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        showSuccessMessage = true
        
        // 목록 새로고침
        await loadAllNotifications()
        
        // 2초 후 성공 메시지 숨기기
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        showSuccessMessage = false
    }
    
    func removeNotification(_ notification: ScheduledNotification) async {
        // 1. 시스템 알림 삭제
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notification.id])
        
        // 2. 습관 데이터에서도 해당 알림 시간 제거
        if let habitId = notification.habitId {
            var habits = loadHabits()
            
            if let habitIndex = habits.firstIndex(where: { $0.id == habitId }) {
                // 해당 시간의 알림을 reminderTimes에서 제거
                habits[habitIndex].reminderTimes.removeAll { reminderTime in
                    let calendar = Calendar.current
                    let hour = calendar.component(.hour, from: reminderTime)
                    let minute = calendar.component(.minute, from: reminderTime)
                    return hour == notification.scheduleHour && minute == notification.scheduleMinute
                }
                
                // 수정된 습관 목록 저장
                saveHabits(habits)
                
                print("✅ 알림 삭제 완료: \(notification.habitTitle) - \(notification.formattedTime)")
            }
        }
        
        // 3. 목록 새로고침
        await loadAllNotifications()
    }
    
    func confirmDeleteNotification(_ notification: ScheduledNotification) {
        notificationToDelete = notification
        showDeleteConfirmation = true
    }
    
    func performDelete() async {
        guard let notification = notificationToDelete else { return }
        await removeNotification(notification)
        notificationToDelete = nil
        showDeleteConfirmation = false
    }
    
    private func loadHabits() -> [Habit] {
        guard let data = userDefaults.data(forKey: saveKey) else {
            return []
        }
        
        do {
            let habits = try JSONDecoder().decode([Habit].self, from: data)
            return habits
        } catch {
            print("습관 로드 실패: \(error)")
            return []
        }
    }
    
    private func saveHabits(_ habits: [Habit]) {
        do {
            let data = try JSONEncoder().encode(habits)
            userDefaults.set(data, forKey: saveKey)
            
            // 위젯 업데이트
            WidgetKit.WidgetCenter.shared.reloadAllTimelines()
            
            // HabitViewModel에 데이터 변경 알림
            NotificationCenter.default.post(name: NSNotification.Name("HabitsDataChanged"), object: nil)
            
            print("✅ 습관 데이터 저장 완료 및 UI 업데이트 알림 전송")
        } catch {
            print("❌ 습관 저장 실패: \(error)")
        }
    }
}

// MARK: - Notification Manager View
struct NotificationManagerView: View {
    @StateObject private var viewModel = NotificationManagerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("알림 목록 불러오는 중...")
                } else if viewModel.scheduledNotifications.isEmpty {
                    emptyStateView
                } else {
                    notificationListView
                }
                
                if viewModel.showSuccessMessage {
                    successMessageOverlay
                }
            }
            .navigationTitle("알림 설정 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadAllNotifications()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadAllNotifications()
            }
            .alert("알림 삭제", isPresented: $viewModel.showDeleteConfirmation) {
                Button("취소", role: .cancel) {
                    viewModel.notificationToDelete = nil
                }
                Button("삭제", role: .destructive) {
                    Task {
                        await viewModel.performDelete()
                    }
                }
            } message: {
                if let notification = viewModel.notificationToDelete {
                    Text("'\(notification.habitTitle)' 습관의 \(notification.formattedTime) 알림을 삭제하시겠습니까?\n\n습관 데이터에서도 이 알림 설정이 제거됩니다.")
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("등록된 알림이 없습니다")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("습관에 알림을 설정하면\n여기에서 확인할 수 있습니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var notificationListView: some View {
        VStack(spacing: 0) {
            // 유령 알림 경고 및 일괄 삭제 버튼
            if viewModel.scheduledNotifications.contains(where: { $0.isOrphaned }) {
                orphanedNotificationsWarning
            }
            
            List {
                // 시간대별 섹션
                let morningAlarms = viewModel.scheduledNotifications.filter { $0.scheduleHour < 12 }
                let afternoonAlarms = viewModel.scheduledNotifications.filter { $0.scheduleHour >= 12 && $0.scheduleHour < 18 }
                let eveningAlarms = viewModel.scheduledNotifications.filter { $0.scheduleHour >= 18 }
                
                if !morningAlarms.isEmpty {
                    Section {
                        ForEach(morningAlarms) { notification in
                            NotificationRow(notification: notification) {
                                viewModel.confirmDeleteNotification(notification)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                            Text("오전 (00:00 ~ 11:59)")
                        }
                    }
                }
                
                if !afternoonAlarms.isEmpty {
                    Section {
                        ForEach(afternoonAlarms) { notification in
                            NotificationRow(notification: notification) {
                                viewModel.confirmDeleteNotification(notification)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.yellow)
                            Text("오후 (12:00 ~ 17:59)")
                        }
                    }
                }
                
                if !eveningAlarms.isEmpty {
                    Section {
                        ForEach(eveningAlarms) { notification in
                            NotificationRow(notification: notification) {
                                viewModel.confirmDeleteNotification(notification)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                                .foregroundColor(.purple)
                            Text("저녁 (18:00 ~ 23:59)")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    private var orphanedNotificationsWarning: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("유령 알림 발견")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("삭제된 습관의 알림이 \(viewModel.scheduledNotifications.filter { $0.isOrphaned }.count)개 있습니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button(action: {
                Task {
                    await viewModel.removeOrphanedNotifications()
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("유령 알림 모두 삭제")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
    
    private var successMessageOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("유령 알림이 삭제되었습니다")
                    .font(.headline)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: viewModel.showSuccessMessage)
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: ScheduledNotification
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 알림 아이콘
            Image(systemName: notification.isOrphaned ? "bell.slash.fill" : "bell.fill")
                .font(.title2)
                .foregroundColor(notification.isOrphaned ? .orange : .blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                // 습관 제목
                Text(notification.habitTitle)
                    .font(.headline)
                    .foregroundColor(notification.isOrphaned ? .secondary : .primary)
                    .strikethrough(notification.isOrphaned)
                
                // 알림 시간
                HStack(spacing: 8) {
                    Label(notification.formattedTime, systemImage: "clock")
                        .font(.subheadline)
                    
                    if notification.isOrphaned {
                        Text("(유령 알림)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(.secondary)
                .font(.caption)
                
                // 알림 내용
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 삭제 버튼
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.body)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview {
    NotificationManagerView()
}

