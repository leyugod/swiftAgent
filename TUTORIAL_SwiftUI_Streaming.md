# SwiftAgent Framework - SwiftUI 流式输出完整教程

本教程将指导您创建一个功能完整的 iOS/macOS AI 助手应用，使用 SwiftAgent Framework 实现流式输出功能。

## 📚 目录

1. [项目设置](#项目设置)
2. [创建聊天界面](#创建聊天界面)
3. [实现 ViewModel](#实现-viewmodel)
4. [集成流式输出](#集成流式输出)
5. [添加工具支持](#添加工具支持)
6. [完整示例代码](#完整示例代码)
7. [运行效果](#运行效果)

---

## 1. 项目设置

### 1.1 创建新项目

在 Xcode 中创建一个新的 iOS/macOS App 项目：

```
File → New → Project → Multiplatform → App
Product Name: SwiftAgentChat
Interface: SwiftUI
Language: Swift
```

### 1.2 添加 SwiftAgent 依赖

在 `Package.swift` 或通过 Xcode 添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/leyugod/swiftAgent.git", from: "1.0.0")
]
```

或在 Xcode 中：
```
File → Add Package Dependencies → 输入 GitHub URL
```

---

## 2. 创建聊天界面

### 2.1 消息数据模型

创建 `ChatMessage.swift`：

```swift
import Foundation

/// 聊天消息模型
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool // 标记是否正在流式接收
    
    enum MessageRole {
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
```

### 2.2 消息气泡视图

创建 `MessageBubbleView.swift`：

```swift
import SwiftUI

/// 消息气泡视图
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // 发送者名称
                Text(message.role.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 消息内容
                Text(message.content)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                    .textSelection(.enabled)
                
                // 时间戳和流式标记
                HStack(spacing: 4) {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.isStreaming {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            
            if message.role != .user {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Private Computed Properties
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.blue
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return Color.orange.opacity(0.3)
        case .tool:
            return Color.green.opacity(0.3)
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
}

// MARK: - Preview

#Preview {
    VStack {
        MessageBubbleView(message: ChatMessage(
            role: .user,
            content: "你好，请计算 2 + 2"
        ))
        
        MessageBubbleView(message: ChatMessage(
            role: .assistant,
            content: "好的，让我为您计算...",
            isStreaming: true
        ))
        
        MessageBubbleView(message: ChatMessage(
            role: .assistant,
            content: "计算结果是 4"
        ))
    }
}
```

### 2.3 主聊天界面

创建 `ChatView.swift`：

```swift
import SwiftUI

/// 主聊天界面
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        // 自动滚动到最新消息
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // 输入区域
                HStack(spacing: 12) {
                    TextField("输入消息...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(inputText.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(inputText.isEmpty || viewModel.isProcessing)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI 助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: viewModel.clearHistory) {
                            Label("清空对话", systemImage: "trash")
                        }
                        
                        Button(action: viewModel.toggleStreamingMode) {
                            Label(
                                viewModel.isStreamingEnabled ? "关闭流式输出" : "开启流式输出",
                                systemImage: viewModel.isStreamingEnabled ? "waveform.slash" : "waveform"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.initialize()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let message = inputText
        inputText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(message)
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
}
```

---

## 3. 实现 ViewModel

创建 `ChatViewModel.swift`：

```swift
import Foundation
import SwiftAgent
import Observation

/// 聊天视图模型
@MainActor
@Observable
class ChatViewModel {
    // MARK: - Published Properties
    
    var messages: [ChatMessage] = []
    var isProcessing: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""
    var isStreamingEnabled: Bool = true
    
    // MARK: - Private Properties
    
    private var agent: Agent?
    private var currentStreamingMessageId: UUID?
    
    // MARK: - Configuration
    
    private let apiKey: String = "your-openai-api-key" // 替换为你的 API Key
    private let modelName: String = "gpt-4o-mini"
    
    // MARK: - Initialization
    
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
                你是一个智能AI助手，可以帮助用户解答问题和完成任务。
                你可以使用以下工具：
                - calculator: 进行数学计算
                - datetime: 获取当前时间和日期
                
                请用友好、专业的态度回答用户的问题。
                """
            )
            
            // 注册基础工具
            await agent.registerBasicTools()
            
            self.agent = agent
            
            // 添加欢迎消息
            addMessage(ChatMessage(
                role: .assistant,
                content: "你好！我是AI助手，很高兴为您服务。我可以帮您计算数学问题、查询时间等。请问有什么可以帮您的吗？"
            ))
            
        } catch {
            showError(message: "初始化失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// 发送消息
    func sendMessage(_ text: String) async {
        guard let agent = agent else {
            showError(message: "Agent 未初始化")
            return
        }
        
        // 添加用户消息
        addMessage(ChatMessage(role: .user, content: text))
        
        isProcessing = true
        defer { isProcessing = false }
        
        if isStreamingEnabled {
            // 使用流式输出
            await sendMessageWithStreaming(text, agent: agent)
        } else {
            // 使用普通输出
            await sendMessageNormal(text, agent: agent)
        }
    }
    
    /// 清空对话历史
    func clearHistory() {
        messages.removeAll()
        agent?.clearHistory()
        
        // 重新添加欢迎消息
        addMessage(ChatMessage(
            role: .assistant,
            content: "对话已清空。请问有什么可以帮您的吗？"
        ))
    }
    
    /// 切换流式输出模式
    func toggleStreamingMode() {
        isStreamingEnabled.toggle()
    }
    
    // MARK: - Private Methods
    
    /// 普通模式发送消息
    private func sendMessageNormal(_ text: String, agent: Agent) async {
        do {
            let response = try await agent.run(text)
            addMessage(ChatMessage(role: .assistant, content: response))
        } catch {
            showError(message: "发送失败：\(error.localizedDescription)")
            addMessage(ChatMessage(
                role: .system,
                content: "抱歉，处理您的请求时出现错误。"
            ))
        }
    }
    
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
                    await self?.finishStreaming()
                },
                onError: { [weak self] error in
                    await self?.showError(message: error.localizedDescription)
                }
            )
            
            // 执行流式请求
            _ = try await agent.streamRunWithCallback(input: text, callback: callback)
            
        } catch {
            showError(message: "流式请求失败：\(error.localizedDescription)")
            finishStreaming()
        }
    }
    
    /// 更新流式消息内容
    private func updateStreamingMessage(content: String) {
        guard let messageId = currentStreamingMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        messages[index].content += content
    }
    
    /// 处理工具调用
    private func handleToolCall(_ toolCall: ToolCallChunk) {
        if let name = toolCall.name {
            addMessage(ChatMessage(
                role: .tool,
                content: "正在调用工具: \(name)"
            ))
        }
    }
    
    /// 完成流式输出
    private func finishStreaming() {
        guard let messageId = currentStreamingMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        messages[index].isStreaming = false
        currentStreamingMessageId = nil
    }
    
    /// 添加消息
    private func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    /// 显示错误
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
```

---

## 4. 集成流式输出

### 4.1 流式输出核心原理

SwiftAgent 的流式输出基于 Swift 的 `AsyncThrowingStream`，实现实时流式响应：

```swift
// 1. 流式生成
let stream = try await agent.streamRun(input: userInput)

// 2. 逐块接收
for try await chunk in stream {
    switch chunk.type {
    case .content(let text):
        // 更新 UI 显示文本
        updateUI(with: text)
        
    case .toolCall(let toolCall):
        // 处理工具调用
        handleTool(toolCall)
        
    case .done:
        // 流式完成
        break
        
    case .error(let message):
        // 处理错误
        showError(message)
    }
}
```

### 4.2 流式回调模式

使用 `StreamingCallback` 简化流式处理：

```swift
let callback = StreamingCallback(
    onContent: { content in
        // 每次收到内容块时调用
        print("收到内容：\(content)")
    },
    onToolCall: { toolCall in
        // 收到工具调用时调用
        print("工具调用：\(toolCall.name ?? "")")
    },
    onCompletion: { response in
        // 流式完成时调用
        print("完成，完整响应：\(response.content)")
    },
    onError: { error in
        // 发生错误时调用
        print("错误：\(error)")
    }
)

let response = try await agent.streamRunWithCallback(
    input: userInput,
    callback: callback
)
```

---

## 5. 添加工具支持

### 5.1 使用内置工具

```swift
// 注册所有内置工具
await agent.registerAllBuiltinTools()

// 或只注册基础工具
await agent.registerBasicTools()
```

### 5.2 创建自定义工具

创建 `CustomTools.swift`：

```swift
import Foundation
import SwiftAgent

/// 天气查询工具
struct WeatherQueryTool: ToolProtocol {
    let name = "get_weather"
    let description = "查询指定城市的天气情况"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "city",
                type: "string",
                description: "城市名称，例如：北京、上海",
                required: true
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let city = arguments["city"] as? String else {
            throw ToolError.invalidArguments("缺少城市参数")
        }
        
        // 模拟 API 调用
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 返回模拟数据
        return """
        \(city)的天气情况：
        - 温度：25°C
        - 天气：晴
        - 湿度：60%
        - 风力：3级
        """
    }
}

/// 翻译工具
struct TranslateTool: ToolProtocol {
    let name = "translate"
    let description = "将文本翻译成指定语言"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "text",
                type: "string",
                description: "要翻译的文本",
                required: true
            ),
            ToolParameter(
                name: "target_language",
                type: "string",
                description: "目标语言，例如：英文、中文、日文",
                required: true
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String,
              let targetLang = arguments["target_language"] as? String else {
            throw ToolError.invalidArguments("缺少必要参数")
        }
        
        // 模拟翻译
        return "已将「\(text)」翻译成\(targetLang)：[翻译结果]"
    }
}
```

注册自定义工具：

```swift
// 在 ChatViewModel 的 initialize 方法中
await agent.registerTools([
    WeatherQueryTool(),
    TranslateTool()
])
```

---

## 6. 完整示例代码

### 6.1 App 入口

创建 `SwiftAgentChatApp.swift`：

```swift
import SwiftUI

@main
struct SwiftAgentChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
    }
}
```

### 6.2 项目结构

```
SwiftAgentChat/
├── SwiftAgentChatApp.swift        # App 入口
├── Views/
│   ├── ChatView.swift             # 主聊天界面
│   └── MessageBubbleView.swift    # 消息气泡视图
├── ViewModels/
│   └── ChatViewModel.swift        # 视图模型
├── Models/
│   └── ChatMessage.swift          # 消息数据模型
└── Tools/
    └── CustomTools.swift          # 自定义工具
```

---

## 7. 运行效果

### 7.1 配置 API Key

在 `ChatViewModel.swift` 中设置你的 OpenAI API Key：

```swift
private let apiKey: String = "sk-your-api-key-here"
```

### 7.2 运行应用

1. 选择目标设备（iOS 模拟器或 macOS）
2. 点击 Run (⌘R)
3. 应用启动后显示聊天界面

### 7.3 测试功能

尝试以下对话：

**基础对话：**
```
用户：你好！
AI：你好！我是AI助手，很高兴为您服务...
```

**数学计算：**
```
用户：请计算 123 + 456
AI：[调用 calculator 工具]
AI：计算结果是 579
```

**时间查询：**
```
用户：现在几点了？
AI：[调用 datetime 工具]
AI：当前时间是 2025年11月17日 14:30
```

**流式输出效果：**
- 文本逐字显示
- 显示"正在输入"动画
- 实时更新内容

---

## 8. 高级功能

### 8.1 添加语音输入

```swift
import Speech

extension ChatView {
    func startVoiceInput() {
        // 实现语音识别
    }
}
```

### 8.2 添加消息复制功能

在 `MessageBubbleView` 中添加：

```swift
.contextMenu {
    Button(action: {
        UIPasteboard.general.string = message.content
    }) {
        Label("复制", systemImage: "doc.on.doc")
    }
}
```

### 8.3 保存对话历史

```swift
extension ChatViewModel {
    func saveHistory() {
        // 使用 FileManager 或 Core Data 保存
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(messages) {
            // 保存 data
        }
    }
    
    func loadHistory() {
        // 加载历史记录
    }
}
```

### 8.4 支持 Markdown 渲染

使用第三方库（如 `MarkdownUI`）：

```swift
import MarkdownUI

struct MessageBubbleView: View {
    var body: some View {
        Markdown(message.content)
            .padding(12)
            .background(backgroundColor)
    }
}
```

---

## 9. 性能优化

### 9.1 消息缓存

```swift
private var messageCache: [UUID: ChatMessage] = [:]
```

### 9.2 懒加载

```swift
LazyVStack {
    ForEach(messages) { message in
        MessageBubbleView(message: message)
    }
}
```

### 9.3 网络请求超时处理

```swift
Task {
    try await withTimeout(seconds: 30) {
        await viewModel.sendMessage(text)
    }
}
```

---

## 10. 故障排查

### 10.1 常见问题

**Q: API 请求失败**
```
A: 检查 API Key 是否正确，网络连接是否正常
```

**Q: 流式输出不工作**
```
A: 确保 LLM Provider 支持流式输出（OpenAIProvider 支持）
```

**Q: 界面卡顿**
```
A: 确保使用 @MainActor 更新 UI，避免在主线程执行耗时操作
```

### 10.2 调试技巧

启用详细日志：

```swift
// 在 ChatViewModel 中添加
private func log(_ message: String) {
    #if DEBUG
    print("[ChatViewModel] \(message)")
    #endif
}
```

---

## 11. 总结

本教程展示了如何使用 SwiftAgent Framework 构建一个功能完整的 AI 助手应用：

✅ 完整的 SwiftUI 聊天界面
✅ 流式输出实现
✅ 工具调用支持
✅ 错误处理
✅ 可扩展架构

### 下一步

- 🚀 添加更多自定义工具
- 🎨 优化 UI 设计
- 💾 实现持久化存储
- 🌐 支持多语言
- 🔐 添加用户认证

---

## 12. 参考资源

- [SwiftAgent GitHub](https://github.com/leyugod/swiftAgent)
- [SwiftUI 官方文档](https://developer.apple.com/documentation/swiftui)
- [OpenAI API 文档](https://platform.openai.com/docs)
- [Swift Concurrency 指南](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

**Happy Coding! 🎉**

如有问题或建议，欢迎在 GitHub 上提 Issue。

