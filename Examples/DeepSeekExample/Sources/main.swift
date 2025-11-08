//
//  main.swift
//  DeepSeekExample
//
//  DeepSeek AI Agent 示例
//

import Foundation
import SwiftAgent

// MARK: - 配置

// 从环境变量获取 API Key
guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] else {
    print("❌ 错误: 请设置 DEEPSEEK_API_KEY 环境变量")
    print("💡 使用方法: export DEEPSEEK_API_KEY='your-api-key'")
    exit(1)
}

// MARK: - 示例 1: 基础对话

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("示例 1: 基础对话")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    let agent = Agent(name: "助手", llmProvider: provider)
    
    print("💭 用户: 你好，请用一句话介绍你自己。\n")
    let response = try await agent.run(input: "你好，请用一句话介绍你自己。")
    print("🤖 助手: \(response)\n")
} catch {
    print("❌ 错误: \(error.localizedDescription)\n")
}

// MARK: - 示例 2: 流式响应

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("示例 2: 流式响应")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    let agent = Agent(name: "助手", llmProvider: provider)
    
    print("💭 用户: 请写一个简短的故事（100字以内）\n")
    print("🤖 助手: ", terminator: "")
    
    let callback = StreamingCallback(
        onContent: { content in
            print(content, terminator: "")
            fflush(stdout)
        },
        onCompletion: { response in
            print("\n")
            if let usage = response.usage {
                print("📊 Token使用: \(usage.totalTokens) (提示: \(usage.promptTokens), 完成: \(usage.completionTokens))\n")
            }
        },
        onError: { error in
            print("\n❌ 错误: \(error.localizedDescription)\n")
        }
    )
    
    _ = try await agent.streamRunWithCallback(
        input: "请写一个简短的故事（100字以内）",
        callback: callback
    )
} catch {
    print("\n❌ 错误: \(error.localizedDescription)\n")
}

// MARK: - 示例 3: 工具调用

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("示例 3: 工具调用")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    let agent = Agent(name: "助手", llmProvider: provider)
    
    // 注册内置工具
    await agent.registerBasicTools()
    
    print("💭 用户: 今天是几号？星期几？\n")
    let response = try await agent.run(input: "今天是几号？星期几？")
    print("🤖 助手: \(response)\n")
} catch {
    print("❌ 错误: \(error.localizedDescription)\n")
}

// MARK: - 示例 4: 代码生成（使用 Coder 模型）

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("示例 4: 代码生成 (DeepSeek Coder)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let coderProvider = DeepSeekProvider(apiKey: apiKey, model: .coder)
    let agent = Agent(name: "代码助手", llmProvider: coderProvider)
    
    print("💭 用户: 写一个Swift函数，计算两个数的最大公约数\n")
    let response = try await agent.run(input: "写一个Swift函数，计算两个数的最大公约数，要求代码简洁优雅")
    print("🤖 代码助手:\n\(response)\n")
} catch {
    print("❌ 错误: \(error.localizedDescription)\n")
}

// MARK: - 示例 5: 多轮对话

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("示例 5: 多轮对话")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    let agent = Agent(name: "助手", llmProvider: provider)
    
    let questions = [
        "什么是 Swift 编程语言？",
        "它有哪些主要特点？",
        "和 Objective-C 相比有什么优势？"
    ]
    
    for question in questions {
        print("💭 用户: \(question)\n")
        let response = try await agent.run(input: question)
        print("🤖 助手: \(response)\n")
        
        // 添加短暂延迟，避免请求过快
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
    }
} catch {
    print("❌ 错误: \(error.localizedDescription)\n")
}

// MARK: - 示例 6: 带缓存的 Agent

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("示例 6: 带缓存的 Agent（演示性能优化）")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    let cacheManager = await CacheManager(defaultTTL: 3600) // 1小时缓存
    let cachedProvider = CachedLLMProvider(
        baseProvider: provider,
        cacheManager: cacheManager,
        enableCache: true
    )
    let agent = Agent(name: "缓存助手", llmProvider: cachedProvider)
    
    let question = "什么是机器学习？"
    
    // 第一次调用（无缓存）
    print("💭 用户: \(question)")
    print("⏱️  第一次调用（无缓存）...")
    let start1 = Date()
    let response1 = try await agent.run(input: question)
    let duration1 = Date().timeIntervalSince(start1)
    print("🤖 助手: \(response1)")
    print("⏱️  耗时: \(String(format: "%.2f", duration1))秒\n")
    
    // 第二次调用（有缓存）
    print("💭 用户: \(question)")
    print("⏱️  第二次调用（应该使用缓存）...")
    let start2 = Date()
    let response2 = try await agent.run(input: question)
    let duration2 = Date().timeIntervalSince(start2)
    print("🤖 助手: \(response2)")
    print("⏱️  耗时: \(String(format: "%.2f", duration2))秒")
    print("🚀 速度提升: \(String(format: "%.1f", duration1/duration2))x\n")
    
    // 显示缓存统计
    let stats = await cacheManager.statistics()
    print("📊 缓存统计:")
    print("   内存缓存数量: \(stats.memoryCount)")
    print("   内存使用率: \(String(format: "%.1f", stats.memoryUsagePercent))%\n")
} catch {
    print("❌ 错误: \(error.localizedDescription)\n")
}

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ 所有示例运行完成！")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

