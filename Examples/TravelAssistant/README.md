# TravelAssistant 示例

这是一个旅行助手 AI Agent 示例，演示如何组合多个工具创建实用的应用。

## 功能特性

- 🌤️ **天气查询**：查询目的地天气和预报
- 🔍 **信息搜索**：搜索景点、美食、住宿等信息  
- 💰 **预算计算**：计算旅行费用和预算分配
- 📅 **日期规划**：处理旅行日期和时区
- 🗺️ **综合规划**：结合多个工具提供完整的旅行方案

## 快速开始

### 1. 设置 API Key

```bash
export OPENAI_API_KEY=your_openai_api_key
```

### 2. 运行示例

```bash
cd Examples/TravelAssistant
swift run
```

## 示例场景

### 场景 1：天气查询

**用户输入**：
```
我计划去北京旅游，请帮我查一下那里的天气情况，包括未来3天的预报。
```

**助手响应**：
```
根据天气查询结果，北京当前天气...
（使用 weather 工具获取实时数据）
```

### 场景 2：景点搜索

**用户输入**：
```
我想了解上海的著名景点和美食推荐。
```

**助手响应**：
```
为您搜索到上海的热门景点：
1. 外滩...
2. 东方明珠...
（使用 web_search 工具获取信息）
```

### 场景 3：预算计算

**用户输入**：
```
我有 5000 元预算，计划 4 天旅行，每天住宿 300 元，餐饮 200 元。
请帮我算一下还剩多少钱可以用于景点门票和购物？
```

**助手响应**：
```
让我帮您计算：
- 总预算：5000 元
- 住宿费用（4天）：300 × 4 = 1200 元
- 餐饮费用（4天）：200 × 4 = 800 元
- 剩余预算：5000 - 1200 - 800 = 3000 元

您还有 3000 元可以用于景点门票和购物。
（使用 calculator 工具进行计算）
```

### 场景 4：日期规划

**用户输入**：
```
现在是几点？如果我从今天开始计划，30 天后是几月几日？
```

**助手响应**：
```
当前时间：2024-11-04 14:30:00
30 天后：2024-12-04
（使用 datetime 工具计算）
```

### 场景 5：综合规划

**用户输入**：
```
帮我规划一个周末（2天）的杭州之旅：
1. 查询杭州的天气
2. 搜索必去景点  
3. 估算总预算
```

**助手响应**：
```
为您规划杭州 2 日游：

🌤️ 天气情况：
（调用 weather 工具）

🗺️ 必去景点：
（调用 web_search 工具）

💰 预算估算：
（调用 calculator 工具）

建议行程：...
```

## 代码结构

```
TravelAssistant/
├── Package.swift
├── README.md
└── Sources/
    └── TravelAssistant/
        └── main.swift
```

## 核心实现

### 1. 创建专业的旅行助手

```swift
let assistant = Agent(
    name: "TravelAssistant",
    llmProvider: provider,
    systemPrompt: """
    你是一个专业的旅行助手...
    """
)

// 注册所有工具
await assistant.registerAllBuiltinTools()
```

### 2. 工具组合使用

旅行助手会根据用户需求自动选择和组合工具：

- **weather**：查询天气
- **web_search**：搜索信息
- **calculator**：计算预算
- **datetime**：处理日期
- **filesystem**：保存行程（可选）

### 3. 复杂场景处理

Agent 可以在一次对话中多次调用不同工具：

```
用户："帮我规划杭州周末游"
  ↓
Agent 思考
  ↓
1. 调用 datetime 工具 → 获取当前时间和周末日期
  ↓
2. 调用 weather 工具 → 查询杭州天气
  ↓
3. 调用 web_search 工具 → 搜索景点信息
  ↓
4. 调用 calculator 工具 → 计算预算
  ↓
综合回复
```

## 扩展功能

### 添加自定义工具

```swift
// 酒店预订工具
struct HotelBookingTool: ToolProtocol {
    let name = "hotel_booking"
    let description = "查询和预订酒店"
    
    // 实现...
}

await assistant.toolRegistry.register(HotelBookingTool())
```

### 保存旅行计划

```swift
// 使用 FileSystem 工具保存行程
let plan = """
杭州 2 日游计划
================
Day 1: ...
Day 2: ...
"""

// Agent 自动调用 filesystem 工具保存
await assistant.run(input: "请把这个行程保存到 hangzhou_trip.txt")
```

## 工具说明

### Weather Tool（模拟模式）

默认使用模拟数据。要使用真实天气API，需要配置：

```swift
let weatherProvider = OpenWeatherMapProvider(
    apiKey: "your_weather_api_key"
)
await BuiltinToolsRegistry.registerWeatherTool(
    to: assistant.toolRegistry,
    weatherProvider: weatherProvider
)
```

### WebSearch Tool（模拟模式）

默认返回模拟搜索结果。要使用真实搜索，需要配置：

```swift
let searchProvider = GoogleSearchProvider(
    apiKey: "your_google_api_key",
    searchEngineId: "your_search_engine_id"
)
await BuiltinToolsRegistry.registerWebSearchTool(
    to: assistant.toolRegistry,
    searchProvider: searchProvider
)
```

## 注意事项

- ⚠️ 默认工具使用模拟数据（演示用）
- ⚠️ 真实使用需要配置相应的 API Key
- ⚠️ 注意 API 调用频率限制
- ⚠️ 预算计算仅供参考

## 相关资源

- [SwiftAgent 文档](../../README.md)
- [内置工具说明](../../IMPLEMENTATION.md#内置工具)
- [更多示例](../)

## 许可证

MIT License
