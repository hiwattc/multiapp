//
//  WeatherView.swift
//  news
//
//  날씨 정보 표시 화면
//

import SwiftUI
import CoreLocation
import Combine

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Air Quality Models
struct AirQualityData: Codable {
    let latitude: Double
    let longitude: Double
    let current: CurrentAirQuality
    
    struct CurrentAirQuality: Codable {
        let pm10: Double?
        let pm25: Double?
        let carbonMonoxide: Double?
        let nitrogenDioxide: Double?
        let sulphurDioxide: Double?
        let ozone: Double?
        let europeanAqi: Int?
        let usAqi: Int?
        let uvIndex: Double?
        
        enum CodingKeys: String, CodingKey {
            case pm10
            case pm25 = "pm2_5"
            case carbonMonoxide = "carbon_monoxide"
            case nitrogenDioxide = "nitrogen_dioxide"
            case sulphurDioxide = "sulphur_dioxide"
            case ozone
            case europeanAqi = "european_aqi"
            case usAqi = "us_aqi"
            case uvIndex = "uv_index"
        }
    }
}

// MARK: - Weather Models (Open-Meteo)
struct WeatherData: Codable {
    let latitude: Double
    let longitude: Double
    let currentWeather: CurrentWeather
    let hourly: HourlyData?
    let daily: DailyData?
    
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case currentWeather = "current_weather"
        case hourly
        case daily
    }
    
    struct CurrentWeather: Codable {
        let temperature: Double
        let windspeed: Double
        let winddirection: Double
        let weathercode: Int
        let time: String
    }
    
    struct HourlyData: Codable {
        let time: [String]
        let temperature2m: [Double]
        let relativehumidity2m: [Int]
        let windspeed10m: [Double]
        
        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case relativehumidity2m = "relativehumidity_2m"
            case windspeed10m = "windspeed_10m"
        }
    }
    
    struct DailyData: Codable {
        let time: [String]
        let weathercode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let precipitationSum: [Double]
        let windspeed10mMax: [Double]
        
        enum CodingKeys: String, CodingKey {
            case time
            case weathercode
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case windspeed10mMax = "windspeed_10m_max"
        }
    }
}

// MARK: - Weather Location Manager
class WeatherLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 가져오기 실패: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - Weather Service (Open-Meteo)
class WeatherService: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var airQualityData: AirQualityData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cityName: String = ""
    
    // Open-Meteo API는 API 키가 필요 없습니다! (완전 무료)
    
    func fetchWeather(latitude: Double, longitude: Double) {
        isLoading = true
        errorMessage = nil
        
        // Open-Meteo API URL (주간예보 포함)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true&hourly=temperature_2m,relativehumidity_2m,windspeed_10m&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "잘못된 URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "네트워크 오류: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "데이터를 받을 수 없습니다"
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let weather = try decoder.decode(WeatherData.self, from: data)
                    self?.weatherData = weather
                    
                    // 도시 이름 가져오기 (Reverse Geocoding)
                    self?.fetchCityName(latitude: latitude, longitude: longitude)
                    
                    // 대기질 데이터 가져오기
                    self?.fetchAirQuality(latitude: latitude, longitude: longitude)
                } catch {
                    self?.errorMessage = "데이터 파싱 실패: \(error.localizedDescription)"
                    print("❌ 파싱 오류: \(error)")
                }
            }
        }.resume()
    }
    
    func fetchAirQuality(latitude: Double, longitude: Double) {
        let urlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,european_aqi,us_aqi,uv_index&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            print("⚠️ 대기질 URL 오류")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ 대기질 데이터 가져오기 실패: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("⚠️ 대기질 데이터 없음")
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let airQuality = try decoder.decode(AirQualityData.self, from: data)
                    self?.airQualityData = airQuality
                    print("✅ 대기질 데이터 로드 성공")
                } catch {
                    print("❌ 대기질 데이터 파싱 실패: \(error)")
                }
            }
        }.resume()
    }
    
    private func fetchCityName(latitude: Double, longitude: Double) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ 도시 이름 가져오기 실패: \(error.localizedDescription)")
                    self?.cityName = "위치"
                    return
                }
                
                if let placemark = placemarks?.first {
                    self?.cityName = placemark.locality ?? placemark.administrativeArea ?? "위치"
                }
            }
        }
    }
}

// MARK: - Weather View
struct WeatherView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = WeatherLocationManager()
    @StateObject private var weatherService = WeatherService()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 배경 그라데이션
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.6),
                        Color.cyan.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                            // 위치 권한 거부됨
                            LocationPermissionDeniedView()
                        } else if locationManager.location == nil {
                            // 위치 가져오는 중
                            LoadingLocationView()
                        } else if weatherService.isLoading {
                            // 날씨 데이터 로딩 중
                            LoadingWeatherView()
                        } else if let errorMessage = weatherService.errorMessage {
                            // 오류 발생
                            ErrorView(message: errorMessage) {
                                if let location = locationManager.location {
                                    weatherService.fetchWeather(
                                        latitude: location.coordinate.latitude,
                                        longitude: location.coordinate.longitude
                                    )
                                }
                            }
                        } else if let weather = weatherService.weatherData {
                            // 날씨 정보 표시
                            WeatherContentView(
                                weather: weather,
                                cityName: weatherService.cityName,
                                airQuality: weatherService.airQualityData
                            )
                        } else {
                            // 초기 상태
                            EmptyWeatherView()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("날씨")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        locationManager.requestLocation()
                    }) {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.location) { oldValue, newValue in
                if let location = newValue {
                    weatherService.fetchWeather(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
            }
        }
    }
}

// MARK: - Weather Content View
struct WeatherContentView: View {
    let weather: WeatherData
    let cityName: String
    let airQuality: AirQualityData?
    
    var body: some View {
        VStack(spacing: 24) {
            // 도시 이름
            Text(cityName.isEmpty ? "현재 위치" : cityName)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.white)
            
            // 날씨 아이콘 및 설명
            VStack(spacing: 8) {
                Image(systemName: weatherIcon(for: weather.currentWeather.weathercode))
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                
                Text(weatherDescription(for: weather.currentWeather.weathercode))
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // 현재 온도
            Text(String(format: "%.0f°", weather.currentWeather.temperature))
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.white)
            
            // 풍속 정보
            Text(String(format: "풍속 %.1f km/h", weather.currentWeather.windspeed))
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            
            // 상세 정보 카드
            if let hourly = weather.hourly,
               !hourly.temperature2m.isEmpty,
               !hourly.relativehumidity2m.isEmpty {
                
                let maxTemp = hourly.temperature2m.max() ?? weather.currentWeather.temperature
                let minTemp = hourly.temperature2m.min() ?? weather.currentWeather.temperature
                
                // 현재 시간과 가장 가까운 인덱스 찾기
                let currentIndex = findCurrentHourIndex(times: hourly.time, currentTime: weather.currentWeather.time)
                let currentHumidity = hourly.relativehumidity2m[safe: currentIndex] ?? hourly.relativehumidity2m.first ?? 0
                
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        WeatherDetailCard(
                            icon: "thermometer.high",
                            title: "최고",
                            value: String(format: "%.0f°", maxTemp)
                        )
                        
                        WeatherDetailCard(
                            icon: "thermometer.low",
                            title: "최저",
                            value: String(format: "%.0f°", minTemp)
                        )
                    }
                    
                    HStack(spacing: 16) {
                        WeatherDetailCard(
                            icon: "humidity.fill",
                            title: "습도",
                            value: "\(currentHumidity)%"
                        )
                        
                        WeatherDetailCard(
                            icon: "wind",
                            title: "풍속",
                            value: String(format: "%.1f km/h", weather.currentWeather.windspeed)
                        )
                    }
                    
                    HStack(spacing: 16) {
                        WeatherDetailCard(
                            icon: "location.northup.fill",
                            title: "풍향",
                            value: windDirection(for: weather.currentWeather.winddirection)
                        )
                        
                        WeatherDetailCard(
                            icon: "clock.fill",
                            title: "업데이트",
                            value: formatTime(weather.currentWeather.time)
                        )
                    }
                }
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(20)
                .shadow(radius: 10)
            }
            
            // 주간 예보
            if let daily = weather.daily, !daily.time.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("주간 예보")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(daily.time.prefix(7).enumerated()), id: \.offset) { index, dateString in
                                if index < daily.weathercode.count,
                                   index < daily.temperature2mMax.count,
                                   index < daily.temperature2mMin.count {
                                    DailyForecastCard(
                                        date: dateString,
                                        weatherCode: daily.weathercode[index],
                                        maxTemp: daily.temperature2mMax[index],
                                        minTemp: daily.temperature2mMin[index],
                                        precipitation: index < daily.precipitationSum.count ? daily.precipitationSum[index] : 0,
                                        isToday: index == 0
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            
            // 대기질 정보
            if let airQuality = airQuality {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("대기질 정보")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // 전체 대기질 지수
                        if let aqi = airQuality.current.europeanAqi {
                            AirQualityBadge(aqi: aqi)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 대기질 상세 카드
                    VStack(spacing: 12) {
                        if let pm10 = airQuality.current.pm10,
                           let pm25 = airQuality.current.pm25 {
                            HStack(spacing: 12) {
                                AirQualityCard(
                                    icon: "aqi.medium",
                                    title: "미세먼지",
                                    value: String(format: "%.0f", pm10),
                                    unit: "μg/m³",
                                    level: pm10Level(pm10)
                                )
                                
                                AirQualityCard(
                                    icon: "aqi.high",
                                    title: "초미세먼지",
                                    value: String(format: "%.0f", pm25),
                                    unit: "μg/m³",
                                    level: pm25Level(pm25)
                                )
                            }
                        }
                        
                        if let ozone = airQuality.current.ozone,
                           let no2 = airQuality.current.nitrogenDioxide {
                            HStack(spacing: 12) {
                                AirQualityCard(
                                    icon: "circle.hexagongrid.fill",
                                    title: "오존",
                                    value: String(format: "%.0f", ozone),
                                    unit: "μg/m³",
                                    level: ozoneLevel(ozone)
                                )
                                
                                AirQualityCard(
                                    icon: "smoke.fill",
                                    title: "이산화질소",
                                    value: String(format: "%.0f", no2),
                                    unit: "μg/m³",
                                    level: no2Level(no2)
                                )
                            }
                        }
                        
                        if let uvIndex = airQuality.current.uvIndex,
                           let co = airQuality.current.carbonMonoxide {
                            HStack(spacing: 12) {
                                AirQualityCard(
                                    icon: "sun.max.fill",
                                    title: "자외선지수",
                                    value: String(format: "%.1f", uvIndex),
                                    unit: "",
                                    level: uvLevel(uvIndex)
                                )
                                
                                AirQualityCard(
                                    icon: "flame.fill",
                                    title: "일산화탄소",
                                    value: String(format: "%.0f", co),
                                    unit: "μg/m³",
                                    level: coLevel(co)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(20)
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    // 미세먼지 등급
    private func pm10Level(_ value: Double) -> AirQualityLevel {
        switch value {
        case 0..<31: return .good
        case 31..<81: return .moderate
        case 81..<151: return .unhealthy
        default: return .veryUnhealthy
        }
    }
    
    // 초미세먼지 등급
    private func pm25Level(_ value: Double) -> AirQualityLevel {
        switch value {
        case 0..<16: return .good
        case 16..<36: return .moderate
        case 36..<76: return .unhealthy
        default: return .veryUnhealthy
        }
    }
    
    // 오존 등급
    private func ozoneLevel(_ value: Double) -> AirQualityLevel {
        switch value {
        case 0..<51: return .good
        case 51..<101: return .moderate
        case 101..<151: return .unhealthy
        default: return .veryUnhealthy
        }
    }
    
    // 이산화질소 등급
    private func no2Level(_ value: Double) -> AirQualityLevel {
        switch value {
        case 0..<31: return .good
        case 31..<61: return .moderate
        case 61..<91: return .unhealthy
        default: return .veryUnhealthy
        }
    }
    
    // 자외선 등급
    private func uvLevel(_ value: Double) -> AirQualityLevel {
        switch value {
        case 0..<3: return .good
        case 3..<6: return .moderate
        case 6..<8: return .unhealthy
        default: return .veryUnhealthy
        }
    }
    
    // 일산화탄소 등급
    private func coLevel(_ value: Double) -> AirQualityLevel {
        switch value {
        case 0..<2001: return .good
        case 2001..<10001: return .moderate
        case 10001..<17001: return .unhealthy
        default: return .veryUnhealthy
        }
    }
    
    // 현재 시간과 가장 가까운 시간 인덱스 찾기
    private func findCurrentHourIndex(times: [String], currentTime: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        guard let current = formatter.date(from: currentTime) else {
            return 0
        }
        
        var closestIndex = 0
        var minDiff = TimeInterval.infinity
        
        for (index, timeString) in times.enumerated() {
            if let time = formatter.date(from: timeString) {
                let diff = abs(time.timeIntervalSince(current))
                if diff < minDiff {
                    minDiff = diff
                    closestIndex = index
                }
            }
        }
        
        return closestIndex
    }
    
    // WMO Weather Code를 아이콘으로 변환
    private func weatherIcon(for code: Int) -> String {
        switch code {
        case 0:
            return "sun.max.fill"  // 맑음
        case 1, 2:
            return "cloud.sun.fill"  // 대체로 맑음
        case 3:
            return "cloud.fill"  // 흐림
        case 45, 48:
            return "cloud.fog.fill"  // 안개
        case 51, 53, 55:
            return "cloud.drizzle.fill"  // 이슬비
        case 61, 63, 65:
            return "cloud.rain.fill"  // 비
        case 71, 73, 75:
            return "snow"  // 눈
        case 77:
            return "snowflake"  // 싸라기눈
        case 80, 81, 82:
            return "cloud.heavyrain.fill"  // 소나기
        case 85, 86:
            return "cloud.snow.fill"  // 눈 소나기
        case 95:
            return "cloud.bolt.fill"  // 천둥번개
        case 96, 99:
            return "cloud.bolt.rain.fill"  // 천둥번개와 우박
        default:
            return "cloud.sun.fill"
        }
    }
    
    // WMO Weather Code를 설명으로 변환
    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0:
            return "맑음"
        case 1:
            return "대체로 맑음"
        case 2:
            return "부분적으로 흐림"
        case 3:
            return "흐림"
        case 45, 48:
            return "안개"
        case 51, 53, 55:
            return "이슬비"
        case 61, 63, 65:
            return "비"
        case 71, 73, 75:
            return "눈"
        case 77:
            return "싸라기눈"
        case 80, 81, 82:
            return "소나기"
        case 85, 86:
            return "눈 소나기"
        case 95:
            return "천둥번개"
        case 96, 99:
            return "천둥번개와 우박"
        default:
            return "날씨 정보"
        }
    }
    
    // 풍향 변환
    private func windDirection(for degree: Double) -> String {
        let directions = ["북", "북동", "동", "남동", "남", "남서", "서", "북서"]
        let index = Int((degree + 22.5) / 45.0) % 8
        return directions[index]
    }
    
    // 시간 포맷
    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        if let date = formatter.date(from: timeString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "HH:mm"
            return outputFormatter.string(from: date)
        }
        return timeString
    }
}

// MARK: - Weather Detail Card
struct WeatherDetailCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Air Quality Level
enum AirQualityLevel {
    case good
    case moderate
    case unhealthy
    case veryUnhealthy
    
    var color: Color {
        switch self {
        case .good: return .green
        case .moderate: return .yellow
        case .unhealthy: return .orange
        case .veryUnhealthy: return .red
        }
    }
    
    var text: String {
        switch self {
        case .good: return "좋음"
        case .moderate: return "보통"
        case .unhealthy: return "나쁨"
        case .veryUnhealthy: return "매우나쁨"
        }
    }
}

// MARK: - Air Quality Badge
struct AirQualityBadge: View {
    let aqi: Int
    
    var level: AirQualityLevel {
        switch aqi {
        case 0..<21: return .good
        case 21..<51: return .moderate
        case 51..<101: return .unhealthy
        default: return .veryUnhealthy
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            
            Text(level.text)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("\(aqi)")
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(level.color.opacity(0.2))
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}

// MARK: - Air Quality Card
struct AirQualityCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let level: AirQualityLevel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
                
                Circle()
                    .fill(level.color)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Text(level.text)
                    .font(.caption2)
                    .foregroundColor(level.color)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Daily Forecast Card
struct DailyForecastCard: View {
    let date: String
    let weatherCode: Int
    let maxTemp: Double
    let minTemp: Double
    let precipitation: Double
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // 날짜
            Text(isToday ? "오늘" : formatDayOfWeek(date))
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(.white)
            
            // 날씨 아이콘
            Image(systemName: weatherIcon(for: weatherCode))
                .font(.title2)
                .foregroundColor(.white)
                .frame(height: 30)
            
            // 강수 확률
            if precipitation > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                    Text(String(format: "%.0fmm", precipitation))
                        .font(.caption2)
                }
                .foregroundColor(.cyan)
            } else {
                Text(" ")
                    .font(.caption2)
            }
            
            // 온도
            VStack(spacing: 4) {
                Text(String(format: "%.0f°", maxTemp))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(String(format: "%.0f°", minTemp))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isToday ? Color.white.opacity(0.25) : Color.white.opacity(0.15))
        )
    }
    
    private func formatDayOfWeek(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "ko_KR")
            dayFormatter.dateFormat = "E"
            return dayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func weatherIcon(for code: Int) -> String {
        switch code {
        case 0:
            return "sun.max.fill"
        case 1, 2:
            return "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 61, 63, 65:
            return "cloud.rain.fill"
        case 71, 73, 75:
            return "snow"
        case 77:
            return "snowflake"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95:
            return "cloud.bolt.fill"
        case 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.sun.fill"
        }
    }
}

// MARK: - Loading Views
struct LoadingLocationView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("위치 정보를 가져오는 중...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingWeatherView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("날씨 정보를 가져오는 중...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyWeatherView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("날씨 정보를 불러오세요")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("위치 권한을 허용하고\n새로고침 버튼을 눌러주세요")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            Text("오류 발생")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("다시 시도")
                }
                .font(.headline)
                .foregroundColor(.blue)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Location Permission Denied View
struct LocationPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            Text("위치 권한 필요")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("날씨 정보를 확인하려면\n위치 권한을 허용해주세요")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("설정으로 이동")
                }
                .font(.headline)
                .foregroundColor(.blue)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
struct WeatherView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherView()
    }
}

