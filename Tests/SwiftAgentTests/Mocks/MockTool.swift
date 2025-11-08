//
//  MockTool.swift
//  SwiftAgentTests
//
//  Mock Tool 用于测试
//

import Foundation
@testable import SwiftAgent

/// Mock Tool 用于测试
public struct MockTool: ToolProtocol {
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]
    
    private let executeHandler: ([String: Any]) async throws -> String
    
    public init(
        name: String,
        description: String,
        parameters: [ToolParameter] = [],
        executeHandler: @escaping ([String: Any]) async throws -> String = { _ in "Mock tool executed" }
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.executeHandler = executeHandler
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        return try await executeHandler(arguments)
    }
}

// MARK: - 便捷构造器

extension MockTool {
    /// 创建简单的 Echo Tool
    public static func echoTool() -> MockTool {
        return MockTool(
            name: "echo",
            description: "回显输入的文本",
            parameters: [
                ToolParameter(
                    name: "text",
                    type: "string",
                    description: "要回显的文本",
                    required: true
                )
            ],
            executeHandler: { args in
                guard let text = args["text"] as? String else {
                    throw ToolError.invalidArguments("Missing 'text' parameter")
                }
                return "Echo: \(text)"
            }
        )
    }
    
    /// 创建延迟执行的 Tool
    public static func delayTool(delaySeconds: Double = 1.0) -> MockTool {
        return MockTool(
            name: "delay",
            description: "延迟执行",
            parameters: [],
            executeHandler: { _ in
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                return "Delayed for \(delaySeconds) seconds"
            }
        )
    }
    
    /// 创建会抛出错误的 Tool
    public static func errorTool(error: Error = ToolError.executionFailed("Mock error")) -> MockTool {
        return MockTool(
            name: "error",
            description: "抛出错误的工具",
            parameters: [],
            executeHandler: { _ in
                throw error
            }
        )
    }
}

