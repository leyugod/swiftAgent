//
//  Evaluator.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 评估结果
public struct EvaluationResult: Codable, Sendable {
    public let testCase: String
    public let success: Bool
    public let score: Double
    public let metrics: [String: Double]
    public let details: String
    public let timestamp: Date
    
    public init(
        testCase: String,
        success: Bool,
        score: Double,
        metrics: [String: Double] = [:],
        details: String = "",
        timestamp: Date = Date()
    ) {
        self.testCase = testCase
        self.success = success
        self.score = score
        self.metrics = metrics
        self.details = details
        self.timestamp = timestamp
    }
}

/// 评估器协议
@preconcurrency
public protocol EvaluatorProtocol: Sendable {
    /// 评估名称
    var name: String { get }
    
    /// 评估单个测试用例
    /// - Parameters:
    ///   - input: 输入
    ///   - output: Agent 输出
    ///   - expected: 期望输出（可选）
    /// - Returns: 评估结果
    func evaluate(
        input: String,
        output: String,
        expected: String?
    ) async throws -> EvaluationResult
    
    /// 批量评估
    /// - Parameter testCases: 测试用例数组
    /// - Returns: 评估结果数组
    func evaluateBatch(
        _ testCases: [(input: String, output: String, expected: String?)]
    ) async throws -> [EvaluationResult]
}

/// 准确性评估器
/// 评估输出是否与期望值匹配
public actor AccuracyEvaluator: EvaluatorProtocol {
    public let name = "Accuracy"
    private let caseSensitive: Bool
    private let fuzzyMatch: Bool
    
    public init(caseSensitive: Bool = false, fuzzyMatch: Bool = true) {
        self.caseSensitive = caseSensitive
        self.fuzzyMatch = fuzzyMatch
    }
    
    public func evaluate(
        input: String,
        output: String,
        expected: String?
    ) async throws -> EvaluationResult {
        guard let expected = expected else {
            return EvaluationResult(
                testCase: input,
                success: false,
                score: 0,
                details: "No expected output provided"
            )
        }
        
        let outputNormalized = caseSensitive ? output : output.lowercased()
        let expectedNormalized = caseSensitive ? expected : expected.lowercased()
        
        let success: Bool
        let score: Double
        
        if fuzzyMatch {
            // 使用编辑距离计算相似度
            let similarity = stringSimilarity(outputNormalized, expectedNormalized)
            score = similarity
            success = similarity >= 0.8
        } else {
            // 完全匹配
            success = outputNormalized == expectedNormalized
            score = success ? 1.0 : 0.0
        }
        
        return EvaluationResult(
            testCase: input,
            success: success,
            score: score,
            metrics: ["similarity": score],
            details: success ? "Match" : "Mismatch"
        )
    }
    
    public func evaluateBatch(
        _ testCases: [(input: String, output: String, expected: String?)]
    ) async throws -> [EvaluationResult] {
        var results: [EvaluationResult] = []
        
        for testCase in testCases {
            let result = try await evaluate(
                input: testCase.input,
                output: testCase.output,
                expected: testCase.expected
            )
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Private Helper
    
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        let len1 = s1.count
        let len2 = s2.count
        
        guard len1 > 0 && len2 > 0 else {
            return len1 == len2 ? 1.0 : 0.0
        }
        
        let distance = levenshteinDistance(s1, s2)
        let maxLen = Double(max(len1, len2))
        return 1.0 - (Double(distance) / maxLen)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let len1 = s1Array.count
        let len2 = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 {
            matrix[i][0] = i
        }
        
        for j in 0...len2 {
            matrix[0][j] = j
        }
        
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[len1][len2]
    }
}

/// 工具调用评估器
/// 评估 Agent 是否正确调用了工具
public actor ToolCallEvaluator: EvaluatorProtocol {
    public let name = "ToolCall"
    
    public init() {}
    
    public func evaluate(
        input: String,
        output: String,
        expected: String?
    ) async throws -> EvaluationResult {
        // 检查输出中是否包含工具调用
        let hasToolCall = output.contains("Action:") || output.contains("tool_name(")
        
        // 如果有期望值，检查是否调用了正确的工具
        if let expected = expected {
            let expectedTools = extractToolNames(from: expected)
            let actualTools = extractToolNames(from: output)
            
            let correctCalls = Set(expectedTools).intersection(Set(actualTools))
            let score = expectedTools.isEmpty ? 0 : Double(correctCalls.count) / Double(expectedTools.count)
            
            return EvaluationResult(
                testCase: input,
                success: score >= 0.8,
                score: score,
                metrics: [
                    "expected_tools": Double(expectedTools.count),
                    "actual_tools": Double(actualTools.count),
                    "correct_calls": Double(correctCalls.count)
                ],
                details: "Expected: \(expectedTools), Actual: \(actualTools)"
            )
        }
        
        // 没有期望值，只检查是否有工具调用
        return EvaluationResult(
            testCase: input,
            success: hasToolCall,
            score: hasToolCall ? 1.0 : 0.0,
            details: hasToolCall ? "Tool call detected" : "No tool call"
        )
    }
    
    public func evaluateBatch(
        _ testCases: [(input: String, output: String, expected: String?)]
    ) async throws -> [EvaluationResult] {
        var results: [EvaluationResult] = []
        
        for testCase in testCases {
            let result = try await evaluate(
                input: testCase.input,
                output: testCase.output,
                expected: testCase.expected
            )
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Private Helper
    
    private func extractToolNames(from text: String) -> [String] {
        let pattern = #"(\w+)\("#
        var toolNames: [String] = []
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    toolNames.append(String(text[range]))
                }
            }
        }
        
        return toolNames
    }
}

/// LLM 评估器
/// 使用 LLM 进行主观评估
public actor LLMEvaluator: EvaluatorProtocol {
    public let name = "LLM"
    private let llmProvider: LLMProviderProtocol
    
    public init(llmProvider: LLMProviderProtocol) {
        self.llmProvider = llmProvider
    }
    
    public func evaluate(
        input: String,
        output: String,
        expected: String?
    ) async throws -> EvaluationResult {
        let prompt = buildEvaluationPrompt(input: input, output: output, expected: expected)
        
        let messages = [LLMMessage.user(prompt)]
        let response = try await llmProvider.chat(
            messages: messages,
            tools: nil,
            temperature: 0.3
        )
        
        // 解析 LLM 的评估结果
        let (success, score, details) = parseEvaluationResponse(response.content)
        
        return EvaluationResult(
            testCase: input,
            success: success,
            score: score,
            details: details
        )
    }
    
    public func evaluateBatch(
        _ testCases: [(input: String, output: String, expected: String?)]
    ) async throws -> [EvaluationResult] {
        var results: [EvaluationResult] = []
        
        for testCase in testCases {
            let result = try await evaluate(
                input: testCase.input,
                output: testCase.output,
                expected: testCase.expected
            )
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func buildEvaluationPrompt(input: String, output: String, expected: String?) -> String {
        var prompt = """
        请评估以下 Agent 的输出质量。
        
        用户输入：
        \(input)
        
        Agent 输出：
        \(output)
        
        """
        
        if let expected = expected {
            prompt += """
            期望输出：
            \(expected)
            
            """
        }
        
        prompt += """
        请从以下维度进行评估：
        1. 相关性：输出是否回答了用户的问题
        2. 准确性：信息是否正确
        3. 完整性：是否提供了充分的信息
        4. 清晰度：表达是否清晰易懂
        
        请给出评分（0-1之间）和简要评价。格式如下：
        Score: 0.85
        Details: 评价内容...
        """
        
        return prompt
    }
    
    private func parseEvaluationResponse(_ response: String) -> (Bool, Double, String) {
        var score = 0.5
        var details = response
        
        // 提取分数
        let scorePattern = #"Score:\s*(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: scorePattern),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response),
           let scoreValue = Double(response[range]) {
            score = scoreValue
        }
        
        // 提取详情
        let detailsPattern = #"Details:\s*(.+)"#
        if let regex = try? NSRegularExpression(pattern: detailsPattern, options: .dotMatchesLineSeparators),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response) {
            details = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return (score >= 0.7, score, details)
    }
}

