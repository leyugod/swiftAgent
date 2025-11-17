//
//  ChatMessage.swift
//  SwiftAgentChatExample
//
//  聊天消息数据模型
//

import Foundation

/// 聊天消息模型
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool // 标记是否正在流式接收
    
    /// 消息角色
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
        case tool
        
        var displayName: String {
            switch self {
            case .user: return "我"
            case .assistant: return "AI助手"
            case .system: return "系统"
            case .tool: return "工具"
            }
        }
        
        var iconName: String {
            switch self {
            case .user: return "person.fill"
            case .assistant: return "brain.head.profile"
            case .system: return "gear"
            case .tool: return "wrench.and.screwdriver.fill"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}

