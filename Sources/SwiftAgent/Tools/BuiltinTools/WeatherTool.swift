//
//  WeatherTool.swift
//  SwiftAgent
//
//  天气查询工具
//

import Foundation

/// 天气查询工具
/// 提供天气信息查询功能（需要配置天气 API）
public struct WeatherTool: ToolProtocol {
    public let name = "weather"
    public let description = "查询指定地点的天气信息。返回当前天气状况、温度、湿度、风速等信息。"
    
    public var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "location",
                type: "string",
                description: "要查询的地点，可以是城市名、坐标等",
                required: true
            ),
            ToolParameter(
                name: "unit",
                type: "string",
                description: "温度单位：'celsius'（摄氏度）或 'fahrenheit'（华氏度），默认为 'celsius'",
                required: false,
                enumValues: ["celsius", "fahrenheit"]
            ),
            ToolParameter(
                name: "forecast_days",
                type: "number",
                description: "预报天数（0-7天），0 表示仅当前天气，默认为 0",
                required: false
            )
        ]
    }
    
    private let weatherProvider: WeatherProvider
    
    /// 初始化天气工具
    /// - Parameter weatherProvider: 天气提供商（如果为 nil，使用模拟提供商）
    public init(weatherProvider: WeatherProvider? = nil) {
        self.weatherProvider = weatherProvider ?? MockWeatherProvider()
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let location = arguments["location"] as? String else {
            throw ToolError.invalidArguments("缺少 'location' 参数")
        }
        
        let unit = arguments["unit"] as? String ?? "celsius"
        let forecastDays = arguments["forecast_days"] as? Int ?? 0
        
        do {
            let weather = try await weatherProvider.getWeather(
                location: location,
                unit: unit,
                forecastDays: forecastDays
            )
            
            return formatWeather(weather)
        } catch {
            throw ToolError.executionFailed("天气查询失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func formatWeather(_ weather: WeatherInfo) -> String {
        let unitSymbol = weather.unit == "celsius" ? "°C" : "°F"
        
        var output = """
        天气信息（\(weather.location)）：
        
        当前天气：
        - 状况：\(weather.condition)
        - 温度：\(weather.temperature)\(unitSymbol)
        - 体感温度：\(weather.feelsLike)\(unitSymbol)
        - 湿度：\(weather.humidity)%
        - 风速：\(weather.windSpeed) km/h
        - 风向：\(weather.windDirection)
        """
        
        if !weather.forecast.isEmpty {
            output += "\n\n未来预报："
            for (index, day) in weather.forecast.enumerated() {
                output += """
                \n
                第 \(index + 1) 天：
                - 日期：\(day.date)
                - 天气：\(day.condition)
                - 温度范围：\(day.minTemp)\(unitSymbol) ~ \(day.maxTemp)\(unitSymbol)
                """
            }
        }
        
        output += "\n\n更新时间：\(weather.updateTime)"
        
        return output
    }
}

// MARK: - Weather Provider Protocol

/// 天气提供商协议
public protocol WeatherProvider {
    func getWeather(location: String, unit: String, forecastDays: Int) async throws -> WeatherInfo
}

/// 天气信息
public struct WeatherInfo {
    public let location: String
    public let condition: String
    public let temperature: Double
    public let feelsLike: Double
    public let humidity: Int
    public let windSpeed: Double
    public let windDirection: String
    public let unit: String
    public let updateTime: String
    public let forecast: [ForecastDay]
    
    public init(
        location: String,
        condition: String,
        temperature: Double,
        feelsLike: Double,
        humidity: Int,
        windSpeed: Double,
        windDirection: String,
        unit: String,
        updateTime: String,
        forecast: [ForecastDay] = []
    ) {
        self.location = location
        self.condition = condition
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.unit = unit
        self.updateTime = updateTime
        self.forecast = forecast
    }
}

/// 预报日
public struct ForecastDay {
    public let date: String
    public let condition: String
    public let maxTemp: Double
    public let minTemp: Double
    
    public init(date: String, condition: String, maxTemp: Double, minTemp: Double) {
        self.date = date
        self.condition = condition
        self.maxTemp = maxTemp
        self.minTemp = minTemp
    }
}

// MARK: - Mock Weather Provider

/// 模拟天气提供商（用于演示和测试）
public struct MockWeatherProvider: WeatherProvider {
    public init() {}
    
    public func getWeather(location: String, unit: String, forecastDays: Int) async throws -> WeatherInfo {
        // 模拟 API 延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        // 生成模拟数据
        let temp = unit == "celsius" ? 22.0 : 71.6
        let feelsLike = unit == "celsius" ? 24.0 : 75.2
        
        var forecast: [ForecastDay] = []
        if forecastDays > 0 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for i in 1...min(forecastDays, 7) {
                let date = Calendar.current.date(byAdding: .day, value: i, to: Date())!
                forecast.append(ForecastDay(
                    date: dateFormatter.string(from: date),
                    condition: ["晴", "多云", "小雨", "阴"].randomElement()!,
                    maxTemp: temp + Double.random(in: -5...5),
                    minTemp: temp - Double.random(in: 5...10)
                ))
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return WeatherInfo(
            location: location,
            condition: "晴（模拟数据）",
            temperature: temp,
            feelsLike: feelsLike,
            humidity: 65,
            windSpeed: 12.5,
            windDirection: "东南风",
            unit: unit,
            updateTime: formatter.string(from: Date()),
            forecast: forecast
        )
    }
}

// MARK: - Real Weather Provider Example

/// OpenWeatherMap 天气提供商示例
/// 需要 OpenWeatherMap API Key
public struct OpenWeatherMapProvider: WeatherProvider {
    private let apiKey: String
    private let session: URLSession
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }
    
    public func getWeather(location: String, unit: String, forecastDays: Int) async throws -> WeatherInfo {
        // OpenWeatherMap API 实现示例
        let baseURL = "https://api.openweathermap.org/data/2.5/weather"
        var components = URLComponents(string: baseURL)!
        
        let units = unit == "celsius" ? "metric" : "imperial"
        components.queryItems = [
            URLQueryItem(name: "q", value: location),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: units),
            URLQueryItem(name: "lang", value: "zh_cn")
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return WeatherInfo(
            location: response.name,
            condition: response.weather.first?.description ?? "未知",
            temperature: response.main.temp,
            feelsLike: response.main.feelsLike,
            humidity: response.main.humidity,
            windSpeed: response.wind.speed,
            windDirection: degreesToDirection(response.wind.deg),
            unit: unit,
            updateTime: formatter.string(from: Date()),
            forecast: [] // 需要额外的 API 调用获取预报
        )
    }
    
    private func degreesToDirection(_ degrees: Double) -> String {
        let directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let index = Int((degrees + 22.5) / 45.0) % 8
        return directions[index]
    }
    
    private struct OpenWeatherResponse: Codable {
        let name: String
        let main: Main
        let weather: [Weather]
        let wind: Wind
        
        struct Main: Codable {
            let temp: Double
            let feelsLike: Double
            let humidity: Int
            
            enum CodingKeys: String, CodingKey {
                case temp
                case feelsLike = "feels_like"
                case humidity
            }
        }
        
        struct Weather: Codable {
            let description: String
        }
        
        struct Wind: Codable {
            let speed: Double
            let deg: Double
        }
    }
}

// MARK: - Weather Error

enum WeatherError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case locationNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的天气 API URL"
        case .apiError(let message):
            return "API 错误：\(message)"
        case .locationNotFound:
            return "找不到指定的地点"
        }
    }
}

