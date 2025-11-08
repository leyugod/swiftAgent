//
//  ToolRegistry.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 工具注册表
/// 管理所有可用工具的注册和查找
public actor ToolRegistry {
    private var tools: [String: ToolProtocol] = [:]
    
    public init() {}
    
    /// 注册工具
    /// - Parameter tool: 要注册的工具
    public func register(_ tool: ToolProtocol) {
        tools[tool.name] = tool
    }
    
    /// 注册多个工具
    /// - Parameter tools: 工具数组
    public func register(_ tools: [ToolProtocol]) {
        for tool in tools {
            self.tools[tool.name] = tool
        }
    }
    
    /// 获取工具
    /// - Parameter name: 工具名称
    /// - Returns: 工具实例，如果不存在则返回 nil
    public func get(_ name: String) -> ToolProtocol? {
        tools[name]
    }
    
    /// 获取所有工具
    /// - Returns: 所有已注册的工具数组
    public func getAll() -> [ToolProtocol] {
        Array(tools.values)
    }
    
    /// 获取所有工具名称
    /// - Returns: 工具名称数组
    public func getAllNames() -> [String] {
        Array(tools.keys)
    }
    
    /// 检查工具是否存在
    /// - Parameter name: 工具名称
    /// - Returns: 是否存在
    public func contains(_ name: String) -> Bool {
        tools[name] != nil
    }
    
    /// 移除工具
    /// - Parameter name: 工具名称
    public func remove(_ name: String) {
        tools.removeValue(forKey: name)
    }
    
    /// 清空所有工具
    public func clear() {
        tools.removeAll()
    }
    
    /// 将工具转换为 LLM 工具函数定义
    /// - Returns: LLM 工具函数定义数组
    public func toLLMTools() -> [LLMToolFunction] {
        tools.values.map { tool in
            // 构建properties对象
            let properties: [String: AnyCodable] = tool.parameters.reduce(into: [:]) { dict, param in
                var paramDict: [String: AnyCodable] = [
                    "type": AnyCodable(param.type),
                    "description": AnyCodable(param.description)
                ]
                
                if let enumValues = param.enumValues {
                    paramDict["enum"] = AnyCodable(enumValues)
                }
                
                dict[param.name] = AnyCodable(paramDict)
            }
            
            // 构建required数组（符合JSON Schema规范）
            let required = tool.parameters.filter { $0.required }.map { $0.name }
            
            // 构建完整的parameters对象
            var parametersDict: [String: AnyCodable] = [
                "type": AnyCodable("object"),
                "properties": AnyCodable(properties)
            ]
            
            if !required.isEmpty {
                parametersDict["required"] = AnyCodable(required)
            }
            
            return LLMToolFunction(
                name: tool.name,
                description: tool.description,
                parameters: parametersDict
            )
        }
    }
}

