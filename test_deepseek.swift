#!/usr/bin/env swift

// 简单的DeepSeek API测试（不依赖Framework）

import Foundation

let apiKey = "sk-23939bb905f24af08f16d7b80f1f5cd5"
let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!

print("🧪 直接测试 DeepSeek API\n")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

// 创建请求
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

let body: [String: Any] = [
    "model": "deepseek-chat",
    "messages": [
        ["role": "user", "content": "你好，请用一句话介绍你自己"]
    ],
    "temperature": 0.7
]

request.httpBody = try! JSONSerialization.data(withJSONObject: body)

print("💭 发送请求到 DeepSeek API...")

let semaphore = DispatchSemaphore(value: 0)
var responseData: Data?
var responseError: Error?

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    responseData = data
    responseError = error
    semaphore.signal()
}

task.resume()
semaphore.wait()

if let error = responseError {
    print("❌ 网络错误: \(error.localizedDescription)")
    exit(1)
}

guard let data = responseData else {
    print("❌ 没有收到数据")
    exit(1)
}

guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    let dataString = String(data: data, encoding: .utf8) ?? "无法解析"
    print("❌ JSON解析失败")
    print("原始响应: \(dataString)")
    exit(1)
}

print("✅ 收到响应！\n")

// 解析响应
if let choices = json["choices"] as? [[String: Any]],
   let firstChoice = choices.first,
   let message = firstChoice["message"] as? [String: Any],
   let content = message["content"] as? String {
    print("📝 DeepSeek 说: \(content)\n")
    
    if let usage = json["usage"] as? [String: Any],
       let totalTokens = usage["total_tokens"] as? Int {
        print("📊 Token使用: \(totalTokens)\n")
    }
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🎉 DeepSeek API 验证成功！")
    print("✅ 网络连接正常")
    print("✅ API Key 有效")
    print("✅ 响应格式正确")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
} else {
    print("❌ 响应格式不正确")
    print("完整响应: \(json)")
    exit(1)
}
