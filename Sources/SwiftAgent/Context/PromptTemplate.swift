//
//  PromptTemplate.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 提示词模板
/// 支持变量替换和模板组合
public struct PromptTemplate {
    private let template: String
    private let variables: Set<String>
    
    /// 初始化提示词模板
    /// - Parameter template: 模板字符串，使用 {{variable}} 语法表示变量
    public init(template: String) {
        self.template = template
        self.variables = PromptTemplate.extractVariables(from: template)
    }
    
    /// 使用参数渲染模板
    /// - Parameter parameters: 参数字典
    /// - Returns: 渲染后的字符串
    public func render(with parameters: [String: String]) throws -> String {
        var result = template
        
        // 检查必需的变量
        let missingVars = variables.subtracting(Set(parameters.keys))
        guard missingVars.isEmpty else {
            throw PromptTemplateError.missingVariables(Array(missingVars))
        }
        
        // 替换变量
        for (key, value) in parameters {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return result
    }
    
    /// 获取模板中的所有变量
    /// - Returns: 变量名称集合
    public func getVariables() -> Set<String> {
        variables
    }
    
    /// 检查模板是否包含指定变量
    /// - Parameter variable: 变量名称
    /// - Returns: 是否包含
    public func hasVariable(_ variable: String) -> Bool {
        variables.contains(variable)
    }
    
    /// 部分渲染（允许某些变量缺失）
    /// - Parameter parameters: 参数字典
    /// - Returns: 部分渲染后的字符串
    public func partialRender(with parameters: [String: String]) -> String {
        var result = template
        
        for (key, value) in parameters {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return result
    }
    
    // MARK: - Static Factory Methods
    
    /// 创建 ReAct 风格的提示词模板
    public static func react() -> PromptTemplate {
        let template = """
        你是一个智能助手，可以使用以下工具来帮助用户：
        
        {{tools}}
        
        请遵循以下格式回答问题：
        
        Thought: 分析当前情况，思考需要采取的行动
        Action: 选择一个工具并指定参数，格式为 tool_name(param="value")
        
        当你收集到足够信息后，使用 finish(answer="...") 给出最终答案。
        
        用户问题：{{question}}
        """
        return PromptTemplate(template: template)
    }
    
    /// 创建问答风格的提示词模板
    public static func questionAnswer() -> PromptTemplate {
        let template = """
        请回答以下问题：
        
        {{question}}
        
        {{context}}
        """
        return PromptTemplate(template: template)
    }
    
    /// 创建代码审查风格的提示词模板
    public static func codeReview() -> PromptTemplate {
        let template = """
        请审查以下代码：
        
        ```{{language}}
        {{code}}
        ```
        
        请提供：
        1. 代码质量评估
        2. 潜在问题
        3. 改进建议
        """
        return PromptTemplate(template: template)
    }
    
    /// 创建总结风格的提示词模板
    public static func summarization() -> PromptTemplate {
        let template = """
        请总结以下内容：
        
        {{content}}
        
        总结要求：
        - 简洁明了
        - 保留关键信息
        - 字数限制：{{max_words}} 字以内
        """
        return PromptTemplate(template: template)
    }
    
    /// 创建翻译风格的提示词模板
    public static func translation() -> PromptTemplate {
        let template = """
        请将以下文本从 {{source_language}} 翻译为 {{target_language}}：
        
        {{text}}
        
        要求：
        - 保持原文的语气和风格
        - 确保翻译准确
        """
        return PromptTemplate(template: template)
    }
    
    // MARK: - Private Methods
    
    private static func extractVariables(from template: String) -> Set<String> {
        let pattern = "\\{\\{([^}]+)\\}\\}"
        var variables = Set<String>()
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return variables
        }
        
        let matches = regex.matches(
            in: template,
            range: NSRange(template.startIndex..., in: template)
        )
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: template) {
                let variable = String(template[range])
                variables.insert(variable)
            }
        }
        
        return variables
    }
}

/// 提示词模板错误
public enum PromptTemplateError: Error {
    case missingVariables([String])
    case invalidTemplate(String)
}

/// 提示词模板构建器
/// 用于链式构建复杂的提示词
public struct PromptTemplateBuilder {
    private var sections: [String] = []
    
    public init() {}
    
    /// 添加系统提示
    /// - Parameter prompt: 系统提示内容
    /// - Returns: 构建器
    public func systemPrompt(_ prompt: String) -> PromptTemplateBuilder {
        var builder = self
        builder.sections.append("# 系统提示\n\n\(prompt)")
        return builder
    }
    
    /// 添加上下文
    /// - Parameter context: 上下文内容
    /// - Returns: 构建器
    public func context(_ context: String) -> PromptTemplateBuilder {
        var builder = self
        builder.sections.append("# 上下文\n\n\(context)")
        return builder
    }
    
    /// 添加工具列表
    /// - Parameter tools: 工具描述
    /// - Returns: 构建器
    public func tools(_ tools: String) -> PromptTemplateBuilder {
        var builder = self
        builder.sections.append("# 可用工具\n\n\(tools)")
        return builder
    }
    
    /// 添加示例
    /// - Parameters:
    ///   - input: 输入示例
    ///   - output: 输出示例
    /// - Returns: 构建器
    public func example(input: String, output: String) -> PromptTemplateBuilder {
        var builder = self
        builder.sections.append("# 示例\n\n输入：\(input)\n\n输出：\(output)")
        return builder
    }
    
    /// 添加指令
    /// - Parameter instructions: 指令内容
    /// - Returns: 构建器
    public func instructions(_ instructions: String) -> PromptTemplateBuilder {
        var builder = self
        builder.sections.append("# 指令\n\n\(instructions)")
        return builder
    }
    
    /// 添加约束
    /// - Parameter constraints: 约束内容
    /// - Returns: 构建器
    public func constraints(_ constraints: String) -> PromptTemplateBuilder {
        var builder = self
        builder.sections.append("# 约束\n\n\(constraints)")
        return builder
    }
    
    /// 添加自定义部分
    /// - Parameters:
    ///   - title: 部分标题
    ///   - content: 部分内容
    /// - Returns: 构建器
    public func section(title: String, content: String) -> PromptTemplateBuilder {
        var builder = self
        builder.sections.append("# \(title)\n\n\(content)")
        return builder
    }
    
    /// 构建最终的提示词模板
    /// - Returns: 提示词模板
    public func build() -> PromptTemplate {
        let template = sections.joined(separator: "\n\n---\n\n")
        return PromptTemplate(template: template)
    }
    
    /// 构建为字符串
    /// - Returns: 组合后的字符串
    public func buildString() -> String {
        sections.joined(separator: "\n\n---\n\n")
    }
}

