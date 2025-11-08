//
//  FileSystemTool.swift
//  SwiftAgent
//
//  文件系统工具
//

import Foundation

/// 文件系统工具
/// 提供安全的文件读写操作（限制在沙盒目录）
public struct FileSystemTool: ToolProtocol {
    public let name = "filesystem"
    public let description = "读写文件系统。支持读取、写入、列出目录、检查文件存在性等操作。出于安全考虑，操作限制在应用沙盒目录内。"
    
    public var parameters: [ToolParameter] {
        [
            ToolParameter(
                name: "action",
                type: "string",
                description: "要执行的操作：'read'（读取）、'write'（写入）、'list'（列表）、'exists'（检查存在）、'delete'（删除）",
                required: true,
                enumValues: ["read", "write", "list", "exists", "delete"]
            ),
            ToolParameter(
                name: "path",
                type: "string",
                description: "文件或目录的相对路径（相对于沙盒根目录）",
                required: true
            ),
            ToolParameter(
                name: "content",
                type: "string",
                description: "要写入的内容（write 操作需要）",
                required: false
            ),
            ToolParameter(
                name: "encoding",
                type: "string",
                description: "文件编码，默认为 'utf8'",
                required: false,
                enumValues: ["utf8", "ascii", "utf16"]
            )
        ]
    }
    
    private let fileManager: FileManager
    private let sandboxRoot: URL
    
    public init(sandboxRoot: URL? = nil) {
        self.fileManager = FileManager.default
        
        // 默认使用应用的 Documents 目录作为沙盒根目录
        if let customRoot = sandboxRoot {
            self.sandboxRoot = customRoot
        } else {
            self.sandboxRoot = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("缺少 'action' 参数")
        }
        
        guard let path = arguments["path"] as? String else {
            throw ToolError.invalidArguments("缺少 'path' 参数")
        }
        
        // 验证路径安全性
        let safePath = try validateAndResolvePath(path)
        
        switch action {
        case "read":
            return try readFile(at: safePath, encoding: arguments["encoding"] as? String)
            
        case "write":
            guard let content = arguments["content"] as? String else {
                throw ToolError.missingRequiredParameter("content")
            }
            return try writeFile(at: safePath, content: content, encoding: arguments["encoding"] as? String)
            
        case "list":
            return try listDirectory(at: safePath)
            
        case "exists":
            return try checkExists(at: safePath)
            
        case "delete":
            return try deleteFile(at: safePath)
            
        default:
            throw ToolError.invalidArguments("不支持的操作：\(action)")
        }
    }
    
    // MARK: - Private Methods
    
    /// 验证并解析路径（确保在沙盒内）
    private func validateAndResolvePath(_ path: String) throws -> URL {
        // 移除路径中的危险字符
        let cleanPath = path
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "~", with: "")
        
        let fullPath = sandboxRoot.appendingPathComponent(cleanPath)
        
        // 确保路径在沙盒内
        guard fullPath.path.hasPrefix(sandboxRoot.path) else {
            throw FileSystemError.pathOutsideSandbox
        }
        
        return fullPath
    }
    
    /// 读取文件
    private func readFile(at url: URL, encoding: String?) throws -> String {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound(url.path)
        }
        
        let stringEncoding = try parseEncoding(encoding)
        
        do {
            let content = try String(contentsOf: url, encoding: stringEncoding)
            return """
            文件内容（\(url.lastPathComponent)）：
            \(content)
            
            文件大小：\(content.count) 字符
            路径：\(url.path)
            """
        } catch {
            throw FileSystemError.readFailed(error.localizedDescription)
        }
    }
    
    /// 写入文件
    private func writeFile(at url: URL, content: String, encoding: String?) throws -> String {
        let stringEncoding = try parseEncoding(encoding)
        
        // 确保父目录存在
        let parentDir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: stringEncoding)
            return """
            文件写入成功：
            - 路径：\(url.path)
            - 大小：\(content.count) 字符
            - 编码：\(encoding ?? "utf8")
            """
        } catch {
            throw FileSystemError.writeFailed(error.localizedDescription)
        }
    }
    
    /// 列出目录内容
    private func listDirectory(at url: URL) throws -> String {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.directoryNotFound(url.path)
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
            
            var result = "目录内容（\(url.lastPathComponent)）：\n"
            
            for item in contents {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let size = resourceValues.fileSize ?? 0
                let type = isDirectory ? "[DIR]" : "[FILE]"
                let sizeStr = isDirectory ? "" : " (\(formatFileSize(size)))"
                
                result += "\(type) \(item.lastPathComponent)\(sizeStr)\n"
            }
            
            result += "\n总计：\(contents.count) 项"
            return result
        } catch {
            throw FileSystemError.listFailed(error.localizedDescription)
        }
    }
    
    /// 检查文件是否存在
    private func checkExists(at url: URL) throws -> String {
        let exists = fileManager.fileExists(atPath: url.path)
        
        if exists {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            let type = isDirectory.boolValue ? "目录" : "文件"
            
            return "\(type)存在：\(url.lastPathComponent)\n路径：\(url.path)"
        } else {
            return "不存在：\(url.lastPathComponent)\n路径：\(url.path)"
        }
    }
    
    /// 删除文件
    private func deleteFile(at url: URL) throws -> String {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound(url.path)
        }
        
        do {
            try fileManager.removeItem(at: url)
            return "删除成功：\(url.lastPathComponent)\n路径：\(url.path)"
        } catch {
            throw FileSystemError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// 解析编码
    private func parseEncoding(_ encoding: String?) throws -> String.Encoding {
        switch encoding?.lowercased() {
        case "utf8", nil:
            return .utf8
        case "ascii":
            return .ascii
        case "utf16":
            return .utf16
        default:
            throw FileSystemError.unsupportedEncoding(encoding!)
        }
    }
    
    /// 格式化文件大小
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - FileSystem Error

enum FileSystemError: Error, LocalizedError {
    case pathOutsideSandbox
    case fileNotFound(String)
    case directoryNotFound(String)
    case readFailed(String)
    case writeFailed(String)
    case listFailed(String)
    case deleteFailed(String)
    case unsupportedEncoding(String)
    
    var errorDescription: String? {
        switch self {
        case .pathOutsideSandbox:
            return "路径超出沙盒范围，操作被拒绝"
        case .fileNotFound(let path):
            return "文件不存在：\(path)"
        case .directoryNotFound(let path):
            return "目录不存在：\(path)"
        case .readFailed(let reason):
            return "读取失败：\(reason)"
        case .writeFailed(let reason):
            return "写入失败：\(reason)"
        case .listFailed(let reason):
            return "列表失败：\(reason)"
        case .deleteFailed(let reason):
            return "删除失败：\(reason)"
        case .unsupportedEncoding(let enc):
            return "不支持的编码：\(enc)"
        }
    }
}

