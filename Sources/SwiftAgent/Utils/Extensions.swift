//
//  Extensions.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

// MARK: - String Extensions

extension String {
    /// 移除首尾空白字符和换行符
    public var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 安全的 substring
    public func substring(from: Int, to: Int) -> String? {
        guard from >= 0, to <= count, from < to else { return nil }
        let startIndex = index(self.startIndex, offsetBy: from)
        let endIndex = index(self.startIndex, offsetBy: to)
        return String(self[startIndex..<endIndex])
    }
    
    /// 截断字符串到指定长度
    public func truncate(length: Int, suffix: String = "...") -> String {
        if count <= length {
            return self
        }
        let truncated = String(prefix(length))
        return truncated + suffix
    }
}

// MARK: - Array Extensions

extension Array {
    /// 安全的下标访问
    public subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
    
    /// 分块
    public func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Dictionary Extensions

extension Dictionary where Key == String, Value == Any {
    /// 转换为 JSON 字符串
    public func toJSONString() -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

// MARK: - Date Extensions

extension Date {
    /// 格式化为字符串
    public func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = style
        return formatter.string(from: self)
    }
    
    /// 相对时间描述
    public var relativeDescription: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        } else {
            return "\(Int(interval / 86400)) 天前"
        }
    }
}

