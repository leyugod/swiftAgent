//
//  AgentLoopTests.swift
//  SwiftAgentTests
//
//  AgentLoop 测试
//

import XCTest
@testable import SwiftAgent

final class AgentLoopTests: XCTestCase {
    var mockLLM: MockLLMProvider!
    var agent: Agent!
    
    override func setUp() async throws {
        mockLLM = MockLLMProvider(modelName: "test-model")
    }
    
    override func tearDown() async throws {
        mockLLM = nil
        agent = nil
    }
    
    // MARK: - 循环配置测试
    
    func testMaxIterationsLimit() async throws {
        // 配置最大迭代次数为 3
        let config = AgentLoopConfig(
            maxIterations: 3,
            stopOnFinish: true,
            temperature: 0.7
        )
        
        agent = Agent(
            name: "TestAgent",
            llmProvider: mockLLM,
            systemPrompt: "You are a test agent",
            loopConfig: config
        )
        
        // 配置 Mock 返回工具调用（会导致多次迭代）
        mockLLM.addResponses([
            MockLLMProvider.responseWithToolCall(toolName: "test", arguments: [:]),
            MockLLMProvider.responseWithToolCall(toolName: "test", arguments: [:]),
            MockLLMProvider.responseWithToolCall(toolName: "test", arguments: [:]),
            MockLLMProvider.simpleResponse("Final response")
        ])
        
        // 注册工具
        await agent.registerTool(MockTool(name: "test", description: "Test tool"))
        
        let response = try await agent.run("Test max iterations")
        
        // 验证响应
        XCTAssertNotNil(response)
        
        // 验证调用次数不超过最大迭代次数
        let history = mockLLM.getCallHistory()
        XCTAssertLessThanOrEqual(history.count, 3)
    }
    
    func testTemperatureConfiguration() async throws {
        let customTemp = 0.3
        let config = AgentLoopConfig(
            maxIterations: 10,
            stopOnFinish: true,
            temperature: customTemp
        )
        
        agent = Agent(
            name: "TestAgent",
            llmProvider: mockLLM,
            systemPrompt: "Test",
            loopConfig: config
        )
        
        mockLLM.addResponse(MockLLMProvider.simpleResponse("Response"))
        
        _ = try await agent.run("Test")
        
        // 验证温度参数传递给 LLM
        let history = mockLLM.getCallHistory()
        XCTAssertEqual(history.first?.temperature, customTemp)
    }
    
    // MARK: - 停止条件测试
    
    func testStopOnFinish() async throws {
        let config = AgentLoopConfig(
            maxIterations: 10,
            stopOnFinish: true,
            temperature: 0.7
        )
        
        agent = Agent(
            name: "TestAgent",
            llmProvider: mockLLM,
            systemPrompt: "Test",
            loopConfig: config
        )
        
        // 配置直接返回完成响应
        mockLLM.addResponse(MockLLMProvider.simpleResponse("Task completed"))
        
        let response = try await agent.run("Complete this task")
        
        XCTAssertEqual(response, "Task completed")
        XCTAssertEqual(mockLLM.getCallHistory().count, 1, "Should stop after first completion")
    }
    
    // MARK: - 多次迭代测试
    
    func testMultipleIterationsWithToolCalls() async throws {
        agent = Agent(
            name: "TestAgent",
            llmProvider: mockLLM,
            systemPrompt: "Test"
        )
        
        // 注册工具
        let tool = MockTool(
            name: "search",
            description: "Search tool",
            executeHandler: { _ in "Search result" }
        )
        await agent.registerTool(tool)
        
        // 配置多次工具调用
        mockLLM.addResponses([
            MockLLMProvider.responseWithToolCall(toolName: "search", arguments: ["query": "test"]),
            MockLLMProvider.simpleResponse("Based on the search result, here's the answer")
        ])
        
        let response = try await agent.run("Search for test")
        
        XCTAssertTrue(response.contains("answer"), "Response: \(response)")
        XCTAssertEqual(mockLLM.getCallHistory().count, 2, "Should have two iterations")
    }
    
    // MARK: - 错误恢复测试
    
    func testErrorRecovery() async throws {
        agent = Agent(
            name: "TestAgent",
            llmProvider: mockLLM,
            systemPrompt: "Test"
        )
        
        // 第一次调用失败，第二次成功
        mockLLM.setError(MockLLMError.networkError)
        
        await assertThrowsError(try await agent.run("Test")) { error in
            XCTAssertTrue(error is MockLLMError)
        }
        
        // 重试应该成功
        mockLLM.addResponse(MockLLMProvider.simpleResponse("Success"))
        let response = try await agent.run("Test again")
        XCTAssertEqual(response, "Success")
    }
}

