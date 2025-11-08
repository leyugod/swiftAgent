//
//  StreamingProtocol.swift
//  SwiftAgent
//
//  流式响应协议
//

import Foundation

// MARK: - Streaming Protocol

/// 流式 LLM 提供商协议
public protocol StreamingLLMProviderProtocol: LLMProviderProtocol {
    /// 流式生成响应
    /// - Parameters:
    ///   - messages: 消息历史
    ///   - tools: 可用工具列表
    /// - Returns: 异步流，产出流式响应块
    func streamGenerate(
        messages: [LLMMessage],
        tools: [LLMToolFunction]?
    ) async throws -> AsyncThrowingStream<StreamingChunk, Error>
}

// MARK: - Streaming Chunk

/// 流式响应块
public struct StreamingChunk: Sendable {
    /// 块类型
    public enum ChunkType: Sendable {
        case content(String)      // 内容片段
        case toolCall(ToolCallChunk) // 工具调用片段
        case done                 // 完成标记
        case error(String)        // 错误信息
    }
    
    /// 块 ID
    public let id: String
    
    /// 块类型
    public let type: ChunkType
    
    /// 时间戳
    public let timestamp: Date
    
    /// 元数据
    public let metadata: [String: String]?
    
    public init(
        id: String = UUID().uuidString,
        type: ChunkType,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Tool Call Chunk

/// 工具调用块
public struct ToolCallChunk: Sendable {
    public let id: String
    public let name: String?
    public let arguments: String?
    
    public init(id: String, name: String?, arguments: String?) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Streaming Response Builder

/// 流式响应构建器
/// 用于将流式块组合成完整响应
public actor StreamingResponseBuilder {
    private var contentParts: [String] = []
    private var toolCalls: [String: ToolCallAccumulator] = [:]
    
    private struct ToolCallAccumulator {
        var id: String
        var name: String = ""
        var arguments: String = ""
    }
    
    /// 处理流式块
    public func process(_ chunk: StreamingChunk) {
        switch chunk.type {
        case .content(let text):
            contentParts.append(text)
            
        case .toolCall(let toolChunk):
            if toolCalls[toolChunk.id] == nil {
                toolCalls[toolChunk.id] = ToolCallAccumulator(id: toolChunk.id)
            }
            
            if let name = toolChunk.name {
                toolCalls[toolChunk.id]?.name += name
            }
            
            if let args = toolChunk.arguments {
                toolCalls[toolChunk.id]?.arguments += args
            }
            
        case .done, .error:
            break
        }
    }
    
    /// 构建完整响应
    public func build() -> LLMResponse {
        let content = contentParts.joined()
        
        let llmToolCalls = toolCalls.values.map { acc in
            LLMToolCall(
                id: acc.id,
                type: "function",
                function: LLMToolCall.FunctionCall(
                    name: acc.name,
                    arguments: acc.arguments
                )
            )
        }
        
        return LLMResponse(
            content: content.isEmpty ? "" : content,
            toolCalls: llmToolCalls.isEmpty ? nil : llmToolCalls,
            finishReason: "stop"
        )
    }
    
    /// 获取当前内容
    public func getCurrentContent() -> String {
        contentParts.joined()
    }
    
    /// 重置构建器
    public func reset() {
        contentParts.removeAll()
        toolCalls.removeAll()
    }
}

// MARK: - Streaming Callback

/// 流式响应回调
public struct StreamingCallback {
    public typealias ContentHandler = (String) async -> Void
    public typealias ToolCallHandler = (ToolCallChunk) async -> Void
    public typealias CompletionHandler = (LLMResponse) async -> Void
    public typealias ErrorHandler = (Error) async -> Void
    
    public let onContent: ContentHandler?
    public let onToolCall: ToolCallHandler?
    public let onCompletion: CompletionHandler?
    public let onError: ErrorHandler?
    
    public init(
        onContent: ContentHandler? = nil,
        onToolCall: ToolCallHandler? = nil,
        onCompletion: CompletionHandler? = nil,
        onError: ErrorHandler? = nil
    ) {
        self.onContent = onContent
        self.onToolCall = onToolCall
        self.onCompletion = onCompletion
        self.onError = onError
    }
}

