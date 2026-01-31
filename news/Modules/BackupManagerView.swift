import SwiftUI
import UniformTypeIdentifiers
import MessageUI
import Combine

// MARK: - Backup Data Models
struct HabitBackupData: Codable {
    let version: String = "1.0"
    let exportDate: Date
    let habits: [Habit]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: exportDate)
    }
    
    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "습관백업_\(formatter.string(from: exportDate)).json"
    }
}

// MARK: - Backup Manager View Model
@MainActor
class BackupManagerViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showMailComposer = false
    @Published var showDocumentPicker = false
    @Published var exportedFileURL: URL?
    @Published var lastBackupDate: Date?
    @Published var iCloudAvailable = false
    @Published var showSettingsAlert = false
    @Published var showBackupPreview = false
    @Published var previewBackupData: HabitBackupData?
    
    private let appGroupID = "group.com.news.habit"
    private let iCloudContainerID = "iCloud.com.news.habit"
    private let saveKey = "SavedHabits"
    private let lastBackupKey = "LastBackupDate"
    
    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    
    init() {
        loadHabits()
        loadLastBackupDate()
        checkiCloudAvailability()
    }
    
    // MARK: - Load Data
    func loadHabits() {
        guard let data = userDefaults.data(forKey: saveKey) else {
            habits = []
            return
        }
        
        do {
            habits = try JSONDecoder().decode([Habit].self, from: data)
        } catch {
            print("습관 로드 실패: \(error)")
            habits = []
        }
    }
    
    private func loadLastBackupDate() {
        if let timestamp = userDefaults.object(forKey: lastBackupKey) as? TimeInterval {
            lastBackupDate = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    private func saveLastBackupDate() {
        let now = Date()
        userDefaults.set(now.timeIntervalSince1970, forKey: lastBackupKey)
        lastBackupDate = now
    }
    
    // MARK: - iCloud Functions
    func checkiCloudAvailability() {
        // 백그라운드 스레드에서 iCloud 확인
        Task.detached {
            let hasToken = FileManager.default.ubiquityIdentityToken != nil
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: self.iCloudContainerID)
            
            await MainActor.run {
                self.iCloudAvailable = hasToken && containerURL != nil
                if self.iCloudAvailable {
                    print("✅ iCloud 사용 가능: \(containerURL?.path ?? "경로 없음")")
                } else {
                    print("❌ iCloud 사용 불가 - Token: \(hasToken), Container: \(containerURL != nil)")
                }
            }
        }
    }
    
    func backupToiCloud() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let backupData = HabitBackupData(exportDate: Date(), habits: habits)
            let jsonData = try JSONEncoder().encode(backupData)
            
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID)?
                .appendingPathComponent("Documents")
                .appendingPathComponent("HabitBackup.json") else {
                throw BackupError.iCloudNotAvailable
            }
            
            // Documents 디렉토리 생성
            let documentsURL = iCloudURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            
            try jsonData.write(to: iCloudURL)
            
            saveLastBackupDate()
            successMessage = "iCloud에 백업되었습니다"
            
            // 3초 후 메시지 숨기기
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
            
        } catch BackupError.iCloudNotAvailable {
            errorMessage = "iCloud를 사용할 수 없습니다. 설정에서 iCloud Drive를 활성화해주세요."
            showSettingsAlert = true
        } catch {
            errorMessage = "iCloud 백업 실패: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func restoreFromiCloud() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID)?
                .appendingPathComponent("Documents")
                .appendingPathComponent("HabitBackup.json") else {
                throw BackupError.iCloudNotAvailable
            }
            
            guard FileManager.default.fileExists(atPath: iCloudURL.path) else {
                throw BackupError.backupNotFound
            }
            
            let jsonData = try Data(contentsOf: iCloudURL)
            try await restoreFromData(jsonData)
            
            successMessage = "iCloud에서 복원되었습니다"
            
            // 3초 후 메시지 숨기기
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
            
        } catch BackupError.iCloudNotAvailable {
            errorMessage = "iCloud를 사용할 수 없습니다. 설정에서 iCloud Drive를 활성화해주세요."
            showSettingsAlert = true
        } catch {
            errorMessage = "iCloud 복원 실패: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Preview Functions
    func previewiCloudBackup() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID)?
                .appendingPathComponent("Documents")
                .appendingPathComponent("HabitBackup.json") else {
                throw BackupError.iCloudNotAvailable
            }
            
            guard FileManager.default.fileExists(atPath: iCloudURL.path) else {
                throw BackupError.backupNotFound
            }
            
            let jsonData = try Data(contentsOf: iCloudURL)
            let decoder = JSONDecoder()
            let backupData = try decoder.decode(HabitBackupData.self, from: jsonData)
            
            previewBackupData = backupData
            showBackupPreview = true
            
        } catch BackupError.iCloudNotAvailable {
            errorMessage = "iCloud를 사용할 수 없습니다."
            showSettingsAlert = true
        } catch BackupError.backupNotFound {
            errorMessage = "백업 파일을 찾을 수 없습니다. 먼저 백업을 생성해주세요."
        } catch {
            errorMessage = "백업 파일 읽기 실패: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Settings
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Export Functions
    func exportToFile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let backupData = HabitBackupData(exportDate: Date(), habits: habits)
            
            // JSON 데이터 생성 (포맷팅 포함)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(backupData)
            
            // 임시 파일로 저장
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(backupData.fileName)
            
            try jsonData.write(to: tempURL)
            
            exportedFileURL = tempURL
            
            print("✅ 백업 파일 생성 완료: \(tempURL.path)")
            print("📄 파일명: \(backupData.fileName)")
            
            // 파일 공유 시트 표시
            await MainActor.run {
                self.shareFile()
            }
            
        } catch {
            errorMessage = "내보내기 실패: \(error.localizedDescription)"
            print("❌ 백업 파일 생성 실패: \(error)")
        }
        
        isLoading = false
    }
    
    private func shareFile() {
        guard let fileURL = exportedFileURL else {
            print("❌ 공유할 파일 URL이 없습니다")
            return
        }
        
        // 파일 존재 확인
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            errorMessage = "파일을 찾을 수 없습니다"
            print("❌ 파일이 존재하지 않음: \(fileURL.path)")
            return
        }
        
        print("📤 파일 공유 시트 표시 중...")
        
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // iPad 지원
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // 최상위 뷰 컨트롤러 찾기
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            topVC.present(activityVC, animated: true) {
                print("✅ 파일 공유 시트 표시 완료")
            }
        } else {
            errorMessage = "공유 화면을 표시할 수 없습니다"
            print("❌ 루트 뷰 컨트롤러를 찾을 수 없음")
        }
    }
    
    // MARK: - Import Functions
    func importFromFile(url: URL) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // 보안 스코프 접근 시작
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let jsonData = try Data(contentsOf: url)
            try await restoreFromData(jsonData)
            
            successMessage = "파일에서 복원되었습니다"
            
            // 3초 후 메시지 숨기기
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
            
        } catch {
            errorMessage = "파일 불러오기 실패: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Restore Logic
    private func restoreFromData(_ jsonData: Data) async throws {
        let decoder = JSONDecoder()
        let backupData = try decoder.decode(HabitBackupData.self, from: jsonData)
        
        // 데이터 저장
        let encoder = JSONEncoder()
        let habitsData = try encoder.encode(backupData.habits)
        userDefaults.set(habitsData, forKey: saveKey)
        
        // UI 업데이트
        habits = backupData.habits
        
        // 알림 재스케줄링
        await rescheduleAllNotifications()
    }
    
    private func rescheduleAllNotifications() async {
        // 기존 모든 습관 알림 삭제
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        let habitIdentifiers = requests.filter { $0.identifier.hasPrefix("habit-") }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: habitIdentifiers)
        
        // 새로운 알림 등록
        for habit in habits {
            for reminderTime in habit.reminderTimes {
                scheduleNotification(for: habit, time: reminderTime)
            }
        }
    }
    
    private func scheduleNotification(for habit: Habit, time: Date) {
        let center = UNUserNotificationCenter.current()
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let timeIdentifier = String(format: "%02d:%02d", timeComponents.hour ?? 0, timeComponents.minute ?? 0)
        
        let content = UNMutableNotificationContent()
        content.title = "습관 알림"
        content.body = "'\(habit.title)' 습관을 체크하세요!"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
        let identifier = "habit-\(habit.id.uuidString)-\(timeIdentifier)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("알림 스케줄링 실패: \(error)")
            }
        }
    }
}

// MARK: - Backup Errors
enum BackupError: LocalizedError {
    case iCloudNotAvailable
    case backupNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud를 사용할 수 없습니다. 설정에서 iCloud Drive를 활성화해주세요."
        case .backupNotFound:
            return "백업 파일을 찾을 수 없습니다."
        case .invalidData:
            return "잘못된 백업 파일입니다."
        }
    }
}

// MARK: - Backup Manager View
struct BackupManagerView: View {
    @StateObject private var viewModel = BackupManagerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    // 상태 섹션
                    statusSection
                    
                    // iCloud 섹션
                    iCloudSection
                    
                    // 파일 백업 섹션
                    fileBackupSection
                    
                    // 위험 구역
                    dangerZoneSection
                }
                .listStyle(.insetGrouped)
                
                // 오버레이 메시지
                if let successMessage = viewModel.successMessage {
                    successMessageOverlay(message: successMessage)
                }
            }
            .navigationTitle("백업 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .alert("iCloud 설정 필요", isPresented: $viewModel.showSettingsAlert) {
                Button("취소", role: .cancel) {
                    viewModel.errorMessage = nil
                    viewModel.showSettingsAlert = false
                }
                Button("설정 열기") {
                    viewModel.openSettings()
                    viewModel.errorMessage = nil
                    viewModel.showSettingsAlert = false
                }
            } message: {
                Text("iCloud Drive가 비활성화되어 있습니다.\n\n설정 > [사용자 이름] > iCloud > iCloud Drive를 활성화해주세요.")
            }
            .alert("오류", isPresented: .constant(viewModel.errorMessage != nil && !viewModel.showSettingsAlert)) {
                Button("확인") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                DocumentPicker { url in
                    Task {
                        await viewModel.importFromFile(url: url)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showBackupPreview) {
                if let backupData = viewModel.previewBackupData {
                    BackupPreviewView(backupData: backupData)
                }
            }
            .onAppear {
                // 화면이 나타날 때마다 iCloud 가용성 체크
                viewModel.checkiCloudAvailability()
            }
        }
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("습관 데이터")
                            .font(.headline)
                        Text("\(viewModel.habits.count)개의 습관")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastBackup = viewModel.lastBackupDate {
                    Divider()
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("마지막 백업: \(formatDate(lastBackup))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("백업 상태")
        }
    }
    
    // MARK: - iCloud Section
    private var iCloudSection: some View {
        Section {
            if viewModel.iCloudAvailable {
                // iCloud 백업
                Button(action: {
                    Task {
                        await viewModel.backupToiCloud()
                    }
                }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud에 백업")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("자동으로 모든 기기에 동기화")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disabled(viewModel.isLoading)
                
                // iCloud 백업 미리보기
                Button(action: {
                    Task {
                        await viewModel.previewiCloudBackup()
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title3)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("백업 파일 미리보기")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("저장된 데이터 확인")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disabled(viewModel.isLoading)
                
                // iCloud 복원
                Button(action: {
                    Task {
                        await viewModel.restoreFromiCloud()
                    }
                }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud에서 복원")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("백업된 데이터 불러오기")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disabled(viewModel.isLoading)
                
            } else {
                Button(action: {
                    viewModel.showSettingsAlert = true
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.icloud")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("iCloud를 사용할 수 없습니다")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("설정에서 iCloud Drive를 활성화해주세요")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.orange)
                        }
                        
                        Divider()
                        
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text("설정 열기")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        } header: {
            Text("iCloud 백업")
        } footer: {
            Text("iCloud에 백업하면 다른 기기에서도 동일한 데이터를 사용할 수 있습니다.")
        }
    }
    
    // MARK: - File Backup Section
    private var fileBackupSection: some View {
        Section {
            // JSON 파일로 내보내기
            Button(action: {
                Task {
                    await viewModel.exportToFile()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("파일로 내보내기")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("메일 또는 파일 앱으로 공유")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .disabled(viewModel.isLoading)
            
            // 파일에서 가져오기
            Button(action: {
                viewModel.showDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "folder")
                        .font(.title3)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("파일에서 가져오기")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("내 파일 앱에서 백업 파일 선택")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .disabled(viewModel.isLoading)
            
        } header: {
            Text("파일 백업")
        } footer: {
            Text("백업 파일을 메일로 전송하거나 파일 앱에 저장할 수 있습니다.")
        }
    }
    
    // MARK: - Danger Zone
    private var dangerZoneSection: some View {
        Section {
            Text("⚠️ 복원 시 현재 데이터가 모두 삭제되고 백업 파일의 데이터로 대체됩니다.")
                .font(.caption)
                .foregroundColor(.red)
                .padding(.vertical, 4)
        } header: {
            Text("주의사항")
        }
    }
    
    // MARK: - Success Message Overlay
    private func successMessageOverlay(message: String) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text(message)
                    .font(.headline)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: viewModel.successMessage)
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

// MARK: - Backup Preview View
struct BackupPreviewView: View {
    let backupData: HabitBackupData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // 백업 정보 섹션
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        BackupInfoRow(label: "백업 버전", value: backupData.version)
                        BackupInfoRow(label: "백업 날짜", value: backupData.formattedDate)
                        BackupInfoRow(label: "습관 개수", value: "\(backupData.habits.count)개")
                        
                        let totalReminders = backupData.habits.reduce(0) { $0 + $1.reminderTimes.count }
                        BackupInfoRow(label: "알림 개수", value: "\(totalReminders)개")
                        
                        let totalCompletions = backupData.habits.reduce(0) { $0 + $1.completions.count }
                        BackupInfoRow(label: "완료 기록", value: "\(totalCompletions)개")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("백업 정보")
                }
                
                // 습관 목록 섹션
                Section {
                    ForEach(backupData.habits) { habit in
                        HabitPreviewRow(habit: habit)
                    }
                } header: {
                    Text("습관 목록 (\(backupData.habits.count))")
                }
                
                // JSON 원본 섹션
                Section {
                    if let jsonString = backupData.toJSONString() {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(jsonString)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                        }
                        .frame(maxHeight: 200)
                        
                        Button(action: {
                            UIPasteboard.general.string = jsonString
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("JSON 복사")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("JSON 원본")
                }
            }
            .navigationTitle("백업 파일 미리보기")
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

// MARK: - Backup Info Row
struct BackupInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Habit Preview Row
struct HabitPreviewRow: View {
    let habit: Habit
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 습관 제목
            HStack {
                Text(habit.title)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // 기본 정보
            HStack(spacing: 16) {
                Label("\(habit.reminderTimes.count)", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Label("\(habit.completions.count)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            // 상세 정보 (확장 시)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    // 알림 시간
                    if !habit.reminderTimes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("알림 시간")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(habit.reminderTimes.indices, id: \.self) { index in
                                Text("• \(formatTime(habit.reminderTimes[index]))")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // 완료 기록
                    if !habit.completions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("최근 완료 기록 (최대 5개)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let sortedCompletions = habit.completions.sorted { $0.key > $1.key }.prefix(5)
                            ForEach(Array(sortedCompletions), id: \.key) { date, completed in
                                HStack {
                                    Text("• \(date)")
                                        .font(.caption)
                                    Spacer()
                                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(completed ? .green : .gray)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - HabitBackupData Extension
extension HabitBackupData {
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(self),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
}

// MARK: - Preview
#Preview {
    BackupManagerView()
}

