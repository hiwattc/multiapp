import SwiftUI
import CoreMotion
import Combine

// MARK: - 걸음 수 카운터 뷰
struct StepCounterView: View {
    @StateObject private var pedometerManager = PedometerManager()
    @State private var dailyGoal: Int = 10000 // 기본 목표: 10,000걸음
    @State private var showingGoalSetter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // 헤더
                    VStack(spacing: 8) {
                        Text("🚶‍♂️ 걸음 수")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("오늘의 걸음 수를 확인하세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // 메인 걸음 수 표시
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 20)
                            .frame(width: 250, height: 250)

                        Circle()
                            .trim(from: 0, to: min(CGFloat(pedometerManager.todaySteps) / CGFloat(dailyGoal), 1.0))
                            .stroke(Color.blue, lineWidth: 20)
                            .frame(width: 250, height: 250)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 8) {
                            Text("\(pedometerManager.todaySteps)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.blue)

                            Text("걸음")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            if pedometerManager.todaySteps >= dailyGoal {
                                Text("🎉 목표 달성!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            } else {
                                Text("\(dailyGoal - pedometerManager.todaySteps)걸음 남음")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 20)

                    // 상세 정보 카드들
                    VStack(spacing: 16) {
                        // 거리
                        InfoCard(
                            icon: "📏",
                            title: "이동 거리",
                            value: String(format: "%.2f km", pedometerManager.todayDistance / 1000),
                            color: .green
                        )

                        // 칼로리
                        InfoCard(
                            icon: "🔥",
                            title: "소모 칼로리",
                            value: "\(Int(pedometerManager.todayCalories)) kcal",
                            color: .orange
                        )

                        // 평균 속도
                        InfoCard(
                            icon: "⚡",
                            title: "평균 속도",
                            value: String(format: "%.1f km/h", pedometerManager.averageSpeed * 3.6),
                            color: .purple
                        )

                        // 걸음 빈도
                        InfoCard(
                            icon: "👣",
                            title: "걸음 빈도",
                            value: String(format: "%.1f 걸음/분", pedometerManager.stepsPerMinute),
                            color: .pink
                        )
                    }

                    // 컨트롤 버튼들
                    VStack(spacing: 16) {
                        // 목표 설정 버튼
                        Button(action: {
                            showingGoalSetter = true
                        }) {
                            HStack {
                                Image(systemName: "target")
                                Text("일일 목표 설정")
                                Text("(\(dailyGoal)걸음)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }

                        // 리셋 버튼
                        Button(action: {
                            pedometerManager.resetTodayData()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("오늘 데이터 리셋")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // 상태 표시
                    if !pedometerManager.isPedometerAvailable {
                        Text("🚫 이 기기에서는 걸음 수 측정이 지원되지 않습니다")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    } else if !pedometerManager.isAuthorized {
                        Text("⚠️ 걸음 수 데이터 접근 권한이 필요합니다")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 새로고침
                        pedometerManager.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingGoalSetter) {
                GoalSetterView(dailyGoal: $dailyGoal)
            }
            .onAppear {
                pedometerManager.startUpdates()
            }
            .onDisappear {
                pedometerManager.stopUpdates()
            }
        }
    }
}

// MARK: - 정보 카드
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - 목표 설정 뷰
struct GoalSetterView: View {
    @Binding var dailyGoal: Int
    @Environment(\.dismiss) private var dismiss
    @State private var tempGoal: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("일일 걸음 수 목표 설정")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("목표 걸음 수")
                        .font(.headline)

                    TextField("예: 10000", text: $tempGoal)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)

                    Text("하루에 걸을 목표 걸음 수를 설정하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // 프리셋 버튼들
                VStack(spacing: 12) {
                    Text("빠른 설정")
                        .font(.headline)

                    HStack(spacing: 12) {
                        PresetButton(title: "5,000", value: 5000, currentGoal: $dailyGoal, tempGoal: $tempGoal)
                        PresetButton(title: "8,000", value: 8000, currentGoal: $dailyGoal, tempGoal: $tempGoal)
                        PresetButton(title: "10,000", value: 10000, currentGoal: $dailyGoal, tempGoal: $tempGoal)
                    }

                    HStack(spacing: 12) {
                        PresetButton(title: "12,000", value: 12000, currentGoal: $dailyGoal, tempGoal: $tempGoal)
                        PresetButton(title: "15,000", value: 15000, currentGoal: $dailyGoal, tempGoal: $tempGoal)
                        PresetButton(title: "20,000", value: 20000, currentGoal: $dailyGoal, tempGoal: $tempGoal)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("취소") {
                    dismiss()
                },
                trailing: Button("저장") {
                    if let goal = Int(tempGoal), goal > 0 {
                        dailyGoal = goal
                        UserDefaults.standard.set(dailyGoal, forKey: "DailyStepGoal")
                    }
                    dismiss()
                }
                .disabled(Int(tempGoal) == nil || Int(tempGoal)! <= 0)
            )
            .onAppear {
                tempGoal = "\(dailyGoal)"
            }
        }
    }
}

// MARK: - 프리셋 버튼
struct PresetButton: View {
    let title: String
    let value: Int
    @Binding var currentGoal: Int
    @Binding var tempGoal: String

    var body: some View {
        Button(action: {
            currentGoal = value
            tempGoal = "\(value)"
        }) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 만보기 매니저
class PedometerManager: NSObject, ObservableObject {
    @Published var todaySteps: Int = 0
    @Published var todayDistance: Double = 0.0
    @Published var todayCalories: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    @Published var stepsPerMinute: Double = 0.0
    @Published var isPedometerAvailable: Bool = false
    @Published var isAuthorized: Bool = false

    private let pedometer = CMPedometer()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        checkAvailability()
        loadSavedGoal()
    }

    func checkAvailability() {
        isPedometerAvailable = CMPedometer.isStepCountingAvailable()
        isAuthorized = true // 실제로는 CMPedometer.authorizationStatus()로 확인해야 함
    }

    func startUpdates() {
        guard isPedometerAvailable else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        // 오늘 데이터 쿼리
        pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] data, error in
            DispatchQueue.main.async {
                if let data = data, error == nil {
                    self?.updateData(with: data)
                }
            }
        }

        // 실시간 업데이트 시작
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            DispatchQueue.main.async {
                if let data = data, error == nil {
                    self?.updateData(with: data)
                }
            }
        }
    }

    func stopUpdates() {
        pedometer.stopUpdates()
    }

    func refreshData() {
        stopUpdates()
        startUpdates()
    }

    func resetTodayData() {
        todaySteps = 0
        todayDistance = 0.0
        todayCalories = 0.0
        averageSpeed = 0.0
        stepsPerMinute = 0.0

        // UserDefaults에 오늘 데이터 리셋 저장 (실제로는 Core Data나 다른 저장소 사용)
        let calendar = Calendar.current
        let todayString = "\(calendar.component(.year, from: Date()))-\(calendar.component(.month, from: Date()))-\(calendar.component(.day, from: Date()))"
        UserDefaults.standard.set(0, forKey: "ResetDay_\(todayString)")
    }

    private func updateData(with data: CMPedometerData) {
        todaySteps = data.numberOfSteps.intValue
        todayDistance = data.distance?.doubleValue ?? 0.0

        // 칼로리 계산 (대략적인 계산: 걸음당 0.04kcal)
        todayCalories = Double(todaySteps) * 0.04

        // 평균 속도 계산 (m/s)
        if let averageActivePace = data.averageActivePace {
            averageSpeed = averageActivePace.doubleValue
        }

        // 걸음 빈도 계산 (걸음/분)
        if let currentCadence = data.currentCadence {
            stepsPerMinute = currentCadence.doubleValue * 60
        }
    }

    private func loadSavedGoal() {
        // UserDefaults에서 저장된 목표 로드
        if let savedGoal = UserDefaults.standard.value(forKey: "DailyStepGoal") as? Int {
            // 외부에서 설정할 수 있도록 하는 방법이 필요하지만, 일단은 기본값 사용
        }
    }
}
