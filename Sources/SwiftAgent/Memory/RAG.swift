//
//  RAG.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 检索增强生成（Retrieval-Augmented Generation）
/// 结合向量检索和语言模型生成
public actor RAGSystem {
    private let vectorStore: VectorStoreProtocol
    private let llmProvider: LLMProviderProtocol
    private let embeddingProvider: EmbeddingProviderProtocol?
    
    /// RAG 配置
    public struct Config {
        public let topK: Int
        public let similarityThreshold: Double
        public let includeMetadata: Bool
        public let maxContextLength: Int
        
        public init(
            topK: Int = 5,
            similarityThreshold: Double = 0.7,
            includeMetadata: Bool = true,
            maxContextLength: Int = 4000
        ) {
            self.topK = topK
            self.similarityThreshold = similarityThreshold
            self.includeMetadata = includeMetadata
            self.maxContextLength = maxContextLength
        }
    }
    
    private let config: Config
    
    /// 初始化 RAG 系统
    /// - Parameters:
    ///   - vectorStore: 向量存储
    ///   - llmProvider: LLM 提供商
    ///   - embeddingProvider: 嵌入提供商（可选）
    ///   - config: RAG 配置
    public init(
        vectorStore: VectorStoreProtocol,
        llmProvider: LLMProviderProtocol,
        embeddingProvider: EmbeddingProviderProtocol? = nil,
        config: Config = Config()
    ) {
        self.vectorStore = vectorStore
        self.llmProvider = llmProvider
        self.embeddingProvider = embeddingProvider
        self.config = config
    }
    
    /// 添加文档到知识库
    /// - Parameters:
    ///   - content: 文档内容
    ///   - metadata: 元数据
    public func addDocument(content: String, metadata: [String: String] = [:]) async throws {
        guard let embeddingProvider = embeddingProvider else {
            throw RAGError.embeddingProviderNotAvailable
        }
        
        // 生成嵌入向量
        let embedding = try await embeddingProvider.embed(text: content)
        
        // 创建文档
        let document = VectorDocument(
            content: content,
            embedding: embedding,
            metadata: metadata
        )
        
        // 添加到向量存储
        try await vectorStore.add(document)
    }
    
    /// 批量添加文档
    /// - Parameter documents: 文档内容和元数据数组
    public func addDocuments(_ documents: [(content: String, metadata: [String: String])]) async throws {
        guard let embeddingProvider = embeddingProvider else {
            throw RAGError.embeddingProviderNotAvailable
        }
        
        var vectorDocs: [VectorDocument] = []
        
        for (content, metadata) in documents {
            let embedding = try await embeddingProvider.embed(text: content)
            let doc = VectorDocument(
                content: content,
                embedding: embedding,
                metadata: metadata
            )
            vectorDocs.append(doc)
        }
        
        try await vectorStore.addBatch(vectorDocs)
    }
    
    /// 检索并生成回答
    /// - Parameters:
    ///   - query: 用户查询
    ///   - systemPrompt: 系统提示词（可选）
    /// - Returns: 生成的回答
    public func query(
        _ query: String,
        systemPrompt: String? = nil
    ) async throws -> String {
        // 1. 检索相关文档
        let relevantDocs = try await retrieve(query: query)
        
        // 2. 构建上下文
        let context = buildContext(from: relevantDocs)
        
        // 3. 生成回答
        let answer = try await generate(
            query: query,
            context: context,
            systemPrompt: systemPrompt
        )
        
        return answer
    }
    
    /// 仅检索相关文档（不生成回答）
    /// - Parameter query: 查询
    /// - Returns: 相关文档数组
    public func retrieve(query: String) async throws -> [VectorSearchResult] {
        guard let embeddingProvider = embeddingProvider else {
            throw RAGError.embeddingProviderNotAvailable
        }
        
        // 生成查询的嵌入向量
        let queryEmbedding = try await embeddingProvider.embed(text: query)
        
        // 向量搜索
        let results = try await vectorStore.search(
            embedding: queryEmbedding,
            limit: config.topK,
            threshold: config.similarityThreshold
        )
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func buildContext(from results: [VectorSearchResult]) -> String {
        var context = "## 相关知识：\n\n"
        
        for (index, result) in results.enumerated() {
            context += "### 文档 \(index + 1) (相似度: \(String(format: "%.2f", result.score)))\n"
            context += result.document.content + "\n\n"
            
            if config.includeMetadata && !result.document.metadata.isEmpty {
                context += "**元数据**: \(result.document.metadata)\n\n"
            }
        }
        
        // 截断过长的上下文
        if context.count > config.maxContextLength {
            context = String(context.prefix(config.maxContextLength)) + "...\n"
        }
        
        return context
    }
    
    private func generate(
        query: String,
        context: String,
        systemPrompt: String?
    ) async throws -> String {
        let defaultSystemPrompt = """
        你是一个知识问答助手。请基于提供的相关知识回答用户的问题。
        
        要求：
        1. 只使用提供的知识内容进行回答
        2. 如果知识中没有相关信息，请明确告知用户
        3. 回答要准确、简洁
        4. 可以引用知识来源
        """
        
        let messages = [
            LLMMessage.system(systemPrompt ?? defaultSystemPrompt),
            LLMMessage.user("\(context)\n\n## 用户问题：\n\(query)")
        ]
        
        let response = try await llmProvider.chat(
            messages: messages,
            tools: nil,
            temperature: 0.3
        )
        
        return response.content
    }
}

/// 嵌入提供商协议
@preconcurrency
public protocol EmbeddingProviderProtocol: Sendable {
    /// 生成文本的嵌入向量
    /// - Parameter text: 文本内容
    /// - Returns: 嵌入向量
    func embed(text: String) async throws -> [Double]
    
    /// 批量生成嵌入向量
    /// - Parameter texts: 文本数组
    /// - Returns: 嵌入向量数组
    func embedBatch(texts: [String]) async throws -> [[Double]]
}

/// RAG 错误
public enum RAGError: Error {
    case embeddingProviderNotAvailable
    case retrievalFailed(String)
    case generationFailed(String)
}

