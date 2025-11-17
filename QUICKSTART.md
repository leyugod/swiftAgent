# SwiftAgent 快速开始指南

## 🎯 5分钟快速上手

### 1. 添加依赖

在你的 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/leyugod/swiftAgent.git", from: "1.0.0")
]
```

### 2. 基础使用

```swift
import SwiftAgent

// 创建 LLM Provider
let provider = OpenAIProvider(
    apiKey: "your-api-key",
    modelName: "gpt-4o-mini"
)

// 创建 Agent
let agent = Agent(
    name: "AI助手",
    llmProvider: provider,
    systemPrompt: "你是一个智能助手"
)

// 注册工具
await agent.registerBasicTools()

// 运行 Agent
let response = try await agent.run("计算 2 + 2")
print(response)
```

### 3. 流式输出

```swift
// 创建流式回调
let callback = StreamingCallback(
    onContent: { content in
        print(content, terminator: "")  // 逐字打印
    },
    onCompletion: { response in
        print("\n完成！")
    }
)

// 流式运行
try await agent.streamRunWithCallback(
    input: "讲个故事",
    callback: callback
)
```

### 4. SwiftUI 集成

```swift
import SwiftUI
import SwiftAgent

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [String] = []
    private var agent: Agent?
    
    func initialize() async {
        let provider = OpenAIProvider(
            apiKey: "your-key",
            modelName: "gpt-4o-mini"
        )
        
        agent = Agent(
            name: "助手",
            llmProvider: provider,
            systemPrompt: "你是一个智能助手"
        )
        
        await agent?.registerBasicTools()
    }
    
    func sendMessage(_ text: String) async {
        messages.append("用户: \(text)")
        
        let callback = StreamingCallback(
            onContent: { [weak self] content in
                if let lastIndex = self?.messages.indices.last,
                   self?.messages[lastIndex].hasPrefix("AI: ") == true {
                    self?.messages[lastIndex] += content
                } else {
                    self?.messages.append("AI: \(content)")
                }
            }
        )
        
        try? await agent?.streamRunWithCallback(
            input: text,
            callback: callback
        )
    }
}

struct ChatView: View {
    @StateObject var viewModel = ChatViewModel()
    @State var input = ""
    
    var body: some View {
        VStack {
            List(viewModel.messages, id: \.self) { message in
                Text(message)
            }
            
            HStack {
                TextField("输入消息", text: $input)
                Button("发送") {
                    Task {
                        await viewModel.sendMessage(input)
                        input = ""
                    }
                }
            }
            .padding()
        }
        .task {
            await viewModel.initialize()
        }
    }
}
```

## 📚 完整示例

查看 `SwiftAgentChatExample/` 目录获取完整的 SwiftUI 聊天应用示例。

## 🛠️ 自定义工具

```swift
struct MyTool: ToolProtocol {
    let name = "my_tool"
    let description = "我的自定义工具"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "input",
                type: "string",
                description: "输入参数",
                required: true
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let input = arguments["input"] as? String else {
            throw ToolError.invalidArguments("缺少输入")
        }
        
        // 处理逻辑
        return "处理结果: \(input)"
    }
}

// 注册
await agent.registerTool(MyTool())
```

## 🎓 更多教程

- **完整教程**: [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md)
- **示例项目**: [SwiftAgentChatExample/](SwiftAgentChatExample/)
- **API 文档**: [Documentation.docc/](Documentation.docc/)

## 💬 获取帮助

- GitHub Issues: https://github.com/leyugod/swiftAgent/issues
- 示例代码: SwiftAgentChatExample 目录
- 完整文档: Documentation.docc 目录

---

**开始构建你的 AI 应用吧！🚀**

