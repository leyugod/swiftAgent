//
//  AgentTests.swift
//  SwiftAgentTests
//
//  Agent 核心功能测试
//

import XCTest
@testable import SwiftAgent

final class AgentTests: XCTestCase {
    var mockLLM: MockLLMProvider!
    var agent: Agent!
    
    override func setUp() async throws {
        mockLLM = MockLLMProvider(modelName: "test-model")
        agent = Agent(
            name: "TestAgent",
            llmProvider: mockLLM,
            systemPrompt: "You are a test agent"
        )
    }
    
    override func tearDown() async throws {
        mockLLM = nil
        agent = nil
    }
    
    // MARK: - 初始化测试
    
    func testAgentInitialization() async throws {
        let name = await agent.name
        XCTAssertEqual(name, "TestAgent")
        let systemPrompt = await agent.systemPrompt
        XCTAssertEqual(systemPrompt, "You are a test agent")
    }
    
    func testAgentSetSystemPrompt() async throws {
        await agent.setSystemPrompt("New system prompt")
        let systemPrompt = await agent.systemPrompt
        XCTAssertEqual(systemPrompt, "New system prompt")
    }
    
    // MARK: - 基本对话测试
    
    func testBasicConversation() async throws {
        // 配置 Mock 响应
        mockLLM.addResponse(MockLLMProvider.simpleResponse("Hello! How can I help you?"))
        
        // 运行 Agent
        let response = try await agent.run("Hello")
        
        // 验证响应
        XCTAssertEqual(response, "Hello! How can I help you?")
        
        // 验证调用历史
        let history = mockLLM.getCallHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertTrue(history[0].messages.contains { $0.content == "Hello" })
    }
    
    func testMultipleConversationTurns() async throws {
        // 配置多轮对话响应
        mockLLM.addResponses([
            MockLLMProvider.simpleResponse("I'm fine, thank you!"),
            MockLLMProvider.simpleResponse("The weather is nice today."),
            MockLLMProvider.simpleResponse("Goodbye!")
        ])
        
        // 第一轮
        let response1 = try await agent.run("How are you?")
        XCTAssertEqual(response1, "I'm fine, thank you!")
        
        // 第二轮
        let response2 = try await agent.run("What's the weather?")
        XCTAssertEqual(response2, "The weather is nice today.")
        
        // 第三轮
        let response3 = try await agent.run("Goodbye")
        XCTAssertEqual(response3, "Goodbye!")
        
        // 验证调用历史
        let history = mockLLM.getCallHistory()
        XCTAssertEqual(history.count, 3)
    }
    
    // MARK: - 工具注册和调用测试
    
    func testToolRegistration() async throws {
        let echoTool = MockTool.echoTool()
        
        // 注册工具
        await agent.registerTool(echoTool)
        
        // 验证工具已注册（通过尝试使用工具）
        mockLLM.addResponse(
            MockLLMProvider.responseWithToolCall(
                toolName: "echo",
                arguments: ["text": "Hello World"]
            )
        )
        mockLLM.addResponse(MockLLMProvider.simpleResponse("I echoed: Hello World"))
        
        let response = try await agent.run("Echo hello world")
        XCTAssertTrue(response.contains("echo") || response.contains("Hello World"), "Response: \(response)")
    }
    
    func testMultipleToolRegistration() async throws {
        let tools: [ToolProtocol] = [
            MockTool.echoTool(),
            MockTool(name: "test1", description: "Test tool 1"),
            MockTool(name: "test2", description: "Test tool 2")
        ]
        
        // 批量注册工具
        await agent.registerTools(tools)
        
        // 验证工具可用（通过调用历史中的工具定义）
        mockLLM.addResponse(MockLLMProvider.simpleResponse("Tools registered"))
        _ = try await agent.run("List tools")
        
        let history = mockLLM.getCallHistory()
        XCTAssertGreaterThan(history.count, 0)
        
        // 检查工具定义是否传递给 LLM
        let lastCall = history.last!
        XCTAssertNotNil(lastCall.tools)
        XCTAssertEqual(lastCall.tools?.count, 3)
    }
    
    func testToolExecution() async throws {
        let echoTool = MockTool.echoTool()
        await agent.registerTool(echoTool)
        
        // 配置工具调用响应
        mockLLM.addResponse(
            MockLLMProvider.responseWithToolCall(
                toolName: "echo",
                arguments: ["text": "Test Message"]
            )
        )
        mockLLM.addResponse(MockLLMProvider.simpleResponse("The echo result was: Echo: Test Message"))
        
        let response = try await agent.run("Please echo 'Test Message'")
        
        // 验证工具被执行并结果被返回
        XCTAssertTrue(
            response.contains("Test Message") || response.contains("echo"),
            "Response should contain echo result: \(response)"
        )
        
        // 验证有两次 LLM 调用（一次请求工具，一次处理结果）
        XCTAssertEqual(mockLLM.getCallHistory().count, 2)
    }
    
    // MARK: - 错误处理测试
    
    func testLLMErrorHandling() async throws {
        // 配置 Mock 抛出错误
        mockLLM.setError(MockLLMError.networkError)
        
        // 验证错误被正确传播
        await assertThrowsError(try await agent.run("Test")) { error in
            XCTAssertTrue(error is MockLLMError)
        }
    }
    
    func testToolExecutionError() async throws {
        // 注册会抛出错误的工具
        let errorTool = MockTool.errorTool()
        await agent.registerTool(errorTool)
        
        // 配置调用错误工具
        mockLLM.addResponse(
            MockLLMProvider.responseWithToolCall(
                toolName: "error",
                arguments: [:]
            )
        )
        mockLLM.addResponse(MockLLMProvider.simpleResponse("Tool execution failed"))
        
        // Agent 应该处理工具错误并继续
        let response = try await agent.run("Use error tool")
        XCTAssertNotNil(response)
    }
    
    // MARK: - 消息历史测试
    
    func testMessageHistoryMaintained() async throws {
        mockLLM.addResponses([
            MockLLMProvider.simpleResponse("Response 1"),
            MockLLMProvider.simpleResponse("Response 2"),
            MockLLMProvider.simpleResponse("Response 3")
        ])
        
        _ = try await agent.run("Message 1")
        _ = try await agent.run("Message 2")
        _ = try await agent.run("Message 3")
        
        // 验证消息历史累积
        let history = mockLLM.getCallHistory()
        XCTAssertEqual(history.count, 3)
        
        // 第三次调用应该包含之前的消息
        let lastCall = history[2]
        XCTAssertGreaterThan(lastCall.messages.count, 1, "Should include message history")
    }
    
    func testClearMessageHistory() async throws {
        mockLLM.addResponse(MockLLMProvider.simpleResponse("First response"))
        _ = try await agent.run("First message")
        
        // 清除历史
        await agent.clearHistory()
        
        mockLLM.addResponse(MockLLMProvider.simpleResponse("Second response"))
        _ = try await agent.run("Second message")
        
        // 验证历史已清除（第二次调用应该只有新消息）
        let history = mockLLM.getCallHistory()
        XCTAssertEqual(history.count, 2)
        // 第二次调用的消息应该较少（没有历史）
        XCTAssertLessThan(history[1].messages.count, history[0].messages.count + 2)
    }
    
    // MARK: - 并发安全测试
    
    func testConcurrentAccess() async throws {
        mockLLM.addResponses(
            Array(repeating: MockLLMProvider.simpleResponse("Concurrent response"), count: 10)
        )
        
        // 并发执行多个请求
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        _ = try await self.agent.run("Concurrent message \(i)")
                    } catch {
                        XCTFail("Concurrent access failed: \(error)")
                    }
                }
            }
        }
        
        // 验证所有请求都完成
        let history = mockLLM.getCallHistory()
        XCTAssertEqual(history.count, 5)
    }
}

