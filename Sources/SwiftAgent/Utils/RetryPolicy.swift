//
//  RetryPolicy.swift
//  SwiftAgent
//
//  重试策略工具
//

import Foundation

/// 重试策略配置
public struct RetryPolicy {
    /// 最大重试次数
    public let maxRetries: Int
    
    /// 初始延迟（秒）
    public let initialDelay: TimeInterval
    
    /// 最大延迟（秒）
    public let maxDelay: TimeInterval
    
    /// 退避倍数
    public let backoffMultiplier: Double
    
    /// 可重试的错误类型判断
    public let shouldRetry: (Error) -> Bool
    
    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        backoffMultiplier: Double = 2.0,
        shouldRetry: @escaping (Error) -> Bool = { _ in true }
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.shouldRetry = shouldRetry
    }
    
    /// 默认重试策略（适用于网络请求）
    public static let `default` = RetryPolicy(
        maxRetries: 3,
        initialDelay: 1.0,
        maxDelay: 60.0,
        backoffMultiplier: 2.0,
        shouldRetry: { error in
            // 判断是否是可重试的错误
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost:
                    return true
                default:
                    return false
                }
            }
            
            // NSError with specific codes
            if let nsError = error as NSError? {
                // HTTP 5xx errors are retryable
                if nsError.domain == "HTTPError" && nsError.code >= 500 && nsError.code < 600 {
                    return true
                }
                // Rate limit errors (429)
                if nsError.domain == "HTTPError" && nsError.code == 429 {
                    return true
                }
            }
            
            return false
        }
    )
    
    /// 保守的重试策略（只重试一次）
    public static let conservative = RetryPolicy(
        maxRetries: 1,
        initialDelay: 2.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0
    )
    
    /// 激进的重试策略（多次重试）
    public static let aggressive = RetryPolicy(
        maxRetries: 5,
        initialDelay: 0.5,
        maxDelay: 30.0,
        backoffMultiplier: 2.0
    )
}

/// 重试执行器
public actor RetryExecutor {
    private let policy: RetryPolicy
    
    public init(policy: RetryPolicy = .default) {
        self.policy = policy
    }
    
    /// 执行带重试的操作
    /// - Parameter operation: 要执行的异步操作
    /// - Returns: 操作结果
    /// - Throws: 如果所有重试都失败，抛出最后一次的错误
    public func execute<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0
        
        while attempt <= policy.maxRetries {
            do {
                // 尝试执行操作
                return try await operation()
            } catch {
                lastError = error
                
                // 检查是否应该重试
                guard attempt < policy.maxRetries && policy.shouldRetry(error) else {
                    throw error
                }
                
                // 计算延迟时间（指数退避）
                let delay = calculateDelay(for: attempt)
                
                // 等待后重试
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                attempt += 1
            }
        }
        
        // 如果所有重试都失败，抛出最后一次的错误
        throw lastError ?? RetryError.allRetriesFailed
    }
    
    /// 计算延迟时间（指数退避）
    private func calculateDelay(for attempt: Int) -> TimeInterval {
        let delay = policy.initialDelay * pow(policy.backoffMultiplier, Double(attempt))
        return min(delay, policy.maxDelay)
    }
}

/// 重试错误
public enum RetryError: Error, LocalizedError {
    case allRetriesFailed
    case maxRetriesExceeded
    
    public var errorDescription: String? {
        switch self {
        case .allRetriesFailed:
            return "所有重试尝试都失败了"
        case .maxRetriesExceeded:
            return "超过最大重试次数"
        }
    }
}

// MARK: - 便捷扩展

extension RetryExecutor {
    /// 执行带重试的操作（带进度回调）
    /// - Parameters:
    ///   - operation: 要执行的异步操作
    ///   - onRetry: 重试时的回调（参数为重试次数）
    /// - Returns: 操作结果
    public func execute<T>(
        _ operation: @escaping () async throws -> T,
        onRetry: @escaping (Int) -> Void
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0
        
        while attempt <= policy.maxRetries {
            do {
                if attempt > 0 {
                    onRetry(attempt)
                }
                return try await operation()
            } catch {
                lastError = error
                
                guard attempt < policy.maxRetries && policy.shouldRetry(error) else {
                    throw error
                }
                
                let delay = calculateDelay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                attempt += 1
            }
        }
        
        throw lastError ?? RetryError.allRetriesFailed
    }
}

