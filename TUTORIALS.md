# SwiftAgent 教程索引

欢迎使用 SwiftAgent Framework！本文档将帮助您找到适合的学习资源。

## 🎯 学习路径

### 1️⃣ 初学者 - 快速入门

**时间：5-10分钟**

👉 [QUICKSTART.md](QUICKSTART.md)

学习内容：
- 基础 Agent 创建
- 简单的对话实现
- 工具注册使用
- 最小化 SwiftUI 集成

适合人群：
- 刚接触 SwiftAgent 的开发者
- 想快速了解框架能力的用户
- 需要快速原型的项目

---

### 2️⃣ 进阶 - 完整应用开发

**时间：30-60分钟**

👉 [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md)

学习内容：
- 完整的 SwiftUI 聊天界面设计
- 流式输出实现原理
- 消息管理和状态处理
- 工具系统深入使用
- 自定义工具开发
- 错误处理和优化
- 性能优化技巧

适合人群：
- 需要构建生产级应用的开发者
- 想深入理解框架原理的用户
- iOS/macOS 应用开发者

---

### 3️⃣ 实战 - 运行完整示例

**时间：10-15分钟**

👉 [SwiftAgentChatExample/](SwiftAgentChatExample/)

包含内容：
- 生产级代码架构
- MVVM 设计模式
- 完整的 UI 组件
- 跨平台支持实现
- 可直接运行的项目

快速开始：
```bash
cd SwiftAgentChatExample
export OPENAI_API_KEY="your-api-key"
swift run
```

适合人群：
- 学习实际项目结构的开发者
- 需要参考代码的用户
- 希望快速开发类似应用的团队

---

## 📚 按主题学习

### 核心概念

| 主题 | 文档 | 难度 |
|-----|------|------|
| Agent 基础 | [QUICKSTART.md](QUICKSTART.md#基础使用) | ⭐ |
| 流式输出 | [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md#集成流式输出) | ⭐⭐ |
| 工具系统 | [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md#添加工具支持) | ⭐⭐ |
| 多智能体 | [README.md](README.md#多智能体协作) | ⭐⭐⭐ |

### SwiftUI 集成

| 主题 | 文档 | 难度 |
|-----|------|------|
| 基础集成 | [QUICKSTART.md](QUICKSTART.md#swiftui-集成) | ⭐ |
| 完整聊天界面 | [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md#创建聊天界面) | ⭐⭐ |
| ViewModel 设计 | [SwiftAgentChatExample](SwiftAgentChatExample/SwiftAgentChat/ViewModels/ChatViewModel.swift) | ⭐⭐ |
| 状态管理 | [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md#实现-viewmodel) | ⭐⭐⭐ |

### 高级功能

| 主题 | 文档 | 难度 |
|-----|------|------|
| 自定义工具 | [CustomTools.swift](SwiftAgentChatExample/SwiftAgentChat/Tools/CustomTools.swift) | ⭐⭐ |
| 记忆与 RAG | [README.md](README.md#记忆与检索-rag) | ⭐⭐⭐ |
| 性能优化 | [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md#性能优化) | ⭐⭐⭐ |
| 错误处理 | [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md#故障排查) | ⭐⭐ |

---

## 🎓 完整学习计划

### Day 1: 基础掌握（1-2小时）

1. 阅读 [QUICKSTART.md](QUICKSTART.md)
2. 运行第一个 Agent
3. 尝试注册和使用工具
4. 理解流式输出基础

**实践任务：**
- 创建一个简单的命令行 Agent
- 添加计算器工具
- 实现基础对话功能

---

### Day 2: SwiftUI 集成（2-3小时）

1. 学习 [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md)
2. 理解 ViewModel 设计
3. 创建聊天界面组件
4. 实现流式输出

**实践任务：**
- 按教程创建聊天应用
- 自定义消息气泡样式
- 添加加载动画

---

### Day 3: 运行示例项目（1小时）

1. 打开 [SwiftAgentChatExample](SwiftAgentChatExample/)
2. 研究代码架构
3. 运行并测试功能
4. 修改和扩展功能

**实践任务：**
- 运行示例项目
- 添加自定义工具
- 修改 UI 主题

---

### Day 4: 高级功能（2-3小时）

1. 学习自定义工具开发
2. 研究 RAG 系统
3. 了解多智能体协作
4. 性能优化实践

**实践任务：**
- 开发一个实用的自定义工具
- 实现简单的 RAG 功能
- 优化应用性能

---

## 💡 常见问题

### Q: 我应该从哪里开始？

**A:** 
- 如果你是新手：从 [QUICKSTART.md](QUICKSTART.md) 开始
- 如果你要做应用：直接看 [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md)
- 如果你想看代码：运行 [SwiftAgentChatExample](SwiftAgentChatExample/)

### Q: 流式输出是必需的吗？

**A:** 不是。你可以使用普通的 `agent.run()` 方法。流式输出提供更好的用户体验，但不是必需的。

### Q: 如何调试问题？

**A:** 
1. 查看 [TUTORIAL_SwiftUI_Streaming.md](TUTORIAL_SwiftUI_Streaming.md#故障排查)
2. 检查控制台日志
3. 参考示例项目的实现
4. 在 GitHub 提 Issue

### Q: 支持哪些 LLM？

**A:** 
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- DeepSeek
- 可扩展支持其他 LLM

---

## 📖 API 文档

完整的 API 文档请查看：
- [Documentation.docc/SwiftAgent.md](Documentation.docc/SwiftAgent.md)
- [GitHub Wiki](https://github.com/leyugod/swiftAgent/wiki)

---

## 🤝 获取帮助

遇到问题？以下渠道可以获得帮助：

1. **GitHub Issues**: https://github.com/leyugod/swiftAgent/issues
2. **示例代码**: 查看 SwiftAgentChatExample 目录
3. **教程文档**: 本文档索引的所有教程
4. **API 文档**: Documentation.docc 目录

---

## 🎯 下一步

完成学习后，你可以：

1. ⭐ 给项目一个 Star
2. 🐛 报告 Bug 或提建议
3. 💻 贡献代码
4. 📝 分享你的使用经验
5. 🚀 构建你的 AI 应用

---

**祝你学习愉快！Happy Coding! 🎉**

如有问题或建议，欢迎在 [GitHub](https://github.com/leyugod/swiftAgent) 上交流。

