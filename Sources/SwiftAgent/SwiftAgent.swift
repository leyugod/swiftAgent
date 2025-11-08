//
//  SwiftAgent.swift
//  SwiftAgent Framework
//
//  Created by SwiftAgent Framework
//  Based on Hello-Agents教程核心思想
//

import Foundation

// MARK: - Framework Public API

/// SwiftAgent Framework
/// 基于 Hello-Agents 教程的 AI Native Agent 开发框架
///
/// 主要特性：
/// - 完整的 Agent Loop（感知-思考-行动-观察）
/// - 多 LLM 提供商支持（OpenAI、Anthropic）
/// - 灵活的工具系统
/// - 记忆与检索（RAG）
/// - 上下文工程
/// - 多智能体协作
/// - 通信协议（MCP、A2A、ANP）
/// - 评估系统
///
/// 快速开始：
/// ```swift
/// // 1. 创建 LLM Provider
/// let llm = OpenAIProvider(
///     apiKey: "your-api-key",
///     modelName: "gpt-4o-mini"
/// )
///
/// // 2. 创建 Agent
/// let agent = Agent(
///     name: "MyAgent",
///     llmProvider: llm,
///     systemPrompt: "你是一个智能助手"
/// )
///
/// // 3. 注册工具（可选）
/// let weatherTool = WeatherTool()
/// await agent.registerTool(weatherTool)
///
/// // 4. 运行 Agent
/// let response = try await agent.run("今天天气怎么样？")
/// print(response)
/// ```
public struct SwiftAgent {
    /// 框架版本
    public static let version = "1.0.0"
    
    /// 框架名称
    public static let name = "SwiftAgent"
    
    /// 框架描述
    public static let description = "基于 Hello-Agents 教程的 AI Native Agent 开发框架"
    
    /// 支持的平台
    public static let platforms = ["iOS 15.0+", "macOS 12.0+"]
    
    /// 获取框架信息
    public static func getInfo() -> String {
        """
        \(name) v\(version)
        \(description)
        
        支持平台: \(platforms.joined(separator: ", "))
        
        主要模块:
        - Core: Agent, AgentLoop, AgentProtocol
        - LLM: OpenAIProvider, AnthropicProvider
        - Tools: Tool, ToolRegistry, ToolExecutor
        - Memory: Memory, VectorStore, RAG
        - Context: ContextManager, MessageHistory, PromptTemplate
        - Protocols: MCP, A2A, ANP
        - MultiAgent: MultiAgentSystem, AgentCoordinator
        - Evaluation: Evaluator, Metrics, Benchmark
        
        GitHub: https://github.com/your-repo/SwiftAgent
        """
    }
}

// MARK: - Public Exports
// 所有公开的类型都已在各自的文件中声明为 public
// 用户可以通过 import SwiftAgent 访问所有公开 API

// MARK: - Convenience Types

/// Agent 构建器
/// 提供链式API来构建Agent
public struct AgentBuilder {
    private var name: String
    private var llmProvider: LLMProviderProtocol?
    private var systemPrompt: String = ""
    private var tools: [ToolProtocol] = []
    private var loopConfig: AgentLoopConfig = AgentLoopConfig()
    
    public init(name: String) {
        self.name = name
    }
    
    /// 设置 LLM Provider
    public func with(llmProvider: LLMProviderProtocol) -> AgentBuilder {
        var builder = self
        builder.llmProvider = llmProvider
        return builder
    }
    
    /// 设置系统提示词
    public func with(systemPrompt: String) -> AgentBuilder {
        var builder = self
        builder.systemPrompt = systemPrompt
        return builder
    }
    
    /// 添加工具
    public func with(tool: ToolProtocol) -> AgentBuilder {
        var builder = self
        builder.tools.append(tool)
        return builder
    }
    
    /// 添加多个工具
    public func with(tools: [ToolProtocol]) -> AgentBuilder {
        var builder = self
        builder.tools.append(contentsOf: tools)
        return builder
    }
    
    /// 设置 Loop 配置
    public func with(loopConfig: AgentLoopConfig) -> AgentBuilder {
        var builder = self
        builder.loopConfig = loopConfig
        return builder
    }
    
    /// 构建 Agent
    public func build() async throws -> Agent {
        guard let llmProvider = llmProvider else {
            throw AgentBuilderError.missingLLMProvider
        }
        
        let agent = Agent(
            name: name,
            llmProvider: llmProvider,
            systemPrompt: systemPrompt,
            loopConfig: loopConfig
        )
        
        if !tools.isEmpty {
            await agent.registerTools(tools)
        }
        
        return agent
    }
}

/// Agent 构建器错误
public enum AgentBuilderError: Error {
    case missingLLMProvider
    case missingName
}
