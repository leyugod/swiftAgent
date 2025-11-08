//
//  SQLiteStorageTests.swift
//  SwiftAgentTests
//
//  SQLite 持久化存储测试
//

import XCTest
@testable import SwiftAgent

final class SQLiteStorageTests: XCTestCase {
    var storage: PersistentMemoryStore!
    var testDBPath: String!
    
    override func setUp() async throws {
        // 创建临时测试数据库
        let tempDir = FileManager.default.temporaryDirectory
        testDBPath = tempDir.appendingPathComponent("test_\(UUID().uuidString).db").path
        storage = try PersistentMemoryStore(dbPath: testDBPath)
    }
    
    override func tearDown() async throws {
        storage = nil
        
        // 清理测试数据库
        if FileManager.default.fileExists(atPath: testDBPath) {
            try? FileManager.default.removeItem(atPath: testDBPath)
        }
    }
    
    // MARK: - 基础 CRUD 测试
    
    func testAddAndGetMemory() async throws {
        // Given
        let entry = MemoryEntry(
            content: "Test memory content",
            metadata: ["type": "test"],
            embedding: [0.1, 0.2, 0.3]
        )
        
        // When
        try await storage.add(entry)
        let retrieved = try await storage.get(entry.id)
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.content, "Test memory content")
        XCTAssertEqual(retrieved?.metadata["type"], "test")
        XCTAssertEqual(retrieved?.embedding, [0.1, 0.2, 0.3])
    }
    
    func testBatchAdd() async throws {
        // Given
        let entries = (1...5).map { i in
            MemoryEntry(
                content: "Memory \(i)",
                metadata: ["index": "\(i)"]
            )
        }
        
        // When
        try await storage.addBatch(entries)
        
        // Then
        for entry in entries {
            let retrieved = try await storage.get(entry.id)
            XCTAssertNotNil(retrieved)
        }
    }
    
    func testSearchMemory() async throws {
        // Given
        try await storage.add(MemoryEntry(content: "Apple is a fruit"))
        try await storage.add(MemoryEntry(content: "Banana is yellow"))
        try await storage.add(MemoryEntry(content: "Apple pie is delicious"))
        
        // When
        let results = try await storage.search(query: "Apple", limit: 10)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.content.contains("Apple") })
    }
    
    func testVectorSearch() async throws {
        // Given
        let embedding1 = [1.0, 0.0, 0.0]
        let embedding2 = [0.0, 1.0, 0.0]
        let embedding3 = [0.9, 0.1, 0.0]
        
        try await storage.add(MemoryEntry(content: "Entry 1", embedding: embedding1))
        try await storage.add(MemoryEntry(content: "Entry 2", embedding: embedding2))
        try await storage.add(MemoryEntry(content: "Entry 3", embedding: embedding3))
        
        // When - 搜索与 embedding1 最相似的
        let results = try await storage.vectorSearch(embedding: [1.0, 0.0, 0.0], limit: 2)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.content, "Entry 1")  // 完全匹配
        XCTAssertEqual(results.last?.content, "Entry 3")   // 第二相似
    }
    
    func testGetRecent() async throws {
        // Given
        for i in 1...5 {
            try await storage.add(MemoryEntry(content: "Memory \(i)"))
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        // When
        let recent = try await storage.getRecent(limit: 3)
        
        // Then
        XCTAssertEqual(recent.count, 3)
    }
    
    func testDeleteMemory() async throws {
        // Given
        let entry = MemoryEntry(content: "To be deleted")
        try await storage.add(entry)
        
        // When
        try await storage.delete(entry.id)
        let retrieved = try await storage.get(entry.id)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testClear() async throws {
        // Given
        try await storage.add(MemoryEntry(content: "Memory 1"))
        try await storage.add(MemoryEntry(content: "Memory 2"))
        try await storage.add(MemoryEntry(content: "Memory 3"))
        
        // When
        try await storage.clear()
        let count = try await storage.count()
        
        // Then
        XCTAssertEqual(count, 0)
    }
    
    func testCount() async throws {
        // Given
        let initialCount = try await storage.count()
        XCTAssertEqual(initialCount, 0)
        
        // When
        try await storage.add(MemoryEntry(content: "Memory 1"))
        try await storage.add(MemoryEntry(content: "Memory 2"))
        
        // Then
        let finalCount = try await storage.count()
        XCTAssertEqual(finalCount, 2)
    }
    
    // MARK: - 持久化测试
    
    func testPersistenceAcrossInstances() async throws {
        // Given
        let entry = MemoryEntry(
            content: "Persistent memory",
            metadata: ["key": "value"]
        )
        try await storage.add(entry)
        
        // When - 重新创建 storage 实例
        storage = nil
        storage = try PersistentMemoryStore(dbPath: testDBPath)
        let retrieved = try await storage.get(entry.id)
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.content, "Persistent memory")
        XCTAssertEqual(retrieved?.metadata["key"], "value")
    }
}

// MARK: - Message History Tests

final class PersistentMessageHistoryTests: XCTestCase {
    var messageHistory: PersistentMessageHistory!
    var testDBPath: String!
    
    override func setUp() async throws {
        // 创建临时测试数据库
        let tempDir = FileManager.default.temporaryDirectory
        testDBPath = tempDir.appendingPathComponent("test_messages_\(UUID().uuidString).db").path
        messageHistory = try PersistentMessageHistory(dbPath: testDBPath)
    }
    
    override func tearDown() async throws {
        messageHistory = nil
        
        // 清理测试数据库
        if FileManager.default.fileExists(atPath: testDBPath) {
            try? FileManager.default.removeItem(atPath: testDBPath)
        }
    }
    
    func testAddAndGetMessages() async throws {
        // Given
        let message1 = LLMMessage(role: .user, content: "Hello")
        let message2 = LLMMessage(role: .assistant, content: "Hi there!")
        
        // When
        try await messageHistory.addMessage(message1)
        try await messageHistory.addMessage(message2)
        let messages = try await messageHistory.getMessages()
        
        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[0].content, "Hello")
        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertEqual(messages[1].content, "Hi there!")
    }
    
    func testMessageOrdering() async throws {
        // Given
        for i in 1...5 {
            let message = LLMMessage(role: .user, content: "Message \(i)")
            try await messageHistory.addMessage(message)
        }
        
        // When
        let messages = try await messageHistory.getMessages()
        
        // Then
        XCTAssertEqual(messages.count, 5)
        XCTAssertEqual(messages[0].content, "Message 1")
        XCTAssertEqual(messages[4].content, "Message 5")
    }
    
    func testMessageLimit() async throws {
        // Given
        for i in 1...10 {
            let message = LLMMessage(role: .user, content: "Message \(i)")
            try await messageHistory.addMessage(message)
        }
        
        // When
        let messages = try await messageHistory.getMessages(limit: 5)
        
        // Then
        XCTAssertEqual(messages.count, 5)
        XCTAssertEqual(messages[0].content, "Message 1")
        XCTAssertEqual(messages[4].content, "Message 5")
    }
}

