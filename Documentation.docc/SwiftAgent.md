# ``SwiftAgent``

一个功能完整、生产级的 Swift AI Agent 开发框架

## Overview

SwiftAgent 是一个使用 Swift 6 构建的现代化 AI Agent 框架，提供完整的 Agent 生命周期管理、多 LLM 支持、工具系统、记忆管理和多智能体协作能力。

### 主要特性

- **多 LLM 支持**：OpenAI、Anthropic 等主流 LLM 提供商
- **工具系统**：5 个内置工具 + 灵活的自定义工具接口
- **多智能体**：支持顺序、并行和协作执行模式
- **记忆管理**：InMemory、Vector Store 和 RAG 支持
- **生产级**：完整测试、日志监控、错误恢复
- **Swift 6**：Actor 并发模型，类型安全

### 快速开始

```swift
import SwiftAgent

// 创建 LLM Provider
let provider = OpenAIProvider(apiKey: "your-api-key", model: "gpt-4")

// 创建 Agent
let agent = Agent(
    name: "MyAssistant",
    llmProvider: provider,
    systemPrompt: "你是一个智能助手"
)

// 注册内置工具
await agent.registerAllBuiltinTools()

// 运行 Agent
let result = try await agent.run(input: "请计算 2 + 2")
print(result)
```

## Topics

### Essentials

- ``Agent``
- ``AgentProtocol``
- ``AgentLoop``

### LLM Providers

- ``LLMProviderProtocol``
- ``OpenAIProvider``
- ``AnthropicProvider``
- ``RetryPolicy``

### Tools

- ``ToolProtocol``
- ``ToolRegistry``
- ``ToolExecutor``
- ``CalculatorTool``
- ``DateTimeTool``
- ``FileSystemTool``
- ``WebSearchTool``
- ``WeatherTool``

### Memory & Context

- ``MemoryProtocol``
- ``InMemoryStore``
- ``VectorStoreProtocol``
- ``RAGSystem``
- ``ContextManager``
- ``MessageHistory``

### Multi-Agent

- ``MultiAgentSystem``
- ``AgentCoordinator``
- ``AgentCommunication``

### Logging & Monitoring

- ``Logger``
- ``LogLevel``
- ``PerformanceMonitor``
- ``PerformanceMetric``

### Protocols

- ``MCPProtocol``
- ``A2AProtocol``
- ``ANPProtocol``

### Evaluation

- ``EvaluatorProtocol``
- ``Metrics``
- ``Benchmark``

