//
//  PersistentMemoryStore.swift
//  SwiftAgent
//
//  持久化记忆存储
//

import Foundation

/// 持久化记忆存储
/// 基于 SQLite 的 MemoryProtocol 实现
public actor PersistentMemoryStore: MemoryProtocol {
    private let storage: SQLiteStorage
    
    public init(dbPath: String? = nil) throws {
        self.storage = try SQLiteStorage(dbPath: dbPath)
    }
    
    // MARK: - MemoryProtocol
    
    public func add(_ entry: MemoryEntry) async throws {
        try await storage.saveMemory(entry)
    }
    
    public func addBatch(_ entries: [MemoryEntry]) async throws {
        for entry in entries {
            try await storage.saveMemory(entry)
        }
    }
    
    public func get(_ id: UUID) async throws -> MemoryEntry? {
        return try await storage.getMemory(id: id)
    }
    
    public func search(query: String, limit: Int) async throws -> [MemoryEntry] {
        return try await storage.searchMemories(query: query, limit: limit)
    }
    
    public func vectorSearch(embedding: [Double], limit: Int) async throws -> [MemoryEntry] {
        let allMemories = try await storage.getAllMemories(limit: 1000)
        
        // 计算相似度并排序
        let scored = allMemories.compactMap { memory -> (MemoryEntry, Double)? in
            guard let memoryEmbedding = memory.embedding else { return nil }
            let similarity = cosineSimilarity(embedding, memoryEmbedding)
            return (memory, similarity)
        }
        
        let sorted = scored.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(limit).map { $0.0 })
    }
    
    public func getRecent(limit: Int) async throws -> [MemoryEntry] {
        return try await storage.getAllMemories(limit: limit)
    }
    
    public func delete(_ id: UUID) async throws {
        try await storage.deleteMemory(id: id)
    }
    
    public func clear() async throws {
        // 删除所有记忆
        let allMemories = try await storage.getAllMemories(limit: 10000)
        for memory in allMemories {
            try await storage.deleteMemory(id: memory.id)
        }
    }
    
    public func count() async throws -> Int {
        return try await storage.getMemoryCount()
    }
    
    // MARK: - Helper Methods
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}

// MARK: - Persistent Message History

/// 持久化消息历史
public actor PersistentMessageHistory {
    private let storage: SQLiteStorage
    private let sessionId: String
    
    public init(sessionId: String? = nil, dbPath: String? = nil) throws {
        self.storage = try SQLiteStorage(dbPath: dbPath)
        self.sessionId = sessionId ?? UUID().uuidString
    }
    
    /// 添加消息
    public func addMessage(_ message: LLMMessage) async throws {
        try await storage.saveMessage(sessionId: sessionId, message: message)
    }
    
    /// 获取消息历史
    public func getMessages(limit: Int = 100) async throws -> [LLMMessage] {
        return try await storage.getMessages(sessionId: sessionId, limit: limit)
    }
    
    /// 获取会话 ID
    public func getSessionId() -> String {
        return sessionId
    }
}

