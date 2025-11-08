//
//  DeepSeekProvider.swift
//  SwiftAgent
//
//  DeepSeek API Provider 实现
//  API格式与OpenAI兼容
//

import Foundation

/// DeepSeek API Provider 实现
/// 支持 DeepSeek 的各个模型系列
public final class DeepSeekProvider: @unchecked Sendable, LLMProviderProtocol {
    public let modelName: String
    
    internal let apiKey: String
    internal let baseURL: String
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.swiftagent.deepseek")
    private let retryExecutor: RetryExecutor
    
    /// DeepSeek 模型枚举
    public enum Model: String {
        case chat = "deepseek-chat"              // 主力对话模型
        case coder = "deepseek-coder"            // 代码专用模型
        case reasoner = "deepseek-reasoner"      // 推理模型
        
        public var displayName: String {
            switch self {
            case .chat: return "DeepSeek Chat"
            case .coder: return "DeepSeek Coder"
            case .reasoner: return "DeepSeek Reasoner"
            }
        }
    }
    
    /// 初始化 DeepSeek Provider
    /// - Parameters:
    ///   - apiKey: DeepSeek API 密钥
    ///   - model: 使用的模型（默认为 deepseek-chat）
    ///   - baseURL: API 基础URL（默认为官方地址）
    ///   - session: 自定义 URLSession（可选）
    ///   - retryPolicy: 重试策略（可选）
    public init(
        apiKey: String,
        model: Model = .chat,
        baseURL: String = "https://api.deepseek.com/v1",
        session: URLSession = .shared,
        retryPolicy: RetryPolicy? = nil
    ) {
        self.apiKey = apiKey
        self.modelName = model.rawValue
        self.baseURL = baseURL
        self.session = session
        self.retryExecutor = RetryExecutor(policy: retryPolicy ?? .default)
    }
    
    /// 使用自定义模型名称初始化
    /// - Parameters:
    ///   - apiKey: DeepSeek API 密钥
    ///   - modelName: 自定义模型名称
    ///   - baseURL: API 基础URL
    ///   - session: 自定义 URLSession（可选）
    ///   - retryPolicy: 重试策略（可选）
    public init(
        apiKey: String,
        modelName: String,
        baseURL: String = "https://api.deepseek.com/v1",
        session: URLSession = .shared,
        retryPolicy: RetryPolicy? = nil
    ) {
        self.apiKey = apiKey
        self.modelName = modelName
        self.baseURL = baseURL
        self.session = session
        self.retryExecutor = RetryExecutor(policy: retryPolicy ?? .default)
    }
    
    // MARK: - LLMProviderProtocol
    
    public func chat(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double
    ) async throws -> LLMResponse {
        return try await retryExecutor.execute {
            try await self.performChat(messages: messages, tools: tools, temperature: temperature)
        }
    }
    
    public func chatStream(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double,
        onChunk: @escaping (String) -> Void
    ) async throws -> LLMResponse {
        return try await retryExecutor.execute {
            try await self.performChatStream(messages: messages, tools: tools, temperature: temperature, onChunk: onChunk)
        }
    }
    
    // MARK: - Private Methods
    
    private func performChat(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double
    ) async throws -> LLMResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "model": modelName,
            "messages": messages.map { msg in
                var dict: [String: Any] = [
                    "role": msg.role.rawValue,
                    "content": msg.content
                ]
                if let name = msg.name {
                    dict["name"] = name
                }
                if let toolCallId = msg.toolCallId {
                    dict["tool_call_id"] = toolCallId
                }
                return dict
            },
            "temperature": temperature
        ]
        
        // 添加工具定义
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": convertAnyCodableToJSONObject(tool.parameters)
                    ]
                ]
            }
            body["tool_choice"] = "auto"
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ToolError.executionFailed("Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ToolError.executionFailed("DeepSeek API error (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        return try parseResponse(data: data)
    }
    
    private func performChatStream(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double,
        onChunk: @escaping (String) -> Void
    ) async throws -> LLMResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "model": modelName,
            "messages": messages.map { msg in
                [
                    "role": msg.role.rawValue,
                    "content": msg.content
                ]
            },
            "temperature": temperature,
            "stream": true
        ]
        
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": tool.parameters
                    ]
                ]
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (asyncBytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ToolError.executionFailed("Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ToolError.executionFailed("DeepSeek API error: \(httpResponse.statusCode)")
        }
        
        var fullContent = ""
        var finishReason: String?
        
        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" {
                    break
                }
                
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first else {
                    continue
                }
                
                if let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    fullContent += content
                    onChunk(content)
                }
                
                if let reason = firstChoice["finish_reason"] as? String {
                    finishReason = reason
                }
            }
        }
        
        return LLMResponse(
            content: fullContent,
            toolCalls: nil,
            finishReason: finishReason
        )
    }
    
    private func parseResponse(data: Data) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.executionFailed("Invalid JSON response")
        }
        
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw ToolError.executionFailed("Invalid response structure")
        }
        
        let content = message["content"] as? String ?? ""
        let finishReason = firstChoice["finish_reason"] as? String
        
        // 解析工具调用
        var toolCalls: [LLMToolCall]?
        if let toolCallsArray = message["tool_calls"] as? [[String: Any]] {
            toolCalls = toolCallsArray.compactMap { toolCallDict in
                guard let id = toolCallDict["id"] as? String,
                      let type = toolCallDict["type"] as? String,
                      let function = toolCallDict["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let arguments = function["arguments"] as? String else {
                    return nil
                }
                
                return LLMToolCall(
                    id: id,
                    type: type,
                    function: LLMToolCall.FunctionCall(name: name, arguments: arguments)
                )
            }
        }
        
        // 解析使用统计
        var usage: LLMResponse.TokenUsage?
        if let usageDict = json["usage"] as? [String: Any],
           let promptTokens = usageDict["prompt_tokens"] as? Int,
           let completionTokens = usageDict["completion_tokens"] as? Int,
           let totalTokens = usageDict["total_tokens"] as? Int {
            usage = LLMResponse.TokenUsage(
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                totalTokens: totalTokens
            )
        }
        
        return LLMResponse(
            content: content,
            toolCalls: toolCalls,
            finishReason: finishReason,
            usage: usage
        )
    }
}

// MARK: - Streaming Support

extension DeepSeekProvider: StreamingLLMProviderProtocol {
    public func streamGenerate(messages: [LLMMessage], tools: [LLMToolFunction]?) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(baseURL)/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    
                    var body: [String: Any] = [
                        "model": modelName,
                        "messages": messages.map { msg in
                            [
                                "role": msg.role.rawValue,
                                "content": msg.content
                            ]
                        },
                        "temperature": 0.7,
                        "stream": true
                    ]
                    
                    if let tools = tools, !tools.isEmpty {
                        body["tools"] = tools.map { tool in
                            [
                                "type": "function",
                                "function": [
                                    "name": tool.name,
                                    "description": tool.description,
                                    "parameters": tool.parameters
                                ]
                            ]
                        }
                    }
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ToolError.executionFailed("Invalid response type")
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw ToolError.executionFailed("DeepSeek API error: \(httpResponse.statusCode)")
                    }
                    
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.yield(StreamingChunk(type: .done))
                                break
                            }
                            
                            guard let jsonData = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let firstChoice = choices.first else {
                                continue
                            }
                            
                            if let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(StreamingChunk(type: .content(content)))
                            }
                            
                            if let reason = firstChoice["finish_reason"] as? String, reason == "stop" {
                                continuation.yield(StreamingChunk(type: .done))
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// 将 AnyCodable 字典转换为 JSON 可序列化对象
    private func convertAnyCodableToJSONObject(_ dict: [String: AnyCodable]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = convertAnyCodableValue(value)
        }
        return result
    }
    
    /// 将单个 AnyCodable 值转换为 JSON 可序列化对象
    private func convertAnyCodableValue(_ codable: AnyCodable) -> Any {
        let value = codable.value
        
        if let dict = value as? [String: Any] {
            return dict.mapValues { item in
                if let nestedCodable = item as? AnyCodable {
                    return convertAnyCodableValue(nestedCodable)
                }
                return item
            }
        } else if let array = value as? [Any] {
            return array.map { item in
                if let nestedCodable = item as? AnyCodable {
                    return convertAnyCodableValue(nestedCodable)
                }
                return item
            }
        } else {
            return value
        }
    }
}

