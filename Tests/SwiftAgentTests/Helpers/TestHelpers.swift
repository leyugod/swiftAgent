//
//  TestHelpers.swift
//  SwiftAgentTests
//
//  测试辅助工具
//

import Foundation
import XCTest
@testable import SwiftAgent

// MARK: - 异步测试辅助

/// 等待异步条件满足
public func waitForCondition(
    timeout: TimeInterval = 5.0,
    pollingInterval: TimeInterval = 0.1,
    condition: @escaping () async -> Bool
) async throws {
    let startTime = Date()
    
    while Date().timeIntervalSince(startTime) < timeout {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
    }
    
    throw TimeoutError.conditionNotMet
}

public enum TimeoutError: Error {
    case conditionNotMet
}

// MARK: - 测试数据生成器

/// 生成测试用的 LLM 消息
public func makeTestMessages(count: Int = 3) -> [LLMMessage] {
    var messages: [LLMMessage] = []
    
    for i in 0..<count {
        if i % 2 == 0 {
            messages.append(LLMMessage(role: .user, content: "User message \(i)"))
        } else {
            messages.append(LLMMessage(role: .assistant, content: "Assistant message \(i)"))
        }
    }
    
    return messages
}

/// 生成测试用的记忆条目
public func makeTestMemoryEntries(count: Int = 5) -> [MemoryEntry] {
    return (0..<count).map { i in
        MemoryEntry(
            content: "Memory content \(i)",
            metadata: ["index": "\(i)"],
            embedding: generateRandomEmbedding(dimension: 10)
        )
    }
}

/// 生成随机向量
public func generateRandomEmbedding(dimension: Int) -> [Double] {
    return (0..<dimension).map { _ in Double.random(in: -1.0...1.0) }
}

// MARK: - XCTest 扩展

extension XCTestCase {
    /// 断言异步抛出错误
    public func assertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
    
    /// 断言异步不抛出错误
    public func assertNoThrow<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> T? {
        do {
            return try await expression()
        } catch {
            XCTFail("Unexpected error thrown: \(error)", file: file, line: line)
            return nil
        }
    }
}

// MARK: - 环境变量工具

/// 获取测试环境变量
public func getTestEnvironmentVariable(_ key: String) -> String? {
    return ProcessInfo.processInfo.environment[key]
}

/// 检查是否应该运行集成测试
public func shouldRunIntegrationTests() -> Bool {
    return getTestEnvironmentVariable("SWIFTAGENT_RUN_INTEGRATION_TESTS") == "1"
}

/// 获取 OpenAI API Key（用于集成测试）
public func getOpenAIAPIKey() -> String? {
    return getTestEnvironmentVariable("OPENAI_API_KEY")
}

/// 获取 Anthropic API Key（用于集成测试）
public func getAnthropicAPIKey() -> String? {
    return getTestEnvironmentVariable("ANTHROPIC_API_KEY")
}

