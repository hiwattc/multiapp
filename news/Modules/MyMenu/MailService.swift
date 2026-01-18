import SwiftUI
import MessageUI
import Combine
import GoogleSignIn

// MARK: - Mail Service
class MailService: ObservableObject {
    @Published var showingMailComposer = false
    @Published var showingNoEmailAlert = false

    private var authViewModel: AuthenticationViewModel?
    private var habitViewModel: HabitViewModel?

    init() {
        // 기본 생성자 - 초기화는 나중에 수행
    }

    func initialize(with authViewModel: AuthenticationViewModel, habitViewModel: HabitViewModel) {
        self.authViewModel = authViewModel
        self.habitViewModel = habitViewModel
    }

    func sendHabitReportEmail() {
        print("📧 습관 보고서 메일 전송")

        guard let authViewModel = authViewModel, let habitViewModel = habitViewModel else {
            print("❌ MailService가 초기화되지 않았습니다")
            return
        }

        // 사용자 이메일 주소 확인
        let userEmail = getUserEmail()

        guard let email = userEmail, !email.isEmpty else {
            print("❌ 이메일 주소를 찾을 수 없습니다")
            print("   - authViewModel.user: \(authViewModel.user != nil ? "있음" : "없음")")
            if let user = authViewModel.user {
                print("   - user.profile: \(user.profile != nil ? "있음" : "없음")")
                if let profile = user.profile {
                    print("   - profile.email: \(profile.email ?? "nil")")
                }
            }
            print("   - Apple 로그인 상태: \(UserDefaults.standard.bool(forKey: "IsAppleSignedIn"))")
            showingNoEmailAlert = true
            return
        }

        print("✅ 이메일 주소 확인: \(email)")
        showingMailComposer = true
    }

    private func getUserEmail() -> String? {
        print("🔍 이메일 주소 검색 시작...")

        // 1. Google Sign-In shared instance에서 직접 확인 (우선순위 최고)
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            print("🔍 GIDSignIn.sharedInstance.currentUser 발견")
            print("🔍 currentUser.userID: \(currentUser.userID ?? "nil")")
            print("🔍 currentUser.profile nil?: \(currentUser.profile == nil)")

            if let profile = currentUser.profile {
                print("🔍 profile.name: \(profile.name ?? "nil")")
                print("🔍 profile.email: \(profile.email)")

                // 이메일이 비어있지 않은지 확인
                if !profile.email.isEmpty {
                    print("✅ GIDSignIn에서 이메일 발견: \(profile.email)")
                    return profile.email
                } else {
                    print("⚠️ GIDSignIn에서 빈 이메일 발견")
                }
            }
        } else {
            print("🔍 GIDSignIn.sharedInstance.currentUser가 nil입니다")
        }

        // 2. ViewModel의 user 확인 (fallback)
        if let authViewModel = authViewModel {
            if let googleUser = authViewModel.user {
                print("🔍 ViewModel의 Google user 발견")
                if let profile = googleUser.profile, !profile.email.isEmpty {
                    print("✅ ViewModel에서 이메일 발견: \(profile.email)")
                    return profile.email
                } else {
                    print("🔍 ViewModel user의 profile이 nil이거나 email이 비어있습니다")
                }
            } else {
                print("🔍 ViewModel의 Google user가 nil입니다")
            }
        } else {
            print("🔍 authViewModel이 nil입니다")
        }

        // 3. Apple 로그인 이메일 확인
        if UserDefaults.standard.bool(forKey: "IsAppleSignedIn") {
            let appleEmail = UserDefaults.standard.string(forKey: "AppleUserEmail")
            print("🔍 Apple 로그인 상태 확인됨")
            print("🔍 Apple 이메일: \(appleEmail ?? "nil")")
            if let email = appleEmail, !email.isEmpty {
                print("✅ Apple에서 이메일 발견: \(email)")
                return email
            }
        } else {
            print("🔍 Apple 로그인 상태가 아님")
        }

        print("❌ 모든 소스에서 이메일을 찾을 수 없습니다")
        return nil
    }

    private func generateHabitReportHTML() -> String {
        guard let habitViewModel = habitViewModel else {
            return "<html><body><h1>오류: 데이터 로드 실패</h1></body></html>"
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayString = String(format: "%04d-%02d-%02d",
                                calendar.component(.year, from: today),
                                calendar.component(.month, from: today),
                                calendar.component(.day, from: today))

        let userName = getUserName() ?? "사용자"

        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
                h1 { color: #007AFF; text-align: center; }
                h2 { color: #5AC8FA; margin-top: 30px; }
                table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
                th { background-color: #f8f9fa; font-weight: bold; }
                .completed { color: #28a745; font-weight: bold; }
                .not-completed { color: #dc3545; font-weight: bold; }
                .summary { background-color: #e9ecef; padding: 15px; border-radius: 8px; margin: 20px 0; }
            </style>
        </head>
        <body>
            <h1>📊 습관관리 보고서</h1>
            <p>안녕하세요, <strong>\(userName)</strong>님!</p>
            <p>오늘의 습관 체크 현황을 알려드립니다.</p>

            <div class="summary">
                <h3>📅 오늘 날짜: \(today.formatted(date: .long, time: .omitted))</h3>
                <p>총 습관 수: <strong>\(habitViewModel.habits.count)개</strong></p>
        """

        let completedCount = habitViewModel.habits.filter { $0.completions[todayString] == true }.count
        let notCompletedCount = habitViewModel.habits.count - completedCount

        html += """
            <p>✅ 완료된 습관: <strong>\(completedCount)개</strong></p>
            <p>❌ 미완료 습관: <strong>\(notCompletedCount)개</strong></p>
        """

        if habitViewModel.habits.count > 0 {
            let percentage = Int((Double(completedCount) / Double(habitViewModel.habits.count)) * 100)
            html += "<p>📈 달성률: <strong>\(percentage)%</strong></p>"
        }

        html += """
            </div>

            <h2>📋 상세 현황</h2>
            <table>
                <thead>
                    <tr>
                        <th>습관명</th>
                        <th>오늘 상태</th>
                        <th>알림 설정</th>
                    </tr>
                </thead>
                <tbody>
        """

        for habit in habitViewModel.habits {
            let isCompleted = habit.completions[todayString] == true
            let statusText = isCompleted ? "✅ 완료" : "❌ 미완료"
            let statusClass = isCompleted ? "completed" : "not-completed"
            
            // 여러 알림 시간 처리
            let reminderText: String
            if habit.reminderTimes.isEmpty {
                reminderText = "설정 안됨"
            } else if habit.reminderTimes.count == 1 {
                reminderText = habit.reminderTimes[0].formatted(date: .omitted, time: .shortened)
            } else {
                let times = habit.reminderTimes.map { $0.formatted(date: .omitted, time: .shortened) }.joined(separator: ", ")
                reminderText = "\(times) (\(habit.reminderTimes.count)개)"
            }

            html += """
                    <tr>
                        <td><strong>\(habit.title)</strong></td>
                        <td class="\(statusClass)">\(statusText)</td>
                        <td>\(reminderText)</td>
                    </tr>
            """
        }

        html += """
                </tbody>
            </table>

            <p>습관관리 앱에서 더 많은 기능을 확인해보세요!</p>
            <p style="color: #666; font-size: 12px;">이 보고서는 \(Date().formatted(date: .long, time: .standard))에 생성되었습니다.</p>
        </body>
        </html>
        """

        return html
    }

    private func getUserName() -> String? {
        guard let authViewModel = authViewModel else { return nil }

        // Google 로그인 이름 확인
        if let googleUser = authViewModel.user {
            return googleUser.profile?.name
        }

        // Apple 로그인 이름 확인
        if UserDefaults.standard.bool(forKey: "IsAppleSignedIn") {
            let givenName = UserDefaults.standard.string(forKey: "AppleUserGivenName") ?? ""
            let familyName = UserDefaults.standard.string(forKey: "AppleUserFamilyName") ?? ""
            let fullName = (givenName + " " + familyName).trimmingCharacters(in: .whitespaces)
            return fullName.isEmpty ? nil : fullName
        }

        return nil
    }

    func createMailComposerView() -> AnyView {
        guard let habitViewModel = habitViewModel else {
            return AnyView(
                Text("데이터 로드 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }

        return AnyView(
            MailComposerView(
                recipient: getUserEmail() ?? "",
                subject: "습관관리 보고서 - \(Date().formatted(date: .long, time: .omitted))",
                htmlBody: generateHabitReportHTML()
            )
        )
    }
}

// MARK: - Mail Composer View
struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let htmlBody: String

    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients([recipient])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(htmlBody, isHTML: true)

        return mailComposer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            switch result {
            case .cancelled:
                print("📧 메일 전송 취소됨")
            case .saved:
                print("📧 메일 임시 저장됨")
            case .sent:
                print("📧 메일 전송 성공!")
            case .failed:
                print("📧 메일 전송 실패: \(error?.localizedDescription ?? "알 수 없는 오류")")
            @unknown default:
                break
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
