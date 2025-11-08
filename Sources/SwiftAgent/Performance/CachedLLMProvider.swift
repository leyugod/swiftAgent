//
//  CachedLLMProvider.swift
//  SwiftAgent
//
//  带缓存的 LLM Provider 包装器
//

import Foundation

/// 带缓存的 LLM Provider
/// 包装现有 LLM Provider 并添加缓存功能
public final class CachedLLMProvider: @unchecked Sendable, LLMProviderProtocol {
    public var modelName: String {
        baseProvider.modelName
    }
    
    private let baseProvider: LLMProviderProtocol
    private let cacheManager: CacheManager
    private let enableCache: Bool
    
    /// 初始化
    /// - Parameters:
    ///   - baseProvider: 基础 LLM Provider
    ///   - cacheManager: 缓存管理器
    ///   - enableCache: 是否启用缓存
    public init(
        baseProvider: LLMProviderProtocol,
        cacheManager: CacheManager,
        enableCache: Bool = true
    ) {
        self.baseProvider = baseProvider
        self.cacheManager = cacheManager
        self.enableCache = enableCache
    }
    
    public func chat(messages: [LLMMessage], tools: [LLMToolFunction]?, temperature: Double) async throws -> LLMResponse {
        // 如果禁用缓存，直接调用基础 Provider
        guard enableCache else {
            return try await baseProvider.chat(messages: messages, tools: tools, temperature: temperature)
        }
        
        // 生成缓存键
        let cacheKey = LLMCacheKeyGenerator.generateKey(
            messages: messages,
            model: modelName,
            tools: tools
        )
        
        // 尝试从缓存获取
        if let cached = try await cacheManager.get(cacheKey, as: LLMResponse.self) {
            return cached
        }
        
        // 调用基础 Provider
        let response = try await baseProvider.chat(messages: messages, tools: tools, temperature: temperature)
        
        // 只缓存非工具调用的响应（工具调用通常是动态的）
        if response.toolCalls == nil || response.toolCalls?.isEmpty == true {
            try await cacheManager.set(response, forKey: cacheKey)
        }
        
        return response
    }
    
    public func chatStream(messages: [LLMMessage], tools: [LLMToolFunction]?, temperature: Double, onChunk: @escaping (String) -> Void) async throws -> LLMResponse {
        // 流式响应不使用缓存
        return try await baseProvider.chatStream(messages: messages, tools: tools, temperature: temperature, onChunk: onChunk)
    }
}


