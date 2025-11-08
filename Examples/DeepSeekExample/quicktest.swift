import Foundation
import SwiftAgent

let apiKey = "sk-23939bb905f24af08f16d7b80f1f5cd5"

print("🧪 SwiftAgent Framework - DeepSeek 快速验证测试\n")

// 测试 1: 基础对话
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("测试 1: 基础对话")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    let messages = [LLMMessage(role: .user, content: "你好，请用一句话介绍你自己")]
    
    print("💭 发送请求...")
    let response = try await provider.chat(messages: messages, tools: nil, temperature: 0.7)
    
    print("✅ 请求成功！")
    print("📝 响应: \(response.content)")
    if let usage = response.usage {
        print("📊 Token使用: \(usage.totalTokens)")
    }
    print()
} catch {
    print("❌ 错误: \(error)")
    exit(1)
}

// 测试 2: 流式响应
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("测试 2: 流式响应")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    let provider = DeepSeekProvider(apiKey: apiKey, model: .chat)
    let messages = [LLMMessage(role: .user, content: "用20字以内说一句鼓励的话")]
    
    print("💭 流式响应: ", terminator: "")
    var fullContent = ""
    
    let response = try await provider.chatStream(
        messages: messages,
        tools: nil,
        temperature: 0.7
    ) { chunk in
        print(chunk, terminator: "")
        fflush(stdout)
        fullContent += chunk
    }
    
    print("\n✅ 流式响应完成！")
    print("📝 完整内容: \(fullContent)")
    print()
} catch {
    print("\n❌ 错误: \(error)")
    exit(1)
}

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🎉 所有测试通过！Framework 可以正常使用！")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
