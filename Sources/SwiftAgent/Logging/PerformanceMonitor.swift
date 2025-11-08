//
//  PerformanceMonitor.swift
//  SwiftAgent
//
//  性能监控系统
//

import Foundation

// MARK: - Performance Metric

/// 性能指标
public struct PerformanceMetric: Codable {
    public let name: String
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let metadata: [String: String]?
    
    public init(
        name: String,
        startTime: Date,
        endTime: Date,
        metadata: [String: String]? = nil
    ) {
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.metadata = metadata
    }
    
    /// 格式化的性能报告
    public var formatted: String {
        var result = "⏱  [\(name)] Duration: \(String(format: "%.3f", duration))s"
        if let metadata = metadata, !metadata.isEmpty {
            let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            result += " | \(metaStr)"
        }
        return result
    }
}

// MARK: - Performance Statistics

/// 性能统计
public struct PerformanceStatistics {
    public let name: String
    public let count: Int
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let minDuration: TimeInterval
    public let maxDuration: TimeInterval
    
    public init(metrics: [PerformanceMetric], name: String) {
        self.name = name
        self.count = metrics.count
        self.totalDuration = metrics.reduce(0) { $0 + $1.duration }
        self.averageDuration = count > 0 ? totalDuration / Double(count) : 0
        self.minDuration = metrics.map(\.duration).min() ?? 0
        self.maxDuration = metrics.map(\.duration).max() ?? 0
    }
    
    /// 格式化的统计报告
    public var formatted: String {
        """
        Performance Statistics - \(name):
          Count: \(count)
          Total: \(String(format: "%.3f", totalDuration))s
          Average: \(String(format: "%.3f", averageDuration))s
          Min: \(String(format: "%.3f", minDuration))s
          Max: \(String(format: "%.3f", maxDuration))s
        """
    }
}

// MARK: - Performance Monitor

/// 性能监控器
public actor PerformanceMonitor {
    public static let shared = PerformanceMonitor()
    
    private var metrics: [String: [PerformanceMetric]] = [:]
    private var isEnabled: Bool = true
    
    private init() {}
    
    /// 启用/禁用性能监控
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// 记录性能指标
    public func record(_ metric: PerformanceMetric) {
        guard isEnabled else { return }
        
        if metrics[metric.name] == nil {
            metrics[metric.name] = []
        }
        metrics[metric.name]?.append(metric)
    }
    
    /// 获取指定名称的指标
    public func getMetrics(for name: String) -> [PerformanceMetric] {
        metrics[name] ?? []
    }
    
    /// 获取所有指标
    public func getAllMetrics() -> [String: [PerformanceMetric]] {
        metrics
    }
    
    /// 获取性能统计
    public func getStatistics(for name: String) -> PerformanceStatistics? {
        guard let nameMetrics = metrics[name], !nameMetrics.isEmpty else {
            return nil
        }
        return PerformanceStatistics(metrics: nameMetrics, name: name)
    }
    
    /// 获取所有统计信息
    public func getAllStatistics() -> [PerformanceStatistics] {
        metrics.compactMap { name, nameMetrics in
            guard !nameMetrics.isEmpty else { return nil }
            return PerformanceStatistics(metrics: nameMetrics, name: name)
        }
    }
    
    /// 清空指定名称的指标
    public func clear(name: String) {
        metrics[name] = nil
    }
    
    /// 清空所有指标
    public func clearAll() {
        metrics.removeAll()
    }
    
    /// 生成性能报告
    public func generateReport() -> String {
        let allStats = getAllStatistics()
        
        guard !allStats.isEmpty else {
            return "No performance data available."
        }
        
        var report = """
        ╔═══════════════════════════════════════════════════════════════╗
        ║              Performance Monitoring Report                     ║
        ╚═══════════════════════════════════════════════════════════════╝
        
        """
        
        for stats in allStats.sorted(by: { $0.name < $1.name }) {
            report += stats.formatted + "\n\n"
        }
        
        return report
    }
}

// MARK: - Performance Tracker

/// 性能追踪器（用于自动计时）
public actor PerformanceTracker {
    private let name: String
    private let startTime: Date
    private var metadata: [String: String]
    
    public init(name: String, metadata: [String: String] = [:]) {
        self.name = name
        self.startTime = Date()
        self.metadata = metadata
        
        Task {
            await Logger.shared.debug("Started tracking: \(name)", category: "performance")
        }
    }
    
    /// 添加元数据
    public func addMetadata(_ key: String, value: String) {
        metadata[key] = value
    }
    
    /// 完成追踪
    public func finish() async {
        let endTime = Date()
        let metric = PerformanceMetric(
            name: name,
            startTime: startTime,
            endTime: endTime,
            metadata: metadata.isEmpty ? nil : metadata
        )
        
        await PerformanceMonitor.shared.record(metric)
        await Logger.shared.debug(metric.formatted, category: "performance")
    }
}

// MARK: - Convenience Functions

/// 测量代码块的执行时间
public func measurePerformance<T>(
    name: String,
    metadata: [String: String] = [:],
    block: () async throws -> T
) async rethrows -> T {
    let tracker = PerformanceTracker(name: name, metadata: metadata)
    let result = try await block()
    await tracker.finish()
    return result
}

/// 测量代码块的执行时间（带返回值）
public func measurePerformance<T>(
    name: String,
    metadata: [String: String] = [:],
    block: () throws -> T
) rethrows -> T {
    let startTime = Date()
    let result = try block()
    let endTime = Date()
    
    let metric = PerformanceMetric(
        name: name,
        startTime: startTime,
        endTime: endTime,
        metadata: metadata.isEmpty ? nil : metadata
    )
    
    Task {
        await PerformanceMonitor.shared.record(metric)
    }
    
    return result
}

// MARK: - Performance Categories

/// 性能监控类别
public enum PerformanceCategory {
    public static let llmCall = "llm.call"
    public static let toolExecution = "tool.execution"
    public static let agentRun = "agent.run"
    public static let agentLoop = "agent.loop"
    public static let memorySearch = "memory.search"
    public static let memoryStore = "memory.store"
    public static let contextBuild = "context.build"
    public static let messageHistory = "message.history"
}

