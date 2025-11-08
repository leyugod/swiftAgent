//
//  AgentCommunication.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// Agent 通信管理
/// 管理 Agent 之间的消息传递
public actor AgentCommunication {
    private let mode: MultiAgentSystem.CommunicationMode
    private var messageQueue: [CommunicationMessage] = []
    private var subscribers: [String: MessageHandler] = [:]
    
    public typealias MessageHandler = @Sendable (CommunicationMessage) async -> Void
    
    public init(mode: MultiAgentSystem.CommunicationMode) {
        self.mode = mode
    }
    
    /// 发送消息
    /// - Parameter message: 通信消息
    public func send(_ message: CommunicationMessage) async {
        messageQueue.append(message)
        await deliverMessage(message)
    }
    
    /// 订阅消息
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - handler: 消息处理器
    public func subscribe(agentId: String, handler: @escaping MessageHandler) {
        subscribers[agentId] = handler
    }
    
    /// 取消订阅
    /// - Parameter agentId: Agent ID
    public func unsubscribe(agentId: String) {
        subscribers.removeValue(forKey: agentId)
    }
    
    /// 获取消息历史
    /// - Parameter filter: 过滤条件
    /// - Returns: 消息数组
    public func getHistory(filter: MessageFilter? = nil) -> [CommunicationMessage] {
        if let filter = filter {
            return messageQueue.filter { message in
                if let sender = filter.sender, message.sender != sender {
                    return false
                }
                if let receiver = filter.receiver, message.receiver != receiver {
                    return false
                }
                if let type = filter.type, message.type != type {
                    return false
                }
                return true
            }
        }
        return messageQueue
    }
    
    /// 清空消息历史
    public func clearHistory() {
        messageQueue.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func deliverMessage(_ message: CommunicationMessage) async {
        switch mode {
        case .shared:
            // 所有订阅者都能收到
            for (_, handler) in subscribers {
                await handler(message)
            }
            
        case .directed:
            // 只有指定接收者能收到
            if let receiver = message.receiver,
               let handler = subscribers[receiver] {
                await handler(message)
            }
            
        case .broadcast:
            // 除发送者外的所有订阅者都能收到
            for (id, handler) in subscribers where id != message.sender {
                await handler(message)
            }
        }
    }
}

/// 通信消息
public struct CommunicationMessage: Codable, Sendable {
    public let id: String
    public let sender: String
    public let receiver: String?
    public let type: MessageType
    public let content: String
    public let metadata: [String: String]
    public let timestamp: Date
    
    public enum MessageType: String, Codable, Sendable {
        case task           // 任务分配
        case result         // 结果反馈
        case question       // 提问
        case answer         // 回答
        case notification   // 通知
        case collaboration  // 协作请求
    }
    
    public init(
        id: String = UUID().uuidString,
        sender: String,
        receiver: String? = nil,
        type: MessageType,
        content: String,
        metadata: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.receiver = receiver
        self.type = type
        self.content = content
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// 消息过滤器
public struct MessageFilter {
    public let sender: String?
    public let receiver: String?
    public let type: CommunicationMessage.MessageType?
    
    public init(
        sender: String? = nil,
        receiver: String? = nil,
        type: CommunicationMessage.MessageType? = nil
    ) {
        self.sender = sender
        self.receiver = receiver
        self.type = type
    }
}

