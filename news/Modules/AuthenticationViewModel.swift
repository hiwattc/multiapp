import SwiftUI
import Combine
import GoogleSignIn
import GoogleSignInSwift

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var user: GIDGoogleUser?
    @Published var errorMessage: String?

    private let appGroupID = "group.com.news.habit"

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    init() {
        print("🚀 AuthenticationViewModel 초기화")

        // 앱 시작 시 저장된 로그인 상태 복원
        loadSignInState()

        // Google Sign-In 설정
        configureGoogleSignIn()

        print("✅ AuthenticationViewModel 초기화 완료")
    }

    private func configureGoogleSignIn() {
        print("🔧 Google Sign-In 설정 시작")

        // Google Sign-In 클라이언트 ID 설정
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            print("✅ Google Client ID 설정: \(clientID)")
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            print("❌ Google Client ID를 Info.plist에서 찾을 수 없습니다")
        }
    }

    func signIn() async {
        print("🔐 Google 로그인 시작")

        // 1. 기본적인 앱 상태 확인
        print("📱 앱 상태 확인 중...")
        guard UIApplication.shared.connectedScenes.count > 0 else {
            print("❌ 연결된 scene이 없음")
            errorMessage = "앱 상태가 올바르지 않습니다"
            return
        }

        // 2. Google Sign-In SDK 사용 가능 여부 확인
        print("🔍 GoogleSignIn SDK 확인 중...")
        #if canImport(GoogleSignIn)
            print("✅ GoogleSignIn SDK가 import됨")
        #else
            print("❌ GoogleSignIn SDK가 import되지 않음 - 모의 로그인 사용")
            await performMockSignIn()
            return
        #endif

        do {
            errorMessage = nil

            // 3. Google Sign-In 초기화 확인
            guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
                print("❌ Google Client ID를 찾을 수 없습니다")
                errorMessage = "Google 설정이 올바르지 않습니다"
                return
            }
            print("✅ Google Client ID: \(clientID.prefix(10))...")

            // 4. UIViewController 가져오기
            guard let presentingViewController = await getPresentingViewController() else {
                print("❌ UIViewController를 가져올 수 없습니다")
                errorMessage = "화면을 표시할 수 없습니다"
                return
            }

            print("🚀 Google Sign-In 시도")

            // 5. 실제 Google Sign-In 호출 (가장 위험한 부분)
            print("⚠️  GIDSignIn.sharedInstance 접근 시도")
            let gidSignIn = GIDSignIn.sharedInstance
            print("✅ GIDSignIn.sharedInstance 접근 성공")

            print("⚠️  signIn(withPresenting:) 호출 시도")
            let result = try await gidSignIn.signIn(withPresenting: presentingViewController)

            // 로그인 성공
            print("✅ Google 로그인 성공!")
            print("👤 사용자: \(result.user.profile?.name ?? "Unknown")")
            print("📧 이메일: \(result.user.profile?.email ?? "Unknown")")

            user = result.user
            isSignedIn = true

            // 로그인 상태 저장
            saveSignInState()

            // 진동 효과
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        } catch let error as NSError {
            print("❌ Google 로그인 실패: \(error.localizedDescription)")
            print("🔍 오류 도메인: \(error.domain)")
            print("🔍 오류 코드: \(error.code)")
            print("🔍 오류 타입: \(type(of: error))")

            // 추가 디버깅 정보
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("🔍 기본 오류: \(underlyingError.localizedDescription)")
            }

            errorMessage = "로그인 실패: \(error.localizedDescription)"
            isSignedIn = false

            // 진동 효과
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        } catch {
            print("❌ 예상치 못한 오류: \(error.localizedDescription)")
            errorMessage = "예상치 못한 오류가 발생했습니다"
            isSignedIn = false
        }
    }

    private func performMockSignIn() async {
        print("🎭 모의 Google 로그인 시작")

        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기

            // 모의 사용자 데이터 생성 (실제 GoogleSignIn이 없을 때 사용)
            print("✅ 모의 로그인 성공!")
            print("👤 모의 사용자: 테스트 사용자")
            print("📧 모의 이메일: test@example.com")

            // 모의 사용자 객체 생성 (실제 GIDGoogleUser 대신)
            user = nil // 실제로는 모의 데이터를 넣을 수 없으므로 nil로 설정
            isSignedIn = true

            errorMessage = nil

            // 로그인 상태 저장
            saveSignInState()

            print("🎭 모의 로그인 완료 - UI 테스트 가능")

        } catch {
            print("❌ 모의 로그인 실패")
            errorMessage = "모의 로그인 실패"
            isSignedIn = false
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        user = nil
        isSignedIn = false
        errorMessage = nil

        // 로그인 상태 제거
        clearSignInState()

        // 진동 효과
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func getPresentingViewController() async -> UIViewController? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // SwiftUI 앱에서 UIViewController 가져오기
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = scene.windows.first(where: { $0.isKeyWindow }),
                      let rootViewController = window.rootViewController else {
                    print("❌ UIViewController를 찾을 수 없습니다")
                    continuation.resume(returning: nil)
                    return
                }

                // 가장 상위의 presented view controller 찾기
                var presentingViewController = rootViewController
                while let presentedViewController = presentingViewController.presentedViewController {
                    presentingViewController = presentedViewController
                }

                print("✅ UIViewController 찾음: \(type(of: presentingViewController))")
                continuation.resume(returning: presentingViewController)
            }
        }
    }

    private func saveSignInState() {
        if let user = user {
            let userData = [
                "userID": user.userID ?? "",
                "email": user.profile?.email ?? "",
                "name": user.profile?.name ?? "",
                "givenName": user.profile?.givenName ?? "",
                "familyName": user.profile?.familyName ?? ""
            ] as [String: Any]

            userDefaults.set(userData, forKey: "GoogleUserData")
            userDefaults.set(true, forKey: "IsSignedIn")
        }
    }

    private func loadSignInState() {
        if userDefaults.bool(forKey: "IsSignedIn"),
           let userData = userDefaults.dictionary(forKey: "GoogleUserData") {
            // 저장된 사용자 데이터로 GIDGoogleUser 객체 재생성 (실제로는 제한적)
            isSignedIn = true
            // 실제 앱에서는 토큰 유효성 검증 필요
        }
    }

    private func clearSignInState() {
        userDefaults.removeObject(forKey: "GoogleUserData")
        userDefaults.removeObject(forKey: "IsSignedIn")
    }
}
