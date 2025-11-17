//
//  ChatViewModel.swift
//  SwiftAgentChatExample
//
//  聊天视图模型 - 处理业务逻辑和数据管理
//

import Foundation
import SwiftAgent

/// 聊天视图模型
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var isStreamingEnabled: Bool = true
    
    // MARK: - Private Properties
    
    private var agent: Agent?
    private var currentStreamingMessageId: UUID?
    
    // MARK: - Configuration
    
    // ⚠️ 请替换为你的实际 API Key
    private let apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "your-openai-api-key"
    private let modelName: String = "gpt-4o-mini"
    
    // MARK: - Initialization
    
    /// 初始化 Agent 和工具
    func initialize() async {
        do {
            // 创建 LLM Provider
            let provider = OpenAIProvider(
                apiKey: apiKey,
                modelName: modelName
            )
            
            // 创建 Agent
            let agent = Agent(
                name: "AI助手",
                llmProvider: provider,
                systemPrompt: """
                你是一个智能、友好的AI助手，名叫"小智"。
                
                你的特点：
                - 专业且友好，善于用简洁清晰的语言解释复杂概念
                - 可以使用工具帮助用户完成任务
                - 会在回答中体现思考过程
                
                你可以使用以下工具：
                - calculator: 进行数学计算，支持基本运算和数学函数
                - datetime: 获取当前的时间和日期信息
                
                请始终保持礼貌、专业，并尽力帮助用户解决问题。
                """
            )
            
            // 注册基础工具（计算器和日期时间工具）
            await agent.registerBasicTools()
            
            self.agent = agent
            
            // 添加欢迎消息
            addMessage(ChatMessage(
                role: .assistant,
                content: "你好！我是AI助手小智 👋\n\n我可以帮您：\n• 💡 回答各类问题\n• 🔢 进行数学计算\n• 📅 查询时间日期\n• 📝 文本处理和分析\n\n请问有什么可以帮您的吗？"
            ))
            
            print("✅ Agent 初始化成功")
            
        } catch {
            showError(message: "初始化失败：\(error.localizedDescription)")
            print("❌ Agent 初始化失败：\(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// 发送消息
    func sendMessage(_ text: String) async {
        guard let agent = agent else {
            showError(message: "Agent 未初始化，请稍后重试")
            return
        }
        
        // 验证输入
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // 添加用户消息
        addMessage(ChatMessage(role: .user, content: trimmedText))
        
        isProcessing = true
        defer { isProcessing = false }
        
        print("📤 发送消息：\(trimmedText)")
        
        // 根据设置选择输出模式
        if isStreamingEnabled {
            await sendMessageWithStreaming(trimmedText, agent: agent)
        } else {
            await sendMessageNormal(trimmedText, agent: agent)
        }
    }
    
    /// 清空对话历史
    func clearHistory() {
        messages.removeAll()
        
        Task {
            await agent?.clearHistory()
            
            // 重新添加欢迎消息
            addMessage(ChatMessage(
                role: .assistant,
                content: "对话已清空 🔄\n\n请问有什么可以帮您的吗？"
            ))
        }
        
        print("🗑️ 清空对话历史")
    }
    
    /// 切换流式输出模式
    func toggleStreamingMode() {
        isStreamingEnabled.toggle()
        
        let mode = isStreamingEnabled ? "开启" : "关闭"
        addMessage(ChatMessage(
            role: .system,
            content: "已\(mode)流式输出模式"
        ))
        
        print("⚙️ 流式输出模式：\(mode)")
    }
    
    // MARK: - Private Methods - Normal Mode
    
    /// 普通模式发送消息
    private func sendMessageNormal(_ text: String, agent: Agent) async {
        do {
            print("🤖 调用 Agent（普通模式）...")
            let response = try await agent.run(text)
            addMessage(ChatMessage(role: .assistant, content: response))
            print("✅ 收到完整响应")
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Private Methods - Streaming Mode
    
    /// 流式模式发送消息
    private func sendMessageWithStreaming(_ text: String, agent: Agent) async {
        // 创建一个空的助手消息用于流式更新
        let messageId = UUID()
        currentStreamingMessageId = messageId
        
        let streamingMessage = ChatMessage(
            id: messageId,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        addMessage(streamingMessage)
        
        print("🌊 开始流式输出...")
        
        do {
            // 创建流式回调
            let callback = StreamingCallback(
                onContent: { [weak self] content in
                    await self?.updateStreamingMessage(content: content)
                },
                onToolCall: { [weak self] toolCall in
                    await self?.handleToolCall(toolCall)
                },
                onCompletion: { [weak self] response in
                    await self?.finishStreaming(response: response)
                },
                onError: { [weak self] error in
                    await self?.handleStreamingError(error)
                }
            )
            
            // 执行流式请求
            _ = try await agent.streamRunWithCallback(input: text, callback: callback)
            
        } catch {
            handleError(error)
            finishStreaming(response: nil)
        }
    }
    
    /// 更新流式消息内容
    private func updateStreamingMessage(content: String) {
        guard let messageId = currentStreamingMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        messages[index].content += content
        
        // 打印流式内容（用于调试）
        // print("📝 流式内容：\(content)")
    }
    
    /// 处理工具调用
    private func handleToolCall(_ toolCall: ToolCallChunk) {
        if let name = toolCall.name {
            print("🔧 工具调用：\(name)")
            
            // 显示工具调用消息
            let toolMessage = ChatMessage(
                role: .tool,
                content: "🔧 正在使用工具：\(name)..."
            )
            addMessage(toolMessage)
            
            // 延迟后移除工具消息（可选）
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if let index = messages.firstIndex(where: { $0.id == toolMessage.id }) {
                    messages.remove(at: index)
                }
            }
        }
    }
    
    /// 完成流式输出
    private func finishStreaming(response: LLMResponse?) {
        guard let messageId = currentStreamingMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        messages[index].isStreaming = false
        currentStreamingMessageId = nil
        
        // 如果消息为空，显示默认消息
        if messages[index].content.isEmpty {
            messages[index].content = "抱歉，我没能生成回复。请重试。"
        }
        
        print("✅ 流式输出完成")
    }
    
    // MARK: - Private Methods - Helpers
    
    /// 添加消息
    private func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    /// 处理错误
    private func handleError(_ error: Error) {
        let errorMsg = "处理失败：\(error.localizedDescription)"
        showError(message: errorMsg)
        print("❌ 错误：\(error)")
        
        addMessage(ChatMessage(
            role: .system,
            content: "⚠️ 抱歉，处理您的请求时出现错误。请检查网络连接或 API 配置。"
        ))
    }
    
    /// 处理流式错误
    private func handleStreamingError(_ error: Error) {
        handleError(error)
    }
    
    /// 显示错误弹窗
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension ChatViewModel {
    /// 添加测试消息（用于预览和调试）
    func addTestMessages() {
        messages = [
            ChatMessage(role: .assistant, content: "你好！我是AI助手。"),
            ChatMessage(role: .user, content: "你好，请帮我计算 123 + 456"),
            ChatMessage(role: .tool, content: "正在使用计算器..."),
            ChatMessage(role: .assistant, content: "计算结果是 579"),
        ]
    }
}
#endif

