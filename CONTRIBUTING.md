# 贡献指南

感谢你对 SwiftAgent 的关注！我们欢迎所有形式的贡献。

## 如何贡献

### 报告 Bug

如果你发现了 Bug，请通过 GitHub Issues 报告：

1. 使用清晰的标题描述问题
2. 提供详细的复现步骤
3. 说明期望的行为和实际行为
4. 提供环境信息（Swift 版本、操作系统等）
5. 如果可能，提供最小化的复现代码

### 提出新功能

如果你有新功能的想法：

1. 先查看是否已有相关 Issue
2. 创建新 Issue 详细描述功能需求
3. 说明为什么需要这个功能
4. 如果可能，提供使用示例

### 提交代码

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add some AmazingFeature'`
4. 推送到分支：`git push origin feature/AmazingFeature`
5. 开启 Pull Request

## 代码规范

### Swift 风格指南

- 遵循 [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- 使用 4 空格缩进
- 每行代码不超过 120 个字符
- 使用有意义的变量和函数名

### 命名规范

- 类型名使用 PascalCase：`AgentProtocol`、`ToolRegistry`
- 变量和函数使用 camelCase：`agentName`、`executeTask`
- 协议名以 `Protocol` 结尾（可选）
- Actor 使用名词：`ToolRegistry`、`ContextManager`

### 文档注释

为公共 API 添加文档注释：

```swift
/// Agent 协议定义
/// 
/// 定义智能体的基本接口，包括运行、思考和行动。
@preconcurrency
public protocol AgentProtocol: AnyObject {
    /// Agent 名称
    var name: String { get }
    
    /// 运行 Agent，处理用户输入
    /// - Parameter input: 用户输入
    /// - Returns: Agent 的最终响应
    func run(_ input: String) async throws -> String
}
```

### 并发安全

- 使用 `actor` 确保并发安全
- 正确使用 `@Sendable` 和 `@preconcurrency`
- 避免数据竞争

### 测试

- 为新功能编写单元测试
- 确保现有测试通过
- 测试覆盖率应保持在 80% 以上

```swift
import XCTest
@testable import SwiftAgent

final class AgentTests: XCTestCase {
    func testAgentCreation() async throws {
        let llm = MockLLMProvider()
        let agent = Agent(
            name: "TestAgent",
            llmProvider: llm,
            systemPrompt: "Test"
        )
        
        XCTAssertEqual(agent.name, "TestAgent")
    }
}
```

## 提交信息规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>(<scope>): <subject>

<body>

<footer>
```

类型（type）：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响代码运行）
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

示例：

```
feat(tools): add WeatherTool implementation

- Add weather query functionality
- Integrate with external weather API
- Add unit tests

Closes #123
```

## Pull Request 规范

### PR 标题

使用清晰的标题，遵循提交信息规范。

### PR 描述

包含以下内容：

- 变更说明
- 相关 Issue 链接
- 测试说明
- 截图（如果适用）

### Code Review

- 所有 PR 需要至少一位维护者审核
- 解决所有 review 意见后才能合并
- 保持讨论友好和建设性

## 开发环境设置

### 要求

- Xcode 15.0+
- Swift 6.0+
- macOS 12.0+

### 设置步骤

1. Clone 仓库：
```bash
git clone https://github.com/your-repo/SwiftAgent.git
cd SwiftAgent
```

2. 打开项目：
```bash
open Package.swift
```

3. 运行测试：
```bash
swift test
```

## 发布流程

1. 更新版本号（Package.swift、README.md）
2. 更新 CHANGELOG.md
3. 创建 Git tag
4. 推送到 GitHub
5. 创建 GitHub Release

## 社区

- GitHub Discussions: 讨论和提问
- GitHub Issues: Bug 报告和功能请求

## 行为准则

我们致力于为所有人提供友好、安全和包容的环境。请遵守以下原则：

- 尊重他人
- 接受建设性批评
- 关注对社区最有利的事情
- 对他人表现出同理心

## 许可证

提交代码即表示你同意将你的贡献以 MIT 许可证授权。

## 问题？

如有任何疑问，请通过以下方式联系：

- GitHub Issues
- Email: your-email@example.com

再次感谢你的贡献！🎉

