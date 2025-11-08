//
//  SQLiteStorage.swift
//  SwiftAgent
//
//  SQLite 持久化存储
//

import Foundation
import SQLite3

// MARK: - SQLite Storage

/// SQLite 持久化存储
public final class SQLiteStorage: @unchecked Sendable {
    private let dbPath: String
    private var db: OpaquePointer?
    private let currentVersion: Int = 1
    private let queue = DispatchQueue(label: "com.swiftagent.sqlite", qos: .userInitiated)
    
    public init(dbPath: String? = nil) throws {
        // 默认使用 Documents 目录
        if let customPath = dbPath {
            self.dbPath = customPath
        } else {
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.dbPath = documentsPath.appendingPathComponent("swiftagent.db").path
        }
        
        try openDatabase()
        try createTables()
        try performMigrations()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Management
    
    private func openDatabase() throws {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw SQLiteError.cannotOpenDatabase(message: String(cString: sqlite3_errmsg(db)))
        }
    }
    
    private func closeDatabase() {
        sqlite3_close(db)
    }
    
    private func createTables() throws {
        // 版本表
        try execute("""
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        )
        """)
        
        // 记忆表
        try execute("""
        CREATE TABLE IF NOT EXISTS memories (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            metadata TEXT,
            embedding TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """)
        
        // 消息历史表
        try execute("""
        CREATE TABLE IF NOT EXISTS message_history (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            tool_call_id TEXT,
            created_at TEXT NOT NULL
        )
        """)
        
        // 会话表
        try execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            agent_name TEXT NOT NULL,
            system_prompt TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            metadata TEXT
        )
        """)
        
        // 创建索引
        try execute("CREATE INDEX IF NOT EXISTS idx_memories_created ON memories(created_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_messages_session ON message_history(session_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_messages_created ON message_history(created_at)")
    }
    
    private func performMigrations() throws {
        let version = try getCurrentVersion()
        
        if version < currentVersion {
            // 执行迁移
            for v in (version + 1)...currentVersion {
                try migrate(to: v)
            }
        }
    }
    
    private func getCurrentVersion() throws -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        let query = "SELECT MAX(version) FROM schema_version"
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let version = sqlite3_column_int(statement, 0)
            return Int(version)
        }
        
        return 0
    }
    
    private func migrate(to version: Int) throws {
        switch version {
        case 1:
            // 初始版本，无需迁移
            break
        default:
            break
        }
        
        // 记录版本
        try execute("""
        INSERT INTO schema_version (version, applied_at)
        VALUES (\(version), '\(ISO8601DateFormatter().string(from: Date()))')
        """)
    }
    
    // MARK: - Execute SQL
    
    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let errorMessage = error.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(error)
            throw SQLiteError.executionFailed(message: errorMessage)
        }
    }
    
    // MARK: - Memory Operations
    
    /// 保存记忆
    public func saveMemory(_ entry: MemoryEntry) throws {
        let sql = """
        INSERT OR REPLACE INTO memories (id, content, metadata, embedding, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        let idString = entry.id.uuidString
        
        sqlite3_bind_text(statement, 1, idString, -1, nil)
        sqlite3_bind_text(statement, 2, entry.content, -1, nil)
        
        if !entry.metadata.isEmpty {
            let metadataJSON = try? JSONSerialization.data(withJSONObject: entry.metadata)
            let metadataString = metadataJSON.flatMap { String(data: $0, encoding: .utf8) }
            sqlite3_bind_text(statement, 3, metadataString, -1, nil)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        
        if let embedding = entry.embedding {
            let embeddingJSON = try? JSONEncoder().encode(embedding)
            let embeddingString = embeddingJSON.flatMap { String(data: $0, encoding: .utf8) }
            sqlite3_bind_text(statement, 4, embeddingString, -1, nil)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        
        sqlite3_bind_text(statement, 5, now, -1, nil)
        sqlite3_bind_text(statement, 6, now, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(message: "Failed to insert memory")
        }
    }
    
    /// 获取记忆
    public func getMemory(id: UUID) throws -> MemoryEntry? {
        let sql = "SELECT id, content, metadata, embedding, created_at FROM memories WHERE id = ?"
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        let idString = id.uuidString
        sqlite3_bind_text(statement, 1, idString, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        
        return try parseMemoryEntry(from: statement)
    }
    
    /// 搜索记忆
    public func searchMemories(query: String, limit: Int = 10) throws -> [MemoryEntry] {
        let sql = """
        SELECT id, content, metadata, embedding, created_at
        FROM memories
        WHERE content LIKE ?
        ORDER BY created_at DESC
        LIMIT ?
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        let searchQuery = "%\(query)%"
        sqlite3_bind_text(statement, 1, searchQuery, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        var results: [MemoryEntry] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let entry = try? parseMemoryEntry(from: statement) {
                results.append(entry)
            }
        }
        
        return results
    }
    
    /// 获取所有记忆
    public func getAllMemories(limit: Int = 100) throws -> [MemoryEntry] {
        let sql = """
        SELECT id, content, metadata, embedding, created_at
        FROM memories
        ORDER BY created_at DESC
        LIMIT ?
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        sqlite3_bind_int(statement, 1, Int32(limit))
        
        var results: [MemoryEntry] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let entry = try? parseMemoryEntry(from: statement) {
                results.append(entry)
            }
        }
        
        return results
    }
    
    /// 删除记忆
    public func deleteMemory(id: UUID) throws {
        let sql = "DELETE FROM memories WHERE id = ?"
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        let idString = id.uuidString
        sqlite3_bind_text(statement, 1, idString, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(message: "Failed to delete memory")
        }
    }
    
    /// 获取记忆数量
    public func getMemoryCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM memories"
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        
        return 0
    }
    
    // MARK: - Message History Operations
    
    /// 保存消息
    public func saveMessage(sessionId: String, message: LLMMessage) throws {
        let sql = """
        INSERT INTO message_history (id, session_id, role, content, tool_call_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        let id = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        
        sqlite3_bind_text(statement, 1, id, -1, nil)
        sqlite3_bind_text(statement, 2, sessionId, -1, nil)
        sqlite3_bind_text(statement, 3, message.role.rawValue, -1, nil)
        sqlite3_bind_text(statement, 4, message.content, -1, nil)
        
        if let toolCallId = message.toolCallId {
            sqlite3_bind_text(statement, 5, toolCallId, -1, nil)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        sqlite3_bind_text(statement, 6, now, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(message: "Failed to insert message")
        }
    }
    
    /// 获取会话消息
    public func getMessages(sessionId: String, limit: Int = 100) throws -> [LLMMessage] {
        let sql = """
        SELECT role, content, tool_call_id
        FROM message_history
        WHERE session_id = ?
        ORDER BY created_at ASC
        LIMIT ?
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        sqlite3_bind_text(statement, 1, sessionId, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        var messages: [LLMMessage] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let message = parseMessage(from: statement) {
                messages.append(message)
            }
        }
        
        return messages
    }
    
    // MARK: - Session Operations
    
    /// 创建会话
    public func createSession(agentName: String, systemPrompt: String?) throws -> String {
        let sessionId = UUID().uuidString
        let sql = """
        INSERT INTO sessions (id, agent_name, system_prompt, created_at, updated_at, metadata)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        
        sqlite3_bind_text(statement, 1, sessionId, -1, nil)
        sqlite3_bind_text(statement, 2, agentName, -1, nil)
        
        if let prompt = systemPrompt {
            sqlite3_bind_text(statement, 3, prompt, -1, nil)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        
        sqlite3_bind_text(statement, 4, now, -1, nil)
        sqlite3_bind_text(statement, 5, now, -1, nil)
        sqlite3_bind_null(statement, 6)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(message: "Failed to create session")
        }
        
        return sessionId
    }
    
    // MARK: - Helper Methods
    
    private func parseMemoryEntry(from statement: OpaquePointer?) throws -> MemoryEntry {
        guard let statement = statement else {
            throw SQLiteError.invalidData
        }
        
        let idString = String(cString: sqlite3_column_text(statement, 0))
        guard let id = UUID(uuidString: idString) else {
            throw SQLiteError.invalidData
        }
        let content = String(cString: sqlite3_column_text(statement, 1))
        
        var metadata: [String: String] = [:]
        if let metadataText = sqlite3_column_text(statement, 2) {
            let metadataString = String(cString: metadataText)
            if let data = metadataString.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                metadata = dict
            }
        }
        
        var embedding: [Double]?
        if let embeddingText = sqlite3_column_text(statement, 3) {
            let embeddingString = String(cString: embeddingText)
            if let data = embeddingString.data(using: .utf8),
               let array = try? JSONDecoder().decode([Double].self, from: data) {
                embedding = array
            }
        }
        
        var timestamp = Date()
        if let createdText = sqlite3_column_text(statement, 4) {
            let dateString = String(cString: createdText)
            if let date = ISO8601DateFormatter().date(from: dateString) {
                timestamp = date
            }
        }
        
        return MemoryEntry(id: id, content: content, timestamp: timestamp, metadata: metadata, embedding: embedding)
    }
    
    private func parseMessage(from statement: OpaquePointer?) -> LLMMessage? {
        guard let statement = statement else { return nil }
        
        let roleString = String(cString: sqlite3_column_text(statement, 0))
        let content = String(cString: sqlite3_column_text(statement, 1))
        
        var toolCallId: String?
        if let toolCallText = sqlite3_column_text(statement, 2) {
            toolCallId = String(cString: toolCallText)
        }
        
        guard let role = MessageRole(rawValue: roleString) else {
            return nil
        }
        
        return LLMMessage(role: role, content: content, toolCallId: toolCallId)
    }
}

// MARK: - SQLite Error

public enum SQLiteError: Error, LocalizedError {
    case cannotOpenDatabase(message: String)
    case prepareFailed
    case executionFailed(message: String)
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .cannotOpenDatabase(let message):
            return "无法打开数据库：\(message)"
        case .prepareFailed:
            return "SQL 准备失败"
        case .executionFailed(let message):
            return "SQL 执行失败：\(message)"
        case .invalidData:
            return "无效的数据格式"
        }
    }
}

