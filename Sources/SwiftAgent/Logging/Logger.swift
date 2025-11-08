//
//  Logger.swift
//  SwiftAgent
//
//  结构化日志系统
//

import Foundation
import os.log

// MARK: - Log Level

/// 日志级别
public enum LogLevel: Int, Comparable, Codable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public var symbol: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
    
    public var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}

// MARK: - Log Entry

/// 日志条目
public struct LogEntry: Codable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String
    public let metadata: [String: String]?
    public let file: String
    public let function: String
    public let line: Int
    
    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String]? = nil,
        file: String,
        function: String,
        line: Int
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.file = file
        self.function = function
        self.line = line
    }
    
    /// 格式化的日志字符串
    public var formatted: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timeStr = dateFormatter.string(from: timestamp)
        
        var result = "[\(timeStr)] \(level.symbol) [\(level.name)] [\(category)] \(message)"
        
        if let metadata = metadata, !metadata.isEmpty {
            let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            result += " | \(metaStr)"
        }
        
        return result
    }
}

// MARK: - Logger Protocol

/// 日志处理器协议
public protocol LogHandler {
    func handle(_ entry: LogEntry)
}

// MARK: - Console Log Handler

/// 控制台日志处理器
public struct ConsoleLogHandler: LogHandler {
    private let minLevel: LogLevel
    private let useColors: Bool
    
    public init(minLevel: LogLevel = .info, useColors: Bool = true) {
        self.minLevel = minLevel
        self.useColors = useColors
    }
    
    public func handle(_ entry: LogEntry) {
        guard entry.level >= minLevel else { return }
        print(entry.formatted)
    }
}

// MARK: - File Log Handler

/// 文件日志处理器
public struct FileLogHandler: LogHandler {
    private let fileURL: URL
    private let minLevel: LogLevel
    
    public init(fileURL: URL, minLevel: LogLevel = .debug) {
        self.fileURL = fileURL
        self.minLevel = minLevel
        
        // 确保文件存在
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }
    
    public func handle(_ entry: LogEntry) {
        guard entry.level >= minLevel else { return }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(entry),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        // 异步写入文件
        let logLine = jsonString + "\n"
        if let logData = logLine.data(using: .utf8),
           let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? fileHandle.close() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(logData)
        }
    }
}

// MARK: - OSLog Handler

/// 系统日志处理器（使用 os.log）
public struct OSLogHandler: LogHandler {
    private let subsystem: String
    private let category: String
    private let osLog: OSLog
    
    public init(subsystem: String = "com.swiftagent", category: String = "default") {
        self.subsystem = subsystem
        self.category = category
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    public func handle(_ entry: LogEntry) {
        let type: OSLogType
        switch entry.level {
        case .debug:
            type = .debug
        case .info:
            type = .info
        case .warning:
            type = .default
        case .error:
            type = .error
        case .critical:
            type = .fault
        }
        
        os_log("%{public}@", log: osLog, type: type, entry.formatted)
    }
}

// MARK: - Logger

/// 全局日志管理器
public actor Logger {
    public static let shared = Logger()
    
    private var handlers: [LogHandler] = []
    private var isEnabled: Bool = true
    
    private init() {
        // 默认添加控制台处理器
        handlers.append(ConsoleLogHandler())
    }
    
    /// 添加日志处理器
    public func addHandler(_ handler: LogHandler) {
        handlers.append(handler)
    }
    
    /// 清空所有处理器
    public func removeAllHandlers() {
        handlers.removeAll()
    }
    
    /// 启用/禁用日志
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// 记录日志
    public func log(
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line
        )
        
        for handler in handlers {
            handler.handle(entry)
        }
    }
    
    // MARK: - Convenience Methods
    
    public func debug(
        _ message: String,
        category: String = "default",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func info(
        _ message: String,
        category: String = "default",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func warning(
        _ message: String,
        category: String = "default",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func error(
        _ message: String,
        category: String = "default",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func critical(
        _ message: String,
        category: String = "default",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .critical, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
}

