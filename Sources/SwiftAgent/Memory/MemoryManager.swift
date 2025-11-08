//
//  MemoryManager.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 记忆管理器
/// 统一管理不同类型的记忆
public actor MemoryManager {
    private let shortTermMemory: MemoryProtocol
    private let longTermMemory: MemoryProtocol
    private let workingMemory: MemoryProtocol
    
    /// 记忆管理器配置
    public struct Config {
        public let shortTermCapacity: Int
        public let workingMemoryCapacity: Int
        public let autoSaveToLongTerm: Bool
        
        public init(
            shortTermCapacity: Int = 50,
            workingMemoryCapacity: Int = 10,
            autoSaveToLongTerm: Bool = true
        ) {
            self.shortTermCapacity = shortTermCapacity
            self.workingMemoryCapacity = workingMemoryCapacity
            self.autoSaveToLongTerm = autoSaveToLongTerm
        }
    }
    
    private let config: Config
    
    /// 初始化记忆管理器
    /// - Parameters:
    ///   - shortTermMemory: 短期记忆存储
    ///   - longTermMemory: 长期记忆存储
    ///   - workingMemory: 工作记忆存储
    ///   - config: 配置
    public init(
        shortTermMemory: MemoryProtocol = InMemoryStore(),
        longTermMemory: MemoryProtocol = InMemoryStore(),
        workingMemory: MemoryProtocol = InMemoryStore(),
        config: Config = Config()
    ) {
        self.shortTermMemory = shortTermMemory
        self.longTermMemory = longTermMemory
        self.workingMemory = workingMemory
        self.config = config
    }
    
    /// 添加记忆
    /// - Parameters:
    ///   - content: 记忆内容
    ///   - type: 记忆类型
    ///   - metadata: 元数据
    public func add(
        content: String,
        type: MemoryType = .shortTerm,
        metadata: [String: String] = [:]
    ) async throws {
        let entry = MemoryEntry(
            content: content,
            metadata: metadata
        )
        
        switch type {
        case .shortTerm:
            try await shortTermMemory.add(entry)
            try await maintainCapacity(for: shortTermMemory, limit: config.shortTermCapacity)
            
        case .longTerm:
            try await longTermMemory.add(entry)
            
        case .working:
            try await workingMemory.add(entry)
            try await maintainCapacity(for: workingMemory, limit: config.workingMemoryCapacity)
        }
    }
    
    /// 搜索记忆
    /// - Parameters:
    ///   - query: 搜索查询
    ///   - types: 要搜索的记忆类型
    ///   - limit: 返回结果数量限制
    /// - Returns: 搜索结果
    public func search(
        query: String,
        types: [MemoryType] = [.shortTerm, .longTerm, .working],
        limit: Int = 10
    ) async throws -> [MemoryEntry] {
        var allResults: [MemoryEntry] = []
        
        for type in types {
            let memory = getMemoryStore(for: type)
            let results = try await memory.search(query: query, limit: limit)
            allResults.append(contentsOf: results)
        }
        
        // 按时间戳排序并限制数量
        let sorted = allResults.sorted { $0.timestamp > $1.timestamp }
        return Array(sorted.prefix(limit))
    }
    
    /// 获取最近的记忆
    /// - Parameters:
    ///   - type: 记忆类型
    ///   - limit: 返回结果数量限制
    /// - Returns: 最近的记忆条目
    public func getRecent(
        type: MemoryType = .shortTerm,
        limit: Int = 10
    ) async throws -> [MemoryEntry] {
        let memory = getMemoryStore(for: type)
        return try await memory.getRecent(limit: limit)
    }
    
    /// 将短期记忆转移到长期记忆
    /// - Parameter entry: 记忆条目
    public func promoteToLongTerm(_ entry: MemoryEntry) async throws {
        try await longTermMemory.add(entry)
        try await shortTermMemory.delete(entry.id)
    }
    
    /// 清空工作记忆
    public func clearWorkingMemory() async throws {
        try await workingMemory.clear()
    }
    
    /// 清空短期记忆
    public func clearShortTermMemory() async throws {
        try await shortTermMemory.clear()
    }
    
    /// 获取记忆统计
    /// - Returns: 各类型记忆的数量
    public func getStatistics() async throws -> [MemoryType: Int] {
        return [
            .shortTerm: try await shortTermMemory.count(),
            .longTerm: try await longTermMemory.count(),
            .working: try await workingMemory.count()
        ]
    }
    
    /// 生成记忆摘要
    /// - Parameter type: 记忆类型
    /// - Returns: 记忆摘要文本
    public func generateSummary(type: MemoryType = .shortTerm) async throws -> String {
        let memory = getMemoryStore(for: type)
        let entries = try await memory.getRecent(limit: 20)
        
        var summary = "# 记忆摘要 (\(type.rawValue))\n\n"
        summary += "总计: \(try await memory.count()) 条记忆\n\n"
        
        if !entries.isEmpty {
            summary += "## 最近的记忆:\n\n"
            for (index, entry) in entries.enumerated() {
                summary += "\(index + 1). \(entry.content)\n"
                summary += "   时间: \(formatDate(entry.timestamp))\n\n"
            }
        }
        
        return summary
    }
    
    // MARK: - Private Methods
    
    private func getMemoryStore(for type: MemoryType) -> MemoryProtocol {
        switch type {
        case .shortTerm:
            return shortTermMemory
        case .longTerm:
            return longTermMemory
        case .working:
            return workingMemory
        }
    }
    
    private func maintainCapacity(for memory: MemoryProtocol, limit: Int) async throws {
        let count = try await memory.count()
        if count > limit {
            // 删除最旧的记忆
            let allEntries = try await memory.getRecent(limit: count)
            let sorted = allEntries.sorted { $0.timestamp < $1.timestamp }
            let toDelete = sorted.prefix(count - limit)
            
            for entry in toDelete {
                if config.autoSaveToLongTerm && memory is InMemoryStore {
                    try await longTermMemory.add(entry)
                }
                try await memory.delete(entry.id)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

