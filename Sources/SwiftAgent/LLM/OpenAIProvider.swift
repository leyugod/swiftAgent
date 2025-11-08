//
//  OpenAIProvider.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// OpenAI API Provider 实现
public final class OpenAIProvider: @unchecked Sendable, LLMProviderProtocol {
    public let modelName: String
    
    internal let apiKey: String
    internal let baseURL: String
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.swiftagent.openai")
    private let retryExecutor: RetryExecutor
    
    /// OpenAI API 请求结构
    private struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let tools: [Tool]?
        let temperature: Double?
        let maxTokens: Int?
        
        struct Message: Codable {
            let role: String
            let content: String?
            let toolCallId: String?
            let name: String?
            let toolCalls: [ToolCall]?
            
            enum CodingKeys: String, CodingKey {
                case role, content, name
                case toolCallId = "tool_call_id"
                case toolCalls = "tool_calls"
            }
        }
        
        struct Tool: Codable {
            let type: String
            let function: Function
            
            struct Function: Codable {
                let name: String
                let description: String
                let parameters: [String: AnyCodable]
            }
        }
        
        struct ToolCall: Codable {
            let id: String
            let type: String
            let function: FunctionCall
            
            struct FunctionCall: Codable {
                let name: String
                let arguments: String
            }
        }
    }
    
    /// OpenAI API 响应结构
    private struct ChatResponse: Codable {
        let id: String
        let choices: [Choice]
        let usage: Usage?
        
        struct Choice: Codable {
            let message: Message
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }
        
        struct Message: Codable {
            let role: String
            let content: String?
            let toolCalls: [ToolCall]?
            
            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
        }
        
        struct ToolCall: Codable {
            let id: String
            let type: String
            let function: FunctionCall
            
            struct FunctionCall: Codable {
                let name: String
                let arguments: String
            }
        }
        
        struct Usage: Codable {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }
    
    /// 初始化 OpenAI Provider
    /// - Parameters:
    ///   - config: LLM Provider 配置
    ///   - retryPolicy: 重试策略（默认: .default）
    public init(config: LLMProviderConfig, retryPolicy: RetryPolicy = .default) {
        self.apiKey = config.apiKey
        self.modelName = config.modelName
        self.baseURL = config.baseURL ?? "https://api.openai.com/v1"
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: configuration)
        self.retryExecutor = RetryExecutor(policy: retryPolicy)
    }
    
    /// 便捷初始化方法
    /// - Parameters:
    ///   - apiKey: API 密钥
    ///   - modelName: 模型名称（默认: gpt-4o-mini）
    ///   - retryPolicy: 重试策略（默认: .default）
    public init(
        apiKey: String,
        modelName: String = "gpt-4o-mini",
        retryPolicy: RetryPolicy = .default
    ) {
        let config = LLMProviderConfig(
            apiKey: apiKey,
            modelName: modelName
        )
        self.apiKey = config.apiKey
        self.modelName = config.modelName
        self.baseURL = config.baseURL ?? "https://api.openai.com/v1"
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: configuration)
        self.retryExecutor = RetryExecutor(policy: retryPolicy)
        // queue 已在主初始化器中设置
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
        // 流式实现（简化版，实际可能需要更复杂的处理）
        // 这里先实现非流式版本
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
        let requestMessages = messages.map { msg in
            ChatRequest.Message(
                role: msg.role.rawValue,
                content: msg.content,
                toolCallId: msg.toolCallId,
                name: msg.name,
                toolCalls: nil
            )
        }
        
        let requestTools = tools?.map { tool in
            ChatRequest.Tool(
                type: "function",
                function: ChatRequest.Tool.Function(
                    name: tool.name,
                    description: tool.description,
                    parameters: tool.parameters
                )
            )
        }
        
        return ChatRequest(
            model: modelName,
            messages: requestMessages,
            tools: requestTools,
            temperature: temperature,
            maxTokens: nil
        )
    }
    
    private func sendRequest(_ request: ChatRequest) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "OpenAIProvider",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ChatResponse.self, from: data)
    }
    
    private func parseResponse(_ response: ChatResponse) -> LLMResponse {
        guard let choice = response.choices.first else {
            return LLMResponse(content: "", toolCalls: nil, finishReason: nil, usage: nil)
        }
        
        let content = choice.message.content ?? ""
        let toolCalls = choice.message.toolCalls?.map { toolCall in
            LLMToolCall(
                id: toolCall.id,
                type: toolCall.type,
                function: LLMToolCall.FunctionCall(
                    name: toolCall.function.name,
                    arguments: toolCall.function.arguments
                )
            )
        }
        
        let usage = response.usage.map { u in
            LLMResponse.TokenUsage(
                promptTokens: u.promptTokens,
                completionTokens: u.completionTokens,
                totalTokens: u.totalTokens
            )
        }
        
        return LLMResponse(
            content: content,
            toolCalls: toolCalls,
            finishReason: choice.finishReason,
            usage: usage
        )
    }
}

