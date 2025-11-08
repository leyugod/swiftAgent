//
//  DateTimeTool.swift
//  SwiftAgent
//
//  日期时间工具
//

import Foundation

/// 日期时间工具
/// 提供日期时间的获取、格式化和计算功能
public struct DateTimeTool: ToolProtocol {
    public let name = "datetime"
    public let description = "获取和处理日期时间信息。支持获取当前时间、格式化日期、计算日期差异、时区转换等。"
    
    public var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "action",
                type: "string",
                description: "要执行的操作：'current'（当前时间）、'format'（格式化）、'add'（加时间）、'diff'（计算差异）",
                required: true,
                enumValues: ["current", "format", "add", "diff"]
            ),
            ToolParameter(
                name: "date",
                type: "string",
                description: "ISO 8601 格式的日期字符串（format/add/diff 操作需要）",
                required: false
            ),
            ToolParameter(
                name: "format",
                type: "string",
                description: "日期格式字符串，如 'yyyy-MM-dd HH:mm:ss'（format 操作需要）",
                required: false
            ),
            ToolParameter(
                name: "amount",
                type: "number",
                description: "要添加的时间量（add 操作需要）",
                required: false
            ),
            ToolParameter(
                name: "unit",
                type: "string",
                description: "时间单位：'seconds'、'minutes'、'hours'、'days'、'months'、'years'（add 操作需要）",
                required: false,
                enumValues: ["seconds", "minutes", "hours", "days", "months", "years"]
            ),
            ToolParameter(
                name: "to_date",
                type: "string",
                description: "目标日期（diff 操作需要）",
                required: false
            ),
            ToolParameter(
                name: "timezone",
                type: "string",
                description: "时区标识符，如 'Asia/Shanghai'、'America/New_York'",
                required: false
            )
        ]
    }
    
    private let isoFormatter: ISO8601DateFormatter
    
    public init() {
        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("缺少 'action' 参数")
        }
        
        switch action {
        case "current":
            return try getCurrentTime(timezone: arguments["timezone"] as? String)
            
        case "format":
            return try formatDate(
                dateString: arguments["date"] as? String,
                format: arguments["format"] as? String,
                timezone: arguments["timezone"] as? String
            )
            
        case "add":
            return try addTime(
                dateString: arguments["date"] as? String,
                amount: arguments["amount"],
                unit: arguments["unit"] as? String
            )
            
        case "diff":
            return try calculateDifference(
                fromDate: arguments["date"] as? String,
                toDate: arguments["to_date"] as? String
            )
            
        default:
            throw ToolError.invalidArguments("不支持的操作：\(action)")
        }
    }
    
    // MARK: - Private Methods
    
    /// 获取当前时间
    private func getCurrentTime(timezone: String?) throws -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let tzIdentifier = timezone {
            guard let tz = TimeZone(identifier: tzIdentifier) else {
                throw DateTimeError.invalidTimezone(tzIdentifier)
            }
            formatter.timeZone = tz
        }
        
        let formatted = formatter.string(from: now)
        let tzName = formatter.timeZone.identifier
        let iso = isoFormatter.string(from: now)
        
        return """
        当前时间：
        - 格式化: \(formatted)
        - 时区: \(tzName)
        - ISO 8601: \(iso)
        - Unix 时间戳: \(Int(now.timeIntervalSince1970))
        """
    }
    
    /// 格式化日期
    private func formatDate(dateString: String?, format: String?, timezone: String?) throws -> String {
        guard let dateString = dateString else {
            throw ToolError.missingRequiredParameter("date")
        }
        
        guard let date = isoFormatter.date(from: dateString) else {
            throw DateTimeError.invalidDateFormat
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = format ?? "yyyy-MM-dd HH:mm:ss"
        
        if let tzIdentifier = timezone {
            guard let tz = TimeZone(identifier: tzIdentifier) else {
                throw DateTimeError.invalidTimezone(tzIdentifier)
            }
            formatter.timeZone = tz
        }
        
        return formatter.string(from: date)
    }
    
    /// 添加时间
    private func addTime(dateString: String?, amount: Any?, unit: String?) throws -> String {
        let date: Date
        if let dateString = dateString {
            guard let parsedDate = isoFormatter.date(from: dateString) else {
                throw DateTimeError.invalidDateFormat
            }
            date = parsedDate
        } else {
            date = Date()
        }
        
        guard let amountValue = amount as? Int else {
            throw ToolError.missingRequiredParameter("amount")
        }
        
        guard let unit = unit else {
            throw ToolError.missingRequiredParameter("unit")
        }
        
        let calendar = Calendar.current
        var component: Calendar.Component
        
        switch unit {
        case "seconds":
            component = .second
        case "minutes":
            component = .minute
        case "hours":
            component = .hour
        case "days":
            component = .day
        case "months":
            component = .month
        case "years":
            component = .year
        default:
            throw ToolError.invalidArguments("不支持的时间单位：\(unit)")
        }
        
        guard let newDate = calendar.date(byAdding: component, value: amountValue, to: date) else {
            throw DateTimeError.calculationFailed
        }
        
        return """
        原始日期: \(isoFormatter.string(from: date))
        新日期: \(isoFormatter.string(from: newDate))
        变化: +\(amountValue) \(unit)
        """
    }
    
    /// 计算日期差异
    private func calculateDifference(fromDate: String?, toDate: String?) throws -> String {
        guard let fromDateString = fromDate,
              let toDateString = toDate else {
            throw ToolError.invalidArguments("需要提供 'date' 和 'to_date' 参数")
        }
        
        guard let date1 = isoFormatter.date(from: fromDateString),
              let date2 = isoFormatter.date(from: toDateString) else {
            throw DateTimeError.invalidDateFormat
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date1,
            to: date2
        )
        
        let totalSeconds = date2.timeIntervalSince(date1)
        
        return """
        从 \(fromDateString) 到 \(toDateString):
        - 年: \(components.year ?? 0)
        - 月: \(components.month ?? 0)
        - 天: \(components.day ?? 0)
        - 小时: \(components.hour ?? 0)
        - 分钟: \(components.minute ?? 0)
        - 秒: \(components.second ?? 0)
        - 总秒数: \(Int(totalSeconds))
        """
    }
}

// MARK: - DateTime Error

enum DateTimeError: Error, LocalizedError {
    case invalidDateFormat
    case invalidTimezone(String)
    case calculationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidDateFormat:
            return "无效的日期格式，请使用 ISO 8601 格式"
        case .invalidTimezone(let tz):
            return "无效的时区：\(tz)"
        case .calculationFailed:
            return "日期计算失败"
        }
    }
}

