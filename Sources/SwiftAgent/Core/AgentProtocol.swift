//
//  AgentProtocol.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// Agent 观察结果
public struct Observation: Sendable {
    public let content: String
    public let toolName: String?
    public let metadata: [String: String] // 改为 String 类型以符合 Sendable
    
    public init(content: String, toolName: String? = nil, metadata: [String: String] = [:]) {
        self.content = content
        self.toolName = toolName
        self.metadata = metadata
    }
}

/// Agent 思考过程
public struct Thought: Sendable {
    public let reasoning: String
    public let plan: [String]
    public let nextAction: String?
    
    public init(reasoning: String, plan: [String] = [], nextAction: String? = nil) {
        self.reasoning = reasoning
        self.plan = plan
        self.nextAction = nextAction
    }
}

/// Agent 行动
public struct Action: Sendable {
    public let toolName: String
    public let arguments: [String: String] // 改为 String 类型以符合 Sendable
    public let thought: Thought?
    
    public init(toolName: String, arguments: [String: String] = [:], thought: Thought? = nil) {
        self.toolName = toolName
        self.arguments = arguments
        self.thought = thought
    }
}

/// Agent 协议定义
@preconcurrency
public protocol AgentProtocol: AnyObject, Sendable {
    /// Agent 名称
    var name: String { get }
    
    /// 系统提示词
    var systemPrompt: String { get async }
    
    /// 设置系统提示词
    func setSystemPrompt(_ prompt: String) async
    
    /// 运行 Agent，处理用户输入
    /// - Parameter input: 用户输入
    /// - Returns: Agent 的最终响应
    func run(_ input: String) async throws -> String
    
    /// 运行单次循环（思考-行动-观察）
    /// - Parameter input: 当前输入（用户输入或观察结果）
    /// - Returns: Agent 的响应（思考+行动）
    func think(_ input: String) async throws -> (thought: Thought, action: Action?)
    
    /// 执行行动
    /// - Parameter action: 要执行的行动
    /// - Returns: 观察结果
    func act(_ action: Action) async throws -> Observation
}

