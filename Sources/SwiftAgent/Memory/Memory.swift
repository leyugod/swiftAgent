//
//  Memory.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 记忆条目
public struct MemoryEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let content: String
    public let timestamp: Date
    public let metadata: [String: String]
    public let embedding: [Double]?
    
    public init(
        id: UUID = UUID(),
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        embedding: [Double]? = nil
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
        self.embedding = embedding
    }
}

/// 记忆类型
public enum MemoryType: String, Codable {
    case shortTerm  // 短期记忆（会话内）
    case longTerm   // 长期记忆（持久化）
    case working    // 工作记忆（当前任务）
}

/// 记忆存储协议
@preconcurrency
public protocol MemoryProtocol: Sendable {
    /// 添加记忆
    /// - Parameter entry: 记忆条目
    func add(_ entry: MemoryEntry) async throws
    
    /// 批量添加记忆
    /// - Parameter entries: 记忆条目数组
    func addBatch(_ entries: [MemoryEntry]) async throws
    
    /// 获取记忆
    /// - Parameter id: 记忆 ID
    /// - Returns: 记忆条目，如果不存在则返回 nil
    func get(_ id: UUID) async throws -> MemoryEntry?
    
    /// 搜索记忆
    /// - Parameters:
    ///   - query: 搜索查询
    ///   - limit: 返回结果数量限制
    /// - Returns: 相关的记忆条目数组
    func search(query: String, limit: Int) async throws -> [MemoryEntry]
    
    /// 向量搜索
    /// - Parameters:
    ///   - embedding: 查询向量
    ///   - limit: 返回结果数量限制
    /// - Returns: 相关的记忆条目数组（按相似度排序）
    func vectorSearch(embedding: [Double], limit: Int) async throws -> [MemoryEntry]
    
    /// 获取最近的记忆
    /// - Parameter limit: 返回结果数量限制
    /// - Returns: 最近的记忆条目数组
    func getRecent(limit: Int) async throws -> [MemoryEntry]
    
    /// 删除记忆
    /// - Parameter id: 记忆 ID
    func delete(_ id: UUID) async throws
    
    /// 清空所有记忆
    func clear() async throws
    
    /// 获取记忆数量
    /// - Returns: 记忆总数
    func count() async throws -> Int
}

/// 简单的内存记忆存储实现
public actor InMemoryStore: MemoryProtocol {
    private var memories: [UUID: MemoryEntry] = [:]
    
    public init() {}
    
    public func add(_ entry: MemoryEntry) async throws {
        memories[entry.id] = entry
    }
    
    public func addBatch(_ entries: [MemoryEntry]) async throws {
        for entry in entries {
            memories[entry.id] = entry
        }
    }
    
    public func get(_ id: UUID) async throws -> MemoryEntry? {
        memories[id]
    }
    
    public func search(query: String, limit: Int) async throws -> [MemoryEntry] {
        let results = memories.values
            .filter { $0.content.localizedCaseInsensitiveContains(query) }
            .sorted { $0.timestamp > $1.timestamp }
        
        return Array(results.prefix(limit))
    }
    
    public func vectorSearch(embedding: [Double], limit: Int) async throws -> [MemoryEntry] {
        // 计算余弦相似度
        let results = memories.values
            .compactMap { entry -> (entry: MemoryEntry, similarity: Double)? in
                guard let entryEmbedding = entry.embedding else { return nil }
                let similarity = cosineSimilarity(embedding, entryEmbedding)
                return (entry, similarity)
            }
            .sorted { $0.similarity > $1.similarity }
        
        return results.prefix(limit).map { $0.entry }
    }
    
    public func getRecent(limit: Int) async throws -> [MemoryEntry] {
        let sorted = memories.values.sorted { $0.timestamp > $1.timestamp }
        return Array(sorted.prefix(limit))
    }
    
    public func delete(_ id: UUID) async throws {
        memories.removeValue(forKey: id)
    }
    
    public func clear() async throws {
        memories.removeAll()
    }
    
    public func count() async throws -> Int {
        memories.count
    }
    
    // MARK: - Private Helper
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }
}

/// 记忆错误
public enum MemoryError: Error {
    case notFound(UUID)
    case storageError(String)
    case embeddingError(String)
}

