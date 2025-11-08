//
//  MultiAgentSystem.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// 多智能体系统
/// 协调多个 Agent 协同工作
public actor MultiAgentSystem {
    private var agents: [String: AgentProtocol] = [:]
    private let coordinator: AgentCoordinator
    private let communication: AgentCommunication
    
    /// 多智能体系统配置
    public struct Config {
        public let coordinationStrategy: CoordinationStrategy
        public let communicationMode: CommunicationMode
        public let maxConcurrentTasks: Int
        
        public init(
            coordinationStrategy: CoordinationStrategy = .sequential,
            communicationMode: CommunicationMode = .shared,
            maxConcurrentTasks: Int = 5
        ) {
            self.coordinationStrategy = coordinationStrategy
            self.communicationMode = communicationMode
            self.maxConcurrentTasks = maxConcurrentTasks
        }
    }
    
    /// 协调策略
    public enum CoordinationStrategy {
        case sequential     // 顺序执行
        case parallel       // 并行执行
        case hierarchical   // 分层执行
        case collaborative  // 协作执行
    }
    
    /// 通信模式
    public enum CommunicationMode {
        case shared         // 共享通信（所有 Agent 可见）
        case directed       // 定向通信（点对点）
        case broadcast      // 广播通信
    }
    
    private let config: Config
    
    /// 初始化多智能体系统
    /// - Parameter config: 配置
    public init(config: Config = Config()) {
        self.config = config
        self.coordinator = AgentCoordinator(strategy: config.coordinationStrategy)
        self.communication = AgentCommunication(mode: config.communicationMode)
    }
    
    /// 注册 Agent
    /// - Parameters:
    ///   - id: Agent ID
    ///   - agent: Agent 实例
    public func register(id: String, agent: AgentProtocol) {
        agents[id] = agent
        print("Agent registered: \(agent.name) (\(id))")
    }
    
    /// 注销 Agent
    /// - Parameter id: Agent ID
    public func unregister(id: String) {
        agents.removeValue(forKey: id)
        print("Agent unregistered: \(id)")
    }
    
    /// 执行任务
    /// - Parameters:
    ///   - task: 任务描述
    ///   - agentIds: 参与的 Agent ID 列表（如果为空，则使用所有 Agent）
    /// - Returns: 执行结果
    public func executeTask(
        _ task: String,
        agentIds: [String]? = nil
    ) async throws -> String {
        let participatingAgents = try getParticipatingAgents(agentIds)
        
        switch config.coordinationStrategy {
        case .sequential:
            return try await executeSequential(task: task, agents: participatingAgents)
        case .parallel:
            return try await executeParallel(task: task, agents: participatingAgents)
        case .hierarchical:
            return try await executeHierarchical(task: task, agents: participatingAgents)
        case .collaborative:
            return try await executeCollaborative(task: task, agents: participatingAgents)
        }
    }
    
    /// 获取所有 Agent ID
    /// - Returns: Agent ID 数组
    public func getAllAgentIds() -> [String] {
        Array(agents.keys)
    }
    
    /// 获取 Agent 数量
    /// - Returns: Agent 数量
    public func getAgentCount() -> Int {
        agents.count
    }
    
    // MARK: - Private Methods
    
    private func getParticipatingAgents(_ ids: [String]?) throws -> [(String, AgentProtocol)] {
        let agentIds = ids ?? Array(agents.keys)
        var result: [(String, AgentProtocol)] = []
        
        for id in agentIds {
            guard let agent = agents[id] else {
                throw MultiAgentError.agentNotFound(id)
            }
            result.append((id, agent))
        }
        
        return result
    }
    
    private func executeSequential(
        task: String,
        agents: [(String, AgentProtocol)]
    ) async throws -> String {
        var results: [String] = []
        var currentTask = task
        
        for (_, agent) in agents {
            print("[\(agent.name)] 开始执行任务...")
            let result = try await agent.run(currentTask)
            results.append("[\(agent.name)]: \(result)")
            
            // 将前一个 Agent 的结果作为下一个 Agent 的输入
            currentTask = "基于之前的结果：\(result)\n\n继续处理：\(task)"
        }
        
        return results.joined(separator: "\n\n")
    }
    
    private func executeParallel(
        task: String,
        agents: [(String, AgentProtocol)]
    ) async throws -> String {
        // 并行执行所有 Agent
        try await withThrowingTaskGroup(of: (String, String).self) { group in
            for (_, agent) in agents {
                group.addTask {
                    let result = try await agent.run(task)
                    return (agent.name, result)
                }
            }
            
            var results: [String] = []
            for try await (name, result) in group {
                results.append("[\(name)]: \(result)")
            }
            
            return results.joined(separator: "\n\n")
        }
    }
    
    private func executeHierarchical(
        task: String,
        agents: [(String, AgentProtocol)]
    ) async throws -> String {
        guard !agents.isEmpty else {
            throw MultiAgentError.noAgentsAvailable
        }
        
        // 第一个 Agent 作为协调者
        let (_, coordinator) = agents[0]
        let workers = Array(agents.dropFirst())
        
        // 协调者分解任务
        let coordinatorPrompt = """
        你是协调者。请将以下任务分解为 \(workers.count) 个子任务：
        
        \(task)
        
        请为每个子任务输出一行，格式为：子任务1、子任务2、...
        """
        
        let subtasksResult = try await coordinator.run(coordinatorPrompt)
        let subtasks = subtasksResult.components(separatedBy: "、")
        
        // 分配给工作 Agent
        var workerResults: [String] = []
        for (index, (_, worker)) in workers.enumerated() {
            let subtask = index < subtasks.count ? subtasks[index] : task
            let result = try await worker.run(subtask)
            workerResults.append("[\(worker.name)]: \(result)")
        }
        
        // 协调者整合结果
        let integrationPrompt = """
        请整合以下工作结果，生成最终答案：
        
        原始任务：\(task)
        
        工作结果：
        \(workerResults.joined(separator: "\n"))
        """
        
        let finalResult = try await coordinator.run(integrationPrompt)
        
        return """
        ## 任务执行过程
        
        ### 子任务分配
        \(subtasks.joined(separator: "\n"))
        
        ### 各 Agent 执行结果
        \(workerResults.joined(separator: "\n\n"))
        
        ### 最终整合结果
        \(finalResult)
        """
    }
    
    private func executeCollaborative(
        task: String,
        agents: [(String, AgentProtocol)]
    ) async throws -> String {
        var discussion: [String] = []
        var currentRound = 0
        let maxRounds = 3
        
        // 初始任务
        var currentContext = task
        
        while currentRound < maxRounds {
            currentRound += 1
            discussion.append("## 第 \(currentRound) 轮讨论")
            
            // 每个 Agent 依次发言
            for (_, agent) in agents {
                let prompt = """
                当前讨论：
                \(currentContext)
                
                之前的发言：
                \(discussion.joined(separator: "\n\n"))
                
                请基于以上信息给出你的看法和建议。
                """
                
                let response = try await agent.run(prompt)
                discussion.append("[\(agent.name)]: \(response)")
                currentContext += "\n\n[\(agent.name)]: \(response)"
            }
        }
        
        // 生成最终结论
        let conclusionPrompt = """
        基于以下讨论历史，请总结最终结论：
        
        \(discussion.joined(separator: "\n\n"))
        """
        
        let finalConclusion = try await agents[0].1.run(conclusionPrompt)
        
        return """
        \(discussion.joined(separator: "\n\n"))
        
        ## 最终结论
        \(finalConclusion)
        """
    }
}

/// 多智能体系统错误
public enum MultiAgentError: Error {
    case agentNotFound(String)
    case noAgentsAvailable
    case executionFailed(String)
    case coordinationFailed(String)
}

