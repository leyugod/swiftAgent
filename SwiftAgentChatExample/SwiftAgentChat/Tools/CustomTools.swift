//
//  CustomTools.swift
//  SwiftAgentChatExample
//
//  自定义工具示例
//

import Foundation
import SwiftAgent

// MARK: - Weather Query Tool

/// 天气查询工具（模拟）
struct WeatherQueryTool: ToolProtocol {
    let name = "get_weather"
    let description = "查询指定城市的当前天气情况，包括温度、天气状况、湿度和风力等信息"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "city",
                type: "string",
                description: "城市名称，例如：北京、上海、广州",
                required: true
            ),
            ToolParameter(
                name: "unit",
                type: "string",
                description: "温度单位，可选 'celsius' 或 'fahrenheit'，默认为 'celsius'",
                required: false,
                enumValues: ["celsius", "fahrenheit"]
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let city = arguments["city"] as? String else {
            throw ToolError.invalidArguments("缺少城市参数")
        }
        
        let unit = arguments["unit"] as? String ?? "celsius"
        let unitSymbol = unit == "celsius" ? "°C" : "°F"
        let temperature = unit == "celsius" ? 25 : 77
        
        // 模拟 API 调用延迟
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 返回模拟天气数据
        return """
        📍 \(city) 的天气情况：
        
        🌡️ 温度：\(temperature)\(unitSymbol)
        ☀️ 天气：晴朗
        💧 湿度：60%
        🌬️ 风力：3级（微风）
        👁️ 能见度：良好
        
        建议：天气晴朗，适合外出活动。
        """
    }
}

// MARK: - Translate Tool

/// 翻译工具（模拟）
struct TranslateTool: ToolProtocol {
    let name = "translate"
    let description = "将文本翻译成指定的目标语言"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "text",
                type: "string",
                description: "要翻译的文本内容",
                required: true
            ),
            ToolParameter(
                name: "target_language",
                type: "string",
                description: "目标语言，例如：英文、中文、日文、韩文",
                required: true
            ),
            ToolParameter(
                name: "source_language",
                type: "string",
                description: "源语言（可选），如果不指定则自动检测",
                required: false
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String,
              let targetLang = arguments["target_language"] as? String else {
            throw ToolError.invalidArguments("缺少必要参数")
        }
        
        let sourceLang = arguments["source_language"] as? String ?? "自动检测"
        
        // 模拟翻译延迟
        try await Task.sleep(nanoseconds: 800_000_000)
        
        // 简单的模拟翻译
        let translatedText: String
        if targetLang.contains("英") {
            translatedText = "Hello, World!" // 简化示例
        } else if targetLang.contains("日") {
            translatedText = "こんにちは、世界！"
        } else {
            translatedText = "[翻译结果示例]"
        }
        
        return """
        🌐 翻译结果：
        
        源语言：\(sourceLang)
        目标语言：\(targetLang)
        
        原文：\(text)
        译文：\(translatedText)
        """
    }
}

// MARK: - Search Tool

/// 搜索工具（模拟）
struct SearchTool: ToolProtocol {
    let name = "web_search"
    let description = "在互联网上搜索信息，返回相关搜索结果"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "query",
                type: "string",
                description: "搜索关键词或问题",
                required: true
            ),
            ToolParameter(
                name: "max_results",
                type: "number",
                description: "返回的最大结果数量，默认为 5",
                required: false
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("缺少搜索查询参数")
        }
        
        let maxResults = (arguments["max_results"] as? Int) ?? 5
        
        // 模拟搜索延迟
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // 返回模拟搜索结果
        return """
        🔍 搜索结果："\(query)"
        
        找到 \(maxResults) 条相关结果：
        
        1. 📄 标题示例 1
           来源：example.com
           摘要：这是一个搜索结果的示例摘要...
        
        2. 📄 标题示例 2
           来源：example2.com
           摘要：另一个相关的搜索结果示例...
        
        （这是模拟数据，实际使用时需要集成真实搜索 API）
        """
    }
}

// MARK: - Image Description Tool

/// 图片描述工具（模拟）
struct ImageDescriptionTool: ToolProtocol {
    let name = "describe_image"
    let description = "分析并描述图片内容"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "image_url",
                type: "string",
                description: "图片的 URL 地址",
                required: true
            ),
            ToolParameter(
                name: "detail_level",
                type: "string",
                description: "描述详细程度：'simple'（简单）或 'detailed'（详细）",
                required: false,
                enumValues: ["simple", "detailed"]
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let imageUrl = arguments["image_url"] as? String else {
            throw ToolError.invalidArguments("缺少图片 URL 参数")
        }
        
        let detailLevel = arguments["detail_level"] as? String ?? "simple"
        
        // 模拟图片分析延迟
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // 返回模拟描述
        if detailLevel == "detailed" {
            return """
            🖼️ 图片详细分析：
            
            📍 URL：\(imageUrl)
            
            🎨 内容描述：
            - 主要对象：[示例对象]
            - 场景：[示例场景]
            - 颜色：[主要颜色]
            - 构图：[构图特点]
            
            💡 标签：#示例 #图片分析
            
            （这是模拟数据，实际使用时需要集成视觉识别 API）
            """
        } else {
            return "🖼️ 这是一张示例图片的简单描述（模拟数据）"
        }
    }
}

