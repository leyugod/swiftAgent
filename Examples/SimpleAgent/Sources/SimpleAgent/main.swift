//
//  main.swift
//  SimpleAgent
//
//  简单的 AI Agent 示例
//  演示如何创建和使用基本的 Agent
//

import Foundation
import SwiftAgent

// MARK: - 配置

let OPENAI_API_KEY = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

// MARK: - Main Function

@main
struct SimpleAgentExample {
    static func main() async {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║              SwiftAgent - Simple Agent 示例                   ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()
        
        // 检查 API Key
        guard !OPENAI_API_KEY.isEmpty else {
            print("❌ 错误：请设置 OPENAI_API_KEY 环境变量")
            print("   示例：export OPENAI_API_KEY=your_api_key")
            return
        }
        
        do {
            // 创建 LLM Provider
            let provider = OpenAIProvider(
                apiKey: OPENAI_API_KEY,
                model: "gpt-4",
                temperature: 0.7
            )
            
            // 创建 Agent
            let agent = Agent(
                name: "SimpleAssistant",
                llmProvider: provider,
                systemPrompt: """
                你是一个智能助手，可以帮助用户解决问题。
                你有以下能力：
                - 数学计算（使用 calculator 工具）
                - 时间日期处理（使用 datetime 工具）
                
                请根据用户的问题，选择合适的工具来回答。
                如果不需要工具，直接回答即可。
                """
            )
            
            // 注册内置工具
            print("📦 注册内置工具...")
            await agent.registerBasicTools()
            print("✅ 工具注册成功\n")
            
            // 运行示例任务
            await runExamples(agent: agent)
            
        } catch {
            print("❌ 错误：\(error)")
        }
    }
}

// MARK: - Examples

func runExamples(agent: Agent) async {
    // 示例 1：简单对话
    await runExample(
        agent: agent,
        title: "示例 1：简单对话",
        input: "你好！介绍一下你自己。"
    )
    
    // 示例 2：数学计算
    await runExample(
        agent: agent,
        title: "示例 2：数学计算（使用工具）",
        input: "请计算 sqrt(144) + 2^5 的结果"
    )
    
    // 示例 3：日期时间
    await runExample(
        agent: agent,
        title: "示例 3：时间查询（使用工具）",
        input: "现在是几点？今天的日期是什么？"
    )
    
    // 示例 4：复杂计算
    await runExample(
        agent: agent,
        title: "示例 4：复杂数学计算",
        input: "计算 sin(3.14159/2) + cos(0) 的值"
    )
}

func runExample(agent: Agent, title: String, input: String) async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📝 \(title)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("👤 用户: \(input)")
    print()
    
    do {
        let startTime = Date()
        let result = try await agent.run(input: input)
        let duration = Date().timeIntervalSince(startTime)
        
        print("🤖 Agent: \(result)")
        print()
        print("⏱  耗时: \(String(format: "%.2f", duration)) 秒")
        print()
    } catch {
        print("❌ 错误: \(error)")
        print()
    }
}

// MARK: - Interactive Mode

/// 交互式模式（可选）
func runInteractiveMode(agent: Agent) async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("💬 进入交互模式")
    print("   输入 'exit' 退出")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    
    while true {
        print("👤 你: ", terminator: "")
        guard let input = readLine(), !input.isEmpty else {
            continue
        }
        
        if input.lowercased() == "exit" {
            print("👋 再见！")
            break
        }
        
        do {
            let result = try await agent.run(input: input)
            print("🤖 Agent: \(result)")
            print()
        } catch {
            print("❌ 错误: \(error)")
            print()
        }
    }
}

