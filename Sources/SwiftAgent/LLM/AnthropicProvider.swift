//
//  AnthropicProvider.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// Anthropic Claude API Provider 实现
public final class AnthropicProvider: @unchecked Sendable, LLMProviderProtocol {
    public let modelName: String
    
    internal let apiKey: String
    internal let baseURL: String
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.swiftagent.anthropic")
    private let retryExecutor: RetryExecutor
    
    /// Anthropic API 请求结构
    private struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let maxTokens: Int
        let temperature: Double?
        let tools: [Tool]?
        
        struct Message: Codable {
            let role: String
            let content: Content
            
            enum Content: Codable {
                case text(String)
                case array([ContentBlock])
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
                    case .text(let string):
                        try container.encode(string)
                    case .array(let blocks):
                        try container.encode(blocks)
                    }
                }
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let string = try? container.decode(String.self) {
                        self = .text(string)
                    } else if let blocks = try? container.decode([ContentBlock].self) {
                        self = .array(blocks)
                    } else {
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: "Content must be a string or array"
                        )
                    }
                }
            }
            
            struct ContentBlock: Codable {
                let type: String
                let text: String?
                let toolUseId: String?
                let name: String?
                let input: [String: AnyCodable]?
                
                enum CodingKeys: String, CodingKey {
                    case type, text, name, input
                    case toolUseId = "tool_use_id"
                }
            }
        }
        
        struct Tool: Codable {
            let name: String
            let description: String
            let inputSchema: [String: AnyCodable]
            
            enum CodingKeys: String, CodingKey {
                case name, description
                case inputSchema = "input_schema"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case model, messages, tools, temperature
            case maxTokens = "max_tokens"
        }
    }
    
    /// Anthropic API 响应结构
    private struct ChatResponse: Codable {
        let id: String
        let type: String
        let role: String
        let content: [ContentBlock]
        let stopReason: String?
        let usage: Usage?
        
        struct ContentBlock: Codable {
            let type: String
            let text: String?
            let id: String?
            let name: String?
            let input: [String: AnyCodable]?
        }
        
        struct Usage: Codable {
            let inputTokens: Int
            let outputTokens: Int
            
            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case id, type, role, content, usage
            case stopReason = "stop_reason"
        }
    }
    
    /// 初始化 Anthropic Provider
    /// - Parameters:
    ///   - config: LLM Provider 配置
    public init(config: LLMProviderConfig, retryPolicy: RetryPolicy = .default) {
        self.apiKey = config.apiKey
        self.modelName = config.modelName
        self.baseURL = config.baseURL ?? "https://api.anthropic.com/v1"
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: configuration)
        self.retryExecutor = RetryExecutor(policy: retryPolicy)
    }
    
    /// 便捷初始化方法
    /// - Parameters:
    ///   - apiKey: API 密钥
    ///   - modelName: 模型名称（默认: claude-3-5-sonnet-20241022）
    public init(
        apiKey: String,
        modelName: String = "claude-3-5-sonnet-20241022",
        retryPolicy: RetryPolicy = .default
    ) {
        let config = LLMProviderConfig(
            apiKey: apiKey,
            modelName: modelName
        )
        self.apiKey = config.apiKey
        self.modelName = config.modelName
        self.baseURL = config.baseURL ?? "https://api.anthropic.com/v1"
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: configuration)
        self.retryExecutor = RetryExecutor(policy: retryPolicy)
    }
    
    /// 调用 LLM
    public func chat(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double
    ) async throws -> LLMResponse {
        // 使用重试机制执行请求
        return try await retryExecutor.execute {
            // 构建请求
            let request = self.buildRequest(messages: messages, tools: tools, temperature: temperature)
            
            // 发送请求
            let response = try await self.sendRequest(request)
            
            // 解析响应
            return self.parseResponse(response)
        }
    }
    
    /// 流式调用 LLM
    public func chatStream(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double,
        onChunk: @escaping (String) -> Void
    ) async throws -> LLMResponse {
        // 流式实现（简化版）
        let response = try await chat(messages: messages, tools: tools, temperature: temperature)
        onChunk(response.content)
        return response
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double
    ) -> ChatRequest {
        // 分离系统消息和用户消息
        var conversationMessages: [LLMMessage] = []
        
        for message in messages {
            if message.role != .system {
                conversationMessages.append(message)
            }
        }
        
        // 转换消息格式
        let requestMessages = conversationMessages.map { msg -> ChatRequest.Message in
            if msg.role == .tool {
                // Anthropic 的工具结果格式
                return ChatRequest.Message(
                    role: "user",
                    content: .array([
                        ChatRequest.Message.ContentBlock(
                            type: "tool_result",
                            text: msg.content,
                            toolUseId: msg.toolCallId,
                            name: nil,
                            input: nil
                        )
                    ])
                )
            } else {
                return ChatRequest.Message(
                    role: msg.role.rawValue,
                    content: .text(msg.content)
                )
            }
        }
        
        // 转换工具定义
        let requestTools = tools?.map { tool in
            ChatRequest.Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.parameters
            )
        }
        
        return ChatRequest(
            model: modelName,
            messages: requestMessages,
            maxTokens: 4096,
            temperature: temperature,
            tools: requestTools
        )
    }
    
    private func sendRequest(_ request: ChatRequest) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw NSError(domain: "AnthropicProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AnthropicProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "AnthropicProvider",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ChatResponse.self, from: data)
    }
    
    private func parseResponse(_ response: ChatResponse) -> LLMResponse {
        var contentText = ""
        var toolCalls: [LLMToolCall] = []
        
        // 解析内容块
        for block in response.content {
            switch block.type {
            case "text":
                if let text = block.text {
                    contentText += text
                }
            case "tool_use":
                if let id = block.id, let name = block.name, let input = block.input {
                    // 将输入转换为 JSON 字符串
                    let inputDict = input.mapValues { $0.value }
                    if let jsonData = try? JSONSerialization.data(withJSONObject: inputDict),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        toolCalls.append(LLMToolCall(
                            id: id,
                            type: "function",
                            function: LLMToolCall.FunctionCall(
                                name: name,
                                arguments: jsonString
                            )
                        ))
                    }
                }
            default:
                break
            }
        }
        
        let usage = response.usage.map { u in
            LLMResponse.TokenUsage(
                promptTokens: u.inputTokens,
                completionTokens: u.outputTokens,
                totalTokens: u.inputTokens + u.outputTokens
            )
        }
        
        return LLMResponse(
            content: contentText,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            finishReason: response.stopReason,
            usage: usage
        )
    }
}

