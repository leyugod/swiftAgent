//
//  CacheManager.swift
//  SwiftAgent
//
//  LLM 响应缓存管理
//

import Foundation

// MARK: - Cache Entry

/// 缓存条目
public struct CacheEntry<T: Codable>: Codable {
    public let value: T
    public let expirationDate: Date
    
    public var isExpired: Bool {
        Date() > expirationDate
    }
    
    public init(value: T, ttl: TimeInterval) {
        self.value = value
        self.expirationDate = Date().addingTimeInterval(ttl)
    }
}

// MARK: - Cache Manager

/// 缓存管理器
/// 用于缓存 LLM 响应，减少 API 调用成本
public actor CacheManager {
    private var memoryCache: [String: Any] = [:]
    private let diskCacheURL: URL?
    private let defaultTTL: TimeInterval
    private let maxMemorySize: Int
    
    /// 初始化
    /// - Parameters:
    ///   - diskCachePath: 磁盘缓存路径（可选）
    ///   - defaultTTL: 默认缓存过期时间（秒）
    ///   - maxMemorySize: 最大内存缓存数量
    public init(
        diskCachePath: String? = nil,
        defaultTTL: TimeInterval = 3600,
        maxMemorySize: Int = 100
    ) {
        self.defaultTTL = defaultTTL
        self.maxMemorySize = maxMemorySize
        
        if let path = diskCachePath {
            self.diskCacheURL = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
        } else {
            self.diskCacheURL = nil
        }
    }
    
    // MARK: - Memory Cache
    
    /// 设置缓存
    public func set<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) throws {
        let entry = CacheEntry(value: value, ttl: ttl ?? defaultTTL)
        memoryCache[key] = entry
        
        // 清理过期缓存
        if memoryCache.count > maxMemorySize {
            try cleanExpiredEntries()
        }
        
        // 写入磁盘缓存
        if let diskURL = diskCacheURL {
            try saveToDisk(entry, forKey: key, at: diskURL)
        }
    }
    
    /// 获取缓存
    public func get<T: Codable>(_ key: String, as type: T.Type) throws -> T? {
        // 先检查内存缓存
        if let entry = memoryCache[key] as? CacheEntry<T> {
            if entry.isExpired {
                memoryCache.removeValue(forKey: key)
                return nil
            }
            return entry.value
        }
        
        // 检查磁盘缓存
        if let diskURL = diskCacheURL {
            if let entry = try loadFromDisk(key, as: CacheEntry<T>.self, at: diskURL) {
                if entry.isExpired {
                    try? remove(key)
                    return nil
                }
                // 恢复到内存缓存
                memoryCache[key] = entry
                return entry.value
            }
        }
        
        return nil
    }
    
    /// 删除缓存
    public func remove(_ key: String) throws {
        memoryCache.removeValue(forKey: key)
        
        if let diskURL = diskCacheURL {
            let fileURL = diskURL.appendingPathComponent("\(key).cache")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    /// 清空所有缓存
    public func clear() throws {
        memoryCache.removeAll()
        
        if let diskURL = diskCacheURL {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: diskURL, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "cache" {
                try fileManager.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func cleanExpiredEntries() throws {
        let expiredKeys = memoryCache.filter { key, value in
            if let entry = value as? (any CacheEntryProtocol) {
                return entry.isExpired
            }
            return false
        }.map { $0.key }
        
        for key in expiredKeys {
            try remove(key)
        }
        
        // 如果还是超出限制，移除最旧的
        if memoryCache.count > maxMemorySize {
            let keysToRemove = Array(memoryCache.keys.prefix(memoryCache.count - maxMemorySize))
            for key in keysToRemove {
                memoryCache.removeValue(forKey: key)
            }
        }
    }
    
    private func saveToDisk<T: Codable>(_ entry: CacheEntry<T>, forKey key: String, at baseURL: URL) throws {
        let fileURL = baseURL.appendingPathComponent("\(key).cache")
        let data = try JSONEncoder().encode(entry)
        try data.write(to: fileURL)
    }
    
    private func loadFromDisk<T: Codable>(_ key: String, as type: T.Type, at baseURL: URL) throws -> T? {
        let fileURL = baseURL.appendingPathComponent("\(key).cache")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Cache Statistics
    
    /// 获取缓存统计
    public func statistics() -> CacheStatistics {
        return CacheStatistics(
            memoryCount: memoryCache.count,
            maxMemorySize: maxMemorySize,
            diskCacheEnabled: diskCacheURL != nil
        )
    }
}

// MARK: - Cache Entry Protocol

private protocol CacheEntryProtocol {
    var isExpired: Bool { get }
}

extension CacheEntry: CacheEntryProtocol {}

// MARK: - Cache Statistics

/// 缓存统计信息
public struct CacheStatistics {
    public let memoryCount: Int
    public let maxMemorySize: Int
    public let diskCacheEnabled: Bool
    
    public var memoryUsagePercent: Double {
        Double(memoryCount) / Double(maxMemorySize) * 100
    }
}

// MARK: - LLM Cache Key Generator

/// LLM 缓存键生成器
public struct LLMCacheKeyGenerator {
    /// 生成缓存键
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - model: 模型名称
    ///   - tools: 工具列表（可选）
    /// - Returns: 缓存键
    public static func generateKey(
        messages: [LLMMessage],
        model: String,
        tools: [LLMToolFunction]? = nil
    ) -> String {
        var components: [String] = [model]
        
        // 添加消息内容
        let messageHash = messages.map { "\($0.role.rawValue):\($0.content)" }.joined(separator: "|")
        components.append(messageHash)
        
        // 添加工具信息
        if let tools = tools {
            let toolsHash = tools.map { $0.name }.joined(separator: ",")
            components.append(toolsHash)
        }
        
        // 生成 SHA256 哈希
        let combined = components.joined(separator: ":")
        return combined.sha256Hash()
    }
}

// MARK: - String SHA256 Extension

private extension String {
    func sha256Hash() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// 导入 CommonCrypto
import CommonCrypto

