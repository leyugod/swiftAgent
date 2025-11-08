//
//  DeepSeekIntegrationTests.swift
//  SwiftAgentTests
//
//  DeepSeek API 集成测试
//

import XCTest
@testable import SwiftAgent

final class DeepSeekIntegrationTests: XCTestCase {
    var provider: DeepSeekProvider!
    var apiKey: String!
    
    override func setUp() async throws {
        // 从环境变量获取 API Key
        apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]
        
        // 如果没有 API Key，跳过测试
        guard apiKey != nil && !apiKey.isEmpty else {
            throw XCTSkip("DEEPSEEK_API_KEY environment variable not set")
        }
        
        provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    }
    
    // MARK: - 基础对话测试
    
    func testBasicChat() async throws {
        // Given
        let messages = [
            LLMMessage(role: .user, content: "你好，请用一句话介绍你自己。")
        ]
        
        // When
        let response = try await provider.chat(messages: messages, tools: nil, temperature: 0.7)
        
        // Then
        XCTAssertFalse(response.content.isEmpty, "响应内容不应为空")
        XCTAssertNotNil(response.usage, "应该返回token使用统计")
        print("✅ 基础对话测试通过")
        print("📝 响应: \(response.content)")
        print("📊 Token使用: \(response.usage?.totalTokens ?? 0)")
    }
    
    func testMultiTurnConversation() async throws {
        // Given
        let messages = [
            LLMMessage(role: .user, content: "我想了解Swift编程语言"),
            LLMMessage(role: .assistant, content: "Swift是Apple开发的现代编程语言，用于iOS、macOS等平台开发。"),
            LLMMessage(role: .user, content: "它有什么特点？请列举3点。")
        ]
        
        // When
        let response = try await provider.chat(messages: messages, tools: nil, temperature: 0.7)
        
        // Then
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertTrue(response.content.contains("1") || response.content.contains("一"), "应该包含列举内容")
        print("✅ 多轮对话测试通过")
        print("📝 响应: \(response.content)")
    }
    
    // MARK: - 流式响应测试
    
    func testStreamingChat() async throws {
        // Given
        let messages = [
            LLMMessage(role: .user, content: "请写一个简短的故事（50字以内）")
        ]
        
        var receivedChunks: [String] = []
        var fullContent = ""
        
        // When
        let response = try await provider.chatStream(
            messages: messages,
            tools: nil,
            temperature: 0.7
        ) { chunk in
            receivedChunks.append(chunk)
            fullContent += chunk
        }
        
        // Then
        XCTAssertFalse(receivedChunks.isEmpty, "应该收到流式数据块")
        XCTAssertFalse(fullContent.isEmpty, "流式内容不应为空")
        XCTAssertEqual(response.content, fullContent, "最终响应应该与流式内容一致")
        print("✅ 流式响应测试通过")
        print("📊 收到 \(receivedChunks.count) 个数据块")
        print("📝 完整内容: \(fullContent)")
    }
    
    func testStreamingWithAgent() async throws {
        // Given
        let agent = Agent(name: "StreamingAgent", llmProvider: provider, systemPrompt: "你是一个helpful的AI助手")
        var chunks: [String] = []
        
        // When
        let callback = StreamingCallback(
            onContent: { content in
                chunks.append(content)
                print(content, terminator: "")
            },
            onToolCall: { toolCall in
                print("\n🔧 工具调用: \(toolCall.name ?? "unknown")")
            },
            onCompletion: { response in
                print("\n✅ 完成: \(response.finishReason ?? "unknown")")
            },
            onError: { error in
                print("\n❌ 错误: \(error.localizedDescription)")
            }
        )
        
        let response = try await agent.streamRunWithCallback(
            input: "请说一句鼓励的话",
            callback: callback
        )
        
        // Then
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertFalse(response.content.isEmpty)
        print("\n✅ Agent流式测试通过")
    }
    
    // MARK: - 工具调用测试
    
    func testToolCalling() async throws {
        // Given
        let tools = [
            LLMToolFunction(
                name: "get_weather",
                description: "获取指定城市的天气信息",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "city": [
                            "type": "string",
                            "description": "城市名称，如：北京、上海"
                        ]
                    ]),
                    "required": AnyCodable(["city"])
                ]
            )
        ]
        
        let messages = [
            LLMMessage(role: .user, content: "今天北京的天气怎么样？")
        ]
        
        // When
        let response = try await provider.chat(messages: messages, tools: tools, temperature: 0.7)
        
        // Then
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            XCTAssertEqual(toolCalls.first?.function.name, "get_weather")
            print("✅ 工具调用测试通过")
            print("🔧 调用工具: \(toolCalls.first?.function.name ?? "")")
            print("📝 参数: \(toolCalls.first?.function.arguments ?? "")")
        } else {
            print("⚠️ 模型没有调用工具，可能直接回答了问题")
            print("📝 响应: \(response.content)")
        }
    }
    
    // MARK: - Agent 完整测试
    
    func testAgentWithDeepSeek() async throws {
        // Given
        let agent = Agent(name: "DeepSeekAgent", llmProvider: provider, systemPrompt: "你是一个helpful的AI助手")
        await agent.registerBasicTools()
        
        // When
        let response = try await agent.run("你好，请告诉我现在的时间")
        
        // Then
        XCTAssertFalse(response.isEmpty)
        print("✅ Agent完整测试通过")
        print("📝 响应: \(response)")
    }
    
    // MARK: - 不同模型测试
    
    func testChatModel() async throws {
        // Given
        let chatProvider = DeepSeekProvider(apiKey: apiKey, model: .chat)
        let messages = [LLMMessage(role: .user, content: "你是什么模型？")]
        
        // When
        let response = try await chatProvider.chat(messages: messages, tools: nil, temperature: 0.7)
        
        // Then
        XCTAssertFalse(response.content.isEmpty)
        print("✅ Chat模型测试通过")
        print("📝 响应: \(response.content)")
    }
    
    func testCoderModel() async throws {
        // Given
        let coderProvider = DeepSeekProvider(apiKey: apiKey, model: .coder)
        let messages = [LLMMessage(role: .user, content: "写一个Swift函数计算斐波那契数列")]
        
        // When
        let response = try await coderProvider.chat(messages: messages, tools: nil, temperature: 0.7)
        
        // Then
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertTrue(response.content.contains("func") || response.content.contains("swift"), "应该包含代码")
        print("✅ Coder模型测试通过")
        print("📝 响应: \(response.content)")
    }
    
    // MARK: - 错误处理测试
    
    func testInvalidAPIKey() async throws {
        // Given
        let invalidProvider = DeepSeekProvider(apiKey: "invalid_key", model: .chat)
        let messages = [LLMMessage(role: .user, content: "test")]
        
        // When/Then
        do {
            _ = try await invalidProvider.chat(messages: messages, tools: nil, temperature: 0.7)
            XCTFail("应该抛出错误")
        } catch {
            print("✅ 错误处理测试通过: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 性能测试
    
    func testResponseTime() async throws {
        // Given
        let messages = [LLMMessage(role: .user, content: "你好")]
        let startTime = Date()
        
        // When
        let response = try await provider.chat(messages: messages, tools: nil, temperature: 0.7)
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertFalse(response.content.isEmpty)
        print("✅ 性能测试通过")
        print("⏱️ 响应时间: \(String(format: "%.2f", duration))秒")
        print("📊 Token使用: \(response.usage?.totalTokens ?? 0)")
    }
}

