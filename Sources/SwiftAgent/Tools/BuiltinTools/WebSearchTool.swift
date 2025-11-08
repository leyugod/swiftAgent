//
//  WebSearchTool.swift
//  SwiftAgent
//
//  网络搜索工具
//

import Foundation

/// 网络搜索工具
/// 提供网络搜索功能（需要配置搜索 API）
public struct WebSearchTool: ToolProtocol {
    public let name = "web_search"
    public let description = "在互联网上搜索信息。返回相关的搜索结果，包括标题、摘要和链接。"
    
    public var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "query",
                type: "string",
                description: "搜索查询关键词",
                required: true
            ),
            ToolParameter(
                name: "max_results",
                type: "number",
                description: "返回的最大结果数，默认为 5",
                required: false
            ),
            ToolParameter(
                name: "language",
                type: "string",
                description: "搜索语言，如 'zh-CN'、'en-US'，默认为 'zh-CN'",
                required: false
            )
        ]
    }
    
    private let searchProvider: SearchProvider
    
    /// 初始化搜索工具
    /// - Parameter searchProvider: 搜索提供商（如果为 nil，使用模拟提供商）
    public init(searchProvider: SearchProvider? = nil) {
        self.searchProvider = searchProvider ?? MockSearchProvider()
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("缺少 'query' 参数")
        }
        
        let maxResults = arguments["max_results"] as? Int ?? 5
        let language = arguments["language"] as? String ?? "zh-CN"
        
        do {
            let results = try await searchProvider.search(
                query: query,
                maxResults: maxResults,
                language: language
            )
            
            return formatResults(results, query: query)
        } catch {
            throw ToolError.executionFailed("搜索失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func formatResults(_ results: [SearchResult], query: String) -> String {
        var output = "搜索结果（关键词：\(query)）：\n\n"
        
        for (index, result) in results.enumerated() {
            output += """
            \(index + 1). \(result.title)
               摘要：\(result.snippet)
               链接：\(result.url)
            
            
            """
        }
        
        if results.isEmpty {
            output += "未找到相关结果"
        } else {
            output += "共找到 \(results.count) 条结果"
        }
        
        return output
    }
}

// MARK: - Search Provider Protocol

/// 搜索提供商协议
public protocol SearchProvider {
    func search(query: String, maxResults: Int, language: String) async throws -> [SearchResult]
}

/// 搜索结果
public struct SearchResult {
    public let title: String
    public let snippet: String
    public let url: String
    
    public init(title: String, snippet: String, url: String) {
        self.title = title
        self.snippet = snippet
        self.url = url
    }
}

// MARK: - Mock Search Provider

/// 模拟搜索提供商（用于演示和测试）
public struct MockSearchProvider: SearchProvider {
    public init() {}
    
    public func search(query: String, maxResults: Int, language: String) async throws -> [SearchResult] {
        // 模拟搜索延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        // 返回模拟结果
        let results = [
            SearchResult(
                title: "关于「\(query)」的维基百科",
                snippet: "这是关于 \(query) 的详细介绍。（这是模拟搜索结果，实际使用需要配置真实的搜索 API）",
                url: "https://zh.wikipedia.org/wiki/\(query)"
            ),
            SearchResult(
                title: "\(query) - 百度百科",
                snippet: "\(query) 是一个重要的概念/主题。（模拟结果）",
                url: "https://baike.baidu.com"
            ),
            SearchResult(
                title: "\(query) 相关文章",
                snippet: "探讨 \(query) 的各个方面，包括历史、应用和未来发展。（模拟结果）",
                url: "https://example.com/articles/\(query)"
            )
        ]
        
        return Array(results.prefix(maxResults))
    }
}

// MARK: - Real Search Providers (需要 API Key)

/// Google 自定义搜索提供商
/// 需要 Google Custom Search API Key 和 Search Engine ID
public struct GoogleSearchProvider: SearchProvider {
    private let apiKey: String
    private let searchEngineId: String
    private let session: URLSession
    
    public init(apiKey: String, searchEngineId: String) {
        self.apiKey = apiKey
        self.searchEngineId = searchEngineId
        self.session = URLSession.shared
    }
    
    public func search(query: String, maxResults: Int, language: String) async throws -> [SearchResult] {
        // Google Custom Search API 实现
        // 注意：这需要有效的 API Key
        let baseURL = "https://www.googleapis.com/customsearch/v1"
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: searchEngineId),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: String(min(maxResults, 10))),
            URLQueryItem(name: "lr", value: "lang_\(language.prefix(2))")
        ]
        
        guard let url = components.url else {
            throw SearchError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
        
        return response.items?.map { item in
            SearchResult(
                title: item.title,
                snippet: item.snippet ?? "",
                url: item.link
            )
        } ?? []
    }
    
    private struct GoogleSearchResponse: Codable {
        let items: [SearchItem]?
        
        struct SearchItem: Codable {
            let title: String
            let snippet: String?
            let link: String
        }
    }
}

// MARK: - Search Error

enum SearchError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的搜索 URL"
        case .apiError(let message):
            return "API 错误：\(message)"
        case .networkError:
            return "网络请求失败"
        }
    }
}

