//
//  AnthropicStreamingProvider.swift
//  SwiftAgent
//
//  Anthropic 流式响应实现
//

import Foundation

extension AnthropicProvider: StreamingLLMProviderProtocol {
    
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
                                    let data = line.dropFirst(6)
                                    
                                    // 解析 JSON
                                    if let jsonData = data.data(using: .utf8),
                                       let chunk = try? parseStreamChunk(jsonData) {
                                        continuation.yield(chunk)
                                        
                                        // 检查是否完成
                                        if case .done = chunk.type {
                                            continuation.finish()
                                            return
                                        }
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
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ToolError.invalidArguments("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // 分离系统消息
        var systemMessage = ""
        var userMessages: [[String: Any]] = []
        
        for msg in messages {
            if msg.role == .system {
                systemMessage = msg.content
            } else {
                userMessages.append([
                    "role": msg.role == .assistant ? "assistant" : "user",
                    "content": msg.content
                ])
            }
        }
        
        var body: [String: Any] = [
            "model": self.modelName,
            "max_tokens": 4096,
            "messages": userMessages,
            "stream": true // 启用流式响应
        ]
        
        if !systemMessage.isEmpty {
            body["system"] = systemMessage
        }
        
        if let tools = tools {
            body["tools"] = tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.parameters
                ]
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func parseStreamChunk(_ data: Data) throws -> StreamingChunk {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let type = json?["type"] as? String else {
            throw ToolError.executionFailed("Invalid response format")
        }
        
        switch type {
        case "content_block_delta":
            if let delta = json?["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                return StreamingChunk(type: .content(text))
            }
            
        case "message_stop":
            return StreamingChunk(type: .done)
            
        default:
            break
        }
        
        // 默认返回空内容
        return StreamingChunk(type: .content(""))
    }
}

