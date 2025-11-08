//
//  LLMProvider.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// LLM 响应
public struct LLMResponse: Sendable, Codable {
    public let content: String
    public let toolCalls: [LLMToolCall]?
    public let finishReason: String?
    public let usage: TokenUsage?
    
    public struct TokenUsage: Sendable, Codable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int
        
        public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }
    }
    
    public init(
        content: String,
        toolCalls: [LLMToolCall]? = nil,
        finishReason: String? = nil,
        usage: TokenUsage? = nil
    ) {
        self.content = content
        self.toolCalls = toolCalls
        self.finishReason = finishReason
        self.usage = usage
    }
}

/// LLM Provider 协议
/// 统一的 LLM 接口，支持不同的提供商实现
@preconcurrency
public protocol LLMProviderProtocol {
    /// 模型名称
    var modelName: String { get }
    
    /// 调用 LLM
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - tools: 可选的工具定义列表
    ///   - temperature: 温度参数
    /// - Returns: LLM 响应
    func chat(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double
    ) async throws -> LLMResponse
    
    /// 流式调用 LLM
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - tools: 可选的工具定义列表
    ///   - temperature: 温度参数
    ///   - onChunk: 每个数据块的回调
    func chatStream(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double,
        onChunk: @escaping (String) -> Void
    ) async throws -> LLMResponse
}

/// LLM Provider 配置
public struct LLMProviderConfig {
    public let apiKey: String
    public let baseURL: String?
    public let modelName: String
    public let temperature: Double
    public let maxTokens: Int?
    
    public init(
        apiKey: String,
        baseURL: String? = nil,
        modelName: String,
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

