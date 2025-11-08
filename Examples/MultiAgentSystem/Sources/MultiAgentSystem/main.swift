//
//  main.swift
//  MultiAgentSystem
//
//  多智能体系统示例
//  演示如何创建和协调多个 AI Agent
//

import Foundation
import SwiftAgent

// MARK: - 配置

let OPENAI_API_KEY = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

// MARK: - Main Function

@main
struct MultiAgentSystemExample {
    static func main() async {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║         SwiftAgent - Multi-Agent System 示例                  ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()
        
        guard !OPENAI_API_KEY.isEmpty else {
            print("❌ 错误：请设置 OPENAI_API_KEY 环境变量")
            return
        }
        
        do {
            // 演示 1：顺序执行
            await demonstrateSequentialExecution()
            
            print("\n" + String(repeating: "=", count: 64) + "\n")
            
            // 演示 2：并行执行
            await demonstrateParallelExecution()
            
            print("\n" + String(repeating: "=", count: 64) + "\n")
            
            // 演示 3：协作任务
            await demonstrateCollaborativeTask()
            
        } catch {
            print("❌ 错误：\(error)")
        }
    }
}

// MARK: - 演示 1：顺序执行

func demonstrateSequentialExecution() async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📋 演示 1：顺序执行多个 Agent")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    
    do {
        // 创建多个专业化的 Agent
        let agents = await createSpecializedAgents()
        
        // 创建多智能体系统
        let system = MultiAgentSystem()
        for (id, agent) in agents {
            await system.addAgent(id: id, agent: agent)
        }
        
        // 定义任务序列
        let tasks = [
            ("researcher", "搜索关于 Swift 并发编程的最新资料"),
            ("analyst", "分析 Swift async/await 的优势和应用场景"),
            ("writer", "用简洁的语言总结 Swift 并发编程的核心概念")
        ]
        
        // 顺序执行
        print("🔄 开始顺序执行任务...\n")
        let startTime = Date()
        
        let results = try await system.executeSequential(tasks: tasks)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 显示结果
        for (agentId, result) in results {
            print("📝 Agent '\(agentId)' 的输出：")
            print(result)
            print()
        }
        
        print("⏱  总耗时: \(String(format: "%.2f", duration)) 秒")
        
    } catch {
        print("❌ 执行失败: \(error)")
    }
}

// MARK: - 演示 2：并行执行

func demonstrateParallelExecution() async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔀 演示 2：并行执行多个 Agent")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    
    do {
        let agents = await createSpecializedAgents()
        let system = MultiAgentSystem()
        
        for (id, agent) in agents {
            await system.addAgent(id: id, agent: agent)
        }
        
        // 定义可以并行执行的任务
        let tasks = [
            ("calculator", "计算 2024 年一共有多少天"),
            ("datetime", "告诉我现在的日期和时间"),
            ("researcher", "Swift 是什么时候发布的？")
        ]
        
        print("⚡ 开始并行执行任务...\n")
        let startTime = Date()
        
        let results = try await system.executeParallel(tasks: tasks)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 显示结果
        for (agentId, result) in results {
            print("📝 Agent '\(agentId)' 的输出：")
            print(result)
            print()
        }
        
        print("⏱  总耗时: \(String(format: "%.2f", duration)) 秒")
        print("💡 提示：并行执行比顺序执行更快！")
        
    } catch {
        print("❌ 执行失败: \(error)")
    }
}

// MARK: - 演示 3：协作任务

func demonstrateCollaborativeTask() async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🤝 演示 3：多 Agent 协作完成复杂任务")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    
    do {
        // 创建研究团队
        let teamLeader = await createTeamLeader()
        let researcher = await createResearcher()
        let analyst = await createAnalyst()
        let writer = await createWriter()
        
        print("📋 任务：撰写一份关于 AI Agent 的技术报告")
        print()
        
        // 步骤 1：团队领导分配任务
        print("👨‍💼 步骤 1：团队领导分配任务")
        let leaderPlan = try await teamLeader.run(input: """
        我们需要撰写一份关于 AI Agent 的技术报告。
        请分解这个任务，说明每个角色应该做什么：
        - Researcher（研究员）
        - Analyst（分析师）
        - Writer（撰稿人）
        """)
        print("计划：\(leaderPlan)")
        print()
        
        // 步骤 2：研究员收集信息
        print("🔍 步骤 2：研究员收集信息")
        let researchResult = try await researcher.run(input: """
        搜索并总结 AI Agent 的定义、核心组件和主要应用场景。
        """)
        print("研究结果：\(researchResult)")
        print()
        
        // 步骤 3：分析师分析数据
        print("📊 步骤 3：分析师分析数据")
        let analysisResult = try await analyst.run(input: """
        基于以下研究结果，分析 AI Agent 的技术特点和发展趋势：
        \(researchResult)
        """)
        print("分析报告：\(analysisResult)")
        print()
        
        // 步骤 4：撰稿人整合内容
        print("✍️  步骤 4：撰稿人整合内容")
        let finalReport = try await writer.run(input: """
        请将以下研究和分析整合成一份简洁的技术报告：
        
        研究结果：
        \(researchResult)
        
        分析报告：
        \(analysisResult)
        
        要求：结构清晰，语言专业，篇幅适中。
        """)
        print("最终报告：")
        print(finalReport)
        print()
        
        print("✅ 协作任务完成！")
        
    } catch {
        print("❌ 执行失败: \(error)")
    }
}

// MARK: - Agent 创建函数

func createSpecializedAgents() async -> [String: Agent] {
    let provider = OpenAIProvider(
        apiKey: OPENAI_API_KEY,
        model: "gpt-4",
        temperature: 0.7
    )
    
    // 研究员 Agent
    let researcher = Agent(
        name: "Researcher",
        llmProvider: provider,
        systemPrompt: """
        你是一个专业的研究员，擅长搜索和整理信息。
        你的任务是收集准确、全面的资料。
        """
    )
    await researcher.registerBasicTools()
    
    // 分析师 Agent
    let analyst = Agent(
        name: "Analyst",
        llmProvider: provider,
        systemPrompt: """
        你是一个数据分析师，擅长分析信息并提取关键洞察。
        你的任务是深入分析数据，找出模式和趋势。
        """
    )
    await analyst.registerBasicTools()
    
    // 撰稿人 Agent
    let writer = Agent(
        name: "Writer",
        llmProvider: provider,
        systemPrompt: """
        你是一个专业撰稿人，擅长将复杂信息转化为易懂的文字。
        你的任务是创作清晰、有条理的内容。
        """
    )
    
    // 计算器 Agent（专门做数学计算）
    let calculator = Agent(
        name: "Calculator",
        llmProvider: provider,
        systemPrompt: "你是一个数学计算专家，专门处理数学问题。"
    )
    await calculator.registerBasicTools()
    
    // 时间助手 Agent
    let datetime = Agent(
        name: "DateTime",
        llmProvider: provider,
        systemPrompt: "你是一个时间日期助手，专门处理时间相关的问题。"
    )
    await datetime.registerBasicTools()
    
    return [
        "researcher": researcher,
        "analyst": analyst,
        "writer": writer,
        "calculator": calculator,
        "datetime": datetime
    ]
}

func createTeamLeader() async -> Agent {
    let provider = OpenAIProvider(
        apiKey: OPENAI_API_KEY,
        model: "gpt-4",
        temperature: 0.7
    )
    
    return Agent(
        name: "TeamLeader",
        llmProvider: provider,
        systemPrompt: """
        你是项目经理，负责协调团队成员完成任务。
        你的职责是：
        1. 理解项目目标
        2. 分解任务
        3. 分配给合适的团队成员
        4. 确保任务按计划完成
        """
    )
}

func createResearcher() async -> Agent {
    let provider = OpenAIProvider(
        apiKey: OPENAI_API_KEY,
        model: "gpt-4",
        temperature: 0.5
    )
    
    let agent = Agent(
        name: "Researcher",
        llmProvider: provider,
        systemPrompt: """
        你是专业研究员，擅长：
        - 信息检索和整理
        - 文献调研
        - 事实核查
        提供客观、准确的研究结果。
        """
    )
    await agent.registerBasicTools()
    return agent
}

func createAnalyst() async -> Agent {
    let provider = OpenAIProvider(
        apiKey: OPENAI_API_KEY,
        model: "gpt-4",
        temperature: 0.6
    )
    
    let agent = Agent(
        name: "Analyst",
        llmProvider: provider,
        systemPrompt: """
        你是数据分析师，擅长：
        - 数据分析和可视化
        - 趋势预测
        - 关键洞察提取
        提供深度分析和专业见解。
        """
    )
    await agent.registerBasicTools()
    return agent
}

func createWriter() async -> Agent {
    let provider = OpenAIProvider(
        apiKey: OPENAI_API_KEY,
        model: "gpt-4",
        temperature: 0.8
    )
    
    return Agent(
        name: "Writer",
        llmProvider: provider,
        systemPrompt: """
        你是专业撰稿人，擅长：
        - 技术文档撰写
        - 内容组织和结构化
        - 清晰简洁的表达
        创作高质量、易读的内容。
        """
    )
}

