//
//  MessageBubbleView.swift
//  SwiftAgentChatExample
//
//  消息气泡视图组件
//

import SwiftUI

/// 消息气泡视图
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 50)
            }
            
            if message.role != .user {
                // 头像图标
                Image(systemName: message.role.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(avatarColor)
                    .clipShape(Circle())
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // 发送者名称
                Text(message.role.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                // 消息内容
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(18)
                    .textSelection(.enabled)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // 时间戳和流式标记
                HStack(spacing: 6) {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.isStreaming {
                        HStack(spacing: 2) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(animationScale)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: animationScale
                                    )
                            }
                        }
                        .onAppear {
                            animationScale = 1.5
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if message.role == .user {
                // 用户头像
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            
            if message.role != .user {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contextMenu {
            Button(action: copyMessage) {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }
    
    // MARK: - Private State
    
    @State private var animationScale: CGFloat = 1.0
    
    // MARK: - Private Computed Properties
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.blue
        case .assistant:
            #if os(iOS)
            return Color(.systemGray5)
            #else
            return Color(nsColor: .controlBackgroundColor)
            #endif
        case .system:
            return Color.orange.opacity(0.2)
        case .tool:
            return Color.green.opacity(0.2)
        }
    }
    
    private var avatarColor: Color {
        switch message.role {
        case .assistant:
            return Color.purple
        case .system:
            return Color.orange
        case .tool:
            return Color.green
        default:
            return Color.blue
        }
    }
    
    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    // MARK: - Private Methods
    
    private func copyMessage() {
        #if os(iOS)
        UIPasteboard.general.string = message.content
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        #endif
    }
}

// MARK: - Preview

#Preview("对话示例") {
    ScrollView {
        VStack(spacing: 12) {
            MessageBubbleView(message: ChatMessage(
                role: .assistant,
                content: "你好！我是AI助手，很高兴为您服务。我可以帮您计算数学问题、查询时间等。请问有什么可以帮您的吗？"
            ))
            
            MessageBubbleView(message: ChatMessage(
                role: .user,
                content: "你好，请帮我计算 123 + 456"
            ))
            
            MessageBubbleView(message: ChatMessage(
                role: .tool,
                content: "正在使用计算器工具..."
            ))
            
            MessageBubbleView(message: ChatMessage(
                role: .assistant,
                content: "好的，让我为您计算...",
                isStreaming: true
            ))
            
            MessageBubbleView(message: ChatMessage(
                role: .assistant,
                content: "计算结果是 579。还有什么我可以帮您的吗？"
            ))
        }
        .padding(.vertical)
    }
    .frame(width: 500, height: 600)
}

