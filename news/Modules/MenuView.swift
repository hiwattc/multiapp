import SwiftUI
import GoogleSignIn
import UIKit
import LocalAuthentication
import Combine

// MARK: - Menu View
struct MenuView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()
    @State private var showMyMenu = false
    @State private var refreshTrigger = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                // Login Status
                VStack(spacing: 20) {
                    if authViewModel.isSignedIn || authViewModel.isBiometricAuthenticated {
                        // 인증 성공 - 로그아웃 버튼 표시
                        VStack(spacing: 16) {
                            Image(systemName: authViewModel.isSignedIn ? "person.circle.fill" : "faceid")
                                .font(.system(size: 60))
                                .foregroundColor(authViewModel.isSignedIn ? .blue : .purple)

                            VStack(spacing: 8) {
                                Text(authViewModel.isSignedIn ? "로그인됨" : "생체인증됨")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(authViewModel.isSignedIn ?
                                     (authViewModel.user?.profile?.email ?? "사용자") :
                                     "생체인증으로 보호됨")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }


                            // 로그아웃 버튼
                            Button(action: {
                                // 로그아웃 처리
                                if authViewModel.isSignedIn {
                                    authViewModel.signOut()
                                } else if authViewModel.isBiometricAuthenticated {
                                    // 생체인증 로그아웃 처리
                                    UserDefaults.standard.set(false, forKey: "IsBiometricAuthenticated")
                                    UserDefaults.standard.removeObject(forKey: "LastBiometricAuth")
                                    // UI 업데이트를 위해 강제로 상태 변경 트리거
                                    NotificationCenter.default.post(name: NSNotification.Name("BiometricAuthStatusChanged"), object: nil)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right.square")
                                        .font(.title2)
                                    Text("로그아웃")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                            // 나의 메뉴 버튼
                            Button(action: {
                                showMyMenu = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.title2)
                                    Text("나의 메뉴")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.top, 24)

                        }
                    } else {
                        // 로그인되지 않은 상태
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("계정으로 로그인")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            VStack(spacing: 12) {
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
                                    .frame(maxWidth: .infinity)
                                }
                                
                                Button(action: {
                                    authViewModel.signInWithApple()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "apple.logo")
                                            .font(.title2)
                                        
                                        Text("Apple로 로그인")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(Color.black)
                                    .cornerRadius(12)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                Button(action: {
                                    Task {
                                        await authViewModel.authenticateWithBiometrics()
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "faceid")
                                            .font(.title2)
                                        
                                        Text("생체인증")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                    .frame(maxWidth: .infinity)
                }
            }
                        }
                    }

                    // Error Message (항상 표시)
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
            .padding(.horizontal, 32)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .onChange(of: authViewModel.isSignedIn || authViewModel.isBiometricAuthenticated) { oldValue, newValue in
            if !newValue {
                // 로그아웃 시 showMyMenu를 false로 설정
                showMyMenu = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BiometricAuthStatusChanged"))) { _ in
            // 생체인증 상태 변경 감지하여 UI 업데이트
            refreshTrigger.toggle()
                }
        .sheet(isPresented: $showMyMenu) {
            MyMenuView()
        }
    }

    private func getBiometricTypeText() -> String {
        // 저장된 생체인증 타입 정보 사용
        if let savedType = UserDefaults.standard.string(forKey: "BiometricType") {
            return "\(savedType) 인증됨"
        }

        // 저장된 정보가 없으면 현재 기기에서 확인
        let context = LAContext()
        let biometricType = context.biometryType

        switch biometricType {
        case .faceID:
            return "Face ID 인증됨"
        case .touchID:
            return "Touch ID 인증됨"
        case .opticID:
            return "광학 생체인증됨"
        default:
            return "생체인증됨"
        }
    }

    private func getDeviceOwnerName() -> String {
        let deviceName = UIDevice.current.name

        // 기기 이름에서 소유자를 추정하기 위한 간단한 로직
        if deviceName.contains("iPhone") || deviceName.contains("iPad") {
            // 기본 iOS 기기 이름인 경우
            if deviceName == "iPhone" || deviceName == "iPad" {
                return "기기 소유자"
            } else {
                // 사용자가 설정한 이름이 있는 경우
                return deviceName
            }
        } else {
            // 커스텀 이름인 경우 그대로 사용
            return deviceName
        }
    }
}
