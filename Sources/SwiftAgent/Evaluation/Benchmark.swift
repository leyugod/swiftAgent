//
//  Benchmark.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 基准测试
/// 提供标准化的测试流程和报告
public actor Benchmark {
    private let name: String
    private let agent: AgentProtocol
    private let evaluators: [EvaluatorProtocol]
    private let metricsCollector = MetricsCollector()
    
    public init(
        name: String,
        agent: AgentProtocol,
        evaluators: [EvaluatorProtocol]
    ) {
        self.name = name
        self.agent = agent
        self.evaluators = evaluators
    }
    
    /// 运行基准测试
    /// - Parameter testCases: 测试用例数组
    /// - Returns: 基准测试报告
    public func run(_ testCases: [BenchmarkTestCase]) async throws -> BenchmarkReport {
        var allResults: [String: [EvaluationResult]] = [:]
        
        for evaluator in evaluators {
            var results: [EvaluationResult] = []
            
            for testCase in testCases {
                // 运行测试用例
                let startTime = Date()
                let output: String
                
                do {
                    output = try await agent.run(testCase.input)
                    let duration = Date().timeIntervalSince(startTime)
                    await metricsCollector.recordExecution(duration: duration)
                } catch {
                    await metricsCollector.recordError()
                    throw error
                }
                
                // 评估结果
                let result = try await evaluator.evaluate(
                    input: testCase.input,
                    output: output,
                    expected: testCase.expected
                )
                
                results.append(result)
            }
            
            allResults[evaluator.name] = results
        }
        
        // 收集性能指标
        let performanceMetrics = await metricsCollector.getPerformanceMetrics()
        
        return BenchmarkReport(
            name: name,
            results: allResults,
            performanceMetrics: performanceMetrics,
            timestamp: Date()
        )
    }
    
    /// 运行单个测试用例
    /// - Parameter testCase: 测试用例
    /// - Returns: 评估结果字典
    public func runSingle(_ testCase: BenchmarkTestCase) async throws -> [String: EvaluationResult] {
        var results: [String: EvaluationResult] = [:]
        
        let startTime = Date()
        let output = try await agent.run(testCase.input)
        let duration = Date().timeIntervalSince(startTime)
        await metricsCollector.recordExecution(duration: duration)
        
        for evaluator in evaluators {
            let result = try await evaluator.evaluate(
                input: testCase.input,
                output: output,
                expected: testCase.expected
            )
            results[evaluator.name] = result
        }
        
        return results
    }
}

/// 基准测试用例
public struct BenchmarkTestCase: Codable {
    public let id: String
    public let input: String
    public let expected: String?
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        input: String,
        expected: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.input = input
        self.expected = expected
        self.metadata = metadata
    }
}

/// 基准测试报告
public struct BenchmarkReport: Codable {
    public let name: String
    public let results: [String: [EvaluationResult]]
    public let performanceMetrics: PerformanceMetrics
    public let timestamp: Date
    
    public init(
        name: String,
        results: [String: [EvaluationResult]],
        performanceMetrics: PerformanceMetrics,
        timestamp: Date
    ) {
        self.name = name
        self.results = results
        self.performanceMetrics = performanceMetrics
        self.timestamp = timestamp
    }
    
    /// 生成汇总报告
    /// - Returns: 报告字符串
    public func generateReport() -> String {
        var report = """
        # 基准测试报告: \(name)
        
        时间: \(formatDate(timestamp))
        
        """
        
        // 各评估器的结果
        for (evaluatorName, evaluationResults) in results.sorted(by: { $0.key < $1.key }) {
            let metrics = EvaluationMetrics.from(evaluationResults)
            report += """
            ## \(evaluatorName) 评估器
            
            \(metrics.generateReport())
            
            """
        }
        
        // 性能指标
        report += performanceMetrics.generateReport()
        
        return report
    }
    
    /// 导出为 JSON
    /// - Returns: JSON 字符串
    public func exportToJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw BenchmarkError.exportFailed
        }
        return json
    }
    
    // MARK: - Private Helper
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

/// 基准测试错误
public enum BenchmarkError: Error {
    case noTestCases
    case noEvaluators
    case executionFailed(String)
    case exportFailed
}

