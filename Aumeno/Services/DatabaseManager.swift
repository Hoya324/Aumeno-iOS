//
//  DatabaseManager.swift
//  Aumeno
//
//  Created by Claude Code
//

import Foundation
import SQLite3

enum DatabaseError: Error {
    case openDatabaseFailed
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
}

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.aumeno.database", qos: .userInitiated)

    private init() {
        do {
            try openDatabase()
            try createTable()
        } catch {
            print("❌ Database initialization failed: \(error)")
        }
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Setup

    private func openDatabase() throws {
        let fileURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Aumeno")

        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)

        let dbPath = fileURL.appendingPathComponent("aumeno.sqlite").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw DatabaseError.openDatabaseFailed
        }

        print("✅ Database opened at: \(dbPath)")
    }

    private func createTable() throws {
        // 새로운 스키마로 테이블 생성
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS meetings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            scheduledTime REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL DEFAULT 'manual',
            slackConfigID TEXT,
            slackTimestamp TEXT,
            createdAt REAL NOT NULL,
            notificationSent INTEGER NOT NULL DEFAULT 0,
            location TEXT,
            notionLink TEXT
        );
        """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, createTableQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(error)
        }

        defer {
            sqlite3_finalize(statement)
        }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.stepFailed(error)
        }

        // 삭제된 Slack 메시지 추적 테이블
        let createDeletedTableQuery = """
        CREATE TABLE IF NOT EXISTS deleted_slack_messages (
            slackTimestamp TEXT PRIMARY KEY,
            deletedAt REAL NOT NULL
        );
        """

        var deletedStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createDeletedTableQuery, -1, &deletedStatement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(error)
        }

        defer {
            sqlite3_finalize(deletedStatement)
        }

        if sqlite3_step(deletedStatement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.stepFailed(error)
        }

        // 기존 테이블이 있다면 마이그레이션
        try migrateOldSchemaIfNeeded()

        print("✅ Table created/verified")
    }

    // 기존 스키마에서 새 스키마로 마이그레이션
    private func migrateOldSchemaIfNeeded() throws {
        // Check if all required columns exist
        let pragmaQuery = "PRAGMA table_info(meetings);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, pragmaQuery, -1, &statement, nil) != SQLITE_OK {
            return // 마이그레이션 불필요
        }

        defer {
            sqlite3_finalize(statement)
        }

        var hasScheduledTime = false
        var hasLocation = false
        var hasNotionLink = false

        while sqlite3_step(statement) == SQLITE_ROW {
            let columnName = String(cString: sqlite3_column_text(statement, 1))
            if columnName == "scheduledTime" {
                hasScheduledTime = true
            } else if columnName == "location" {
                hasLocation = true
            } else if columnName == "notionLink" {
                hasNotionLink = true
            }
        }

        // 마이그레이션이 필요하면 실행
        if !hasScheduledTime {
            try performMigration()
        } else if !hasLocation || !hasNotionLink {
            // Add missing columns
            try addMissingColumns(hasLocation: hasLocation, hasNotionLink: hasNotionLink)
        }
    }

    private func performMigration() throws {
        print("🔄 Migrating database schema...")

        // 1. 백업 테이블 생성
        let backupQuery = "ALTER TABLE meetings RENAME TO meetings_old;"
        try executeSQL(backupQuery)

        // 2. 새 테이블 생성
        let createNewTable = """
        CREATE TABLE meetings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            scheduledTime REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL DEFAULT 'slack',
            slackConfigID TEXT,
            slackTimestamp TEXT,
            createdAt REAL NOT NULL,
            notificationSent INTEGER NOT NULL DEFAULT 0,
            location TEXT,
            notionLink TEXT
        );
        """
        try executeSQL(createNewTable)

        // 3. 데이터 복사 (기존 데이터는 모두 Slack 출처로 간주)
        let copyData = """
        INSERT INTO meetings (id, title, scheduledTime, note, source, slackTimestamp, createdAt, notificationSent)
        SELECT id, title, startTime, note, 'slack', id, startTime, 0 FROM meetings_old;
        """
        try executeSQL(copyData)

        // 4. 백업 테이블 삭제
        try executeSQL("DROP TABLE meetings_old;")

        print("✅ Migration completed")
    }

    // Add missing columns to existing table
    private func addMissingColumns(hasLocation: Bool, hasNotionLink: Bool) throws {
        print("🔄 Adding missing columns to database...")

        if !hasLocation {
            try executeSQL("ALTER TABLE meetings ADD COLUMN location TEXT;")
            print("✅ Added location column")
        }

        if !hasNotionLink {
            try executeSQL("ALTER TABLE meetings ADD COLUMN notionLink TEXT;")
            print("✅ Added notionLink column")
        }
    }

    private func executeSQL(_ query: String) throws {
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(error)
        }

        defer {
            sqlite3_finalize(statement)
        }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.stepFailed(error)
        }
    }

    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("❌ Failed to close database")
        }
        db = nil
    }

    // MARK: - CRUD Operations

    func insertMeeting(_ meeting: Meeting) throws {
        try dbQueue.sync {
            let insertQuery = """
            INSERT OR REPLACE INTO meetings (
                id, title, scheduledTime, note, source,
                slackConfigID, slackTimestamp, createdAt, notificationSent,
                location, notionLink
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.prepareFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Use SQLITE_TRANSIENT for string safety
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            // Bind parameters
            sqlite3_bind_text(statement, 1, (meeting.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, (meeting.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 3, meeting.scheduledTime.timeIntervalSince1970)
            sqlite3_bind_text(statement, 4, (meeting.note as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, (meeting.source.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)

            if let slackConfigID = meeting.slackConfigID {
                sqlite3_bind_text(statement, 6, (slackConfigID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 6)
            }

            if let slackTimestamp = meeting.slackTimestamp {
                sqlite3_bind_text(statement, 7, (slackTimestamp as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 7)
            }

            sqlite3_bind_double(statement, 8, meeting.createdAt.timeIntervalSince1970)
            sqlite3_bind_int(statement, 9, meeting.notificationSent ? 1 : 0)

            if let location = meeting.location {
                sqlite3_bind_text(statement, 10, (location as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 10)
            }

            if let notionLink = meeting.notionLink {
                sqlite3_bind_text(statement, 11, (notionLink as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 11)
            }

            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.stepFailed(error)
            }
        }
    }

    func fetchAllMeetings() throws -> [Meeting] {
        try dbQueue.sync {
            let query = """
            SELECT id, title, scheduledTime, note, source,
                   slackConfigID, slackTimestamp, createdAt, notificationSent,
                   location, notionLink
            FROM meetings ORDER BY scheduledTime DESC;
            """

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.prepareFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            var meetings: [Meeting] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let scheduledTime = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                let note = String(cString: sqlite3_column_text(statement, 3))
                let sourceString = String(cString: sqlite3_column_text(statement, 4))
                let source = MeetingSource(rawValue: sourceString) ?? .manual

                let slackConfigID: String? = if let text = sqlite3_column_text(statement, 5) {
                    String(cString: text)
                } else {
                    nil
                }

                let slackTimestamp: String? = if let text = sqlite3_column_text(statement, 6) {
                    String(cString: text)
                } else {
                    nil
                }

                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
                let notificationSent = sqlite3_column_int(statement, 8) == 1

                let location: String? = if let text = sqlite3_column_text(statement, 9) {
                    String(cString: text)
                } else {
                    nil
                }

                let notionLink: String? = if let text = sqlite3_column_text(statement, 10) {
                    String(cString: text)
                } else {
                    nil
                }

                let meeting = Meeting(
                    id: id,
                    title: title,
                    scheduledTime: scheduledTime,
                    note: note,
                    source: source,
                    slackConfigID: slackConfigID,
                    slackTimestamp: slackTimestamp,
                    createdAt: createdAt,
                    notificationSent: notificationSent,
                    location: location,
                    notionLink: notionLink
                )
                meetings.append(meeting)
            }

            return meetings
        }
    }

    func updateMeetingNote(id: String, note: String) throws {
        try dbQueue.sync {
            let updateQuery = "UPDATE meetings SET note = ? WHERE id = ?;"

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.prepareFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            sqlite3_bind_text(statement, 1, (note as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (id as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.stepFailed(error)
            }
        }
    }

    func deleteMeeting(id: String) throws {
        try dbQueue.sync {
            // First, check if this is a Slack meeting
            let checkQuery = "SELECT slackTimestamp FROM meetings WHERE id = ?;"
            var checkStatement: OpaquePointer?

            if sqlite3_prepare_v2(db, checkQuery, -1, &checkStatement, nil) == SQLITE_OK {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(checkStatement, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)

                if sqlite3_step(checkStatement) == SQLITE_ROW,
                   let slackTimestampText = sqlite3_column_text(checkStatement, 0) {
                    let slackTimestamp = String(cString: slackTimestampText)

                    // Record as deleted Slack message
                    try recordDeletedSlackMessage(slackTimestamp)
                    print("📝 Recorded deleted Slack message: \(slackTimestamp)")
                }
                sqlite3_finalize(checkStatement)
            }

            // Delete the meeting
            let deleteQuery = "DELETE FROM meetings WHERE id = ?;"
            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.prepareFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)

            print("🗑️ Executing DELETE FROM meetings WHERE id = '\(id)'")

            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                print("❌ Failed to delete meeting from database: \(error)")
                throw DatabaseError.stepFailed(error)
            }

            let rowsAffected = sqlite3_changes(db)
            print("✅ Database deletion successful: \(rowsAffected) row(s) affected for id '\(id)'")
        }
    }

    // 삭제된 Slack 메시지 기록
    private func recordDeletedSlackMessage(_ slackTimestamp: String) throws {
        let insertQuery = "INSERT OR IGNORE INTO deleted_slack_messages (slackTimestamp, deletedAt) VALUES (?, ?);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(error)
        }

        defer {
            sqlite3_finalize(statement)
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (slackTimestamp as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.stepFailed(error)
        }
    }

    // 삭제된 Slack 메시지인지 확인
    func isDeletedSlackMessage(_ slackTimestamp: String) throws -> Bool {
        try dbQueue.sync {
            let query = "SELECT COUNT(*) FROM deleted_slack_messages WHERE slackTimestamp = ?;"
            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.prepareFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, (slackTimestamp as NSString).utf8String, -1, SQLITE_TRANSIENT)

            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                return count > 0
            }

            return false
        }
    }

    func meetingExists(id: String) throws -> Bool {
        try dbQueue.sync {
            let query = "SELECT COUNT(*) FROM meetings WHERE id = ?;"

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.prepareFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                return count > 0
            }

            return false
        }
    }

    // 회의 업데이트 (전체 객체)
    func updateMeeting(_ meeting: Meeting) throws {
        try insertMeeting(meeting) // INSERT OR REPLACE
    }

    // 알림 전송 플래그 업데이트
    func markNotificationSent(id: String) throws {
        try dbQueue.sync {
            let updateQuery = "UPDATE meetings SET notificationSent = 1 WHERE id = ?;"

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.prepareFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.stepFailed(error)
            }
        }
    }

    // 예정된 회의 가져오기 (알림 미전송 + 시간 임박)
    func fetchUpcomingMeetings(within minutes: Int = 5) throws -> [Meeting] {
        let now = Date()
        let futureTime = now.addingTimeInterval(TimeInterval(minutes * 60))

        return try fetchAllMeetings().filter { meeting in
            !meeting.notificationSent &&
            meeting.scheduledTime > now &&
            meeting.scheduledTime <= futureTime
        }
    }
}
