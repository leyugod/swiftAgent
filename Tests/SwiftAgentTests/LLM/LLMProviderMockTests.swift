//
//  LLMProviderMockTests.swift
//  SwiftAgentTests
//
//  LLM Provider Mock 测试
//

import XCTest
@testable import SwiftAgent

final class LLMProviderMockTests: XCTestCase {
    
    // MARK: - MockLLMProvider 测试
    
    func testMockProviderBasicResponse() async throws {
        let mock = MockLLMProvider()
        mock.addResponse(MockLLMProvider.simpleResponse("Test response"))
        
        let response = try await mock.chat(
            messages: [LLMMessage(role: .user, content: "Test")],
            tools: nil,
            temperature: 0.7
        )
        
        XCTAssertEqual(response.content, "Test response")
    }
    
    func testMockProviderMultipleResponses() async throws {
        let mock = MockLLMProvider()
        mock.addResponses([
            MockLLMProvider.simpleResponse("Response 1"),
            MockLLMProvider.simpleResponse("Response 2"),
            MockLLMProvider.simpleResponse("Response 3")
        ])
        
        let r1 = try await mock.chat(messages: makeTestMessages(count: 1), tools: nil, temperature: 0.7)
        let r2 = try await mock.chat(messages: makeTestMessages(count: 1), tools: nil, temperature: 0.7)
        let r3 = try await mock.chat(messages: makeTestMessages(count: 1), tools: nil, temperature: 0.7)
        
        XCTAssertEqual(r1.content, "Response 1")
        XCTAssertEqual(r2.content, "Response 2")
        XCTAssertEqual(r3.content, "Response 3")
    }
    
    func testMockProviderErrorInjection() async throws {
        let mock = MockLLMProvider()
        mock.setError(MockLLMError.networkError)
        
        await assertThrowsError(
            try await mock.chat(messages: makeTestMessages(count: 1), tools: nil, temperature: 0.7)
        ) { error in
            XCTAssertTrue(error is MockLLMError)
        }
    }
    
    func testMockProviderCallHistory() async throws {
        let mock = MockLLMProvider()
        mock.addResponses([
            MockLLMProvider.simpleResponse("R1"),
            MockLLMProvider.simpleResponse("R2")
        ])
        
        _ = try await mock.chat(
            messages: [LLMMessage(role: .user, content: "Message 1")],
            tools: nil,
            temperature: 0.5
        )
        
        _ = try await mock.chat(
            messages: [LLMMessage(role: .user, content: "Message 2")],
            tools: nil,
            temperature: 0.8
        )
        
        let history = mock.getCallHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].temperature, 0.5)
        XCTAssertEqual(history[1].temperature, 0.8)
        XCTAssertEqual(history[0].messages.first?.content, "Message 1")
        XCTAssertEqual(history[1].messages.first?.content, "Message 2")
    }
    
    func testMockProviderToolCallResponse() async throws {
        let mock = MockLLMProvider()
        let response = MockLLMProvider.responseWithToolCall(
            toolName: "calculator",
            arguments: ["expression": "2 + 2"]
        )
        mock.addResponse(response)
        
        let result = try await mock.chat(
            messages: makeTestMessages(count: 1),
            tools: nil,
            temperature: 0.7
        )
        
        XCTAssertNotNil(result.toolCalls)
        XCTAssertEqual(result.toolCalls?.count, 1)
        XCTAssertEqual(result.toolCalls?.first?.function.name, "calculator")
    }
    
    func testMockProviderReset() async throws {
        let mock = MockLLMProvider()
        mock.addResponses([
            MockLLMProvider.simpleResponse("R1"),
            MockLLMProvider.simpleResponse("R2")
        ])
        
        _ = try await mock.chat(messages: makeTestMessages(count: 1), tools: nil, temperature: 0.7)
        
        mock.reset()
        
        // 重置后应该没有预设响应和调用历史
        XCTAssertEqual(mock.getCallHistory().count, 0)
        
        // 应该返回默认响应
        let response = try await mock.chat(messages: makeTestMessages(count: 1), tools: nil, temperature: 0.7)
        XCTAssertEqual(response.content, "Mock response")
    }
    
    func testMockProviderStreamingResponse() async throws {
        let mock = MockLLMProvider()
        mock.addResponse(MockLLMProvider.simpleResponse("Hello World Test"))
        
        var chunks: [String] = []
        let response = try await mock.chatStream(
            messages: makeTestMessages(count: 1),
            tools: nil,
            temperature: 0.7
        ) { chunk in
            chunks.append(chunk)
        }
        
        XCTAssertEqual(response.content, "Hello World Test")
        XCTAssertGreaterThan(chunks.count, 0)
        
        // 合并所有 chunks 应该得到完整响应
        let combined = chunks.joined().trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(combined, "Hello World Test")
    }
    
    // MARK: - LLMMessage 测试
    
    func testLLMMessageCreation() {
        let message = LLMMessage(role: .user, content: "Hello")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNil(message.toolCallId)
    }
    
    func testLLMToolCallCreation() {
        let toolCall = LLMToolCall(
            id: "call_123",
            type: "function",
            function: LLMToolCall.FunctionCall(
                name: "test_tool",
                arguments: "{\"key\":\"value\"}"
            )
        )
        
        XCTAssertEqual(toolCall.id, "call_123")
        XCTAssertEqual(toolCall.type, "function")
        XCTAssertEqual(toolCall.function.name, "test_tool")
        XCTAssertTrue(toolCall.function.arguments.contains("key"))
    }
    
    func testLLMMessageRoles() {
        let systemMsg = LLMMessage(role: .system, content: "System prompt")
        let userMsg = LLMMessage(role: .user, content: "User message")
        let assistantMsg = LLMMessage(role: .assistant, content: "Assistant reply")
        let toolMsg = LLMMessage(role: .tool, content: "Tool result", name: "test_tool", toolCallId: "call_123")
        
        XCTAssertEqual(systemMsg.role, .system)
        XCTAssertEqual(userMsg.role, .user)
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertEqual(toolMsg.role, .tool)
        XCTAssertEqual(toolMsg.name, "test_tool")
        XCTAssertEqual(toolMsg.toolCallId, "call_123")
    }
    
    // MARK: - LLMResponse 测试
    
    func testLLMResponseCreation() {
        let response = LLMResponse(
            content: "Test content",
            toolCalls: nil,
            finishReason: "stop",
            usage: LLMResponse.TokenUsage(
                promptTokens: 10,
                completionTokens: 20,
                totalTokens: 30
            )
        )
        
        XCTAssertEqual(response.content, "Test content")
        XCTAssertNil(response.toolCalls)
        XCTAssertEqual(response.finishReason, "stop")
        XCTAssertEqual(response.usage?.promptTokens, 10)
        XCTAssertEqual(response.usage?.completionTokens, 20)
        XCTAssertEqual(response.usage?.totalTokens, 30)
    }
    
    func testLLMResponseWithToolCalls() {
        let toolCalls = [
            LLMToolCall(
                id: "call_1",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "tool1", arguments: "{\"a\":1}")
            ),
            LLMToolCall(
                id: "call_2",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "tool2", arguments: "{\"b\":2}")
            )
        ]
        
        let response = LLMResponse(
            content: "",
            toolCalls: toolCalls,
            finishReason: "tool_calls",
            usage: nil
        )
        
        XCTAssertEqual(response.toolCalls?.count, 2)
        XCTAssertEqual(response.finishReason, "tool_calls")
    }
    
    // MARK: - LLMToolFunction 测试
    
    func testLLMToolFunctionCreation() {
        let params: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "query": ["type": "string", "description": "Search query"]
            ]),
            "required": AnyCodable(["query"])
        ]
        
        let toolFunc = LLMToolFunction(
            name: "search",
            description: "Search the web",
            parameters: params
        )
        
        XCTAssertEqual(toolFunc.name, "search")
        XCTAssertEqual(toolFunc.description, "Search the web")
        XCTAssertNotNil(toolFunc.parameters["type"])
    }
}

