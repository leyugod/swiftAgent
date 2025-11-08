# MultiAgentSystem 示例

这是一个多智能体系统示例，演示如何创建、协调和管理多个 AI Agent 完成复杂任务。

## 功能特性

- 🔄 **顺序执行**：Agent 按顺序依次完成任务
- ⚡ **并行执行**：多个 Agent 同时工作，提高效率
- 🤝 **协作任务**：多个 Agent 协同完成复杂项目
- 👥 **角色专业化**：每个 Agent 专注于特定领域
- 📊 **任务编排**：灵活的任务分配和结果汇总

## 快速开始

### 1. 设置 API Key

```bash
export OPENAI_API_KEY=your_openai_api_key
```

### 2. 运行示例

```bash
cd Examples/MultiAgentSystem
swift run
```

## 演示场景

### 演示 1：顺序执行

多个 Agent 按照固定顺序完成任务，后一个 Agent 的输入依赖前一个的输出。

```
Researcher → Analyst → Writer
```

**应用场景**：
- 内容创作流程
- 数据处理管道
- 审批工作流

**示例任务**：
```swift
let tasks = [
    ("researcher", "搜索关于 Swift 并发编程的最新资料"),
    ("analyst", "分析 Swift async/await 的优势和应用场景"),
    ("writer", "用简洁的语言总结 Swift 并发编程的核心概念")
]

let results = try await system.executeSequential(tasks: tasks)
```

### 演示 2：并行执行

多个 Agent 同时执行独立的任务，互不干扰，提高整体效率。

```
Calculator  ──┐
DateTime    ──┼──→ 汇总结果
Researcher  ──┘
```

**应用场景**：
- 数据并行处理
- 多源信息采集
- 独立任务批处理

**示例任务**：
```swift
let tasks = [
    ("calculator", "计算 2024 年一共有多少天"),
    ("datetime", "告诉我现在的日期和时间"),
    ("researcher", "Swift 是什么时候发布的？")
]

let results = try await system.executeParallel(tasks: tasks)
```

**性能优势**：并行执行可以将总耗时减少到最慢任务的时间。

### 演示 3：协作任务

多个 Agent 协同工作，完成复杂的项目。每个 Agent 扮演不同角色，共同达成目标。

```
TeamLeader (项目经理)
    ↓
    规划任务
    ↓
    ┌────────────┬────────────┬────────────┐
    ↓            ↓            ↓            ↓
Researcher   Analyst      Writer       其他
    ↓            ↓            ↓
    收集信息      分析数据      撰写报告
    └────────────┴────────────┴────────────┘
                    ↓
                最终输出
```

**应用场景**：
- 研究报告撰写
- 产品开发流程
- 问题诊断与解决

**示例流程**：
```
1. TeamLeader：分解任务，分配角色
2. Researcher：收集相关资料
3. Analyst：分析数据，提取洞察
4. Writer：整合信息，撰写报告
5. 输出最终成果
```

## 代码结构

```
MultiAgentSystem/
├── Package.swift
├── README.md
└── Sources/
    └── MultiAgentSystem/
        └── main.swift  (~400 行)
```

## 核心实现

### 1. 创建专业化 Agent

```swift
// 研究员 - 专注信息搜集
let researcher = Agent(
    name: "Researcher",
    llmProvider: provider,
    systemPrompt: "你是专业研究员，擅长搜索和整理信息..."
)

// 分析师 - 专注数据分析
let analyst = Agent(
    name: "Analyst",
    llmProvider: provider,
    systemPrompt: "你是数据分析师，擅长分析信息并提取洞察..."
)

// 撰稿人 - 专注内容创作
let writer = Agent(
    name: "Writer",
    llmProvider: provider,
    systemPrompt: "你是专业撰稿人，擅长将复杂信息转化为易懂的文字..."
)
```

### 2. 构建多智能体系统

```swift
let system = MultiAgentSystem()

// 添加 Agent
await system.addAgent(id: "researcher", agent: researcher)
await system.addAgent(id: "analyst", agent: analyst)
await system.addAgent(id: "writer", agent: writer)
```

### 3. 顺序执行任务

```swift
let tasks = [
    ("researcher", "搜索资料"),
    ("analyst", "分析数据"),
    ("writer", "撰写报告")
]

let results = try await system.executeSequential(tasks: tasks)
```

### 4. 并行执行任务

```swift
let tasks = [
    ("agent1", "任务1"),
    ("agent2", "任务2"),
    ("agent3", "任务3")
]

let results = try await system.executeParallel(tasks: tasks)
```

### 5. 手动协调（更灵活）

```swift
// 步骤 1
let result1 = try await agent1.run(input: "任务1")

// 步骤 2（使用步骤1的结果）
let result2 = try await agent2.run(input: "基于 \(result1) 执行任务2")

// 步骤 3
let result3 = try await agent3.run(input: "整合 \(result1) 和 \(result2)")
```

## 设计模式

### 1. 管道模式（Pipeline）
数据按顺序流经多个 Agent，每个 Agent 处理并传递结果。

```
Input → Agent1 → Agent2 → Agent3 → Output
```

### 2. 分散-汇总模式（Scatter-Gather）
任务分发给多个 Agent 并行处理，然后汇总结果。

```
       ┌─→ Agent1 ─┐
Input ─┼─→ Agent2 ─┼→ Aggregator → Output
       └─→ Agent3 ─┘
```

### 3. 主从模式（Master-Worker）
主 Agent 分配任务，从 Agent 执行任务并报告结果。

```
        Master
       /   |   \
Worker1 Worker2 Worker3
```

### 4. 协作模式（Collaborative）
Agent 之间相互通信，共同完成任务。

```
Agent1 ←→ Agent2 ←→ Agent3
```

## 高级特性

### 角色专业化

每个 Agent 可以配置不同的：
- **System Prompt**：定义角色和专长
- **Temperature**：控制创造性（0.0-1.0）
- **Tools**：赋予特定能力
- **Model**：使用不同的 LLM

```swift
// 创造性写作 - 高 temperature
let creativeWriter = Agent(
    ...,
    llmProvider: OpenAIProvider(..., temperature: 0.9)
)

// 精确计算 - 低 temperature
let calculator = Agent(
    ...,
    llmProvider: OpenAIProvider(..., temperature: 0.1)
)
```

### 动态任务分配

根据任务类型自动选择合适的 Agent：

```swift
func routeTask(_ task: String) async -> String {
    if task.contains("计算") {
        return "calculator"
    } else if task.contains("搜索") {
        return "researcher"
    } else {
        return "general"
    }
}

let agentId = await routeTask("请搜索...")
let result = try await agents[agentId]?.run(input: task)
```

### 结果聚合

处理多个 Agent 的输出：

```swift
func aggregateResults(_ results: [(String, String)]) -> String {
    var summary = "汇总报告：\n\n"
    for (agent, result) in results {
        summary += "[\(agent)]: \(result)\n\n"
    }
    return summary
}
```

## 性能优化

### 1. 并行执行优化

```swift
// ✅ 好：独立任务并行
await system.executeParallel([
    ("agent1", "独立任务1"),
    ("agent2", "独立任务2")
])

// ❌ 差：有依赖的任务并行（会出错）
// agent2 需要 agent1 的结果，不能并行
```

### 2. 批量处理

```swift
// 将大量小任务分配给多个 Agent
let tasks = largeBatch.chunked(into: agentCount)
for (agentId, taskBatch) in zip(agentIds, tasks) {
    results.append(await agents[agentId].processBatch(taskBatch))
}
```

### 3. 缓存和记忆

```swift
// Agent 可以记住之前的对话
let agent = Agent(..., maxHistory: 10)
```

## 实际应用案例

### 案例 1：内容创作流水线

```
1. Researcher：调研主题背景
2. Analyst：分析受众需求
3. Writer：撰写初稿
4. Editor：审校润色
5. Publisher：发布内容
```

### 案例 2：数据处理管道

```
1. Collector：采集数据
2. Cleaner：清洗数据
3. Analyzer：分析数据
4. Visualizer：生成图表
5. Reporter：生成报告
```

### 案例 3：问题诊断系统

```
1. Triager：问题分类
2. Specialists：各专家诊断（并行）
3. Coordinator：整合诊断结果
4. Resolver：提供解决方案
```

## 故障排除

### 问题：Agent 响应慢
- **原因**：顺序执行造成累积延迟
- **解决**：使用并行执行独立任务

### 问题：Agent 之间信息丢失
- **原因**：没有正确传递上下文
- **解决**：在任务描述中包含必要的上下文信息

### 问题：并发错误
- **原因**：修改共享状态
- **解决**：使用 Actor 隔离，避免共享可变状态

## 扩展示例

### 自定义协调器

```swift
actor CustomCoordinator {
    private var agents: [String: Agent]
    
    func orchestrate(task: ComplexTask) async throws -> Result {
        // 自定义编排逻辑
    }
}
```

### Agent 间通信

```swift
// 使用 MCP 协议
let message = MCPMessage(...)
try await agent1.send(message, to: agent2)
```

## 相关资源

- [SwiftAgent 文档](../../README.md)
- [多智能体协作指南](../../IMPLEMENTATION.md#多智能体系统)
- [更多示例](../)

## 许可证

MIT License
