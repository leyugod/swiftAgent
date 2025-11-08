//
//  CalculatorTool.swift
//  SwiftAgent
//
//  数学计算工具
//

import Foundation

/// 数学计算工具
/// 支持基本的数学运算和表达式求值
public struct CalculatorTool: ToolProtocol {
    public let name = "calculator"
    public let description = "执行数学计算。支持基本运算（+、-、*、/）、幂运算（^）、括号和常见数学函数（sin、cos、sqrt等）。"
    
    public var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "expression",
                type: "string",
                description: "要计算的数学表达式，例如：'2 + 2'、'sqrt(16)'、'sin(3.14/2)'",
                required: true
            )
        ]
    }
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let expression = arguments["expression"] as? String else {
            throw ToolError.invalidArguments("缺少 'expression' 参数")
        }
        
        do {
            let result = try evaluateExpression(expression)
            return "计算结果：\(result)"
        } catch {
            throw ToolError.executionFailed("计算失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// 评估数学表达式
    private func evaluateExpression(_ expression: String) throws -> Double {
        // 清理表达式
        let cleanedExpression = expression
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        
        // 处理数学函数
        var processedExpression = cleanedExpression
        processedExpression = try replaceMathFunctions(processedExpression)
        
        // 使用 NSExpression 求值
        let nsExpression = NSExpression(format: processedExpression)
        
        guard let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw CalculatorError.invalidExpression
        }
        
        return result.doubleValue
    }
    
    /// 替换数学函数为可计算的形式
    private func replaceMathFunctions(_ expression: String) throws -> String {
        var result = expression
        
        // 处理常见数学函数
        let functions: [(String, (Double) -> Double)] = [
            ("sqrt", sqrt),
            ("abs", abs),
            ("sin", sin),
            ("cos", cos),
            ("tan", tan),
            ("log", log10),
            ("ln", log)
        ]
        
        for (funcName, function) in functions {
            while let range = result.range(of: "\(funcName)\\([^)]+\\)", options: .regularExpression) {
                let match = String(result[range])
                let argStart = match.index(match.startIndex, offsetBy: funcName.count + 1)
                let argEnd = match.index(before: match.endIndex)
                let argString = String(match[argStart..<argEnd])
                
                // 递归计算参数
                let argValue = try evaluateExpression(argString)
                let funcResult = function(argValue)
                
                result.replaceSubrange(range, with: String(funcResult))
            }
        }
        
        // 处理幂运算 (^)
        while let range = result.range(of: "[0-9.]+\\^[0-9.]+", options: .regularExpression) {
            let match = String(result[range])
            let components = match.components(separatedBy: "^")
            if components.count == 2,
               let base = Double(components[0]),
               let exponent = Double(components[1]) {
                let powResult = pow(base, exponent)
                result.replaceSubrange(range, with: String(powResult))
            }
        }
        
        return result
    }
}

// MARK: - Calculator Error

enum CalculatorError: Error, LocalizedError {
    case invalidExpression
    case divisionByZero
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .invalidExpression:
            return "无效的数学表达式"
        case .divisionByZero:
            return "除数不能为零"
        case .unsupportedOperation:
            return "不支持的数学运算"
        }
    }
}

