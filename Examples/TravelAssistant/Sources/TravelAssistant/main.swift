//
//  main.swift
//  TravelAssistant
//
//  旅行助手示例
//  演示如何使用多个工具创建实用的 AI 应用
//

import Foundation
import SwiftAgent

// MARK: - 配置

let OPENAI_API_KEY = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

// MARK: - Main Function

@main
struct TravelAssistantExample {
    static func main() async {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║           SwiftAgent - Travel Assistant 示例                  ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()
        
        guard !OPENAI_API_KEY.isEmpty else {
            print("❌ 错误：请设置 OPENAI_API_KEY 环境变量")
            return
        }
        
        do {
            // 创建旅行助手
            let assistant = try await createTravelAssistant()
            
            // 运行示例场景
            await runTravelScenarios(assistant: assistant)
            
        } catch {
            print("❌ 错误：\(error)")
        }
    }
}

// MARK: - Create Travel Assistant

func createTravelAssistant() async throws -> Agent {
    let provider = OpenAIProvider(
        apiKey: OPENAI_API_KEY,
        model: "gpt-4",
        temperature: 0.7
    )
    
    let agent = Agent(
        name: "TravelAssistant",
        llmProvider: provider,
        systemPrompt: """
        你是一个专业的旅行助手，可以帮助用户规划旅行。
        
        你的能力包括：
        1. 查询天气信息（使用 weather 工具）
        2. 搜索旅行信息（使用 web_search 工具）
        3. 计算旅行时间和预算（使用 calculator 工具）
        4. 处理日期和时区（使用 datetime 工具）
        
        请根据用户需求，使用合适的工具提供专业的旅行建议。
        回答要详细、友好，并提供实用的信息。
        """
    )
    
    // 注册所有相关工具
    print("📦 正在配置旅行助手...")
    await agent.registerAllBuiltinTools()
    print("✅ 配置完成！已加载 5 个工具\n")
    
    return agent
}

// MARK: - Travel Scenarios

func runTravelScenarios(assistant: Agent) async {
    // 场景 1：查询天气
    await runScenario(
        assistant: assistant,
        title: "场景 1：目的地天气查询",
        userInput: "我计划去北京旅游，请帮我查一下那里的天气情况，包括未来3天的预报。"
    )
    
    // 场景 2：旅行信息搜索
    await runScenario(
        assistant: assistant,
        title: "场景 2：旅行信息搜索",
        userInput: "我想了解上海的著名景点和美食推荐。"
    )
    
    // 场景 3：预算计算
    await runScenario(
        assistant: assistant,
        title: "场景 3：旅行预算计算",
        userInput: "我有 5000 元预算，计划 4 天旅行，每天住宿 300 元，餐饮 200 元。请帮我算一下还剩多少钱可以用于景点门票和购物？"
    )
    
    // 场景 4：时间和日期计算
    await runScenario(
        assistant: assistant,
        title: "场景 4：旅行日期规划",
        userInput: "现在是几点？如果我从今天开始计划，30 天后是几月几日？那个时候适合去哪里旅游？"
    )
    
    // 场景 5：综合规划
    await runScenario(
        assistant: assistant,
        title: "场景 5：综合旅行规划",
        userInput: """
        帮我规划一个周末（2天）的杭州之旅：
        1. 查询杭州的天气
        2. 搜索必去景点
        3. 估算总预算（包括往返交通 400 元，住宿 2 晚）
        """
    )
}

func runScenario(assistant: Agent, title: String, userInput: String) async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🎯 \(title)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("👤 用户需求:")
    print(userInput)
    print()
    
    do {
        let startTime = Date()
        let response = try await assistant.run(input: userInput)
        let duration = Date().timeIntervalSince(startTime)
        
        print("🤖 旅行助手:")
        print(response)
        print()
        print("⏱  处理时间: \(String(format: "%.2f", duration)) 秒")
        print()
        
        // 添加延迟以避免 API 速率限制
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
        
    } catch {
        print("❌ 处理失败: \(error)")
        print()
    }
}

// MARK: - Interactive Mode

/// 交互式旅行规划模式
func runInteractiveMode(assistant: Agent) async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("💬 旅行规划交互模式")
    print("   告诉我你的旅行需求，我会帮你规划！")
    print("   输入 'exit' 退出，输入 'help' 查看功能")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    
    while true {
        print("👤 你: ", terminator: "")
        guard let input = readLine(), !input.isEmpty else {
            continue
        }
        
        if input.lowercased() == "exit" {
            print("✈️  祝你旅途愉快！再见！")
            break
        }
        
        if input.lowercased() == "help" {
            showHelp()
            continue
        }
        
        do {
            let response = try await assistant.run(input: input)
            print("🤖 助手: \(response)")
            print()
        } catch {
            print("❌ 错误: \(error)")
            print()
        }
    }
}

func showHelp() {
    print("""
    
    🎯 旅行助手功能：
    
    1. 🌤️  天气查询
       示例："查询北京的天气"
       
    2. 🔍 信息搜索
       示例："上海有哪些值得去的景点？"
       
    3. 💰 预算计算
       示例："帮我算一下 3 天旅行的预算"
       
    4. 📅 日期规划
       示例："10 天后是几月几日？"
       
    5. 🗺️  综合规划
       示例："帮我规划一个成都 3 日游"
    
    """)
}

