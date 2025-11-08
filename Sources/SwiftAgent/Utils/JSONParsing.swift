//
//  JSONParsing.swift
//  SwiftAgent
//
//  Created by SwiftAgent Framework
//

import Foundation

/// JSON 解析工具
public enum JSONParsing {
    /// 从字符串解析 JSON
    /// - Parameter jsonString: JSON 字符串
    /// - Returns: 解析后的字典
    public static func parse(_ jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            throw JSONParsingError.invalidString
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONParsingError.invalidFormat
        }
        
        return json
    }
    
    /// 将字典转换为 JSON 字符串
    /// - Parameter dictionary: 字典
    /// - Returns: JSON 字符串
    public static func stringify(_ dictionary: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw JSONParsingError.encodingFailed
        }
        
        return string
    }
    
    /// 从文件加载 JSON
    /// - Parameter path: 文件路径
    /// - Returns: 解析后的字典
    public static func loadFromFile(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONParsingError.invalidFormat
        }
        
        return json
    }
    
    /// 保存 JSON 到文件
    /// - Parameters:
    ///   - dictionary: 字典
    ///   - path: 文件路径
    public static func saveToFile(_ dictionary: [String: Any], path: String) throws {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    /// 提取 JSON 中的值
    /// - Parameters:
    ///   - json: JSON 字典
    ///   - keyPath: 键路径（如 "user.name"）
    /// - Returns: 值（如果存在）
    public static func extract<T>(from json: [String: Any], keyPath: String) -> T? {
        let keys = keyPath.components(separatedBy: ".")
        var current: Any? = json
        
        for key in keys {
            guard let dict = current as? [String: Any],
                  let value = dict[key] else {
                return nil
            }
            current = value
        }
        
        return current as? T
    }
}

/// JSON 解析错误
public enum JSONParsingError: Error {
    case invalidString
    case invalidFormat
    case encodingFailed
    case fileNotFound
    case keyPathNotFound(String)
}

