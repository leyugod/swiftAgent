//
//  LLMIntegrationTests.swift
//  SwiftAgentTests
//
//  LLM Provider 集成测试（需要真实 API Key）
//
//  运行集成测试：
//  export SWIFTAGENT_RUN_INTEGRATION_TESTS=1
//  export OPENAI_API_KEY=your_openai_key
//  export ANTHROPIC_API_KEY=your_anthropic_key
//  swift test
//

import XCTest
@testable import SwiftAgent

final class LLMIntegrationTests: XCTestCase {
    
    override func setUp() async throws {
        guard shouldRunIntegrationTests() else {
            throw XCTSkip("Integration tests are disabled. Set SWIFTAGENT_RUN_INTEGRATION_TESTS=1 to enable.")
        }
    }
    
    // MARK: - OpenAI Integration Tests
    
    func testOpenAIBasicChat() async throws {
        guard let apiKey = getOpenAIAPIKey() else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(
            apiKey: apiKey,
            modelName: "gpt-3.5-turbo"
        )
        
        let messages = [
            LLMMessage(role: .user, content: "Say 'Hello, World!' and nothing else.")
        ]
        
        let response = try await provider.chat(
            messages: messages,
            tools: nil,
            temperature: 0.0
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNotNil(response.usage)
        print("OpenAI Response: \(response.content)")
    }
    
    func testOpenAIWithToolCall() async throws {
        guard let apiKey = getOpenAIAPIKey() else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(
            apiKey: apiKey,
            modelName: "gpt-3.5-turbo"
        )
        
        let toolFunction = LLMToolFunction(
            name: "get_weather",
            description: "Get the weather for a location",
            parameters: [
                "type": AnyCodable("object"),
                "properties": AnyCodable([
                    "location": [
                        "type": "string",
                        "description": "The city name"
                    ]
                ]),
                "required": AnyCodable(["location"])
            ]
        )
        
        let messages = [
            LLMMessage(role: .user, content: "What's the weather in Tokyo?")
        ]
        
        let response = try await provider.chat(
            messages: messages,
            tools: [toolFunction],
            temperature: 0.0
        )
        
        // 如果模型决定调用工具，验证工具调用
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            XCTAssertEqual(toolCalls.first?.function.name, "get_weather")
            print("OpenAI Tool Call: \(toolCalls.first?.function.name ?? "none")")
        }
        
        XCTAssertNotNil(response.usage)
    }
    
    func testOpenAIConversationContext() async throws {
        guard let apiKey = getOpenAIAPIKey() else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(
            apiKey: apiKey,
            modelName: "gpt-3.5-turbo"
        )
        
        // 多轮对话
        var messages = [
            LLMMessage(role: .user, content: "My name is Alice.")
        ]
        
        var response = try await provider.chat(
            messages: messages,
            tools: nil,
            temperature: 0.0
        )
        
        messages.append(LLMMessage(role: .assistant, content: response.content))
        messages.append(LLMMessage(role: .user, content: "What is my name?"))
        
        response = try await provider.chat(
            messages: messages,
            tools: nil,
            temperature: 0.0
        )
        
        // 应该记住名字是 Alice
        XCTAssertTrue(
            response.content.lowercased().contains("alice"),
            "Response should contain 'Alice': \(response.content)"
        )
    }
    
    // MARK: - Anthropic Integration Tests
    
    func testAnthropicBasicChat() async throws {
        guard let apiKey = getAnthropicAPIKey() else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = AnthropicProvider(
            apiKey: apiKey,
            modelName: "claude-3-haiku-20240307"
        )
        
        let messages = [
            LLMMessage(role: .user, content: "Say 'Hello, Claude!' and nothing else.")
        ]
        
        let response = try await provider.chat(
            messages: messages,
            tools: nil,
            temperature: 0.0
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNotNil(response.usage)
        print("Anthropic Response: \(response.content)")
    }
    
    func testAnthropicWithToolCall() async throws {
        guard let apiKey = getAnthropicAPIKey() else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = AnthropicProvider(
            apiKey: apiKey,
            modelName: "claude-3-haiku-20240307"
        )
        
        let toolFunction = LLMToolFunction(
            name: "calculate",
            description: "Perform a mathematical calculation",
            parameters: [
                "type": AnyCodable("object"),
                "properties": AnyCodable([
                    "expression": [
                        "type": "string",
                        "description": "The mathematical expression to evaluate"
                    ]
                ]),
                "required": AnyCodable(["expression"])
            ]
        )
        
        let messages = [
            LLMMessage(role: .user, content: "What is 25 * 4?")
        ]
        
        let response = try await provider.chat(
            messages: messages,
            tools: [toolFunction],
            temperature: 0.0
        )
        
        // 如果模型决定调用工具
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            XCTAssertEqual(toolCalls.first?.function.name, "calculate")
            print("Anthropic Tool Call: \(toolCalls.first?.function.name ?? "none")")
        }
        
        XCTAssertNotNil(response.usage)
    }
    
    // MARK: - Error Handling Tests
    
    func testOpenAIInvalidAPIKey() async throws {
        let provider = OpenAIProvider(
            apiKey: "invalid_key",
            modelName: "gpt-3.5-turbo"
        )
        
        let messages = [
            LLMMessage(role: .user, content: "Test")
        ]
        
        await assertThrowsError(
            try await provider.chat(messages: messages, tools: nil, temperature: 0.7)
        ) { error in
            // 应该抛出认证错误
            print("Expected error: \(error)")
        }
    }
    
    func testAnthropicInvalidAPIKey() async throws {
        let provider = AnthropicProvider(
            apiKey: "invalid_key",
            modelName: "claude-3-haiku-20240307"
        )
        
        let messages = [
            LLMMessage(role: .user, content: "Test")
        ]
        
        await assertThrowsError(
            try await provider.chat(messages: messages, tools: nil, temperature: 0.7)
        ) { error in
            // 应该抛出认证错误
            print("Expected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testOpenAIResponseTime() async throws {
        guard let apiKey = getOpenAIAPIKey() else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(
            apiKey: apiKey,
            modelName: "gpt-3.5-turbo"
        )
        
        let messages = [
            LLMMessage(role: .user, content: "Say hello")
        ]
        
        let startTime = Date()
        
        _ = try await provider.chat(
            messages: messages,
            tools: nil,
            temperature: 0.0
        )
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("OpenAI Response time: \(elapsed)s")
        
        // 响应时间应该在合理范围内（30秒内）
        XCTAssertLessThan(elapsed, 30.0)
    }
}

