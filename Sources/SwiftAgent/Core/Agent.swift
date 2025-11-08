//
//  Agent.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// Agent 类
/// 实现核心的智能体功能
public actor Agent: AgentProtocol {
    public let name: String
    private var _systemPrompt: String
    
    public var systemPrompt: String {
        get async {
            _systemPrompt
        }
    }
    
    /// 设置系统提示词
    public func setSystemPrompt(_ prompt: String) async {
        _systemPrompt = prompt
    }
    
    private let llmProvider: LLMProviderProtocol
    internal let toolRegistry: ToolRegistry  // internal 以供扩展访问
    private let toolExecutor: ToolExecutor
    private let loopConfig: AgentLoopConfig
    
    /// AgentLoop 懒加载，避免初始化器中的并发警告
    private var _loop: AgentLoop?
    
    /// 消息历史（用于上下文管理）
    private var messageHistory: [LLMMessage] = []
    
    /// 初始化 Agent
    /// - Parameters:
    ///   - name: Agent 名称
    ///   - llmProvider: LLM 提供商
    ///   - systemPrompt: 系统提示词
    ///   - toolRegistry: 工具注册表
    ///   - loopConfig: Loop 配置
    public init(
        name: String,
        llmProvider: LLMProviderProtocol,
        systemPrompt: String,
        toolRegistry: ToolRegistry = ToolRegistry(),
        loopConfig: AgentLoopConfig = AgentLoopConfig()
    ) {
        self.name = name
        self.llmProvider = llmProvider
        self._systemPrompt = systemPrompt
        self.toolRegistry = toolRegistry
        self.toolExecutor = ToolExecutor(registry: toolRegistry)
        self.loopConfig = loopConfig
        // loop 将在首次访问时初始化
    }
    
    /// 获取或初始化 AgentLoop
    private func getLoop() -> AgentLoop {
        if let loop = _loop {
            return loop
        }
        let loop = AgentLoop(agent: self, config: loopConfig)
        _loop = loop
        return loop
    }
    
    /// 运行 Agent，处理用户输入
    /// - Parameter input: 用户输入
    /// - Returns: Agent 的最终响应
    public func run(_ input: String) async throws -> String {
        // 使用 AgentLoop 运行完整循环
        let loop = getLoop()
        return try await loop.run(input)
    }
    
    /// 运行单次循环（思考-行动-观察）
    /// - Parameter input: 当前输入（用户输入或观察结果）
    /// - Returns: Agent 的响应（思考+行动）
    public func think(_ input: String) async throws -> (thought: Thought, action: Action?) {
        // 构建消息列表
        let messages = buildMessages(input: input)
        
        // 获取可用工具
        let tools = await toolRegistry.toLLMTools()
        
        // 调用 LLM（使用配置的temperature）
        let response = try await llmProvider.chat(
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            temperature: loopConfig.temperature
        )
        
        // 更新消息历史
        messageHistory.append(LLMMessage.user(input))
        messageHistory.append(LLMMessage.assistant(response.content))
        
        // 解析思考过程
        let thought = parseThought(from: response.content)
        
        // 检查是否有工具调用
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            // 使用第一个工具调用
            let toolCall = toolCalls[0]
            let argumentsDict = try parseToolArguments(toolCall.function.arguments)
            let action = Action(
                toolName: toolCall.function.name,
                arguments: argumentsDict,
                thought: thought
            )
            return (thought, action)
        }
        
        // 检查是否是完成响应
        if response.content.contains("finish(") || response.finishReason == "stop" {
            return (thought, nil)
        }
        
        return (thought, nil)
    }
    
    /// 执行行动
    /// - Parameter action: 要执行的行动
    /// - Returns: 观察结果
    public func act(_ action: Action) async throws -> Observation {
        // 创建工具调用
        let argumentsJSON = try encodeToolArguments(action.arguments)
        let toolCall = LLMToolCall(
            id: UUID().uuidString,
            type: "function",
            function: LLMToolCall.FunctionCall(
                name: action.toolName,
                arguments: argumentsJSON
            )
        )
        
        // 执行工具（捕获错误并转换为观察结果）
        let observation: Observation
        do {
            observation = try await toolExecutor.execute(toolCall)
        } catch {
            // 工具执行失败，创建错误观察结果
            observation = Observation(
                content: "工具 '\(action.toolName)' 执行失败: \(error.localizedDescription)",
                toolName: action.toolName,
                metadata: ["error": "true", "error_type": "\(type(of: error))"]
            )
        }
        
        // 更新消息历史（添加工具结果）
        messageHistory.append(LLMMessage.tool(
            content: observation.content,
            toolCallId: toolCall.id,
            name: action.toolName
        ))
        
        return observation
    }
    
    /// 注册工具
    /// - Parameter tool: 要注册的工具
    public func registerTool(_ tool: ToolProtocol) async {
        await toolRegistry.register(tool)
    }
    
    /// 注册多个工具
    /// - Parameter tools: 工具数组
    public func registerTools(_ tools: [ToolProtocol]) async {
        await toolRegistry.register(tools)
    }
    
    /// 清空消息历史
    public func clearHistory() {
        messageHistory.removeAll()
    }
    
    /// 获取消息历史
    /// - Returns: 消息历史数组
    public func getHistory() -> [LLMMessage] {
        messageHistory
    }
    
    // MARK: - Private Methods
    
    private func buildMessages(input: String) -> [LLMMessage] {
        var messages: [LLMMessage] = []
        
        // 添加系统提示词
        if !_systemPrompt.isEmpty {
            messages.append(LLMMessage.system(_systemPrompt))
        }
        
        // 添加历史消息
        messages.append(contentsOf: messageHistory)
        
        // 添加当前输入
        messages.append(LLMMessage.user(input))
        
        return messages
    }
    
    private func parseThought(from content: String) -> Thought {
        // 简单解析思考过程
        // 实际实现可能需要更复杂的解析逻辑
        var reasoning = content
        let plan: [String] = []
        var nextAction: String? = nil
        
        // 尝试提取 Thought: 部分
        if let thoughtRange = content.range(of: "Thought:", options: .caseInsensitive) {
            let thoughtContent = String(content[thoughtRange.upperBound...])
            reasoning = thoughtContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 尝试提取 Action: 部分
            if let actionRange = thoughtContent.range(of: "Action:", options: .caseInsensitive) {
                let actionContent = String(thoughtContent[actionRange.upperBound...])
                nextAction = actionContent.trimmingCharacters(in: .whitespacesAndNewlines)
                reasoning = String(thoughtContent[..<actionRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return Thought(reasoning: reasoning, plan: plan, nextAction: nextAction)
    }
    
    private func parseToolArguments(_ jsonString: String) throws -> [String: String] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ToolError.invalidArguments("无法解析参数字符串")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.invalidArguments("参数必须是 JSON 对象")
        }
        
        // 转换为 [String: String]
        var result: [String: String] = [:]
        for (key, value) in json {
            if let stringValue = value as? String {
                result[key] = stringValue
            } else {
                // 将其他类型转换为字符串
                if let jsonData = try? JSONSerialization.data(withJSONObject: value),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    result[key] = jsonString
                } else {
                    result[key] = String(describing: value)
                }
            }
        }
        
        return result
    }
    
    private func encodeToolArguments(_ arguments: [String: String]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: arguments)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ToolError.invalidArguments("无法编码参数")
        }
        return jsonString
    }
    
    // MARK: - 内置工具便捷方法
    
    /// 注册所有内置工具
    public func registerAllBuiltinTools() async {
        await toolRegistry.register([
            CalculatorTool(),
            DateTimeTool(),
            FileSystemTool(),
            WebSearchTool(),
            WeatherTool()
        ])
    }
    
    /// 注册基础工具（不需要外部依赖）
    public func registerBasicTools() async {
        await toolRegistry.register([
            CalculatorTool(),
            DateTimeTool()
        ])
    }
    
    // MARK: - 流式响应
    
    /// 流式运行 Agent
    /// - Parameter input: 用户输入
    /// - Returns: 流式响应块
    public func streamRun(input: String) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        guard let streamingProvider = llmProvider as? StreamingLLMProviderProtocol else {
            throw ToolError.executionFailed("当前 LLM Provider 不支持流式响应")
        }
        
        // 构建消息
        let messages = buildMessages(input: input)
        
        // 获取工具定义
        let tools = await toolRegistry.getAll().map { tool in
            // 构建properties对象（符合JSON Schema规范）
            let properties: [String: AnyCodable] = tool.parameters.reduce(into: [:]) { dict, param in
                var paramDict: [String: AnyCodable] = [
                    "type": AnyCodable(param.type),
                    "description": AnyCodable(param.description)
                ]
                
                if let enumValues = param.enumValues {
                    paramDict["enum"] = AnyCodable(enumValues)
                }
                
                dict[param.name] = AnyCodable(paramDict)
            }
            
            // 构建required数组
            let required = tool.parameters.filter { $0.required }.map { $0.name }
            
            // 构建完整的parameters对象
            var params: [String: AnyCodable] = [
                "type": AnyCodable("object"),
                "properties": AnyCodable(properties)
            ]
            
            if !required.isEmpty {
                params["required"] = AnyCodable(required)
            }
            
            return LLMToolFunction(
                name: tool.name,
                description: tool.description,
                parameters: params
            )
        }
        
        // 返回流
        return try await streamingProvider.streamGenerate(
            messages: messages,
            tools: tools.isEmpty ? nil : tools
        )
    }
    
    /// 流式运行 Agent（带回调）
    /// - Parameters:
    ///   - input: 用户输入
    ///   - callback: 流式回调
    /// - Returns: 最终的完整响应
    public func streamRunWithCallback(
        input: String,
        callback: StreamingCallback
    ) async throws -> LLMResponse {
        let builder = StreamingResponseBuilder()
        
        do {
            let stream = try await streamRun(input: input)
            
            for try await chunk in stream {
                await builder.process(chunk)
                
                switch chunk.type {
                case .content(let text):
                    await callback.onContent?(text)
                    
                case .toolCall(let toolChunk):
                    await callback.onToolCall?(toolChunk)
                    
                case .done:
                    break
                    
                case .error(let message):
                    throw ToolError.executionFailed(message)
                }
            }
            
            let response = await builder.build()
            await callback.onCompletion?(response)
            
            return response
            
        } catch {
            await callback.onError?(error)
            throw error
        }
    }
}

