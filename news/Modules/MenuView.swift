import SwiftUI
import GoogleSignIn

// MARK: - Menu View
struct MenuView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 16) {
                    Text("Google 로그인 테스트")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("로그인 기능만 테스트합니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Login Status
                VStack(spacing: 20) {
                    if authViewModel.isSignedIn {
                        // 로그인된 상태
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            VStack(spacing: 8) {
                                Text("로그인 성공!")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(authViewModel.user?.profile?.name ?? "테스트 사용자")
                                    .font(.headline)

                                Text(authViewModel.user?.profile?.email ?? "test@example.com")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Button(action: {
                                authViewModel.signOut()
                            }) {
                                Text("로그아웃")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                        }
                    } else {
                        // 로그인되지 않은 상태
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("Google 계정으로 로그인")
                                .font(.title2)
                                .fontWeight(.bold)

                            Button(action: {
                                Task {
                                    await authViewModel.signIn()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.title2)

                                    Text("Google로 로그인")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Error Message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 60)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
}
