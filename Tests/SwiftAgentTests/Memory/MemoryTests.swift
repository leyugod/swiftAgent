//
//  MemoryTests.swift
//  SwiftAgentTests
//
//  Memory 系统测试
//

import XCTest
@testable import SwiftAgent

final class MemoryTests: XCTestCase {
    
    // MARK: - InMemoryStore 测试
    
    func testMemoryEntryCreation() {
        let entry = MemoryEntry(
            content: "Test content",
            metadata: ["key": "value"],
            embedding: [0.1, 0.2, 0.3]
        )
        
        XCTAssertEqual(entry.content, "Test content")
        XCTAssertEqual(entry.metadata["key"], "value")
        XCTAssertEqual(entry.embedding?.count, 3)
    }
    
    func testAddMemory() async throws {
        let store = InMemoryStore()
        let entry = MemoryEntry(content: "Test memory")
        
        try await store.add(entry)
        
        let retrieved = try await store.get(entry.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.content, "Test memory")
    }
    
    func testAddBatchMemories() async throws {
        let store = InMemoryStore()
        let entries = makeTestMemoryEntries(count: 5)
        
        try await store.addBatch(entries)
        
        let allMemories = try await store.search(query: "", limit: 10)
        XCTAssertEqual(allMemories.count, 5)
    }
    
    func testGetNonexistentMemory() async throws {
        let store = InMemoryStore()
        let randomId = UUID()
        
        let retrieved = try await store.get(randomId)
        XCTAssertNil(retrieved)
    }
    
    func testSearchMemories() async throws {
        let store = InMemoryStore()
        
        let entries = [
            MemoryEntry(content: "Swift programming language", metadata: ["topic": "coding"]),
            MemoryEntry(content: "Python is great for data science", metadata: ["topic": "coding"]),
            MemoryEntry(content: "I love eating pizza", metadata: ["topic": "food"]),
            MemoryEntry(content: "Machine learning with Python", metadata: ["topic": "ai"])
        ]
        
        try await store.addBatch(entries)
        
        // 搜索包含 "Python" 的记忆
        let results = try await store.search(query: "Python", limit: 5)
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.contains { $0.content.contains("Python") })
    }
    
    func testSearchWithLimit() async throws {
        let store = InMemoryStore()
        let entries = makeTestMemoryEntries(count: 10)
        try await store.addBatch(entries)
        
        let results = try await store.search(query: "", limit: 3)
        XCTAssertEqual(results.count, 3)
    }
    
    func testUpdateMemory() async throws {
        let store = InMemoryStore()
        let entry = MemoryEntry(content: "Original content")
        try await store.add(entry)
        
        // 通过重新添加来更新（覆盖）
        let updated = MemoryEntry(
            id: entry.id,
            content: "Updated content",
            metadata: entry.metadata,
            embedding: entry.embedding
        )
        try await store.add(updated)
        
        let retrieved = try await store.get(entry.id)
        XCTAssertEqual(retrieved?.content, "Updated content")
    }
    
    func testDeleteMemory() async throws {
        let store = InMemoryStore()
        let entry = MemoryEntry(content: "To be deleted")
        try await store.add(entry)
        
        let retrieved1 = try await store.get(entry.id)
        XCTAssertNotNil(retrieved1)
        
        try await store.delete(entry.id)
        
        let retrieved2 = try await store.get(entry.id)
        XCTAssertNil(retrieved2)
    }
    
    func testClearAllMemories() async throws {
        let store = InMemoryStore()
        let entries = makeTestMemoryEntries(count: 5)
        try await store.addBatch(entries)
        
        let count1 = try await store.search(query: "", limit: 10).count
        XCTAssertEqual(count1, 5)
        
        try await store.clear()
        
        let count2 = try await store.search(query: "", limit: 10).count
        XCTAssertEqual(count2, 0)
    }
    
    // MARK: - VectorStore 测试
    // 注意：这些测试需要实际的 VectorStore 实现
    // 当前使用 InMemoryStore 的 vectorSearch 功能进行测试
    
    func testVectorSearch() async throws {
        let store = InMemoryStore()
        
        let entries = [
            MemoryEntry(content: "Entry 1", embedding: [1.0, 0.0, 0.0]),
            MemoryEntry(content: "Entry 2", embedding: [0.9, 0.1, 0.0]),
            MemoryEntry(content: "Entry 3", embedding: [0.0, 1.0, 0.0])
        ]
        
        try await store.addBatch(entries)
        
        // 搜索与 [1.0, 0.0, 0.0] 相似的向量
        let query = [1.0, 0.0, 0.0]
        let results = try await store.vectorSearch(embedding: query, limit: 2)
        
        XCTAssertEqual(results.count, 2)
        // 第一个结果应该是最相似的
        XCTAssertEqual(results[0].content, "Entry 1")
    }
    
    // MARK: - MemoryManager 测试
    
    func testMemoryManagerCreation() async {
        let manager = MemoryManager()
        XCTAssertNotNil(manager)
    }
    
    func testAddToShortTermMemory() async throws {
        let manager = MemoryManager()
        
        try await manager.add(content: "Short term memory", type: .shortTerm)
        
        let memories = try await manager.search(query: "", types: [.shortTerm], limit: 10)
        XCTAssertGreaterThanOrEqual(memories.count, 1)
        XCTAssertTrue(memories.contains { $0.content == "Short term memory" })
    }
    
    func testAddToLongTermMemory() async throws {
        let manager = MemoryManager()
        
        try await manager.add(content: "Long term memory", type: .longTerm)
        
        let memories = try await manager.search(query: "", types: [.longTerm], limit: 10)
        XCTAssertGreaterThanOrEqual(memories.count, 1)
        XCTAssertTrue(memories.contains { $0.content == "Long term memory" })
    }
    
    func testSearchAcrossMemories() async throws {
        let manager = MemoryManager()
        
        try await manager.add(content: "Swift programming", type: .shortTerm)
        try await manager.add(content: "Python programming", type: .longTerm)
        try await manager.add(content: "JavaScript programming", type: .working)
        
        let results = try await manager.search(query: "programming", types: [.shortTerm, .longTerm, .working], limit: 10)
        XCTAssertGreaterThanOrEqual(results.count, 3)
    }
    
    func testClearShortTermMemory() async throws {
        let manager = MemoryManager()
        
        try await manager.add(content: "Temp 1", type: .shortTerm)
        try await manager.add(content: "Temp 2", type: .shortTerm)
        
        let count1 = try await manager.search(query: "", types: [.shortTerm], limit: 10).count
        XCTAssertGreaterThanOrEqual(count1, 2)
        
        try await manager.clearShortTermMemory()
        
        let count2 = try await manager.search(query: "", types: [.shortTerm], limit: 10).count
        XCTAssertEqual(count2, 0)
    }
    
    // MARK: - RAG 测试（简化版）
    // 注意：完整的 RAG 测试需要更复杂的设置
    
    func testRAGBasicFunctionality() async throws {
        // 使用 InMemoryStore 进行基本的向量搜索测试
        let store = InMemoryStore()
        
        let documents = [
            MemoryEntry(content: "Swift is a programming language", embedding: generateRandomEmbedding(dimension: 10)),
            MemoryEntry(content: "Python is used for data science", embedding: generateRandomEmbedding(dimension: 10)),
            MemoryEntry(content: "JavaScript runs in browsers", embedding: generateRandomEmbedding(dimension: 10))
        ]
        
        try await store.addBatch(documents)
        
        // 检索文档
        let queryEmbedding = generateRandomEmbedding(dimension: 10)
        let results = try await store.vectorSearch(embedding: queryEmbedding, limit: 2)
        
        XCTAssertLessThanOrEqual(results.count, 2)
    }
    
    // MARK: - 并发安全测试
    
    func testConcurrentMemoryAccess() async throws {
        let store = InMemoryStore()
        
        // 并发添加记忆
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let entry = MemoryEntry(content: "Concurrent memory \(i)")
                    try? await store.add(entry)
                }
            }
        }
        
        let allMemories = try await store.search(query: "", limit: 20)
        XCTAssertEqual(allMemories.count, 10)
    }
    
    func testConcurrentVectorStoreAccess() async throws {
        let store = InMemoryStore()
        
        // 并发添加向量
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { [self] in
                    let entry = MemoryEntry(
                        content: "Vector \(i)",
                        embedding: self.generateRandomEmbedding(dimension: 3)
                    )
                    try? await store.add(entry)
                }
            }
        }
        
        let count = try await store.count()
        XCTAssertEqual(count, 10)
    }
}

// MARK: - Helper Functions

extension MemoryTests {
    /// 生成测试用的记忆条目数组
    func makeTestMemoryEntries(count: Int) -> [MemoryEntry] {
        return (0..<count).map { i in
            MemoryEntry(
                content: "Test memory \(i)",
                metadata: ["index": "\(i)"]
            )
        }
    }
    
    /// 生成随机向量
    func generateRandomEmbedding(dimension: Int) -> [Double] {
        return (0..<dimension).map { _ in Double.random(in: 0.0...1.0) }
    }
}

