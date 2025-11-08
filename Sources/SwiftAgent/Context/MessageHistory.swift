//
//  MessageHistory.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 消息历史管理
public actor MessageHistory {
    private var messages: [LLMMessage] = []
    private var systemPrompt: String?
    
    /// 初始化消息历史
    /// - Parameter systemPrompt: 系统提示词
    public init(systemPrompt: String? = nil) {
        self.systemPrompt = systemPrompt
        if let prompt = systemPrompt {
            messages.append(.system(prompt))
        }
    }
    
    /// 添加消息
    /// - Parameter message: 消息
    public func add(_ message: LLMMessage) {
        messages.append(message)
    }
    
    /// 批量添加消息
    /// - Parameter messages: 消息数组
    public func addBatch(_ messages: [LLMMessage]) {
        self.messages.append(contentsOf: messages)
    }
    
    /// 获取所有消息
    /// - Returns: 消息数组
    public func getAll() -> [LLMMessage] {
        messages
    }
    
    /// 获取最近的 N 条消息
    /// - Parameter count: 消息数量
    /// - Returns: 消息数组
    public func getRecent(count: Int) -> [LLMMessage] {
        Array(messages.suffix(count))
    }
    
    /// 获取指定角色的消息
    /// - Parameter role: 消息角色
    /// - Returns: 消息数组
    public func getByRole(_ role: MessageRole) -> [LLMMessage] {
        messages.filter { $0.role == role }
    }
    
    /// 获取用户消息
    /// - Returns: 用户消息数组
    public func getUserMessages() -> [LLMMessage] {
        getByRole(.user)
    }
    
    /// 获取助手消息
    /// - Returns: 助手消息数组
    public func getAssistantMessages() -> [LLMMessage] {
        getByRole(.assistant)
    }
    
    /// 清空所有消息
    public func clear() {
        messages.removeAll()
        if let prompt = systemPrompt {
            messages.append(.system(prompt))
        }
    }
    
    /// 重置到初始状态
    public func reset() {
        messages.removeAll()
        if let prompt = systemPrompt {
            messages.append(.system(prompt))
        }
    }
    
    /// 获取消息数量
    /// - Returns: 消息总数
    public func count() -> Int {
        messages.count
    }
    
    /// 更新系统提示词
    /// - Parameter prompt: 新的系统提示词
    public func updateSystemPrompt(_ prompt: String) {
        self.systemPrompt = prompt
        
        // 移除旧的系统消息
        messages.removeAll { $0.role == .system }
        
        // 添加新的系统消息到开头
        messages.insert(.system(prompt), at: 0)
    }
    
    /// 删除最后一条消息
    /// - Returns: 被删除的消息，如果为空则返回 nil
    @discardableResult
    public func removeLast() -> LLMMessage? {
        guard !messages.isEmpty else { return nil }
        return messages.removeLast()
    }
    
    /// 删除指定索引的消息
    /// - Parameter index: 索引
    /// - Returns: 被删除的消息
    @discardableResult
    public func remove(at index: Int) -> LLMMessage? {
        guard index >= 0 && index < messages.count else { return nil }
        return messages.remove(at: index)
    }
    
    /// 导出为 JSON
    /// - Returns: JSON 字符串
    public func exportToJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(messages)
        guard let json = String(data: data, encoding: .utf8) else {
            throw MessageHistoryError.exportFailed
        }
        return json
    }
    
    /// 从 JSON 导入
    /// - Parameter json: JSON 字符串
    public func importFromJSON(_ json: String) throws {
        guard let data = json.data(using: .utf8) else {
            throw MessageHistoryError.importFailed("无效的 JSON 字符串")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importedMessages = try decoder.decode([LLMMessage].self, from: data)
        self.messages = importedMessages
    }
    
    /// 获取对话摘要
    /// - Returns: 摘要字符串
    public func getSummary() -> String {
        let userCount = messages.filter { $0.role == .user }.count
        let assistantCount = messages.filter { $0.role == .assistant }.count
        let toolCount = messages.filter { $0.role == .tool }.count
        
        return """
        消息历史摘要:
        - 总消息数: \(messages.count)
        - 用户消息: \(userCount)
        - 助手消息: \(assistantCount)
        - 工具消息: \(toolCount)
        """
    }
}

/// 消息历史错误
public enum MessageHistoryError: Error {
    case exportFailed
    case importFailed(String)
    case invalidData
}

