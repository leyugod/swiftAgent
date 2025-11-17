# SwiftAgent Chat Example

一个完整的 SwiftUI AI 聊天助手示例应用，演示如何使用 SwiftAgent Framework 构建带流式输出的智能对话应用。

## 📱 功能特性

- ✅ 完整的 SwiftUI 聊天界面
- ✅ 实时流式输出（逐字显示）
- ✅ 支持工具调用（计算器、日期时间）
- ✅ 消息历史管理
- ✅ 错误处理和重试机制
- ✅ 复制消息功能
- ✅ 跨平台支持（iOS & macOS）

## 🚀 快速开始

### 1. 环境要求

- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

### 2. 配置 API Key

在运行前，需要配置 OpenAI API Key。有两种方式：

**方式 1：环境变量（推荐）**
```bash
export OPENAI_API_KEY="your-api-key-here"
```

**方式 2：直接修改代码**

编辑 `SwiftAgentChat/ViewModels/ChatViewModel.swift`：

```swift
private let apiKey: String = "your-api-key-here"
```

### 3. 运行项目

#### 使用 Xcode

1. 打开 `SwiftAgentChatExample` 目录
2. 双击 `Package.swift` 在 Xcode 中打开
3. 选择运行目标（iOS 模拟器或 macOS）
4. 点击 Run (⌘R)

#### 使用命令行

```bash
# 进入示例项目目录
cd SwiftAgentChatExample

# 运行 macOS 版本
swift run

# 或使用 xcodebuild
xcodebuild -scheme SwiftAgentChatExample -destination 'platform=macOS'
```

## 📁 项目结构

```
SwiftAgentChatExample/
├── Package.swift                   # SPM 配置文件
├── README.md                       # 本文档
└── SwiftAgentChat/
    ├── SwiftAgentChatApp.swift    # App 入口
    ├── Views/
    │   ├── ChatView.swift          # 主聊天界面
    │   └── MessageBubbleView.swift # 消息气泡组件
    ├── ViewModels/
    │   └── ChatViewModel.swift     # 视图模型（业务逻辑）
    ├── Models/
    │   └── ChatMessage.swift       # 消息数据模型
    └── Tools/
        └── CustomTools.swift       # 自定义工具示例
```

## 💡 核心代码解析

### 1. 初始化 Agent

```swift
let provider = OpenAIProvider(
    apiKey: apiKey,
    modelName: "gpt-4o-mini"
)

let agent = Agent(
    name: "AI助手",
    llmProvider: provider,
    systemPrompt: "你是一个智能、友好的AI助手..."
)

await agent.registerBasicTools()
```

### 2. 流式输出实现

```swift
let callback = StreamingCallback(
    onContent: { content in
        // 实时更新 UI 显示流式内容
        await self.updateStreamingMessage(content: content)
    },
    onCompletion: { response in
        // 流式完成
        await self.finishStreaming()
    }
)

try await agent.streamRunWithCallback(input: text, callback: callback)
```

### 3. 消息管理

```swift
// 添加用户消息
addMessage(ChatMessage(role: .user, content: text))

// 创建流式消息
let streamingMessage = ChatMessage(
    id: messageId,
    role: .assistant,
    content: "",
    isStreaming: true
)
```

## 🎯 使用示例

### 基础对话

```
用户：你好！
AI：你好！我是AI助手小智 👋 很高兴为您服务...
```

### 数学计算

```
用户：请帮我计算 (123 + 456) * 2
AI：🔧 正在使用工具：calculator...
AI：计算结果是 1158
```

### 时间查询

```
用户：现在几点了？
AI：🔧 正在使用工具：datetime...
AI：当前时间是 2025年11月17日 14:30
```

## 🔧 自定义工具

在 `Tools/CustomTools.swift` 中添加自定义工具：

```swift
struct MyCustomTool: ToolProtocol {
    let name = "my_tool"
    let description = "工具描述"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "param1",
                type: "string",
                description: "参数描述",
                required: true
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        // 实现工具逻辑
        return "执行结果"
    }
}
```

在 `ChatViewModel.initialize()` 中注册：

```swift
await agent.registerTools([MyCustomTool()])
```

## ⚙️ 配置选项

### 修改 LLM 模型

```swift
private let modelName: String = "gpt-4o"  // 或其他模型
```

### 调整 System Prompt

编辑 `ChatViewModel.swift` 中的 `systemPrompt`：

```swift
systemPrompt: """
你是一个专业的编程助手...
[自定义提示词]
"""
```

### 启用/禁用流式输出

点击界面右上角菜单 → "开启/关闭流式输出"

或在代码中设置：

```swift
@Published var isStreamingEnabled: Bool = true  // 或 false
```

## 📊 性能优化

### 1. 懒加载消息列表

```swift
LazyVStack {
    ForEach(messages) { message in
        MessageBubbleView(message: message)
    }
}
```

### 2. 消息缓存

```swift
private var messageCache: [UUID: ChatMessage] = [:]
```

### 3. 图片优化

对于大量消息的场景，考虑实现分页加载：

```swift
.onAppear {
    if message.id == messages.first?.id {
        loadMoreMessages()
    }
}
```

## 🐛 故障排查

### 问题 1：API 请求失败

**症状**：显示 "处理失败" 错误

**解决方案**：
1. 检查 API Key 是否正确
2. 确认网络连接正常
3. 查看控制台日志获取详细错误信息

### 问题 2：流式输出不工作

**症状**：消息不是逐字显示

**解决方案**：
1. 确认已启用流式输出模式
2. 检查 OpenAIProvider 是否正确实现 StreamingLLMProviderProtocol
3. 查看控制台是否有流式相关错误

### 问题 3：工具调用失败

**症状**：工具没有被调用

**解决方案**：
1. 确认工具已正确注册
2. 检查工具参数定义是否正确
3. 增强 System Prompt 中关于工具使用的说明

## 🎨 界面定制

### 修改消息气泡颜色

在 `MessageBubbleView.swift` 中：

```swift
private var backgroundColor: Color {
    switch message.role {
    case .user:
        return Color.blue  // 修改为你喜欢的颜色
    // ...
    }
}
```

### 调整字体大小

```swift
Text(message.content)
    .font(.system(size: 16))  // 修改字体大小
```

## 📚 扩展阅读

- [SwiftAgent 完整教程](../TUTORIAL_SwiftUI_Streaming.md)
- [SwiftAgent 框架文档](../Documentation.docc/SwiftAgent.md)
- [OpenAI API 文档](https://platform.openai.com/docs)

## 📝 TODO

- [ ] 添加消息导出功能
- [ ] 实现对话分支管理
- [ ] 支持图片上传和分析
- [ ] 添加语音输入/输出
- [ ] 实现消息编辑和重新生成
- [ ] 添加 Markdown 渲染支持
- [ ] 实现离线模式

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

**Happy Coding! 🚀**

如有问题或建议，欢迎在 [GitHub](https://github.com/leyugod/swiftAgent) 上讨论。

