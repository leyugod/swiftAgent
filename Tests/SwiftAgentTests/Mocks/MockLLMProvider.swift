//
//  MockLLMProvider.swift
//  SwiftAgentTests
//
//  Mock LLM Provider 用于单元测试
//

import Foundation
@testable import SwiftAgent

/// Mock LLM Provider 用于测试
/// 支持预设响应、工具调用模拟、错误注入
public final class MockLLMProvider: @unchecked Sendable, LLMProviderProtocol {
    public let modelName: String
    
    // 预设响应
    private var responses: [LLMResponse] = []
    private var currentResponseIndex = 0
    private let queue = DispatchQueue(label: "com.swiftagent.mock")
    
    // 错误注入
    private var shouldThrowError: Error?
    
    // 调用记录
    private(set) var callHistory: [CallRecord] = []
    
    public struct CallRecord {
        public let messages: [LLMMessage]
        public let tools: [LLMToolFunction]?
        public let temperature: Double
        public let timestamp: Date
    }
    
    public init(modelName: String = "mock-model") {
        self.modelName = modelName
    }
    
    // MARK: - 配置方法
    
    /// 添加预设响应
    public func addResponse(_ response: LLMResponse) {
        queue.sync {
            responses.append(response)
        }
    }
    
    /// 添加多个预设响应
    public func addResponses(_ responses: [LLMResponse]) {
        queue.sync {
            self.responses.append(contentsOf: responses)
        }
    }
    
    /// 设置错误注入
    public func setError(_ error: Error) {
        queue.sync {
            self.shouldThrowError = error
        }
    }
    
    /// 清除所有配置
    public func reset() {
        queue.sync {
            responses.removeAll()
            currentResponseIndex = 0
            shouldThrowError = nil
            callHistory.removeAll()
        }
    }
    
    /// 获取调用历史
    public func getCallHistory() -> [CallRecord] {
        queue.sync {
            return callHistory
        }
    }
    
    // MARK: - LLMProviderProtocol
    
    public func chat(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double
    ) async throws -> LLMResponse {
        return try queue.sync {
            // 记录调用
            let record = CallRecord(
                messages: messages,
                tools: tools,
                temperature: temperature,
                timestamp: Date()
            )
            callHistory.append(record)
            
            // 检查是否应该抛出错误
            if let error = shouldThrowError {
                shouldThrowError = nil // 只抛出一次
                throw error
            }
            
            // 返回预设响应
            guard currentResponseIndex < responses.count else {
                // 如果没有预设响应，返回默认响应
                return LLMResponse(
                    content: "Mock response",
                    toolCalls: nil,
                    finishReason: "stop",
                    usage: LLMResponse.TokenUsage(
                        promptTokens: 10,
                        completionTokens: 5,
                        totalTokens: 15
                    )
                )
            }
            
            let response = responses[currentResponseIndex]
            currentResponseIndex += 1
            return response
        }
    }
    
    public func chatStream(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?,
        temperature: Double,
        onChunk: @escaping (String) -> Void
    ) async throws -> LLMResponse {
        // 简单实现：分块发送完整响应
        let response = try await chat(messages: messages, tools: tools, temperature: temperature)
        
        // 模拟流式输出
        let words = response.content.split(separator: " ")
        for word in words {
            onChunk(String(word) + " ")
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        return response
    }
}

// MARK: - 便捷构造器

extension MockLLMProvider {
    /// 创建简单文本响应
    public static func simpleResponse(_ content: String) -> LLMResponse {
        return LLMResponse(
            content: content,
            toolCalls: nil,
            finishReason: "stop",
            usage: LLMResponse.TokenUsage(
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15
            )
        )
    }
    
    /// 创建包含工具调用的响应
    public static func responseWithToolCall(
        toolName: String,
        arguments: [String: Any]
    ) -> LLMResponse {
        // 将参数转换为 JSON 字符串
        let argumentsData = try? JSONSerialization.data(withJSONObject: arguments)
        let argumentsString = argumentsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        let toolCall = LLMToolCall(
            id: "call_\(UUID().uuidString)",
            type: "function",
            function: LLMToolCall.FunctionCall(
                name: toolName,
                arguments: argumentsString
            )
        )
        
        return LLMResponse(
            content: "",
            toolCalls: [toolCall],
            finishReason: "tool_calls",
            usage: LLMResponse.TokenUsage(
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15
            )
        )
    }
}

// MARK: - Mock 错误类型

public enum MockLLMError: Error {
    case networkError
    case apiError(String)
    case timeout
    case rateLimitExceeded
}

