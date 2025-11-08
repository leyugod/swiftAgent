//
//  AgentCoordinator.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// Agent 协调器
/// 负责协调多个 Agent 的任务分配和执行
public actor AgentCoordinator {
    private let strategy: MultiAgentSystem.CoordinationStrategy
    
    public init(strategy: MultiAgentSystem.CoordinationStrategy) {
        self.strategy = strategy
    }
    
    /// 分配任务
    /// - Parameters:
    ///   - task: 任务描述
    ///   - agents: Agent 列表
    /// - Returns: 任务分配方案
    public func allocateTasks(
        task: String,
        agents: [(String, AgentProtocol)]
    ) async throws -> [TaskAllocation] {
        switch strategy {
        case .sequential:
            return allocateSequential(task: task, agents: agents)
        case .parallel:
            return allocateParallel(task: task, agents: agents)
        case .hierarchical:
            return try await allocateHierarchical(task: task, agents: agents)
        case .collaborative:
            return allocateCollaborative(task: task, agents: agents)
        }
    }
    
    /// 整合结果
    /// - Parameter results: 各 Agent 的执行结果
    /// - Returns: 整合后的结果
    public func integrateResults(_ results: [TaskResult]) async -> String {
        var integrated = "# 任务执行结果\n\n"
        
        for result in results {
            integrated += "## \(result.agentName)\n"
            integrated += result.output + "\n\n"
        }
        
        return integrated
    }
    
    // MARK: - Private Methods
    
    private func allocateSequential(
        task: String,
        agents: [(String, AgentProtocol)]
    ) -> [TaskAllocation] {
        var allocations: [TaskAllocation] = []
        
        for (index, (id, agent)) in agents.enumerated() {
            let allocation = TaskAllocation(
                agentId: id,
                agentName: agent.name,
                task: task,
                priority: index,
                dependencies: index > 0 ? [agents[index - 1].0] : []
            )
            allocations.append(allocation)
        }
        
        return allocations
    }
    
    private func allocateParallel(
        task: String,
        agents: [(String, AgentProtocol)]
    ) -> [TaskAllocation] {
        var allocations: [TaskAllocation] = []
        
        for (id, agent) in agents {
            let allocation = TaskAllocation(
                agentId: id,
                agentName: agent.name,
                task: task,
                priority: 0,
                dependencies: []
            )
            allocations.append(allocation)
        }
        
        return allocations
    }
    
    private func allocateHierarchical(
        task: String,
        agents: [(String, AgentProtocol)]
    ) async throws -> [TaskAllocation] {
        guard !agents.isEmpty else { return [] }
        
        var allocations: [TaskAllocation] = []
        
        // 协调者
        let (coordinatorId, coordinator) = agents[0]
        let coordinatorAllocation = TaskAllocation(
            agentId: coordinatorId,
            agentName: coordinator.name,
            task: "协调和分解任务：\(task)",
            priority: 0,
            dependencies: []
        )
        allocations.append(coordinatorAllocation)
        
        // 工作者
        for (id, agent) in agents.dropFirst() {
            let workerAllocation = TaskAllocation(
                agentId: id,
                agentName: agent.name,
                task: "执行子任务",
                priority: 1,
                dependencies: [coordinatorId]
            )
            allocations.append(workerAllocation)
        }
        
        return allocations
    }
    
    private func allocateCollaborative(
        task: String,
        agents: [(String, AgentProtocol)]
    ) -> [TaskAllocation] {
        var allocations: [TaskAllocation] = []
        
        for (id, agent) in agents {
            let allocation = TaskAllocation(
                agentId: id,
                agentName: agent.name,
                task: "参与协作讨论：\(task)",
                priority: 0,
                dependencies: []
            )
            allocations.append(allocation)
        }
        
        return allocations
    }
}

/// 任务分配
public struct TaskAllocation {
    public let agentId: String
    public let agentName: String
    public let task: String
    public let priority: Int
    public let dependencies: [String]
    
    public init(
        agentId: String,
        agentName: String,
        task: String,
        priority: Int,
        dependencies: [String]
    ) {
        self.agentId = agentId
        self.agentName = agentName
        self.task = task
        self.priority = priority
        self.dependencies = dependencies
    }
}

/// 任务结果
public struct TaskResult {
    public let agentId: String
    public let agentName: String
    public let output: String
    public let success: Bool
    public let error: Error?
    
    public init(
        agentId: String,
        agentName: String,
        output: String,
        success: Bool = true,
        error: Error? = nil
    ) {
        self.agentId = agentId
        self.agentName = agentName
        self.output = output
        self.success = success
        self.error = error
    }
}

