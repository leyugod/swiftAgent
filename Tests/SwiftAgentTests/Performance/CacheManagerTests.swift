//
//  CacheManagerTests.swift
//  SwiftAgentTests
//
//  缓存管理器测试
//

import XCTest
@testable import SwiftAgent

final class CacheManagerTests: XCTestCase {
    var cacheManager: CacheManager!
    var tempCachePath: String!
    
    override func setUp() async throws {
        // 创建临时缓存目录
        let tempDir = FileManager.default.temporaryDirectory
        tempCachePath = tempDir.appendingPathComponent("test_cache_\(UUID().uuidString)").path
        
        cacheManager = await CacheManager(
            diskCachePath: tempCachePath,
            defaultTTL: 1.0,  // 1秒过期，用于测试
            maxMemorySize: 10
        )
    }
    
    override func tearDown() async throws {
        cacheManager = nil
        
        // 清理临时缓存
        if FileManager.default.fileExists(atPath: tempCachePath) {
            try? FileManager.default.removeItem(atPath: tempCachePath)
        }
    }
    
    // MARK: - 基础缓存测试
    
    func testSetAndGet() async throws {
        // Given
        let key = "test_key"
        let value = "test_value"
        
        // When
        try await cacheManager.set(value, forKey: key, ttl: 60)
        let retrieved = try await cacheManager.get(key, as: String.self)
        
        // Then
        XCTAssertEqual(retrieved, value)
    }
    
    func testCacheExpiration() async throws {
        // Given
        let key = "expire_key"
        let value = "expire_value"
        
        // When
        try await cacheManager.set(value, forKey: key, ttl: 0.5)  // 0.5秒过期
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 等待1秒
        let retrieved = try await cacheManager.get(key, as: String.self)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testRemove() async throws {
        // Given
        let key = "remove_key"
        let value = "remove_value"
        try await cacheManager.set(value, forKey: key)
        
        // When
        try await cacheManager.remove(key)
        let retrieved = try await cacheManager.get(key, as: String.self)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testClear() async throws {
        // Given
        try await cacheManager.set("value1", forKey: "key1")
        try await cacheManager.set("value2", forKey: "key2")
        try await cacheManager.set("value3", forKey: "key3")
        
        // When
        try await cacheManager.clear()
        let retrieved1 = try await cacheManager.get("key1", as: String.self)
        let retrieved2 = try await cacheManager.get("key2", as: String.self)
        let retrieved3 = try await cacheManager.get("key3", as: String.self)
        
        // Then
        XCTAssertNil(retrieved1)
        XCTAssertNil(retrieved2)
        XCTAssertNil(retrieved3)
    }
    
    // MARK: - 磁盘缓存测试
    
    func testDiskPersistence() async throws {
        // Given
        let key = "persist_key"
        let value = "persist_value"
        try await cacheManager.set(value, forKey: key)
        
        // When - 重新创建 cache manager
        cacheManager = nil
        cacheManager = await CacheManager(diskCachePath: tempCachePath)
        let retrieved = try await cacheManager.get(key, as: String.self)
        
        // Then
        XCTAssertEqual(retrieved, value)
    }
    
    // MARK: - 统计测试
    
    func testStatistics() async throws {
        // Given
        try await cacheManager.set("value1", forKey: "key1")
        try await cacheManager.set("value2", forKey: "key2")
        
        // When
        let stats = await cacheManager.statistics()
        
        // Then
        XCTAssertEqual(stats.memoryCount, 2)
        XCTAssertTrue(stats.diskCacheEnabled)
    }
}

// MARK: - LLM Cache Key Tests

final class LLMCacheKeyGeneratorTests: XCTestCase {
    func testGenerateKey() {
        // Given
        let messages = [
            LLMMessage(role: .user, content: "Hello"),
            LLMMessage(role: .assistant, content: "Hi")
        ]
        let model = "gpt-4"
        
        // When
        let key1 = LLMCacheKeyGenerator.generateKey(messages: messages, model: model, tools: nil)
        let key2 = LLMCacheKeyGenerator.generateKey(messages: messages, model: model, tools: nil)
        
        // Then - 相同输入应生成相同的键
        XCTAssertEqual(key1, key2)
    }
    
    func testDifferentMessagesGenerateDifferentKeys() {
        // Given
        let messages1 = [LLMMessage(role: .user, content: "Hello")]
        let messages2 = [LLMMessage(role: .user, content: "Hi")]
        let model = "gpt-4"
        
        // When
        let key1 = LLMCacheKeyGenerator.generateKey(messages: messages1, model: model, tools: nil)
        let key2 = LLMCacheKeyGenerator.generateKey(messages: messages2, model: model, tools: nil)
        
        // Then - 不同输入应生成不同的键
        XCTAssertNotEqual(key1, key2)
    }
}

