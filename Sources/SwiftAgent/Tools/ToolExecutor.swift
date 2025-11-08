//
//  ToolExecutor.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 工具执行器
/// 负责执行工具调用并处理结果
public actor ToolExecutor {
    private let registry: ToolRegistry
    
    public init(registry: ToolRegistry) {
        self.registry = registry
    }
    
    /// 执行工具调用
    /// - Parameter toolCall: LLM 工具调用
    /// - Returns: 执行结果观察
    public func execute(_ toolCall: LLMToolCall) async throws -> Observation {
        // 获取工具
        guard let tool = await registry.get(toolCall.function.name) else {
            throw ToolError.toolNotFound(toolCall.function.name)
        }
        
        // 解析参数
        let arguments = try parseArguments(toolCall.function.arguments)
        
        // 验证参数
        try validateArguments(arguments, against: tool.parameters)
        
        // 执行工具
        do {
            let result = try await tool.execute(arguments: arguments)
            return Observation(
                content: result,
                toolName: tool.name,
                metadata: ["tool_call_id": toolCall.id]
            )
        } catch {
            throw ToolError.executionFailed("工具 '\(tool.name)' 执行失败: \(error.localizedDescription)")
        }
    }
    
    /// 批量执行工具调用
    /// - Parameter toolCalls: 工具调用数组
    /// - Returns: 执行结果数组
    public func execute(_ toolCalls: [LLMToolCall]) async throws -> [Observation] {
        var observations: [Observation] = []
        
        for toolCall in toolCalls {
            let observation = try await execute(toolCall)
            observations.append(observation)
        }
        
        return observations
    }
    
    // MARK: - Private Methods
    
    private func parseArguments(_ jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ToolError.invalidArguments("无法解析参数字符串")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.invalidArguments("参数必须是 JSON 对象")
        }
        
        return json
    }
    
    private func validateArguments(_ arguments: [String: Any], against parameters: [ToolParameter]) throws {
        // 检查必需参数
        for param in parameters where param.required {
            guard arguments[param.name] != nil else {
                throw ToolError.missingRequiredParameter(param.name)
            }
        }
        
        // 检查枚举值
        for param in parameters {
            if let enumValues = param.enumValues,
               let value = arguments[param.name] as? String {
                guard enumValues.contains(value) else {
                    throw ToolError.invalidArguments("参数 '\(param.name)' 的值 '\(value)' 不在允许的枚举值中")
                }
            }
        }
    }
}

