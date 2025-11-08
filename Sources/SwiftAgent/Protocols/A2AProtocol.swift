//
//  A2AProtocol.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//
//  Agent-to-Agent Protocol (A2A)
//  用于多个 Agent 之间的直接通信

import Foundation

/// A2A 消息类型
public enum A2AMessageType: String, Codable, Sendable {
    case request        // 请求
    case response       // 响应
    case delegation     // 任务委托
    case collaboration  // 协作邀请
    case notification   // 通知
}

/// A2A 消息
public struct A2AMessage: Codable, Sendable {
    public let id: String
    public let type: A2AMessageType
    public let sender: String
    public let receiver: String
    public let content: String
    public let metadata: [String: String]
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        type: A2AMessageType,
        sender: String,
        receiver: String,
        content: String,
        metadata: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.sender = sender
        self.receiver = receiver
        self.content = content
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// A2A 协议接口
@preconcurrency
public protocol A2AProtocol: Sendable {
    /// Agent ID
    var agentId: String { get }
    
    /// 发送消息
    /// - Parameter message: A2A 消息
    func send(_ message: A2AMessage) async throws
    
    /// 接收消息
    /// - Returns: 接收到的消息
    func receive() async throws -> A2AMessage
    
    /// 请求其他 Agent 执行任务
    /// - Parameters:
    ///   - receiverId: 接收者 ID
    ///   - task: 任务描述
    /// - Returns: 响应消息
    func request(to receiverId: String, task: String) async throws -> A2AMessage
    
    /// 委托任务给其他 Agent
    /// - Parameters:
    ///   - receiverId: 接收者 ID
    ///   - task: 任务描述
    ///   - context: 上下文信息
    func delegate(to receiverId: String, task: String, context: [String: String]) async throws
    
    /// 发送协作邀请
    /// - Parameters:
    ///   - receiverId: 接收者 ID
    ///   - proposal: 协作提案
    func collaborate(with receiverId: String, proposal: String) async throws
}

/// A2A 消息处理器协议
@preconcurrency
public protocol A2AMessageHandler: Sendable {
    /// 处理收到的消息
    /// - Parameter message: A2A 消息
    /// - Returns: 响应消息（如果需要）
    func handle(_ message: A2AMessage) async throws -> A2AMessage?
}

/// A2A 通信通道
/// 提供 Agent 之间的消息传递机制
public actor A2AChannel {
    private var messageQueues: [String: [A2AMessage]] = [:]
    private var handlers: [String: A2AMessageHandler] = [:]
    
    public init() {}
    
    /// 注册 Agent
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - handler: 消息处理器
    public func register(agentId: String, handler: A2AMessageHandler) {
        handlers[agentId] = handler
        if messageQueues[agentId] == nil {
            messageQueues[agentId] = []
        }
    }
    
    /// 发送消息
    /// - Parameter message: A2A 消息
    public func send(_ message: A2AMessage) async throws {
        guard handlers[message.receiver] != nil else {
            throw A2AError.receiverNotFound(message.receiver)
        }
        
        // 将消息添加到接收者的队列
        if messageQueues[message.receiver] == nil {
            messageQueues[message.receiver] = []
        }
        messageQueues[message.receiver]?.append(message)
        
        // 如果有处理器，立即处理
        if let handler = handlers[message.receiver] {
            _ = try await handler.handle(message)
        }
    }
    
    /// 接收消息
    /// - Parameter agentId: Agent ID
    /// - Returns: 消息（如果有）
    public func receive(for agentId: String) async throws -> A2AMessage? {
        guard var queue = messageQueues[agentId], !queue.isEmpty else {
            return nil
        }
        
        let message = queue.removeFirst()
        messageQueues[agentId] = queue
        return message
    }
    
    /// 广播消息
    /// - Parameters:
    ///   - sender: 发送者 ID
    ///   - content: 消息内容
    public func broadcast(from sender: String, content: String) async throws {
        for (agentId, _) in handlers where agentId != sender {
            let message = A2AMessage(
                type: .notification,
                sender: sender,
                receiver: agentId,
                content: content
            )
            try await send(message)
        }
    }
    
    /// 获取所有在线的 Agent ID
    /// - Returns: Agent ID 数组
    public func getOnlineAgents() -> [String] {
        Array(handlers.keys)
    }
}

/// A2A Agent 适配器
/// 将 Agent 连接到 A2A 通信通道
public actor A2AAgentAdapter: A2AProtocol {
    public let agentId: String
    private let channel: A2AChannel
    private let agent: AgentProtocol
    
    public init(
        agentId: String,
        channel: A2AChannel,
        agent: AgentProtocol
    ) {
        self.agentId = agentId
        self.channel = channel
        self.agent = agent
    }
    
    public func send(_ message: A2AMessage) async throws {
        try await channel.send(message)
    }
    
    public func receive() async throws -> A2AMessage {
        while true {
            if let message = try await channel.receive(for: agentId) {
                return message
            }
            // 等待一段时间再检查
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    public func request(to receiverId: String, task: String) async throws -> A2AMessage {
        let message = A2AMessage(
            type: .request,
            sender: agentId,
            receiver: receiverId,
            content: task
        )
        
        try await send(message)
        
        // 等待响应
        return try await receive()
    }
    
    public func delegate(to receiverId: String, task: String, context: [String: String]) async throws {
        let message = A2AMessage(
            type: .delegation,
            sender: agentId,
            receiver: receiverId,
            content: task,
            metadata: context
        )
        
        try await send(message)
    }
    
    public func collaborate(with receiverId: String, proposal: String) async throws {
        let message = A2AMessage(
            type: .collaboration,
            sender: agentId,
            receiver: receiverId,
            content: proposal
        )
        
        try await send(message)
    }
}

/// A2A 错误
public enum A2AError: Error {
    case receiverNotFound(String)
    case messageTimeout
    case invalidMessage(String)
    case communicationFailed(String)
}

