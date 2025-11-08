# SwiftAgent

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" />
  <img src="https://img.shields.io/badge/iOS-15.0+-blue.svg" />
  <img src="https://img.shields.io/badge/macOS-12.0+-blue.svg" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" />
</p>

基于 [Hello-Agents](https://github.com/datawhalechina/Hello-Agents) 教程核心思想的 Swift AI Native Agent 开发框架。

## 项目简介

SwiftAgent 是一个完整的、生产就绪的智能体开发框架，旨在帮助开发者快速构建强大的 AI Native Agent 应用。

### 核心特性

- ✅ **完整的 Agent Loop**: 实现感知-思考-行动-观察的完整循环
- ✅ **多 LLM 提供商支持**: 支持 OpenAI、Anthropic 等主流模型
- ✅ **灵活的工具系统**: 易于扩展的工具注册和执行机制
- ✅ **记忆与检索 (RAG)**: 向量存储和检索增强生成
- ✅ **上下文工程**: 高级上下文管理和提示词模板系统
- ✅ **多智能体协作**: 支持顺序、并行、分层和协作等多种协调策略
- ✅ **通信协议**: 实现 MCP、A2A、ANP 等协议
- ✅ **评估系统**: 完整的测试和基准测试框架
- ✅ **Swift 6 原生**: 充分利用 Swift Concurrency 和类型安全

## 快速开始

### 安装

#### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/SwiftAgent.git", from: "1.0.0")
]
```

### 基础使用

```swift
import SwiftAgent

// 1. 创建 LLM Provider
let llm = OpenAIProvider(
    apiKey: "your-api-key",
    modelName: "gpt-4o-mini"
)

// 2. 创建 Agent
let agent = Agent(
    name: "智能助手",
    llmProvider: llm,
    systemPrompt: "你是一个专业的智能助手，可以使用工具帮助用户解决问题。"
)

// 3. 运行 Agent
let response = try await agent.run("你好，请介绍一下你自己")
print(response)
```

### 使用工具

```swift
// 定义自定义工具
struct WeatherTool: ToolProtocol {
    let name = "get_weather"
    let description = "查询指定城市的天气"
    
    var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "city",
                type: "string",
                description: "城市名称",
                required: true
            )
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let city = arguments["city"] as? String else {
            throw ToolError.invalidArguments("城市参数缺失")
        }
        
        // 实现天气查询逻辑
        return "\(city)当前天气：晴，25摄氏度"
    }
}

// 注册工具
let weatherTool = WeatherTool()
await agent.registerTool(weatherTool)

// 使用工具
let response = try await agent.run("北京今天天气怎么样？")
```

### 多智能体协作

```swift
// 创建多个 Agent
let researcher = Agent(
    name: "研究员",
    llmProvider: llm,
    systemPrompt: "你是一个专业研究员，擅长收集和分析信息。"
)

let writer = Agent(
    name: "写作者",
    llmProvider: llm,
    systemPrompt: "你是一个专业写作者，擅长将信息整理成文章。"
)

// 创建多智能体系统
let system = MultiAgentSystem(
    config: .init(
        coordinationStrategy: .hierarchical,
        communicationMode: .shared
    )
)

// 注册 Agent
await system.register(id: "researcher", agent: researcher)
await system.register(id: "writer", agent: writer)

// 执行任务
let result = try await system.executeTask("写一篇关于人工智能的文章")
```

### 记忆与检索 (RAG)

```swift
// 创建向量存储
let vectorStore = InMemoryVectorStore()

// 创建 RAG 系统
let rag = RAGSystem(
    vectorStore: vectorStore,
    llmProvider: llm
)

// 添加文档到知识库
try await rag.addDocument(
    content: "人工智能是一种模拟人类智能的技术...",
    metadata: ["source": "wiki", "category": "AI"]
)

// 检索并生成回答
let answer = try await rag.query("什么是人工智能？")
```

## 架构设计

SwiftAgent 采用模块化设计，主要包含以下模块：

```
SwiftAgent/
├── Core/              # 核心 Agent 实现
│   ├── Agent.swift
│   ├── AgentLoop.swift
│   └── AgentProtocol.swift
├── LLM/               # LLM 提供商
│   ├── LLMProvider.swift
│   ├── OpenAIProvider.swift
│   └── AnthropicProvider.swift
├── Tools/             # 工具系统
│   ├── Tool.swift
│   ├── ToolRegistry.swift
│   └── ToolExecutor.swift
├── Memory/            # 记忆与检索
│   ├── Memory.swift
│   ├── VectorStore.swift
│   ├── RAG.swift
│   └── MemoryManager.swift
├── Context/           # 上下文工程
│   ├── ContextManager.swift
│   ├── MessageHistory.swift
│   └── PromptTemplate.swift
├── Protocols/         # 通信协议
│   ├── MCPProtocol.swift
│   ├── A2AProtocol.swift
│   └── ANPProtocol.swift
├── MultiAgent/        # 多智能体系统
│   ├── MultiAgentSystem.swift
│   ├── AgentCoordinator.swift
│   └── AgentCommunication.swift
└── Evaluation/        # 评估系统
    ├── Evaluator.swift
    ├── Metrics.swift
    └── Benchmark.swift
```

## 核心概念

### Agent Loop

SwiftAgent 实现了完整的智能体循环：

1. **感知 (Perception)**: 接收用户输入或环境反馈
2. **思考 (Thought)**: LLM 分析并制定计划
3. **行动 (Action)**: 调用工具或生成响应
4. **观察 (Observation)**: 接收行动结果并继续循环

### 工具系统

工具是 Agent 与外部世界交互的桥梁。通过 `ToolProtocol` 协议，你可以轻松创建自定义工具：

- 定义工具名称和描述
- 声明参数类型和要求
- 实现执行逻辑

### 多智能体协作

支持多种协调策略：

- **Sequential**: 顺序执行，每个 Agent 依次处理
- **Parallel**: 并行执行，所有 Agent 同时工作
- **Hierarchical**: 分层执行，协调者分配任务给工作者
- **Collaborative**: 协作执行，多轮讨论达成共识

## 高级功能

### 自定义提示词模板

```swift
let template = PromptTemplate(template: """
你是一个{{role}}，擅长{{skill}}。
请回答以下问题：{{question}}
""")

let rendered = try template.render(with: [
    "role": "数据分析师",
    "skill": "数据可视化",
    "question": "如何制作一个好的图表？"
])
```

### 性能评估

```swift
// 创建评估器
let accuracyEvaluator = AccuracyEvaluator()
let toolCallEvaluator = ToolCallEvaluator()

// 创建基准测试
let benchmark = Benchmark(
    name: "Agent 性能测试",
    agent: agent,
    evaluators: [accuracyEvaluator, toolCallEvaluator]
)

// 运行测试
let testCases = [
    BenchmarkTestCase(
        input: "北京天气",
        expected: "调用 get_weather 工具"
    )
]

let report = try await benchmark.run(testCases)
print(report.generateReport())
```

## 示例项目

查看 `Examples/` 目录获取完整示例：

- **SimpleAgent**: 基础 Agent 使用示例
- **TravelAssistant**: 智能旅行助手（集成工具调用）
- **MultiAgentSystem**: 多智能体协作示例

## 技术栈

- Swift 6.0+
- Swift Concurrency (async/await, Actor)
- Swift Package Manager
- 支持 iOS 15.0+ 和 macOS 12.0+

## 路线图

- [ ] 更多内置工具
- [ ] 持久化存储支持
- [ ] 流式响应优化
- [ ] Web UI 界面
- [ ] 更多 LLM 提供商
- [ ] Docker 部署支持

## 贡献

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 致谢

本项目基于 [Hello-Agents](https://github.com/datawhalechina/Hello-Agents) 教程的核心思想开发，感谢 Datawhale 社区的贡献。

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 联系方式

- GitHub: [@your-username](https://github.com/your-username)
- Email: your-email@example.com

---

⭐ 如果这个项目对你有帮助，请给它一个 Star！
