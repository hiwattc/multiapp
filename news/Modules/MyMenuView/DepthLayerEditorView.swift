import SwiftUI
import ARKit
import RealityKit
import UIKit
import Combine

// MARK: - Depth Layer Editor View
struct DepthLayerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DepthLayerEditorViewModel()
    
    var body: some View {
        ZStack {
            // AR Depth Camera View
            if viewModel.capturedImage == nil {
                ARDepthCameraContainer(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
            } else {
                // Layer Editor View
                DepthLayerEditorContainer(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
            }
            
            // UI Overlay
            VStack {
                // Top Bar
                HStack {
                    Button(action: {
                        if viewModel.capturedImage != nil {
                            viewModel.clearCapture()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: viewModel.capturedImage != nil ? "arrow.left.circle.fill" : "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if viewModel.capturedImage == nil {
                            Text("LiDAR 깊이 카메라")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: viewModel.isDepthAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(viewModel.isDepthAvailable ? .green : .yellow)
                                Text(viewModel.isDepthAvailable ? "LiDAR 사용 가능" : "LiDAR 미지원")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("레이어 편집")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("레이어: \(viewModel.totalLayers)개")
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                // Camera Control
                if viewModel.capturedImage == nil {
                    VStack(spacing: 20) {
                        Text("📸 LiDAR 센서로 깊이 정보를 포함한 사진을 촬영합니다")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        
                        Button(action: {
                            viewModel.captureDepthPhoto()
                        }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.blue.opacity(0.3)))
                        }
                        .padding(.bottom, 50)
                    }
                } else {
                    // Layer Editor Controls
                    VStack(spacing: 16) {
                        // Layer Slider
                        VStack(spacing: 8) {
                            Text("레이어 선택: \(viewModel.selectedLayer + 1)/\(viewModel.totalLayers)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("가까움")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Slider(value: Binding(
                                    get: { Double(viewModel.selectedLayer) },
                                    set: { viewModel.selectedLayer = Int($0) }
                                ), in: 0...Double(viewModel.totalLayers - 1), step: 1)
                                .accentColor(.cyan)
                                
                                Text("멀리")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        
                        // Edit Controls
                        HStack(spacing: 15) {
                            Button(action: {
                                viewModel.adjustBrightness(by: 0.1)
                            }) {
                                VStack {
                                    Image(systemName: "sun.max.fill")
                                        .font(.title2)
                                    Text("밝게")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange.opacity(0.7))
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                viewModel.adjustBrightness(by: -0.1)
                            }) {
                                VStack {
                                    Image(systemName: "sun.min.fill")
                                        .font(.title2)
                                    Text("어둡게")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.gray.opacity(0.7))
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                viewModel.toggleLayerVisibility()
                            }) {
                                VStack {
                                    Image(systemName: viewModel.isLayerVisible ? "eye.fill" : "eye.slash.fill")
                                        .font(.title2)
                                    Text(viewModel.isLayerVisible ? "표시" : "숨김")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green.opacity(0.7))
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                viewModel.applyBlur()
                            }) {
                                VStack {
                                    Image(systemName: "aqi.medium")
                                        .font(.title2)
                                    Text("흐림")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - AR Depth Camera Container
struct ARDepthCameraContainer: UIViewRepresentable {
    @ObservedObject var viewModel: DepthLayerEditorViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 구성 (LiDAR depth)
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            print("✅ Scene Depth 활성화됨")
        } else {
            print("⚠️ Scene Depth를 지원하지 않습니다")
        }
        
        arView.session.run(configuration)
        
        // 세션 델리게이트 설정
        arView.session.delegate = context.coordinator
        
        // ViewModel에 ARView 설정
        viewModel.setARView(arView)
        
        // 코디네이터 설정
        context.coordinator.arView = arView
        context.coordinator.viewModel = viewModel
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 업데이트 필요시 구현
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        weak var viewModel: DepthLayerEditorViewModel?
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // 깊이 데이터 캡처
            guard let viewModel = viewModel else { return }
            viewModel.processFrame(frame)
        }
    }
}

// MARK: - Depth Layer Editor Container
struct DepthLayerEditorContainer: View {
    @ObservedObject var viewModel: DepthLayerEditorViewModel
    
    var body: some View {
        GeometryReader { geometry in
            if let compositeImage = viewModel.getCompositeImage() {
                Image(uiImage: compositeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                Color.black
            }
        }
    }
}

// MARK: - Depth Layer Editor View Model
class DepthLayerEditorViewModel: ObservableObject {
    @Published var isDepthAvailable: Bool = false
    @Published var capturedImage: UIImage?
    @Published var depthMap: CVPixelBuffer?
    @Published var selectedLayer: Int = 0
    @Published var totalLayers: Int = 5
    @Published var isLayerVisible: Bool = true
    
    weak var arView: ARView?
    private var layers: [DepthLayer] = []
    private var layerAdjustments: [Int: LayerAdjustment] = [:]
    
    func setARView(_ view: ARView) {
        self.arView = view
        checkDepthSupport()
    }
    
    func checkDepthSupport() {
        isDepthAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }
    
    func processFrame(_ frame: ARFrame) {
        // 깊이 데이터가 있는지 확인
        if frame.sceneDepth != nil {
            isDepthAvailable = true
        }
    }
    
    func captureDepthPhoto() {
        guard let arView = arView,
              let frame = arView.session.currentFrame else {
            print("❌ 현재 프레임을 가져올 수 없습니다")
            return
        }
        
        // 이미지 캡처
        let image = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: image)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            capturedImage = UIImage(cgImage: cgImage)
        }
        
        // 깊이 맵 캡처
        if let sceneDepth = frame.sceneDepth {
            depthMap = sceneDepth.depthMap
            
            // 레이어 생성
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.createDepthLayers()
            }
        }
        
        print("✅ 깊이 사진 캡처 완료")
    }
    
    func createDepthLayers() {
        guard let capturedImage = capturedImage,
              let depthMap = depthMap,
              let cgImage = capturedImage.cgImage else { return }
        
        // 깊이 데이터 분석
        let depthData = extractDepthData(from: depthMap)
        
        // 깊이 범위 계산
        let minDepth = depthData.min() ?? 0
        let maxDepth = depthData.max() ?? 10
        let depthRange = maxDepth - minDepth
        let layerStep = depthRange / Float(totalLayers)
        
        // 레이어 생성
        var newLayers: [DepthLayer] = []
        
        for i in 0..<totalLayers {
            let layerMinDepth = minDepth + Float(i) * layerStep
            let layerMaxDepth = minDepth + Float(i + 1) * layerStep
            
            // 이 깊이 범위에 해당하는 픽셀만 추출
            if let layerImage = createLayerImage(
                from: cgImage,
                depthData: depthData,
                minDepth: layerMinDepth,
                maxDepth: layerMaxDepth
            ) {
                let layer = DepthLayer(
                    id: i,
                    image: layerImage,
                    minDepth: layerMinDepth,
                    maxDepth: layerMaxDepth
                )
                newLayers.append(layer)
            }
        }
        
        DispatchQueue.main.async {
            self.layers = newLayers
            print("✅ \(newLayers.count)개 레이어 생성 완료")
        }
    }
    
    func extractDepthData(from depthMap: CVPixelBuffer) -> [Float] {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        var depthValues: [Float] = []
        
        for y in 0..<height {
            let rowData = baseAddress! + y * bytesPerRow
            let floatBuffer = rowData.assumingMemoryBound(to: Float32.self)
            
            for x in 0..<width {
                let depth = floatBuffer[x]
                if depth > 0 && depth < 100 { // 유효한 깊이 값
                    depthValues.append(depth)
                }
            }
        }
        
        return depthValues
    }
    
    func createLayerImage(from cgImage: CGImage, depthData: [Float], minDepth: Float, maxDepth: Float) -> UIImage? {
        guard let depthMap = depthMap else { return nil }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = cgImage.width
        let height = cgImage.height
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        // 이미지 데이터 생성
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelBuffer = context.data else { return nil }
        let pixels = pixelBuffer.assumingMemoryBound(to: UInt8.self)
        
        // 깊이 맵과 이미지 매칭하여 레이어 생성
        for y in 0..<height {
            for x in 0..<width {
                // 깊이 맵 좌표로 변환
                let depthX = Int(Float(x) * Float(depthWidth) / Float(width))
                let depthY = Int(Float(y) * Float(depthHeight) / Float(height))
                
                if depthX < depthWidth && depthY < depthHeight {
                    let rowData = baseAddress! + depthY * bytesPerRow
                    let floatBuffer = rowData.assumingMemoryBound(to: Float32.self)
                    let depth = floatBuffer[depthX]
                    
                    let pixelIndex = (y * width + x) * 4
                    
                    // 이 깊이가 현재 레이어 범위에 속하지 않으면 투명하게
                    if depth < minDepth || depth > maxDepth || depth <= 0 || depth > 100 {
                        pixels[pixelIndex + 3] = 0 // 알파 채널을 0으로 (투명)
                    }
                }
            }
        }
        
        if let newImage = context.makeImage() {
            return UIImage(cgImage: newImage)
        }
        
        return nil
    }
    
    func getCompositeImage() -> UIImage? {
        guard !layers.isEmpty,
              let capturedImage = capturedImage else { return capturedImage }
        
        let size = capturedImage.size
        
        // 모든 레이어를 합성
        UIGraphicsBeginImageContextWithOptions(size, false, capturedImage.scale)
        defer { UIGraphicsEndImageContext() }
        
        // 배경 (원본 이미지)
        capturedImage.draw(at: .zero)
        
        // 각 레이어를 위에 그리기
        for (index, layer) in layers.enumerated() {
            var layerImage = layer.image
            
            // 선택된 레이어에 편집 효과 적용
            if index == selectedLayer {
                if let adjustment = layerAdjustments[selectedLayer] {
                    layerImage = applyAdjustments(to: layerImage, adjustment: adjustment)
                }
                
                // 선택된 레이어가 숨김 상태면 그리지 않음
                if !isLayerVisible {
                    continue
                }
                
                // 선택된 레이어는 하이라이트 (약간 밝게)
                layerImage = highlightImage(layerImage)
            }
            
            layerImage.draw(at: .zero, blendMode: .normal, alpha: 1.0)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func highlightImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        // 선택된 레이어에 테두리 효과
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.2, forKey: kCIInputBrightnessKey)
        filter?.setValue(1.2, forKey: kCIInputSaturationKey)
        
        if let outputImage = filter?.outputImage {
            let context = CIContext()
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return image
    }
    
    func applyAdjustments(to image: UIImage, adjustment: LayerAdjustment) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        var outputImage = ciImage
        
        // 밝기 조정
        if adjustment.brightness != 0 {
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(outputImage, forKey: kCIInputImageKey)
            filter?.setValue(adjustment.brightness, forKey: kCIInputBrightnessKey)
            if let result = filter?.outputImage {
                outputImage = result
            }
        }
        
        // 흐림 효과
        if adjustment.blurRadius > 0 {
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(outputImage, forKey: kCIInputImageKey)
            filter?.setValue(adjustment.blurRadius, forKey: kCIInputRadiusKey)
            if let result = filter?.outputImage {
                outputImage = result
            }
        }
        
        let context = CIContext()
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return image
    }
    
    func adjustBrightness(by value: Float) {
        var adjustment = layerAdjustments[selectedLayer] ?? LayerAdjustment()
        adjustment.brightness += value
        adjustment.brightness = max(-1.0, min(1.0, adjustment.brightness))
        layerAdjustments[selectedLayer] = adjustment
        objectWillChange.send()
    }
    
    func applyBlur() {
        var adjustment = layerAdjustments[selectedLayer] ?? LayerAdjustment()
        adjustment.blurRadius = adjustment.blurRadius > 0 ? 0 : 10
        layerAdjustments[selectedLayer] = adjustment
        objectWillChange.send()
    }
    
    func toggleLayerVisibility() {
        isLayerVisible.toggle()
    }
    
    func clearCapture() {
        capturedImage = nil
        depthMap = nil
        layers.removeAll()
        layerAdjustments.removeAll()
        selectedLayer = 0
        isLayerVisible = true
    }
}

// MARK: - Depth Layer Model
struct DepthLayer: Identifiable {
    let id: Int
    let image: UIImage
    let minDepth: Float
    let maxDepth: Float
}

// MARK: - Layer Adjustment
struct LayerAdjustment {
    var brightness: Float = 0
    var blurRadius: Float = 0
}
