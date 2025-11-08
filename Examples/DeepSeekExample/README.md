# DeepSeek Example

这个示例展示了如何使用 SwiftAgent Framework 与 DeepSeek API 进行交互。

## 功能演示

1. **基础对话** - 简单的问答交互
2. **流式响应** - 实时显示生成的内容
3. **工具调用** - Agent 使用内置工具
4. **代码生成** - 使用 DeepSeek Coder 模型
5. **多轮对话** - 保持上下文的连续对话
6. **性能优化** - 使用缓存提升响应速度

## 准备工作

### 1. 获取 DeepSeek API Key

访问 [DeepSeek 官网](https://platform.deepseek.com/) 注册并获取 API Key。

### 2. 设置环境变量

```bash
export DEEPSEEK_API_KEY='your-deepseek-api-key-here'
```

## 运行示例

### 方式 1: 直接运行

```bash
cd Examples/DeepSeekExample
swift run
```

### 方式 2: 使用 Xcode

1. 打开 `Examples/DeepSeekExample/Package.swift`
2. 在 Xcode 中选择 Scheme: DeepSeekExample
3. 编辑 Scheme，添加环境变量 `DEEPSEEK_API_KEY`
4. 运行

## DeepSeek 模型说明

### 可用模型

1. **deepseek-chat** (默认)
   - 通用对话模型
   - 适合：问答、对话、创作
   - 上下文长度：32K tokens

2. **deepseek-coder**
   - 代码专用模型
   - 适合：代码生成、代码解释、技术问答
   - 支持多种编程语言

3. **deepseek-reasoner**
   - 推理增强模型
   - 适合：复杂问题分析、逻辑推理

### 使用不同模型

```swift
// 使用 Chat 模型
let chatProvider = DeepSeekProvider(apiKey: apiKey, model: .chat)

// 使用 Coder 模型
let coderProvider = DeepSeekProvider(apiKey: apiKey, model: .coder)

// 使用 Reasoner 模型
let reasonerProvider = DeepSeekProvider(apiKey: apiKey, model: .reasoner)

// 使用自定义模型名称
let customProvider = DeepSeekProvider(apiKey: apiKey, modelName: "your-model")
```

## 示例代码说明

### 示例 1: 基础对话

```swift
let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
let agent = Agent(name: "助手", llmProvider: provider)
let response = try await agent.run(input: "你好")
```

### 示例 2: 流式响应

```swift
let callback = StreamingCallback(
    onContent: { content in
        print(content, terminator: "")
    }
)
let response = try await agent.streamRunWithCallback(
    input: "讲个故事",
    callback: callback
)
```

### 示例 3: 工具调用

```swift
await agent.registerBasicTools()  // 注册内置工具
let response = try await agent.run(input: "今天几号？")
```

### 示例 4: 使用缓存

```swift
let cacheManager = await CacheManager(defaultTTL: 3600)
let cachedProvider = CachedLLMProvider(
    baseProvider: provider,
    cacheManager: cacheManager
)
let agent = Agent(name: "缓存助手", llmProvider: cachedProvider)
```

## API 特点

### DeepSeek API 优势

- ✅ **兼容 OpenAI 格式** - 易于迁移和使用
- ✅ **中文优化** - 对中文理解和生成效果好
- ✅ **性价比高** - 价格友好
- ✅ **支持流式输出** - 实时响应
- ✅ **工具调用支持** - Function Calling

### 请求参数

```swift
public func chat(
    messages: [LLMMessage],     // 消息历史
    tools: [LLMToolFunction]?,  // 可用工具（可选）
    temperature: Double         // 温度参数 (0.0-2.0)
) async throws -> LLMResponse
```

### 响应结构

```swift
public struct LLMResponse {
    public let content: String              // 生成的内容
    public let toolCalls: [LLMToolCall]?   // 工具调用（如果有）
    public let finishReason: String?       // 结束原因
    public let usage: TokenUsage?          // Token 使用统计
}
```

## 最佳实践

### 1. 合理设置温度参数

- `temperature: 0.1-0.3` - 需要准确性（代码生成、事实问答）
- `temperature: 0.7-0.9` - 需要创造性（故事创作、头脑风暴）
- `temperature: 1.0+` - 最大创造性（实验性用途）

### 2. 使用流式响应提升体验

```swift
// 推荐：使用流式响应，提供实时反馈
let stream = try await agent.streamRun(input: userInput)
for try await chunk in stream {
    // 实时显示
}
```

### 3. 启用缓存降低成本

```swift
// 对于重复的查询，使用缓存
let cachedProvider = CachedLLMProvider(
    baseProvider: provider,
    cacheManager: cacheManager
)
```

### 4. 错误处理

```swift
do {
    let response = try await agent.run(input: userInput)
} catch let error as ToolError {
    print("工具错误: \(error)")
} catch {
    print("未知错误: \(error)")
}
```

### 5. 监控 Token 使用

```swift
if let usage = response.usage {
    print("Token使用: \(usage.totalTokens)")
    print("成本估算: $\(estimateCost(usage.totalTokens))")
}
```

## 性能优化

### 1. 连接复用

框架自动管理 URLSession，复用 HTTP 连接。

### 2. 请求重试

自动重试失败的请求（默认3次）：

```swift
let provider = DeepSeekProvider(
    apiKey: apiKey,
    retryPolicy: RetryPolicy(
        maxRetries: 3,
        initialDelay: 1.0
    )
)
```

### 3. 响应缓存

缓存相同请求的响应，降低 API 成本：

```swift
let cacheManager = await CacheManager(
    diskCachePath: "./cache",
    defaultTTL: 3600,  // 1小时
    maxMemorySize: 100
)
```

## 常见问题

### Q: 如何处理 API 限流？

```swift
// 使用重试策略
let provider = DeepSeekProvider(
    apiKey: apiKey,
    retryPolicy: .exponentialBackoff
)
```

### Q: 如何切换模型？

```swift
// 方式1: 使用预定义模型
let provider = DeepSeekProvider(apiKey: apiKey, model: .coder)

// 方式2: 使用自定义模型名
let provider = DeepSeekProvider(apiKey: apiKey, modelName: "custom-model")
```

### Q: 如何监控 API 调用？

```swift
// 使用框架的日志系统
let logger = await Logger.shared
await logger.log("API调用", level: .info, metadata: [
    "model": provider.modelName,
    "tokens": "\(usage.totalTokens)"
])
```

## 相关资源

- [DeepSeek 官方文档](https://platform.deepseek.com/docs)
- [DeepSeek API 参考](https://platform.deepseek.com/api-docs)
- [SwiftAgent 文档](../../README.md)
- [定价信息](https://platform.deepseek.com/pricing)

## 支持

如有问题，请：
1. 查看 [SwiftAgent 文档](../../README.md)
2. 查看 [DeepSeek 文档](https://platform.deepseek.com/docs)
3. 提交 Issue 到项目仓库

