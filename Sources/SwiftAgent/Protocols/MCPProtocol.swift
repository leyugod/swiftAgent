//
//  MCPProtocol.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//
//  Model Context Protocol (MCP)
//  用于 Agent 与外部工具/服务之间的通信

import Foundation

/// MCP 消息类型
public enum MCPMessageType: String, Codable, Sendable {
    case request
    case response
    case notification
    case error
}

/// MCP 消息
public struct MCPMessage: Codable, Sendable {
    public let id: String
    public let type: MCPMessageType
    public let method: String?
    public let params: [String: AnyCodable]?
    public let result: AnyCodable?
    public let error: MCPError?
    
    public init(
        id: String = UUID().uuidString,
        type: MCPMessageType,
        method: String? = nil,
        params: [String: AnyCodable]? = nil,
        result: AnyCodable? = nil,
        error: MCPError? = nil
    ) {
        self.id = id
        self.type = type
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }
}

/// MCP 错误
public struct MCPError: Codable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: AnyCodable?
    
    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// MCP 服务器接口
@preconcurrency
public protocol MCPServerProtocol: Sendable {
    /// 处理 MCP 请求
    /// - Parameter message: MCP 消息
    /// - Returns: 响应消息
    func handleRequest(_ message: MCPMessage) async throws -> MCPMessage
    
    /// 获取服务器能力
    /// - Returns: 能力描述
    func getCapabilities() async -> [String: AnyCodable]
}

/// MCP 客户端接口
@preconcurrency
public protocol MCPClientProtocol: Sendable {
    /// 发送请求
    /// - Parameters:
    ///   - method: 方法名
    ///   - params: 参数
    /// - Returns: 响应结果
    func sendRequest(method: String, params: [String: AnyCodable]?) async throws -> AnyCodable
    
    /// 发送通知（不需要响应）
    /// - Parameters:
    ///   - method: 方法名
    ///   - params: 参数
    func sendNotification(method: String, params: [String: AnyCodable]?) async throws
}

/// MCP 工具服务器
/// 提供工具调用的 MCP 服务器实现
public actor MCPToolServer: MCPServerProtocol {
    private let toolRegistry: ToolRegistry
    
    public init(toolRegistry: ToolRegistry) {
        self.toolRegistry = toolRegistry
    }
    
    public func handleRequest(_ message: MCPMessage) async throws -> MCPMessage {
        guard message.type == .request else {
            throw MCPError(code: -32600, message: "Invalid Request")
        }
        
        guard let method = message.method else {
            throw MCPError(code: -32600, message: "Method not specified")
        }
        
        switch method {
        case "tools/list":
            return try await handleListTools(message)
        case "tools/execute":
            return try await handleExecuteTool(message)
        default:
            throw MCPError(code: -32601, message: "Method not found: \(method)")
        }
    }
    
    public func getCapabilities() async -> [String: AnyCodable] {
        return [
            "tools": AnyCodable([
                "list": true,
                "execute": true
            ])
        ]
    }
    
    // MARK: - Private Methods
    
    private func handleListTools(_ message: MCPMessage) async throws -> MCPMessage {
        let tools = await toolRegistry.getAll()
        let toolsList = tools.map { tool in
            [
                "name": AnyCodable(tool.name),
                "description": AnyCodable(tool.description),
                "parameters": AnyCodable(tool.parameters.map { param in
                    [
                        "name": param.name,
                        "type": param.type,
                        "description": param.description,
                        "required": param.required
                    ]
                })
            ]
        }
        
        return MCPMessage(
            id: message.id,
            type: .response,
            result: AnyCodable(["tools": toolsList])
        )
    }
    
    private func handleExecuteTool(_ message: MCPMessage) async throws -> MCPMessage {
        guard let params = message.params,
              let toolNameValue = params["toolName"],
              let toolName = toolNameValue.value as? String else {
            throw MCPError(code: -32602, message: "Invalid params: toolName required")
        }
        
        guard let tool = await toolRegistry.get(toolName) else {
            throw MCPError(code: -32602, message: "Tool not found: \(toolName)")
        }
        
        // 提取参数
        var arguments: [String: Any] = [:]
        if let argsValue = params["arguments"],
           let args = argsValue.value as? [String: Any] {
            arguments = args
        }
        
        // 执行工具
        let result = try await tool.execute(arguments: arguments)
        
        return MCPMessage(
            id: message.id,
            type: .response,
            result: AnyCodable(["result": result])
        )
    }
}

/// MCP 客户端实现
public actor MCPClient: MCPClientProtocol {
    private let serverURL: URL
    private let session: URLSession
    
    public init(serverURL: URL) {
        self.serverURL = serverURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    public func sendRequest(method: String, params: [String: AnyCodable]?) async throws -> AnyCodable {
        let message = MCPMessage(
            type: .request,
            method: method,
            params: params
        )
        
        let response = try await send(message)
        
        if let error = response.error {
            throw error
        }
        
        guard let result = response.result else {
            throw MCPError(code: -32603, message: "No result in response")
        }
        
        return result
    }
    
    public func sendNotification(method: String, params: [String: AnyCodable]?) async throws {
        let message = MCPMessage(
            type: .notification,
            method: method,
            params: params
        )
        
        _ = try await send(message)
    }
    
    // MARK: - Private Methods
    
    private func send(_ message: MCPMessage) async throws -> MCPMessage {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(message)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError(code: -32603, message: "Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MCPError(code: httpResponse.statusCode, message: "HTTP Error: \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(MCPMessage.self, from: data)
    }
}

