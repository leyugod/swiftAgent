//
//  Metrics.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 评估指标
public struct EvaluationMetrics: Codable {
    public let totalTests: Int
    public let successCount: Int
    public let failureCount: Int
    public let averageScore: Double
    public let accuracy: Double
    public let customMetrics: [String: Double]
    
    public init(
        totalTests: Int,
        successCount: Int,
        failureCount: Int,
        averageScore: Double,
        accuracy: Double,
        customMetrics: [String: Double] = [:]
    ) {
        self.totalTests = totalTests
        self.successCount = successCount
        self.failureCount = failureCount
        self.averageScore = averageScore
        self.accuracy = accuracy
        self.customMetrics = customMetrics
    }
    
    /// 从评估结果计算指标
    /// - Parameter results: 评估结果数组
    /// - Returns: 评估指标
    public static func from(_ results: [EvaluationResult]) -> EvaluationMetrics {
        let totalTests = results.count
        let successCount = results.filter { $0.success }.count
        let failureCount = totalTests - successCount
        let averageScore = results.isEmpty ? 0 : results.map { $0.score }.reduce(0, +) / Double(totalTests)
        let accuracy = totalTests > 0 ? Double(successCount) / Double(totalTests) : 0
        
        // 聚合自定义指标
        var customMetrics: [String: [Double]] = [:]
        for result in results {
            for (key, value) in result.metrics {
                customMetrics[key, default: []].append(value)
            }
        }
        
        let aggregatedMetrics = customMetrics.mapValues { values in
            values.reduce(0, +) / Double(values.count)
        }
        
        return EvaluationMetrics(
            totalTests: totalTests,
            successCount: successCount,
            failureCount: failureCount,
            averageScore: averageScore,
            accuracy: accuracy,
            customMetrics: aggregatedMetrics
        )
    }
    
    /// 生成报告
    /// - Returns: 报告字符串
    public func generateReport() -> String {
        var report = """
        # 评估报告
        
        ## 总体指标
        - 测试总数: \(totalTests)
        - 成功数: \(successCount)
        - 失败数: \(failureCount)
        - 准确率: \(String(format: "%.2f%%", accuracy * 100))
        - 平均分数: \(String(format: "%.4f", averageScore))
        
        """
        
        if !customMetrics.isEmpty {
            report += "## 详细指标\n"
            for (key, value) in customMetrics.sorted(by: { $0.key < $1.key }) {
                report += "- \(key): \(String(format: "%.4f", value))\n"
            }
        }
        
        return report
    }
}

/// 性能指标
public struct PerformanceMetrics: Codable {
    public let averageLatency: TimeInterval
    public let minLatency: TimeInterval
    public let maxLatency: TimeInterval
    public let throughput: Double
    public let errorRate: Double
    
    public init(
        averageLatency: TimeInterval,
        minLatency: TimeInterval,
        maxLatency: TimeInterval,
        throughput: Double,
        errorRate: Double
    ) {
        self.averageLatency = averageLatency
        self.minLatency = minLatency
        self.maxLatency = maxLatency
        self.throughput = throughput
        self.errorRate = errorRate
    }
    
    /// 生成报告
    /// - Returns: 报告字符串
    public func generateReport() -> String {
        """
        # 性能报告
        
        ## 延迟
        - 平均延迟: \(String(format: "%.2f", averageLatency * 1000))ms
        - 最小延迟: \(String(format: "%.2f", minLatency * 1000))ms
        - 最大延迟: \(String(format: "%.2f", maxLatency * 1000))ms
        
        ## 吞吐量
        - 每秒请求数: \(String(format: "%.2f", throughput))
        
        ## 错误率
        - 错误率: \(String(format: "%.2f%%", errorRate * 100))
        """
    }
}

/// 指标收集器
public actor MetricsCollector {
    private var executionTimes: [TimeInterval] = []
    private var errorCount = 0
    private var totalRequests = 0
    
    public init() {}
    
    /// 记录执行时间
    /// - Parameter duration: 执行时长
    public func recordExecution(duration: TimeInterval) {
        executionTimes.append(duration)
        totalRequests += 1
    }
    
    /// 记录错误
    public func recordError() {
        errorCount += 1
        totalRequests += 1
    }
    
    /// 获取性能指标
    /// - Returns: 性能指标
    public func getPerformanceMetrics() -> PerformanceMetrics {
        guard !executionTimes.isEmpty else {
            return PerformanceMetrics(
                averageLatency: 0,
                minLatency: 0,
                maxLatency: 0,
                throughput: 0,
                errorRate: 0
            )
        }
        
        let avg = executionTimes.reduce(0, +) / Double(executionTimes.count)
        let min = executionTimes.min() ?? 0
        let max = executionTimes.max() ?? 0
        let throughput = avg > 0 ? 1.0 / avg : 0
        let errorRate = totalRequests > 0 ? Double(errorCount) / Double(totalRequests) : 0
        
        return PerformanceMetrics(
            averageLatency: avg,
            minLatency: min,
            maxLatency: max,
            throughput: throughput,
            errorRate: errorRate
        )
    }
    
    /// 重置指标
    public func reset() {
        executionTimes.removeAll()
        errorCount = 0
        totalRequests = 0
    }
}

