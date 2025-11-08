//
//  ANPProtocol.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//
//  Agent Network Protocol (ANP)
//  用于 Agent 网络的服务发现和管理

import Foundation

/// ANP Agent 信息
public struct ANPAgentInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let type: String
    public let capabilities: [String]
    public let endpoint: String
    public let status: AgentStatus
    public let metadata: [String: String]
    public let lastSeen: Date
    
    public enum AgentStatus: String, Codable, Sendable {
        case online
        case offline
        case busy
        case idle
    }
    
    public init(
        id: String,
        name: String,
        type: String,
        capabilities: [String],
        endpoint: String,
        status: AgentStatus = .online,
        metadata: [String: String] = [:],
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.capabilities = capabilities
        self.endpoint = endpoint
        self.status = status
        self.metadata = metadata
        self.lastSeen = lastSeen
    }
}

/// ANP 服务发现协议
@preconcurrency
public protocol ANPDiscoveryProtocol: Sendable {
    /// 注册 Agent
    /// - Parameter info: Agent 信息
    func register(_ info: ANPAgentInfo) async throws
    
    /// 注销 Agent
    /// - Parameter agentId: Agent ID
    func unregister(agentId: String) async throws
    
    /// 发现 Agent
    /// - Parameter query: 查询条件
    /// - Returns: 匹配的 Agent 信息数组
    func discover(query: ANPQuery) async throws -> [ANPAgentInfo]
    
    /// 获取 Agent 信息
    /// - Parameter agentId: Agent ID
    /// - Returns: Agent 信息
    func getAgent(id agentId: String) async throws -> ANPAgentInfo?
    
    /// 更新 Agent 状态
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - status: 新状态
    func updateStatus(agentId: String, status: ANPAgentInfo.AgentStatus) async throws
    
    /// 心跳
    /// - Parameter agentId: Agent ID
    func heartbeat(agentId: String) async throws
}

/// ANP 查询
public struct ANPQuery: Sendable {
    public let type: String?
    public let capabilities: [String]?
    public let status: ANPAgentInfo.AgentStatus?
    public let metadata: [String: String]?
    
    public init(
        type: String? = nil,
        capabilities: [String]? = nil,
        status: ANPAgentInfo.AgentStatus? = nil,
        metadata: [String: String]? = nil
    ) {
        self.type = type
        self.capabilities = capabilities
        self.status = status
        self.metadata = metadata
    }
}

/// ANP 服务注册中心
/// 实现 Agent 的注册和发现
public actor ANPRegistry: ANPDiscoveryProtocol {
    private var agents: [String: ANPAgentInfo] = [:]
    private let heartbeatTimeout: TimeInterval
    
    public init(heartbeatTimeout: TimeInterval = 30.0) {
        self.heartbeatTimeout = heartbeatTimeout
    }
    
    public func register(_ info: ANPAgentInfo) async throws {
        agents[info.id] = info
        print("Agent registered: \(info.name) (\(info.id))")
    }
    
    public func unregister(agentId: String) async throws {
        agents.removeValue(forKey: agentId)
        print("Agent unregistered: \(agentId)")
    }
    
    public func discover(query: ANPQuery) async throws -> [ANPAgentInfo] {
        var results = Array(agents.values)
        
        // 按类型过滤
        if let type = query.type {
            results = results.filter { $0.type == type }
        }
        
        // 按能力过滤
        if let capabilities = query.capabilities {
            results = results.filter { agent in
                capabilities.allSatisfy { agent.capabilities.contains($0) }
            }
        }
        
        // 按状态过滤
        if let status = query.status {
            results = results.filter { $0.status == status }
        }
        
        // 按元数据过滤
        if let metadata = query.metadata {
            results = results.filter { agent in
                metadata.allSatisfy { key, value in
                    agent.metadata[key] == value
                }
            }
        }
        
        // 过滤超时的 Agent
        let now = Date()
        results = results.filter { agent in
            now.timeIntervalSince(agent.lastSeen) < heartbeatTimeout
        }
        
        return results
    }
    
    public func getAgent(id agentId: String) async throws -> ANPAgentInfo? {
        agents[agentId]
    }
    
    public func updateStatus(agentId: String, status: ANPAgentInfo.AgentStatus) async throws {
        guard var agent = agents[agentId] else {
            throw ANPError.agentNotFound(agentId)
        }
        
        agent = ANPAgentInfo(
            id: agent.id,
            name: agent.name,
            type: agent.type,
            capabilities: agent.capabilities,
            endpoint: agent.endpoint,
            status: status,
            metadata: agent.metadata,
            lastSeen: Date()
        )
        
        agents[agentId] = agent
    }
    
    public func heartbeat(agentId: String) async throws {
        guard var agent = agents[agentId] else {
            throw ANPError.agentNotFound(agentId)
        }
        
        agent = ANPAgentInfo(
            id: agent.id,
            name: agent.name,
            type: agent.type,
            capabilities: agent.capabilities,
            endpoint: agent.endpoint,
            status: agent.status,
            metadata: agent.metadata,
            lastSeen: Date()
        )
        
        agents[agentId] = agent
    }
    
    /// 获取所有在线的 Agent
    /// - Returns: Agent 信息数组
    public func getAllOnlineAgents() async -> [ANPAgentInfo] {
        let now = Date()
        return agents.values.filter { agent in
            agent.status == .online &&
            now.timeIntervalSince(agent.lastSeen) < heartbeatTimeout
        }
    }
    
    /// 获取统计信息
    /// - Returns: 统计信息
    public func getStatistics() async -> [String: Int] {
        let now = Date()
        let onlineCount = agents.values.filter {
            $0.status == .online &&
            now.timeIntervalSince($0.lastSeen) < heartbeatTimeout
        }.count
        
        return [
            "total": agents.count,
            "online": onlineCount,
            "offline": agents.count - onlineCount
        ]
    }
    
    /// 清理超时的 Agent
    public func cleanupStaleAgents() async {
        let now = Date()
        let staleAgents = agents.filter { _, agent in
            now.timeIntervalSince(agent.lastSeen) >= heartbeatTimeout
        }
        
        for (id, _) in staleAgents {
            agents.removeValue(forKey: id)
            print("Removed stale agent: \(id)")
        }
    }
}

/// ANP Agent 客户端
/// 帮助 Agent 与注册中心交互
public actor ANPClient {
    private let registry: ANPRegistry
    private let agentInfo: ANPAgentInfo
    private var heartbeatTask: Task<Void, Never>?
    
    public init(registry: ANPRegistry, agentInfo: ANPAgentInfo) {
        self.registry = registry
        self.agentInfo = agentInfo
    }
    
    /// 启动（注册并开始心跳）
    public func start() async throws {
        try await registry.register(agentInfo)
        startHeartbeat()
    }
    
    /// 停止（注销并停止心跳）
    public func stop() async throws {
        stopHeartbeat()
        try await registry.unregister(agentId: agentInfo.id)
    }
    
    /// 发现其他 Agent
    /// - Parameter query: 查询条件
    /// - Returns: 匹配的 Agent 信息数组
    public func discover(query: ANPQuery) async throws -> [ANPAgentInfo] {
        try await registry.discover(query: query)
    }
    
    /// 更新状态
    /// - Parameter status: 新状态
    public func updateStatus(_ status: ANPAgentInfo.AgentStatus) async throws {
        try await registry.updateStatus(agentId: agentInfo.id, status: status)
    }
    
    // MARK: - Private Methods
    
    private func startHeartbeat() {
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await registry.heartbeat(agentId: agentInfo.id)
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }
}

/// ANP 错误
public enum ANPError: Error {
    case agentNotFound(String)
    case registrationFailed(String)
    case discoveryFailed(String)
    case networkError(String)
}

