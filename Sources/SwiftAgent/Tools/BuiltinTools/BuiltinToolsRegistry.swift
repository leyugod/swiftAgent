//
//  BuiltinToolsRegistry.swift
//  SwiftAgent
//
//  内置工具注册器
//

import Foundation

/// 内置工具注册器
/// 提供便捷的方法来注册所有内置工具
public struct BuiltinToolsRegistry {
    
    /// 注册所有内置工具到指定的工具注册表
    /// - Parameter registry: 目标工具注册表
    public static func registerAllBuiltinTools(to registry: ToolRegistry) async {
        await registry.register([
            CalculatorTool(),
            DateTimeTool(),
            FileSystemTool(),
            WebSearchTool(),
            WeatherTool()
        ])
    }
    
    /// 注册基础工具（Calculator + DateTime）
    /// 这些工具不需要外部依赖，可以直接使用
    /// - Parameter registry: 目标工具注册表
    public static func registerBasicTools(to registry: ToolRegistry) async {
        await registry.register([
            CalculatorTool(),
            DateTimeTool()
        ])
    }
    
    /// 注册文件系统工具
    /// - Parameters:
    ///   - registry: 目标工具注册表
    ///   - sandboxRoot: 沙盒根目录（可选）
    public static func registerFileSystemTool(
        to registry: ToolRegistry,
        sandboxRoot: URL? = nil
    ) async {
        await registry.register(FileSystemTool(sandboxRoot: sandboxRoot))
    }
    
    /// 注册网络搜索工具
    /// - Parameters:
    ///   - registry: 目标工具注册表
    ///   - searchProvider: 搜索提供商（如果为 nil，使用模拟提供商）
    public static func registerWebSearchTool(
        to registry: ToolRegistry,
        searchProvider: SearchProvider? = nil
    ) async {
        await registry.register(WebSearchTool(searchProvider: searchProvider))
    }
    
    /// 注册天气查询工具
    /// - Parameters:
    ///   - registry: 目标工具注册表
    ///   - weatherProvider: 天气提供商（如果为 nil，使用模拟提供商）
    public static func registerWeatherTool(
        to registry: ToolRegistry,
        weatherProvider: WeatherProvider? = nil
    ) async {
        await registry.register(WeatherTool(weatherProvider: weatherProvider))
    }
    
    /// 创建配置了所有内置工具的新 Agent
    /// - Parameters:
    ///   - name: Agent 名称
    ///   - llmProvider: LLM 提供商
    ///   - systemPrompt: 系统提示词
    /// - Returns: 配置好的 Agent
    public static func createAgentWithBuiltinTools(
        name: String,
        llmProvider: LLMProviderProtocol,
        systemPrompt: String
    ) async -> Agent {
        let registry = ToolRegistry()
        await registerAllBuiltinTools(to: registry)
        
        return Agent(
            name: name,
            llmProvider: llmProvider,
            systemPrompt: systemPrompt,
            toolRegistry: registry
        )
    }
}

// MARK: - 便捷扩展

// Agent 扩展在 Agent.swift 中实现，以避免访问控制问题

// MARK: - 工具集合枚举

/// 内置工具集合
public enum BuiltinToolSet {
    /// 所有内置工具
    case all
    /// 基础工具（Calculator + DateTime）
    case basic
    /// 文件系统工具
    case fileSystem(sandboxRoot: URL?)
    /// 网络工具（Search + Weather）
    case network(searchProvider: SearchProvider?, weatherProvider: WeatherProvider?)
    /// 自定义组合
    case custom([ToolProtocol])
    
    /// 获取工具列表
    public func tools() -> [ToolProtocol] {
        switch self {
        case .all:
            return [
                CalculatorTool(),
                DateTimeTool(),
                FileSystemTool(),
                WebSearchTool(),
                WeatherTool()
            ]
            
        case .basic:
            return [
                CalculatorTool(),
                DateTimeTool()
            ]
            
        case .fileSystem(let sandboxRoot):
            return [FileSystemTool(sandboxRoot: sandboxRoot)]
            
        case .network(let searchProvider, let weatherProvider):
            return [
                WebSearchTool(searchProvider: searchProvider),
                WeatherTool(weatherProvider: weatherProvider)
            ]
            
        case .custom(let tools):
            return tools
        }
    }
    
    /// 注册到工具注册表
    public func register(to registry: ToolRegistry) async {
        await registry.register(tools())
    }
}

