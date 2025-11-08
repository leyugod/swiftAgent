//
//  LLMMessage.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// LLM 消息角色
public enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

/// LLM 消息模型
public struct LLMMessage: Codable, Equatable {
    public let role: MessageRole
    public let content: String
    public let name: String?
    public let toolCallId: String?
    
    public init(
        role: MessageRole,
        content: String,
        name: String? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallId = toolCallId
    }
    
    /// 创建系统消息
    public static func system(_ content: String) -> LLMMessage {
        LLMMessage(role: .system, content: content)
    }
    
    /// 创建用户消息
    public static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }
    
    /// 创建助手消息
    public static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }
    
    /// 创建工具消息
    public static func tool(content: String, toolCallId: String, name: String) -> LLMMessage {
        LLMMessage(role: .tool, content: content, name: name, toolCallId: toolCallId)
    }
}

/// LLM 工具函数定义
public struct LLMToolFunction: Codable {
    public let name: String
    public let description: String
    public let parameters: [String: AnyCodable]
    
    public init(name: String, description: String, parameters: [String: AnyCodable]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// LLM 工具调用
public struct LLMToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: FunctionCall
    
    public struct FunctionCall: Codable, Sendable {
        public let name: String
        public let arguments: String
    }
    
    public init(id: String, type: String, function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// 用于 Codable 支持任意 JSON 值
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDict = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

