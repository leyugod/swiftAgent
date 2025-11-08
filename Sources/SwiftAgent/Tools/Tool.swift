//
//  Tool.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 工具参数定义
public struct ToolParameter {
    public let name: String
    public let type: String
    public let description: String
    public let required: Bool
    public let enumValues: [String]?
    
    public init(
        name: String,
        type: String,
        description: String,
        required: Bool = true,
        enumValues: [String]? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.enumValues = enumValues
    }
}

/// 工具协议
/// 所有工具必须实现此协议
@preconcurrency
public protocol ToolProtocol: Sendable {
    /// 工具名称
    var name: String { get }
    
    /// 工具描述
    var description: String { get }
    
    /// 工具参数定义
    var parameters: [ToolParameter] { get }
    
    /// 执行工具
    /// - Parameter arguments: 参数字典
    /// - Returns: 执行结果（字符串格式）
    func execute(arguments: [String: Any]) async throws -> String
}

/// 工具执行错误
public enum ToolError: Error {
    case invalidArguments(String)
    case executionFailed(String)
    case toolNotFound(String)
    case missingRequiredParameter(String)
}

