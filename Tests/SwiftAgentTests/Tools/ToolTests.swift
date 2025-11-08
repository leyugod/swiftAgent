//
//  ToolTests.swift
//  SwiftAgentTests
//
//  Tool 系统测试
//

import XCTest
@testable import SwiftAgent

final class ToolTests: XCTestCase {
    
    // MARK: - Tool Registry 测试
    
    func testToolRegistration() async throws {
        let registry = ToolRegistry()
        let tool = MockTool.echoTool()
        
        await registry.register(tool)
        
        let retrievedTool = await registry.get("echo")
        XCTAssertNotNil(retrievedTool)
        XCTAssertEqual(retrievedTool?.name, "echo")
    }
    
    func testMultipleToolRegistration() async throws {
        let registry = ToolRegistry()
        let tools: [ToolProtocol] = [
            MockTool(name: "tool1", description: "Tool 1"),
            MockTool(name: "tool2", description: "Tool 2"),
            MockTool(name: "tool3", description: "Tool 3")
        ]
        
        await registry.register(tools)
        
        let allTools = await registry.getAll()
        XCTAssertEqual(allTools.count, 3)
        
        let tool2 = await registry.get("tool2")
        XCTAssertNotNil(tool2)
        XCTAssertEqual(tool2?.description, "Tool 2")
    }
    
    func testToolNotFound() async throws {
        let registry = ToolRegistry()
        
        let tool = await registry.get("nonexistent")
        XCTAssertNil(tool)
    }
    
    func testDuplicateToolRegistration() async throws {
        let registry = ToolRegistry()
        let tool1 = MockTool(name: "duplicate", description: "First")
        let tool2 = MockTool(name: "duplicate", description: "Second")
        
        await registry.register(tool1)
        await registry.register(tool2)
        
        // 应该覆盖第一个工具
        let retrieved = await registry.get("duplicate")
        XCTAssertEqual(retrieved?.description, "Second")
    }
    
    func testUnregisterTool() async throws {
        let registry = ToolRegistry()
        let tool = MockTool(name: "temporary", description: "Temp tool")
        
        await registry.register(tool)
        let retrieved1 = await registry.get("temporary")
        XCTAssertNotNil(retrieved1)
        
        await registry.remove("temporary")
        let retrieved2 = await registry.get("temporary")
        XCTAssertNil(retrieved2)
    }
    
    func testGetToolFunctions() async throws {
        let registry = ToolRegistry()
        let tool = MockTool(
            name: "calculator",
            description: "Performs calculations",
            parameters: [
                ToolParameter(name: "expression", type: "string", description: "Math expression", required: true)
            ]
        )
        
        await registry.register(tool)
        
        let functions = await registry.toLLMTools()
        XCTAssertEqual(functions.count, 1)
        XCTAssertEqual(functions[0].name, "calculator")
        XCTAssertEqual(functions[0].description, "Performs calculations")
        XCTAssertNotNil(functions[0].parameters["properties"])
    }
    
    // MARK: - Tool Executor 测试
    
    func testToolExecution() async throws {
        let registry = ToolRegistry()
        let executor = ToolExecutor(registry: registry)
        
        let tool = MockTool.echoTool()
        await registry.register(tool)
        
        let toolCall = LLMToolCall(
            id: "call_test",
            type: "function",
            function: LLMToolCall.FunctionCall(
                name: "echo",
                arguments: "{\"text\":\"Hello\"}"
            )
        )
        
        let result = try await executor.execute(toolCall)
        
        XCTAssertTrue(result.content.contains("Hello"), "Result: \(result.content)")
    }
    
    func testToolExecutionNotFound() async throws {
        let registry = ToolRegistry()
        let executor = ToolExecutor(registry: registry)
        
        let toolCall = LLMToolCall(
            id: "call_test",
            type: "function",
            function: LLMToolCall.FunctionCall(
                name: "nonexistent",
                arguments: "{}"
            )
        )
        
        await assertThrowsError(
            try await executor.execute(toolCall)
        ) { error in
            guard case ToolError.toolNotFound = error else {
                XCTFail("Expected toolNotFound error, got: \(error)")
                return
            }
        }
    }
    
    func testToolExecutionWithError() async throws {
        let registry = ToolRegistry()
        let executor = ToolExecutor(registry: registry)
        
        let errorTool = MockTool.errorTool()
        await registry.register(errorTool)
        
        let toolCall = LLMToolCall(
            id: "call_test",
            type: "function",
            function: LLMToolCall.FunctionCall(
                name: "error",
                arguments: "{}"
            )
        )
        
        await assertThrowsError(
            try await executor.execute(toolCall)
        ) { error in
            guard case ToolError.executionFailed = error else {
                XCTFail("Expected executionFailed error, got: \(error)")
                return
            }
        }
    }
    
    func testBatchToolExecution() async throws {
        let registry = ToolRegistry()
        let executor = ToolExecutor(registry: registry)
        
        let echoTool = MockTool.echoTool()
        await registry.register(echoTool)
        
        let toolCalls = [
            LLMToolCall(
                id: "call1",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "echo", arguments: "{\"text\":\"First\"}")
            ),
            LLMToolCall(
                id: "call2",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "echo", arguments: "{\"text\":\"Second\"}")
            ),
            LLMToolCall(
                id: "call3",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "echo", arguments: "{\"text\":\"Third\"}")
            )
        ]
        
        let results = try await executor.execute(toolCalls)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].content.contains("First"), "Result: \(results[0].content)")
        XCTAssertTrue(results[1].content.contains("Second"), "Result: \(results[1].content)")
        XCTAssertTrue(results[2].content.contains("Third"), "Result: \(results[2].content)")
    }
    
    func testBatchExecutionWithPartialFailure() async throws {
        let registry = ToolRegistry()
        let executor = ToolExecutor(registry: registry)
        
        await registry.register(MockTool.echoTool())
        await registry.register(MockTool.errorTool())
        
        let toolCalls = [
            LLMToolCall(
                id: "call1",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "echo", arguments: "{\"text\":\"Success\"}")
            ),
            LLMToolCall(
                id: "call2",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "error", arguments: "{}")
            ),
            LLMToolCall(
                id: "call3",
                type: "function",
                function: LLMToolCall.FunctionCall(name: "echo", arguments: "{\"text\":\"Also Success\"}")
            )
        ]
        
        // 批量执行时，一个错误应该导致整个批次失败
        do {
            _ = try await executor.execute(toolCalls)
            XCTFail("Should have thrown error")
        } catch {
            // 预期会抛出错误
            XCTAssertTrue(error is ToolError)
        }
    }
    
    // MARK: - Tool 参数验证测试
    
    func testParameterValidation() async throws {
        let tool = MockTool(
            name: "test",
            description: "Test tool",
            parameters: [
                ToolParameter(name: "required_param", type: "string", description: "Required", required: true),
                ToolParameter(name: "optional_param", type: "string", description: "Optional", required: false)
            ],
            executeHandler: { args in
                guard args["required_param"] != nil else {
                    throw ToolError.missingRequiredParameter("required_param")
                }
                return "Success"
            }
        )
        
        let registry = ToolRegistry()
        let executor = ToolExecutor(registry: registry)
        await registry.register(tool)
        
        // 缺少必需参数应该失败
        let invalidToolCall = LLMToolCall(
            id: "call_test",
            type: "function",
            function: LLMToolCall.FunctionCall(name: "test", arguments: "{}")
        )
        
        await assertThrowsError(
            try await executor.execute(invalidToolCall)
        ) { error in
            guard case ToolError.missingRequiredParameter = error else {
                XCTFail("Expected missingRequiredParameter error, got: \(error)")
                return
            }
        }
        
        // 提供必需参数应该成功
        let validToolCall = LLMToolCall(
            id: "call_test",
            type: "function",
            function: LLMToolCall.FunctionCall(name: "test", arguments: "{\"required_param\":\"value\"}")
        )
        
        let result = try await executor.execute(validToolCall)
        XCTAssertTrue(result.content.contains("Success"), "Result: \(result.content)")
    }
    
    // MARK: - 并发测试
    
    func testConcurrentToolExecution() async throws {
        let registry = ToolRegistry()
        let executor = ToolExecutor(registry: registry)
        
        let delayTool = MockTool.delayTool(delaySeconds: 0.1)
        await registry.register(delayTool)
        
        // 并发执行多个工具
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        let toolCall = LLMToolCall(
                            id: "call_\(i)",
                            type: "function",
                            function: LLMToolCall.FunctionCall(name: "delay", arguments: "{}")
                        )
                        let result = try await executor.execute(toolCall)
                        XCTAssertTrue(result.content.contains("Delayed"), "Execution \(i) failed: \(result.content)")
                    } catch {
                        XCTFail("Concurrent execution \(i) failed: \(error)")
                    }
                }
            }
        }
    }
}

