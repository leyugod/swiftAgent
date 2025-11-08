//
//  ConnectionPool.swift
//  SwiftAgent
//
//  URL 连接池管理
//

import Foundation

/// URL 会话连接池
/// 管理和复用 URLSession 实例，提高性能
public actor URLSessionPool {
    private var sessions: [String: URLSession] = [:]
    private let maxSessions: Int
    private let sessionConfiguration: URLSessionConfiguration
    
    /// 初始化
    /// - Parameters:
    ///   - maxSessions: 最大会话数量
    ///   - configuration: URL 会话配置
    public init(
        maxSessions: Int = 10,
        configuration: URLSessionConfiguration = .default
    ) {
        self.maxSessions = maxSessions
        self.sessionConfiguration = configuration
        
        // 优化配置
        self.sessionConfiguration.httpMaximumConnectionsPerHost = 6
        self.sessionConfiguration.requestCachePolicy = .returnCacheDataElseLoad
        self.sessionConfiguration.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,    // 50 MB
            diskCapacity: 100 * 1024 * 1024,     // 100 MB
            diskPath: "swiftagent_url_cache"
        )
    }
    
    /// 获取或创建会话
    /// - Parameter key: 会话键（通常使用域名）
    /// - Returns: URL 会话
    public func getSession(for key: String) -> URLSession {
        if let existing = sessions[key] {
            return existing
        }
        
        // 检查是否达到最大数量
        if sessions.count >= maxSessions {
            // 移除最旧的会话
            if let oldestKey = sessions.keys.first {
                sessions[oldestKey]?.finishTasksAndInvalidate()
                sessions.removeValue(forKey: oldestKey)
            }
        }
        
        let newSession = URLSession(configuration: sessionConfiguration)
        sessions[key] = newSession
        return newSession
    }
    
    /// 清理特定会话
    /// - Parameter key: 会话键
    public func invalidateSession(for key: String) {
        if let session = sessions[key] {
            session.finishTasksAndInvalidate()
            sessions.removeValue(forKey: key)
        }
    }
    
    /// 清理所有会话
    public func invalidateAllSessions() {
        for session in sessions.values {
            session.finishTasksAndInvalidate()
        }
        sessions.removeAll()
    }
    
    /// 获取统计信息
    public func statistics() -> PoolStatistics {
        return PoolStatistics(
            activeSessionCount: sessions.count,
            maxSessions: maxSessions
        )
    }
}

/// 连接池统计信息
public struct PoolStatistics {
    public let activeSessionCount: Int
    public let maxSessions: Int
    
    public var utilizationPercent: Double {
        Double(activeSessionCount) / Double(maxSessions) * 100
    }
}

// MARK: - Batch Request Handler

/// 批量请求处理器
/// 将多个请求打包处理，提高并发效率
public actor BatchRequestHandler {
    private let maxBatchSize: Int
    private let batchDelay: TimeInterval
    private var pendingRequests: [(request: URLRequest, continuation: CheckedContinuation<(Data, URLResponse), Error>)] = []
    private var batchTask: Task<Void, Never>?
    
    /// 初始化
    /// - Parameters:
    ///   - maxBatchSize: 最大批次大小
    ///   - batchDelay: 批次延迟（秒）
    public init(
        maxBatchSize: Int = 10,
        batchDelay: TimeInterval = 0.1
    ) {
        self.maxBatchSize = maxBatchSize
        self.batchDelay = batchDelay
    }
    
    /// 添加请求到批次
    /// - Parameter request: URL 请求
    /// - Returns: 响应数据和元数据
    public func addRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await self._addRequest(request, continuation: continuation)
            }
        }
    }
    
    private func _addRequest(
        _ request: URLRequest,
        continuation: CheckedContinuation<(Data, URLResponse), Error>
    ) {
        pendingRequests.append((request, continuation))
        
        // 如果达到批次大小，立即处理
        if pendingRequests.count >= maxBatchSize {
            processBatch()
        } else if batchTask == nil {
            // 启动延迟处理任务
            batchTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(batchDelay * 1_000_000_000))
                await self.processBatch()
            }
        }
    }
    
    private func processBatch() {
        guard !pendingRequests.isEmpty else { return }
        
        let batch = pendingRequests
        pendingRequests.removeAll()
        batchTask?.cancel()
        batchTask = nil
        
        // 并发处理所有请求
        Task {
            await withTaskGroup(of: Void.self) { group in
                for (request, continuation) in batch {
                    group.addTask {
                        do {
                            let (data, response) = try await URLSession.shared.data(for: request)
                            continuation.resume(returning: (data, response))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Memory Pressure Handler

/// 内存压力处理器
/// 监控和响应内存压力事件
public actor MemoryPressureHandler {
    private var pressureHandlers: [(MemoryPressureLevel) -> Void] = []
    private var isMonitoring = false
    
    public enum MemoryPressureLevel {
        case normal
        case warning
        case critical
    }
    
    /// 注册压力处理器
    /// - Parameter handler: 处理闭包
    public func registerHandler(_ handler: @escaping (MemoryPressureLevel) -> Void) {
        pressureHandlers.append(handler)
        
        if !isMonitoring {
            startMonitoring()
        }
    }
    
    private func startMonitoring() {
        isMonitoring = true
        
        #if os(iOS) || os(tvOS) || os(watchOS)
        // iOS/tvOS/watchOS: 使用通知
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handlePressure(.warning)
            }
        }
        #endif
        
        // macOS: 使用 dispatch_source
        #if os(macOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task {
                let level: MemoryPressureLevel = source.data.contains(.critical) ? .critical : .warning
                await self?.handlePressure(level)
            }
        }
        source.resume()
        #endif
    }
    
    private func handlePressure(_ level: MemoryPressureLevel) {
        for handler in pressureHandlers {
            handler(level)
        }
    }
}

