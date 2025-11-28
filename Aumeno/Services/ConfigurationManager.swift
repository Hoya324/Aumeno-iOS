//
//  ConfigurationManager.swift
//  Aumeno
//
//  Created by Claude Code
//

import Foundation
import SQLite3

enum ConfigurationError: Error {
    case databaseError(String)
    case notFound
    case invalidData
}

final class ConfigurationManager {
    static let shared = ConfigurationManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.aumeno.configuration", qos: .userInitiated)

    private init() {
        do {
            try openDatabase()
            try createConfigurationTable()
        } catch {
            print("❌ Failed to initialize ConfigurationManager: \(error)")
        }
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Setup

    private func openDatabase() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let dbDirectory = appSupportURL.appendingPathComponent("Aumeno")
        try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

        let dbPath = dbDirectory.appendingPathComponent("aumeno.sqlite").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw ConfigurationError.databaseError("Failed to open database")
        }

        print("✅ ConfigurationManager database opened at: \(dbPath)")
    }

    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    private func createConfigurationTable() throws {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS slack_configurations (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            channelName TEXT,
            token TEXT NOT NULL,
            channelID TEXT NOT NULL,
            keywords TEXT,
            isEnabled INTEGER NOT NULL DEFAULT 1,
            createdAt REAL NOT NULL
        );
        """

        try dbQueue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, createTableQuery, -1, &statement, nil) != SQLITE_OK {
                throw ConfigurationError.databaseError("Failed to prepare create table statement")
            }

            if sqlite3_step(statement) != SQLITE_DONE {
                throw ConfigurationError.databaseError("Failed to create configurations table")
            }
        }

        // Migration: Add channelName column if it doesn't exist
        try migrateAddChannelName()

        print("✅ Slack configurations table ready")
    }

    private func migrateAddChannelName() throws {
        let checkColumnQuery = "PRAGMA table_info(slack_configurations);"
        var hasChannelName = false

        try dbQueue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, checkColumnQuery, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let columnName = sqlite3_column_text(statement, 1) {
                        if String(cString: columnName) == "channelName" {
                            hasChannelName = true
                            break
                        }
                    }
                }
            }

            if !hasChannelName {
                print("📦 Migrating: Adding channelName column...")
                let alterQuery = "ALTER TABLE slack_configurations ADD COLUMN channelName TEXT DEFAULT '';"
                var alterStatement: OpaquePointer?
                defer { sqlite3_finalize(alterStatement) }

                if sqlite3_prepare_v2(db, alterQuery, -1, &alterStatement, nil) != SQLITE_OK {
                    throw ConfigurationError.databaseError("Failed to prepare alter table statement")
                }

                if sqlite3_step(alterStatement) != SQLITE_DONE {
                    throw ConfigurationError.databaseError("Failed to add channelName column")
                }

                print("✅ Migration complete: channelName column added")
            }
        }
    }

    // MARK: - CRUD Operations

    func insertConfiguration(_ config: SlackConfiguration) throws {
        try dbQueue.sync {
            let insertQuery = """
            INSERT OR REPLACE INTO slack_configurations (id, name, channelName, token, channelID, keywords, isEnabled, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw ConfigurationError.databaseError("Failed to prepare insert statement: \(error)")
            }

            let keywordsJSON = try JSONEncoder().encode(config.keywords)
            let keywordsString = String(data: keywordsJSON, encoding: .utf8) ?? "[]"

            // Use SQLITE_TRANSIENT to make SQLite copy the strings
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            sqlite3_bind_text(statement, 1, (config.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, (config.name as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, (config.channelName as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, (config.token as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, (config.channelID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 6, (keywordsString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 7, config.isEnabled ? 1 : 0)
            sqlite3_bind_double(statement, 8, config.createdAt.timeIntervalSince1970)

            print("📝 Inserting configuration:")
            print("   ID: \(config.id)")
            print("   Workspace: \(config.name)")
            print("   Channel: \(config.channelName)")
            print("   Token: \(config.token.prefix(20))...")
            print("   Channel ID: \(config.channelID)")
            print("   Keywords: \(config.keywords)")

            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                throw ConfigurationError.databaseError("Failed to insert configuration: \(error)")
            }

            print("✅ Configuration inserted successfully")
        }
    }

    func fetchAllConfigurations() throws -> [SlackConfiguration] {
        try dbQueue.sync {
            let selectQuery = "SELECT * FROM slack_configurations ORDER BY createdAt DESC;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, selectQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw ConfigurationError.databaseError("Failed to prepare select statement: \(error)")
            }

            var configurations: [SlackConfiguration] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                // Safely extract strings with NULL checks
                guard let idText = sqlite3_column_text(statement, 0),
                      let nameText = sqlite3_column_text(statement, 1) else {
                    print("⚠️ Skipping row with NULL id or name")
                    continue
                }

                let id = String(cString: idText)
                let name = String(cString: nameText)

                // channelName might be NULL for legacy data
                let channelName: String
                if let channelNameText = sqlite3_column_text(statement, 2) {
                    channelName = String(cString: channelNameText)
                } else {
                    channelName = "" // Default to empty for migration
                }

                guard let tokenText = sqlite3_column_text(statement, 3),
                      let channelText = sqlite3_column_text(statement, 4) else {
                    print("⚠️ Skipping row with NULL token or channelID")
                    continue
                }

                let token = String(cString: tokenText)
                let channelID = String(cString: channelText)

                let keywordsString: String
                if let keywordsText = sqlite3_column_text(statement, 5) {
                    keywordsString = String(cString: keywordsText)
                } else {
                    keywordsString = "[]"
                }

                let isEnabled = sqlite3_column_int(statement, 6) == 1
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))

                let keywords: [String]
                if let keywordsData = keywordsString.data(using: .utf8),
                   let decodedKeywords = try? JSONDecoder().decode([String].self, from: keywordsData) {
                    keywords = decodedKeywords
                } else {
                    keywords = []
                }

                let config = SlackConfiguration(
                    id: id,
                    name: name,
                    channelName: channelName,
                    token: token,
                    channelID: channelID,
                    keywords: keywords,
                    isEnabled: isEnabled,
                    createdAt: createdAt
                )

                print("📖 Loaded configuration: \(name) / \(channelName) with \(keywords.count) keywords")

                configurations.append(config)
            }

            print("✅ Fetched \(configurations.count) configuration(s) from database")
            return configurations
        }
    }

    func fetchEnabledConfigurations() throws -> [SlackConfiguration] {
        try fetchAllConfigurations().filter { $0.isEnabled }
    }

    func fetchConfiguration(id: String) throws -> SlackConfiguration? {
        try fetchAllConfigurations().first { $0.id == id }
    }

    func updateConfiguration(_ config: SlackConfiguration) throws {
        try insertConfiguration(config) // INSERT OR REPLACE
    }

    func deleteConfiguration(id: String) throws {
        try dbQueue.sync {
            let deleteQuery = "DELETE FROM slack_configurations WHERE id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw ConfigurationError.databaseError("Failed to prepare delete statement: \(error)")
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)

            print("🗑️ Deleting configuration with ID: \(id)")

            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                throw ConfigurationError.databaseError("Failed to delete configuration: \(error)")
            }

            print("✅ Configuration deleted successfully")
        }
    }

    func configurationExists(id: String) throws -> Bool {
        try fetchConfiguration(id: id) != nil
    }

    func hasAnyConfiguration() throws -> Bool {
        return !(try fetchAllConfigurations().isEmpty)
    }

    // MARK: - Database Maintenance

    /// Clean up corrupted configurations (empty names, tokens, or channel IDs)
    func cleanupCorruptedConfigurations() throws {
        print("🧹 Cleaning up corrupted configurations...")

        let allConfigs = try fetchAllConfigurations()
        var deletedCount = 0

        for config in allConfigs {
            if config.name.isEmpty || config.token.isEmpty || config.channelID.isEmpty {
                print("   🗑️ Removing corrupted config: ID=\(config.id.prefix(8)), name='\(config.name)', token='\(config.token.prefix(10))'")
                try deleteConfiguration(id: config.id)
                deletedCount += 1
            }
        }

        print("✅ Cleanup complete: removed \(deletedCount) corrupted configuration(s)")
    }

    /// Completely reset the database (delete all configurations)
    func resetDatabase() throws {
        print("🔄 Resetting database...")

        try dbQueue.sync {
            let deleteAllQuery = "DELETE FROM slack_configurations;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, deleteAllQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw ConfigurationError.databaseError("Failed to prepare reset statement: \(error)")
            }

            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                throw ConfigurationError.databaseError("Failed to reset database: \(error)")
            }
        }

        print("✅ Database reset complete")
    }
}
