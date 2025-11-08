//
//  AgentLoop.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// Agent Loop 状态
public enum AgentLoopState {
    case idle
    case thinking
    case acting
    case observing
    case finished
    case error(Error)
}

/// Agent Loop 事件
public enum AgentLoopEvent {
    case started
    case thoughtGenerated(Thought)
    case actionDecided(Action)
    case actionExecuted(Observation)
    case finished(String)
    case error(Error)
}

/// Agent Loop 配置
public struct AgentLoopConfig {
    /// 最大循环次数
    public let maxIterations: Int
    
    /// 是否在完成后停止
    public let stopOnFinish: Bool
    
    /// 思考时的温度参数
    public let temperature: Double
    
    public init(
        maxIterations: Int = 10,
        stopOnFinish: Bool = true,
        temperature: Double = 0.7
    ) {
        self.maxIterations = maxIterations
        self.stopOnFinish = stopOnFinish
        self.temperature = temperature
    }
}

/// Agent Loop 实现
/// 实现感知-思考-行动-观察的完整循环
public actor AgentLoop {
    private var state: AgentLoopState = .idle
    private var iterationCount: Int = 0
    private let config: AgentLoopConfig
    private let agent: AgentProtocol
    
    public init(agent: AgentProtocol, config: AgentLoopConfig = AgentLoopConfig()) {
        self.agent = agent
        self.config = config
    }
    
    /// 运行完整的 Agent Loop
    /// - Parameter input: 初始用户输入
    /// - Returns: 最终响应
    public func run(_ input: String) async throws -> String {
        state = .idle
        iterationCount = 0
        var currentInput = input
        var observations: [Observation] = []
        
        while iterationCount < config.maxIterations {
            iterationCount += 1
            
            // 感知阶段：构建当前上下文
            let context = buildContext(input: currentInput, observations: observations)
            
            // 思考阶段
            state = .thinking
            let (thought, action) = try await agent.think(context)
            
            // 如果没有行动，说明已经完成
            guard let action = action else {
                state = .finished
                return extractFinalAnswer(from: thought)
            }
            
            // 行动阶段
            state = .acting
            let observation = try await agent.act(action)
            observations.append(observation)
            
            // 观察阶段：准备下一轮输入
            state = .observing
            currentInput = formatObservation(observation)
            
            // 检查是否应该停止
            if config.stopOnFinish && shouldStop(thought: thought, observation: observation) {
                state = .finished
                return extractFinalAnswer(from: thought)
            }
        }
        
        state = .finished
        return "达到最大迭代次数 (\(config.maxIterations))，任务未完成。"
    }
    
    /// 获取当前状态
    public func getState() -> AgentLoopState {
        state
    }
    
    /// 获取迭代次数
    public func getIterationCount() -> Int {
        iterationCount
    }
    
    // MARK: - Private Methods
    
    private func buildContext(input: String, observations: [Observation]) -> String {
        var context = input
        
        if !observations.isEmpty {
            context += "\n\n## 之前的观察结果：\n"
            for (index, obs) in observations.enumerated() {
                context += "\(index + 1). \(obs.content)\n"
            }
        }
        
        return context
    }
    
    private func formatObservation(_ observation: Observation) -> String {
        if let toolName = observation.toolName {
            return "工具 '\(toolName)' 的执行结果：\(observation.content)"
        }
        return observation.content
    }
    
    private func shouldStop(thought: Thought, observation: Observation) -> Bool {
        // 检查思考中是否包含完成标记
        let completionKeywords = ["完成", "done", "finished", "完成", "结束"]
        let thoughtText = thought.reasoning.lowercased()
        return completionKeywords.contains { thoughtText.contains($0) }
    }
    
    private func extractFinalAnswer(from thought: Thought) -> String {
        // 优先使用 nextAction，否则使用 reasoning
        if let nextAction = thought.nextAction, nextAction.hasPrefix("finish") {
            // 解析 finish(answer="...") 格式
            if let answer = extractAnswerFromFinishAction(nextAction) {
                return answer
            }
        }
        return thought.reasoning
    }
    
    private func extractAnswerFromFinishAction(_ action: String) -> String? {
        // 简单解析 finish(answer="...") 格式
        let pattern = #"finish\(answer\s*=\s*"([^"]+)"\)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: action, options: [], range: NSRange(action.startIndex..., in: action)),
           let answerRange = Range(match.range(at: 1), in: action) {
            return String(action[answerRange])
        }
        return nil
    }
}

