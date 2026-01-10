import SwiftUI
import Combine
import CoreLocation
import WebKit

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
        self.manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Map Type
enum MapType: String, CaseIterable {
    case openStreetMap = "OpenStreetMap"
    case esriSatellite = "ESRI 항공"
    
    var icon: String {
        switch self {
        case .openStreetMap: return "map"
        case .esriSatellite: return "globe.asia.australia.fill"
        }
    }
}

// MARK: - Map View
struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var selectedMapType: MapType = .esriSatellite
    @State private var mapHTML = ""
    @State private var isMeasuring = false
    @State private var mapKey = UUID()
    
    var body: some View {
        ZStack {
            // Map WebView
            MapWebView(html: mapHTML)
                .id(mapKey)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Bottom Controls
                HStack(alignment: .bottom) {
                    // Left Controls (Zoom, Measure & Map Type)
                    VStack(spacing: 12) {
                        // Zoom In Button
                        Button(action: {
                            executeMapScript("map.zoomIn();")
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        
                        // Zoom Out Button
                        Button(action: {
                            executeMapScript("map.zoomOut();")
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        
                        // Measure Distance Button
                        Button(action: {
                            isMeasuring.toggle()
                            if isMeasuring {
                                executeMapScript("startMeasuring();")
                            } else {
                                executeMapScript("stopMeasuring();")
                            }
                        }) {
                            Image(systemName: isMeasuring ? "ruler.fill" : "ruler")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(isMeasuring ? Color.orange : Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        
                        // Map Type Toggle Button
                        Button(action: {
                            selectedMapType = selectedMapType == .openStreetMap ? .esriSatellite : .openStreetMap
                            isMeasuring = false
                            updateMap()
                            mapKey = UUID()
                        }) {
                            Image(systemName: selectedMapType == .openStreetMap ? "map" : "globe.asia.australia.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.green)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Current Location Button
                    VStack(spacing: 12) {
                        Button(action: {
                            locationManager.requestLocation()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let location = locationManager.location {
                                    executeMapScript("map.setView([\(location.latitude), \(location.longitude)], 16);")
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                    }
                    .padding()
                }
                .padding(.bottom, 80) // Tab bar 공간 확보
            }
        }
        .onAppear {
            locationManager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                updateMap()
            }
        }
        .onChange(of: selectedMapType) { oldValue, newValue in
            isMeasuring = false
            updateMap()
            mapKey = UUID()
        }
        .onChange(of: locationManager.location) { oldValue, newLocation in
            if let location = newLocation {
                updateMap()
            }
        }
    }
    
    private func executeMapScript(_ script: String) {
        // 약간의 딜레이 후 실행 (지도 로딩 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("ExecuteMapScript"), object: script)
        }
    }
    
    private func updateMap() {
        let lat = locationManager.location?.latitude ?? 37.5665
        let lon = locationManager.location?.longitude ?? 126.9780
        
        let tileLayer = selectedMapType == .openStreetMap
            ? "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            : "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
        
        let attribution = selectedMapType == .openStreetMap
            ? "© OpenStreetMap contributors"
            : "© Esri"
        
        mapHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
            <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
            <style>
                body { margin: 0; padding: 0; }
                #map { width: 100vw; height: 100vh; }
                .distance-label {
                    background: white;
                    padding: 4px 8px;
                    border: 2px solid #333;
                    border-radius: 4px;
                    font-weight: bold;
                    font-size: 12px;
                    white-space: nowrap;
                }
            </style>
        </head>
        <body>
            <div id="map"></div>
            <script>
                var map = L.map('map', {
                    doubleClickZoom: false,
                    tap: true,
                    tapTolerance: 15
                }).setView([\(lat), \(lon)], 15);
                
                L.tileLayer('\(tileLayer)', {
                    attribution: '\(attribution)',
                    maxZoom: 19
                }).addTo(map);
                
                // 전역 변수로 저장 (나중에 교체하기 위해)
                window.tileLayer = L.tileLayer('\(tileLayer)', {
                    attribution: '\(attribution)',
                    maxZoom: 19
                }).addTo(map);
                
                var marker = L.marker([\(lat), \(lon)]).addTo(map);
                marker.bindPopup('<b>현재 위치</b>').openPopup();
                
                var circle = L.circle([\(lat), \(lon)], {
                    color: 'blue',
                    fillColor: '#30a3ec',
                    fillOpacity: 0.2,
                    radius: 100
                }).addTo(map);
                
                // 한 손가락 확대/축소 (더블탭 후 드래그)
                var doubleTapZoom = false;
                var lastTap = 0;
                var startY = 0;
                var startZoom = 0;
                
                map.on('touchstart', function(e) {
                    if (e.originalEvent.touches.length === 1) {
                        var now = Date.now();
                        if (now - lastTap < 300) {
                            // 더블탭 감지
                            doubleTapZoom = true;
                            startY = e.originalEvent.touches[0].clientY;
                            startZoom = map.getZoom();
                            e.originalEvent.preventDefault();
                        }
                        lastTap = now;
                    }
                });
                
                map.on('touchmove', function(e) {
                    if (doubleTapZoom && e.originalEvent.touches.length === 1) {
                        var currentY = e.originalEvent.touches[0].clientY;
                        var deltaY = startY - currentY;
                        
                        // 위로 드래그: 확대, 아래로 드래그: 축소
                        var zoomDelta = deltaY / 100;
                        var newZoom = startZoom + zoomDelta;
                        
                        // 줌 레벨 제한
                        newZoom = Math.max(1, Math.min(19, newZoom));
                        map.setZoom(newZoom, { animate: false });
                        
                        e.originalEvent.preventDefault();
                    }
                });
                
                map.on('touchend', function(e) {
                    if (doubleTapZoom) {
                        doubleTapZoom = false;
                    }
                });
                
                // Distance Measurement
                var measurePoints = [];
                var measureMarkers = [];
                var measureLines = [];
                var isMeasuring = false;
                
                window.startMeasuring = function() {
                    console.log('Start measuring');
                    isMeasuring = true;
                    clearMeasurement();
                    map.on('click', onMapClick);
                }
                
                window.stopMeasuring = function() {
                    console.log('Stop measuring');
                    isMeasuring = false;
                    map.off('click', onMapClick);
                }
                
                function clearMeasurement() {
                    measurePoints = [];
                    measureMarkers.forEach(m => map.removeLayer(m));
                    measureLines.forEach(l => map.removeLayer(l));
                    measureMarkers = [];
                    measureLines = [];
                }
                
                function onMapClick(e) {
                    console.log('Map clicked:', e.latlng);
                    if (!isMeasuring) return;
                    
                    measurePoints.push(e.latlng);
                    
                    // Add marker
                    var marker = L.circleMarker(e.latlng, {
                        radius: 6,
                        color: '#ff0000',
                        fillColor: '#ff0000',
                        fillOpacity: 1,
                        weight: 2
                    }).addTo(map);
                    measureMarkers.push(marker);
                    
                    // Draw line if more than one point
                    if (measurePoints.length > 1) {
                        var lastTwo = measurePoints.slice(-2);
                        var line = L.polyline(lastTwo, {
                            color: '#ff0000',
                            weight: 3,
                            opacity: 0.8
                        }).addTo(map);
                        measureLines.push(line);
                        
                        // Calculate distance
                        var distance = map.distance(lastTwo[0], lastTwo[1]);
                        var distanceText = distance < 1000 
                            ? distance.toFixed(0) + 'm'
                            : (distance / 1000).toFixed(2) + 'km';
                        
                        // Add label
                        var midpoint = L.latLng(
                            (lastTwo[0].lat + lastTwo[1].lat) / 2,
                            (lastTwo[0].lng + lastTwo[1].lng) / 2
                        );
                        
                        var label = L.marker(midpoint, {
                            icon: L.divIcon({
                                className: 'distance-label',
                                html: distanceText
                            })
                        }).addTo(map);
                        measureLines.push(label);
                        
                        // Total distance
                        var total = 0;
                        for (var i = 1; i < measurePoints.length; i++) {
                            total += map.distance(measurePoints[i-1], measurePoints[i]);
                        }
                        var totalText = total < 1000 
                            ? '총 거리: ' + total.toFixed(0) + 'm'
                            : '총 거리: ' + (total / 1000).toFixed(2) + 'km';
                        
                        marker.bindPopup(totalText).openPopup();
                    } else {
                        marker.bindPopup('시작점').openPopup();
                    }
                }
                
                console.log('Map initialized');
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Map WebView
struct MapWebView: UIViewRepresentable {
    let html: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isMultipleTouchEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        
        // 터치 제스처 추가
        let doubleTapGesture = DoubleTapDragGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTapDrag(_:)))
        webView.addGestureRecognizer(doubleTapGesture)
        context.coordinator.doubleTapGesture = doubleTapGesture
        
        // NotificationCenter 관찰자 등록
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.executeScript(_:)),
            name: NSNotification.Name("ExecuteMapScript"),
            object: nil
        )
        
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    class Coordinator: NSObject {
        weak var webView: WKWebView?
        var doubleTapGesture: DoubleTapDragGestureRecognizer?
        
        @objc func executeScript(_ notification: Notification) {
            guard let script = notification.object as? String else { return }
            webView?.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("JavaScript error: \(error)")
                }
            }
        }
        
        @objc func handleDoubleTapDrag(_ gesture: DoubleTapDragGestureRecognizer) {
            guard let webView = webView else { return }
            
            switch gesture.state {
            case .began:
                print("Double tap drag began")
                // 초기 줌 레벨 저장
                webView.evaluateJavaScript("map.getZoom()") { result, _ in
                    if let zoom = result as? Double {
                        gesture.startZoom = zoom
                    } else if let zoom = result as? Int {
                        gesture.startZoom = Double(zoom)
                    }
                }
            case .changed:
                let translation = gesture.translation(in: webView)
                let zoomDelta = -translation.y / 100.0 // 위로 = +, 아래로 = -
                let newZoom = gesture.startZoom + zoomDelta
                let clampedZoom = max(1, min(19, newZoom))
                
                print("Zoom: \(clampedZoom)")
                // 에러를 무시하고 줌만 실행
                webView.evaluateJavaScript("if (typeof map !== 'undefined') { map.setZoom(\(clampedZoom), { animate: false }); }", completionHandler: nil)
            case .ended, .cancelled:
                print("Double tap drag ended")
            default:
                break
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Double Tap Drag Gesture Recognizer
class DoubleTapDragGestureRecognizer: UIGestureRecognizer {
    var startZoom: Double = 13.0
    private var initialTouch: CGPoint = .zero
    private var tapCount = 0
    private var lastTapTime: TimeInterval = 0
    private var isDragging = false
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let currentTime = Date().timeIntervalSince1970
        
        if currentTime - lastTapTime < 0.3 {
            // 더블탭 감지
            tapCount += 1
            if tapCount == 2 {
                initialTouch = touch.location(in: view)
                state = .began
                isDragging = true
                print("Double tap detected!")
            }
        } else {
            tapCount = 1
        }
        
        lastTapTime = currentTime
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if isDragging {
            state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if isDragging {
            state = .ended
            isDragging = false
            tapCount = 0
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if isDragging {
            state = .cancelled
            isDragging = false
            tapCount = 0
        }
    }
    
    override func reset() {
        super.reset()
        isDragging = false
    }
    
    func translation(in view: UIView?) -> CGPoint {
        guard let touch = UITouch.allTouches?.first,
              let view = view else {
            return .zero
        }
        let currentTouch = touch.location(in: view)
        return CGPoint(x: currentTouch.x - initialTouch.x,
                      y: currentTouch.y - initialTouch.y)
    }
}

extension UITouch {
    static var allTouches: Set<UITouch>? {
        // iOS 15+에서는 windowScene.windows를 사용
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows
                .first?.rootViewController?.view.window?.allTouches
        } else {
            // iOS 14 이하에서는 기존 API 사용
            return UIApplication.shared.windows.first?.rootViewController?.view.window?.allTouches
        }
    }
}

extension UIWindow {
    var allTouches: Set<UITouch>? {
        var touches = Set<UITouch>()

        func findTouches(in view: UIView) {
            for subview in view.subviews {
                if let gestureRecognizers = subview.gestureRecognizers {
                    for recognizer in gestureRecognizers {
                        if let touch = recognizer.view?.window {
                            // touches 수집
                        }
                    }
                }
                findTouches(in: subview)
            }
        }

        if let rootViewController = rootViewController?.view {
            findTouches(in: rootViewController)
        }

        return touches.isEmpty ? nil : touches
    }
}
