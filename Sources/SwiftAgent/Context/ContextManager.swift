//
//  ContextManager.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 上下文管理器
/// 管理对话上下文，包括消息历史、token 计数、上下文窗口等
public actor ContextManager {
    private var messageHistory: MessageHistory
    private let config: Config
    
    /// 上下文管理器配置
    public struct Config {
        public let maxMessages: Int
        public let maxTokens: Int
        public let includeSystemPrompt: Bool
        public let compressionStrategy: CompressionStrategy
        
        public init(
            maxMessages: Int = 50,
            maxTokens: Int = 4000,
            includeSystemPrompt: Bool = true,
            compressionStrategy: CompressionStrategy = .truncateOldest
        ) {
            self.maxMessages = maxMessages
            self.maxTokens = maxTokens
            self.includeSystemPrompt = includeSystemPrompt
            self.compressionStrategy = compressionStrategy
        }
    }
    
    /// 压缩策略
    public enum CompressionStrategy {
        case truncateOldest      // 删除最旧的消息
        case truncateMiddle      // 删除中间的消息（保留最新和最旧）
        case summarize           // 总结旧消息
        case slidingWindow       // 滑动窗口
    }
    
    /// 初始化上下文管理器
    /// - Parameters:
    ///   - systemPrompt: 系统提示词
    ///   - config: 配置
    public init(
        systemPrompt: String? = nil,
        config: Config = Config()
    ) {
        self.messageHistory = MessageHistory(systemPrompt: systemPrompt)
        self.config = config
    }
    
    /// 添加消息
    /// - Parameter message: 消息
    public func addMessage(_ message: LLMMessage) async {
        await messageHistory.add(message)
        await maintainContextWindow()
    }
    
    /// 添加用户消息
    /// - Parameter content: 消息内容
    public func addUserMessage(_ content: String) async {
        await messageHistory.add(.user(content))
        await maintainContextWindow()
    }
    
    /// 添加助手消息
    /// - Parameter content: 消息内容
    public func addAssistantMessage(_ content: String) async {
        await messageHistory.add(.assistant(content))
        await maintainContextWindow()
    }
    
    /// 添加工具消息
    /// - Parameters:
    ///   - content: 消息内容
    ///   - toolCallId: 工具调用 ID
    ///   - name: 工具名称
    public func addToolMessage(content: String, toolCallId: String, name: String) async {
        await messageHistory.add(.tool(content: content, toolCallId: toolCallId, name: name))
        await maintainContextWindow()
    }
    
    /// 获取所有消息
    /// - Returns: 消息数组
    public func getMessages() async -> [LLMMessage] {
        await messageHistory.getAll()
    }
    
    /// 获取最近的 N 条消息
    /// - Parameter count: 消息数量
    /// - Returns: 消息数组
    public func getRecentMessages(count: Int) async -> [LLMMessage] {
        await messageHistory.getRecent(count: count)
    }
    
    /// 获取格式化的上下文
    /// - Returns: 格式化的上下文字符串
    public func getFormattedContext() async -> String {
        let messages = await messageHistory.getAll()
        var context = ""
        
        for message in messages {
            switch message.role {
            case .system:
                context += "System: \(message.content)\n\n"
            case .user:
                context += "User: \(message.content)\n\n"
            case .assistant:
                context += "Assistant: \(message.content)\n\n"
            case .tool:
                if let name = message.name {
                    context += "Tool [\(name)]: \(message.content)\n\n"
                }
            }
        }
        
        return context
    }
    
    /// 清空消息历史
    public func clear() async {
        await messageHistory.clear()
    }
    
    /// 重置到系统提示词
    public func reset() async {
        await messageHistory.reset()
    }
    
    /// 获取消息数量
    /// - Returns: 消息总数
    public func count() async -> Int {
        await messageHistory.count()
    }
    
    /// 估算 token 数量
    /// - Returns: 估算的 token 数量
    public func estimateTokens() async -> Int {
        let messages = await messageHistory.getAll()
        // 简单估算：平均每个字符 0.25 个 token（英文）
        // 中文约 0.5-1 个 token 每字符
        let totalChars = messages.reduce(0) { $0 + $1.content.count }
        return Int(Double(totalChars) * 0.4) // 粗略估算
    }
    
    /// 更新系统提示词
    /// - Parameter prompt: 新的系统提示词
    public func updateSystemPrompt(_ prompt: String) async {
        await messageHistory.updateSystemPrompt(prompt)
    }
    
    // MARK: - Private Methods
    
    private func maintainContextWindow() async {
        let messages = await messageHistory.getAll()
        
        // 检查消息数量
        if messages.count > config.maxMessages {
            await applyCompressionStrategy()
        }
        
        // 检查 token 数量
        let tokens = await estimateTokens()
        if tokens > config.maxTokens {
            await applyCompressionStrategy()
        }
    }
    
    private func applyCompressionStrategy() async {
        switch config.compressionStrategy {
        case .truncateOldest:
            await truncateOldest()
        case .truncateMiddle:
            await truncateMiddle()
        case .summarize:
            // 总结策略需要 LLM 支持，这里暂时使用删除策略
            await truncateOldest()
        case .slidingWindow:
            await applySlidingWindow()
        }
    }
    
    private func truncateOldest() async {
        let messages = await messageHistory.getAll()
        let systemMessages = messages.filter { $0.role == .system }
        let otherMessages = messages.filter { $0.role != .system }
        
        // 保留系统消息和最近的消息
        let keepCount = config.maxMessages - systemMessages.count
        let keptMessages = Array(otherMessages.suffix(keepCount))
        
        await messageHistory.clear()
        for message in systemMessages + keptMessages {
            await messageHistory.add(message)
        }
    }
    
    private func truncateMiddle() async {
        let messages = await messageHistory.getAll()
        let systemMessages = messages.filter { $0.role == .system }
        let otherMessages = messages.filter { $0.role != .system }
        
        guard otherMessages.count > config.maxMessages else { return }
        
        // 保留开头和结尾的消息
        let keepEachSide = (config.maxMessages - systemMessages.count) / 2
        let first = Array(otherMessages.prefix(keepEachSide))
        let last = Array(otherMessages.suffix(keepEachSide))
        
        await messageHistory.clear()
        for message in systemMessages + first + last {
            await messageHistory.add(message)
        }
    }
    
    private func applySlidingWindow() async {
        let messages = await messageHistory.getAll()
        let windowSize = config.maxMessages
        
        if messages.count > windowSize {
            let systemMessages = messages.filter { $0.role == .system }
            let otherMessages = messages.filter { $0.role != .system }
            let windowMessages = Array(otherMessages.suffix(windowSize - systemMessages.count))
            
            await messageHistory.clear()
            for message in systemMessages + windowMessages {
                await messageHistory.add(message)
            }
        }
    }
}

