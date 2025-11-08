//
//  OpenAIStreamingProvider.swift
//  SwiftAgent
//
//  OpenAI 流式响应实现
//

import Foundation

extension OpenAIProvider: StreamingLLMProviderProtocol {
    
    /// 流式生成响应
    public func streamGenerate(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?
    ) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 构建请求
                    let request = try await buildStreamRequest(messages: messages, tools: tools)
                    
                    // 发送流式请求
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw ToolError.executionFailed("Invalid response")
                    }
                    
                    // 解析 Server-Sent Events (SSE)
                    var buffer = ""
                    
                    for try await byte in bytes {
                        let character = String(UnicodeScalar(byte))
                        buffer += character
                        
                        // 检查是否是完整的事件
                        if buffer.hasSuffix("\n\n") {
                            let lines = buffer.components(separatedBy: "\n")
                            buffer = ""
                            
                            for line in lines {
                                if line.hasPrefix("data: ") {
                                    let data = line.dropFirst(6) // 移除 "data: "
                                    
                                    // 检查是否是结束标记
                                    if data == "[DONE]" {
                                        continuation.yield(StreamingChunk(type: .done))
                                        continuation.finish()
                                        return
                                    }
                                    
                                    // 解析 JSON
                                    if let jsonData = data.data(using: .utf8),
                                       let chunk = try? parseStreamChunk(jsonData) {
                                        continuation.yield(chunk)
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func buildStreamRequest(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?
    ) async throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ToolError.invalidArguments("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "model": self.modelName,
            "messages": messages.map { msg in
                [
                    "role": msg.role.rawValue,
                    "content": msg.content
                ]
            },
            "temperature": 0.7,
            "stream": true // 启用流式响应
        ]
        
        if let tools = tools {
            body["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": tool.parameters
                    ]
                ]
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func parseStreamChunk(_ data: Data) throws -> StreamingChunk {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any] else {
            throw ToolError.executionFailed("Invalid response format")
        }
        
        // 解析内容
        if let content = delta["content"] as? String {
            return StreamingChunk(type: .content(content))
        }
        
        // 解析工具调用
        if let toolCalls = delta["tool_calls"] as? [[String: Any]],
           let toolCall = toolCalls.first {
            let id = toolCall["id"] as? String ?? ""
            
            if let function = toolCall["function"] as? [String: Any] {
                let name = function["name"] as? String
                let arguments = function["arguments"] as? String
                
                let toolChunk = ToolCallChunk(id: id, name: name, arguments: arguments)
                return StreamingChunk(type: .toolCall(toolChunk))
            }
        }
        
        // 默认返回空内容
        return StreamingChunk(type: .content(""))
    }
}

