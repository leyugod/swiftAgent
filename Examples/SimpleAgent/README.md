# SimpleAgent 示例

这是一个简单的 AI Agent 示例，演示如何使用 SwiftAgent 框架创建和运行基本的智能体。

## 功能特性

- ✅ 基本对话能力
- ✅ 数学计算（使用 Calculator 工具）
- ✅ 时间日期查询（使用 DateTime 工具）
- ✅ 自动工具选择和执行

## 快速开始

### 1. 设置环境变量

```bash
export OPENAI_API_KEY=your_openai_api_key
```

### 2. 运行示例

```bash
cd Examples/SimpleAgent
swift run
```

## 示例输出

```
╔══════════════════════════════════════════════════════════════╗
║              SwiftAgent - Simple Agent 示例                   ║
╚══════════════════════════════════════════════════════════════╝

📦 注册内置工具...
✅ 工具注册成功

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 示例 1：简单对话
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 用户: 你好！介绍一下你自己。

🤖 Agent: 你好！我是 SimpleAssistant，一个智能助手...

⏱  耗时: 1.23 秒

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 示例 2：数学计算（使用工具）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 用户: 请计算 sqrt(144) + 2^5 的结果

🤖 Agent: 计算结果是 44.0

⏱  耗时: 2.15 秒
```

## 代码结构

```
SimpleAgent/
├── Package.swift          # Swift Package 配置
├── README.md             # 本文件
└── Sources/
    └── SimpleAgent/
        └── main.swift     # 主程序
```

## 核心代码解析

### 创建 Agent

```swift
let provider = OpenAIProvider(
    apiKey: OPENAI_API_KEY,
    model: "gpt-4",
    temperature: 0.7
)

let agent = Agent(
    name: "SimpleAssistant",
    llmProvider: provider,
    systemPrompt: "你是一个智能助手..."
)
```

### 注册工具

```swift
// 注册基础工具（Calculator + DateTime）
await agent.registerBasicTools()
```

### 运行 Agent

```swift
let result = try await agent.run(input: "请计算 2 + 2")
print(result)
```

## 可用工具

### Calculator Tool
- 基本运算：`+`、`-`、`*`、`/`
- 幂运算：`^`
- 数学函数：`sqrt`、`sin`、`cos`、`tan`、`log`、`ln`、`abs`

示例：
```
请计算 sqrt(16) + 2^3
```

### DateTime Tool
- 获取当前时间
- 日期格式化
- 日期加减
- 计算日期差异

示例：
```
现在是几点？
从今天到 2025-12-31 还有多少天？
```

## 扩展示例

### 添加更多工具

```swift
// 注册所有内置工具
await agent.registerAllBuiltinTools()
```

### 自定义工具

```swift
struct MyCustomTool: ToolProtocol {
    let name = "my_tool"
    let description = "My custom tool"
    var parameters: [ToolParameter] { ... }
    
    func execute(arguments: [String: Any]) async throws -> String {
        // 实现工具逻辑
        return "Result"
    }
}

await agent.toolRegistry.register(MyCustomTool())
```

## 故障排除

### 问题：API Key 错误
```
❌ 错误：请设置 OPENAI_API_KEY 环境变量
```

**解决方案**：设置有效的 OpenAI API Key
```bash
export OPENAI_API_KEY=sk-...
```

### 问题：网络超时
**解决方案**：检查网络连接，或增加超时时间

### 问题：工具调用失败
**解决方案**：检查工具参数格式，查看详细错误信息

## 相关资源

- [SwiftAgent 文档](../../README.md)
- [工具开发指南](../../IMPLEMENTATION.md)
- [更多示例](../)

## 许可证

MIT License
