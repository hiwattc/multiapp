import SwiftUI
import ARKit
import RealityKit

// MARK: - Direct 3D Viewer (저장 없이 직접 표시)
struct Direct3DViewer: View {
    @Environment(\.dismiss) private var dismiss
    let entities: [Entity]
    @State private var arView: ARView?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 3D 뷰
                if let arView = arView {
                    DirectARViewContainer(arView: arView)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    ProgressView("로딩 중...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
                
                // 컨트롤 오버레이
                VStack {
                    Spacer()
                    
                    Button(action: {
                        resetView()
                    }) {
                        VStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                            Text("리셋")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("3D 뷰어")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadEntities()
            }
        }
    }
    
    private func loadEntities() {
        // ARView 생성
        let view = ARView(frame: .zero)
        
        // AR 세션 설정
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        view.session.run(configuration)
        
        // 앵커 엔티티 생성 (카메라 앞에 배치)
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1.5))
        
        // 모든 엔티티 추가
        for entity in entities {
            anchor.addChild(entity)
            
            // ModelEntity인 경우 제스처 추가
            if let modelEntity = entity as? ModelEntity {
                view.installGestures([.rotation, .scale], for: modelEntity)
            } else {
                // 자식 중 ModelEntity 찾아서 제스처 추가
                addGesturesToChildren(in: entity, arView: view)
            }
        }
        
        view.scene.addAnchor(anchor)
        self.arView = view
        
        print("✅ 직접 3D 뷰어 로드 완료: \(entities.count)개 엔티티")
    }
    
    private func addGesturesToChildren(in entity: Entity, arView: ARView) {
        for child in entity.children {
            if let modelEntity = child as? ModelEntity {
                arView.installGestures([.rotation, .scale], for: modelEntity)
            } else {
                addGesturesToChildren(in: child, arView: arView)
            }
        }
    }
    
    private func resetView() {
        guard let arView = arView else { return }
        
        // 모든 앵커 제거
        for anchor in arView.scene.anchors {
            arView.scene.removeAnchor(anchor)
        }
        
        // 다시 로드
        loadEntities()
    }
}

// MARK: - Direct ARView Container
struct DirectARViewContainer: UIViewRepresentable {
    let arView: ARView
    
    func makeUIView(context: Context) -> ARView {
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 업데이트 불필요
    }
}

