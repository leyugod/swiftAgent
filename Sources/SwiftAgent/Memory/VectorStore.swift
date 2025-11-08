//
//  VectorStore.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 向量文档
public struct VectorDocument: Codable, Identifiable, Sendable {
    public let id: UUID
    public let content: String
    public let embedding: [Double]
    public let metadata: [String: String]
    
    public init(
        id: UUID = UUID(),
        content: String,
        embedding: [Double],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.content = content
        self.embedding = embedding
        self.metadata = metadata
    }
}

/// 向量搜索结果
public struct VectorSearchResult: Sendable {
    public let document: VectorDocument
    public let score: Double
    
    public init(document: VectorDocument, score: Double) {
        self.document = document
        self.score = score
    }
}

/// 向量存储协议
@preconcurrency
public protocol VectorStoreProtocol: Sendable {
    /// 添加文档
    /// - Parameter document: 向量文档
    func add(_ document: VectorDocument) async throws
    
    /// 批量添加文档
    /// - Parameter documents: 文档数组
    func addBatch(_ documents: [VectorDocument]) async throws
    
    /// 获取文档
    /// - Parameter id: 文档 ID
    /// - Returns: 向量文档，如果不存在则返回 nil
    func get(_ id: UUID) async throws -> VectorDocument?
    
    /// 相似度搜索
    /// - Parameters:
    ///   - embedding: 查询向量
    ///   - limit: 返回结果数量限制
    ///   - threshold: 相似度阈值（0-1）
    /// - Returns: 搜索结果数组（按相似度降序排列）
    func search(
        embedding: [Double],
        limit: Int,
        threshold: Double
    ) async throws -> [VectorSearchResult]
    
    /// 删除文档
    /// - Parameter id: 文档 ID
    func delete(_ id: UUID) async throws
    
    /// 清空所有文档
    func clear() async throws
    
    /// 获取文档数量
    /// - Returns: 文档总数
    func count() async throws -> Int
}

/// 简单的内存向量存储实现
public actor InMemoryVectorStore: VectorStoreProtocol {
    private var documents: [UUID: VectorDocument] = [:]
    
    public init() {}
    
    public func add(_ document: VectorDocument) async throws {
        documents[document.id] = document
    }
    
    public func addBatch(_ documents: [VectorDocument]) async throws {
        for document in documents {
            self.documents[document.id] = document
        }
    }
    
    public func get(_ id: UUID) async throws -> VectorDocument? {
        documents[id]
    }
    
    public func search(
        embedding: [Double],
        limit: Int,
        threshold: Double = 0.0
    ) async throws -> [VectorSearchResult] {
        let results = documents.values
            .map { doc -> VectorSearchResult in
                let similarity = cosineSimilarity(embedding, doc.embedding)
                return VectorSearchResult(document: doc, score: similarity)
            }
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }
        
        return Array(results.prefix(limit))
    }
    
    public func delete(_ id: UUID) async throws {
        documents.removeValue(forKey: id)
    }
    
    public func clear() async throws {
        documents.removeAll()
    }
    
    public func count() async throws -> Int {
        documents.count
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

/// 向量存储错误
public enum VectorStoreError: Error {
    case invalidDimension(String)
    case notFound(UUID)
    case storageError(String)
}

