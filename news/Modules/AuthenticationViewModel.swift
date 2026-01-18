import SwiftUI
import Combine
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import LocalAuthentication

@MainActor
class AuthenticationViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isSignedIn = false
    @Published var user: GIDGoogleUser?
    @Published var errorMessage: String?

    private let appGroupID = "group.com.news.habit"

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    override init() {
        super.init()

        print("🚀 AuthenticationViewModel 초기화")

        // 앱 시작 시 저장된 로그인 상태 복원
        loadSignInState()

        // Google Sign-In 설정
        configureGoogleSignIn()

        print("✅ AuthenticationViewModel 초기화 완료")
    }

    // Apple 로그인 상태 확인
    private func loadAppleSignInState() -> Bool {
        return UserDefaults.standard.bool(forKey: "IsAppleSignedIn")
    }

    private func configureGoogleSignIn() {
        print("🔧 Google Sign-In 설정 시작")

        // Google Sign-In 클라이언트 ID 설정
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            print("✅ Google Client ID 설정: \(clientID)")

            // 이메일과 프로필 정보 접근을 위한 configuration 설정
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            print("✅ Google Sign-In configuration 설정 완료")
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
            print("🔍 user ID: \(result.user.userID ?? "Unknown")")
            print("🔍 profile이 nil인가?: \(result.user.profile == nil)")

            // 사용자 정보 저장
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

    func signInWithApple() {
        print("🍎 Apple 로그인 시작")

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self

        print("🍎 Apple 인증 컨트롤러 표시 시도")
        authorizationController.performRequests()
    }

    // MARK: - ASAuthorizationController Delegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("✅ Apple 로그인 성공!")

        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            // Apple ID 로그인 성공
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email

            print("👤 Apple ID: \(userIdentifier)")
            print("📧 이메일: \(email ?? "Not provided")")
            print("👤 이름: \(fullName?.givenName ?? "") \(fullName?.familyName ?? "")")

            // 사용자 정보 저장 (실제 앱에서는 더 안전하게 저장)
            UserDefaults.standard.set(userIdentifier, forKey: "AppleUserID")
            UserDefaults.standard.set(email, forKey: "AppleUserEmail")
            UserDefaults.standard.set(fullName?.givenName, forKey: "AppleUserGivenName")
            UserDefaults.standard.set(fullName?.familyName, forKey: "AppleUserFamilyName")
            UserDefaults.standard.set(true, forKey: "IsAppleSignedIn")

            // 로그인 상태 업데이트
            isSignedIn = true
            errorMessage = nil

            // 진동 효과
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        case let passwordCredential as ASPasswordCredential:
            // 저장된 비밀번호 로그인 (iOS 12+)
            print("🔑 저장된 비밀번호로 로그인: \(passwordCredential.user)")
            isSignedIn = true
            errorMessage = nil

        default:
            print("❌ 알 수 없는 인증 타입")
            errorMessage = "알 수 없는 인증 방식입니다"
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple 로그인 실패: \(error.localizedDescription)")

        let errorCode = (error as NSError).code
        switch errorCode {
        case ASAuthorizationError.canceled.rawValue:
            print("🚫 사용자 취소")
            errorMessage = "로그인이 취소되었습니다"
        case ASAuthorizationError.failed.rawValue:
            print("❌ 인증 실패")
            errorMessage = "인증에 실패했습니다"
        case ASAuthorizationError.invalidResponse.rawValue:
            print("❌ 잘못된 응답")
            errorMessage = "잘못된 응답을 받았습니다"
        case ASAuthorizationError.notHandled.rawValue:
            print("❌ 처리되지 않은 요청")
            errorMessage = "요청을 처리할 수 없습니다"
        case ASAuthorizationError.unknown.rawValue:
            print("❓ 알 수 없는 오류")
            errorMessage = "알 수 없는 오류가 발생했습니다"
        default:
            errorMessage = "로그인 실패: \(error.localizedDescription)"
        }

        isSignedIn = false

        // 진동 효과
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - ASAuthorizationController Presentation Context
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }

    func authenticateWithBiometrics() async {
        print("👆 생체인증 시작")

        let context = LAContext()
        var error: NSError?

        // 생체인증 지원 여부 확인
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ 생체인증 지원되지 않음: \(error?.localizedDescription ?? "알 수 없는 오류")")
            await MainActor.run {
                errorMessage = "이 기기는 생체인증을 지원하지 않습니다"
            }
            return
        }

        // 생체인증 타입 확인 및 저장
        let biometricType = context.biometryType
        let reason: String

        switch biometricType {
        case .faceID:
            reason = "Face ID로 인증해주세요"
            print("👤 Face ID 사용")
            UserDefaults.standard.set("Face ID", forKey: "BiometricType")
        case .touchID:
            reason = "Touch ID로 인증해주세요"
            print("👆 Touch ID 사용")
            UserDefaults.standard.set("Touch ID", forKey: "BiometricType")
        case .opticID:
            reason = "광학 생체인증으로 인증해주세요"
            print("👁️ 광학 생체인증 사용")
            UserDefaults.standard.set("광학 생체인증", forKey: "BiometricType")
        default:
            reason = "생체인증으로 인증해주세요"
            print("🔐 일반 생체인증 사용")
            UserDefaults.standard.set("생체인증", forKey: "BiometricType")
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)

            await MainActor.run {
                if success {
                    print("✅ 생체인증 성공!")
                    errorMessage = nil

                    // 생체인증 성공 상태를 UserDefaults에 저장
                    UserDefaults.standard.set(true, forKey: "IsBiometricAuthenticated")
                    UserDefaults.standard.set(Date(), forKey: "LastBiometricAuth")

                    // 진동 효과
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                } else {
                    print("❌ 생체인증 실패")
                    errorMessage = "생체인증에 실패했습니다"

                    // 진동 효과
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }

        } catch let error as LAError {
            await MainActor.run {
                print("❌ 생체인증 오류: \(error.localizedDescription)")

                switch error.code {
                case .authenticationFailed:
                    errorMessage = "생체인증에 실패했습니다"
                case .userCancel:
                    errorMessage = "사용자가 취소했습니다"
                case .userFallback:
                    errorMessage = "비밀번호 입력으로 전환되었습니다"
                case .systemCancel:
                    errorMessage = "시스템에 의해 취소되었습니다"
                case .passcodeNotSet:
                    errorMessage = "기기 비밀번호가 설정되지 않았습니다"
                case .biometryNotAvailable:
                    errorMessage = "생체인증을 사용할 수 없습니다"
                case .biometryNotEnrolled:
                    errorMessage = "생체인증이 등록되지 않았습니다"
                case .biometryLockout:
                    errorMessage = "생체인증이 잠겼습니다. 잠시 후 다시 시도해주세요"
                case .appCancel:
                    errorMessage = "앱에 의해 취소되었습니다"
                case .invalidContext:
                    errorMessage = "잘못된 컨텍스트입니다"
                default:
                    errorMessage = "알 수 없는 오류가 발생했습니다"
                }

                // 진동 효과
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        } catch {
            await MainActor.run {
                print("❌ 예상치 못한 오류: \(error.localizedDescription)")
                errorMessage = "예상치 못한 오류가 발생했습니다"
            }
        }
    }

    // 생체인증 상태 확인
    var isBiometricAuthenticated: Bool {
        UserDefaults.standard.bool(forKey: "IsBiometricAuthenticated")
    }

    // 마지막 생체인증 시간
    var lastBiometricAuthTime: Date? {
        UserDefaults.standard.object(forKey: "LastBiometricAuth") as? Date
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
        clearAppleSignInState()
        clearBiometricState()

        // 진동 효과
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func clearAppleSignInState() {
        UserDefaults.standard.removeObject(forKey: "AppleUserID")
        UserDefaults.standard.removeObject(forKey: "AppleUserEmail")
        UserDefaults.standard.removeObject(forKey: "AppleUserGivenName")
        UserDefaults.standard.removeObject(forKey: "AppleUserFamilyName")
        UserDefaults.standard.removeObject(forKey: "IsAppleSignedIn")
    }

    private func clearBiometricState() {
        UserDefaults.standard.removeObject(forKey: "IsBiometricAuthenticated")
        UserDefaults.standard.removeObject(forKey: "LastBiometricAuth")
        UserDefaults.standard.removeObject(forKey: "BiometricType")
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
        // Google 로그인 상태 확인
        if userDefaults.bool(forKey: "IsSignedIn"),
           let userData = userDefaults.dictionary(forKey: "GoogleUserData") {
            // 저장된 사용자 데이터로 GIDGoogleUser 객체 재생성 (실제로는 제한적)
            isSignedIn = true
            // 실제 앱에서는 토큰 유효성 검증 필요
        }
        // Apple 로그인 상태 확인
        else if UserDefaults.standard.bool(forKey: "IsAppleSignedIn") {
            isSignedIn = true
        }
    }

    private func clearSignInState() {
        userDefaults.removeObject(forKey: "GoogleUserData")
        userDefaults.removeObject(forKey: "IsSignedIn")
    }
}
