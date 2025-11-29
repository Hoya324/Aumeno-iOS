import Foundation
import SQLite3

// MARK: - Error Enum
enum DatabaseError: Error {
    case openDatabaseFailed
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case notFound
    case invalidData
    case noScheduleFound
}

// MARK: - DatabaseManager Class
final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.aumeno.database", qos: .userInitiated)
    
    private init() {
        do {
            try openDatabase()
            try createTables()
            try migrateOldTables() // Ensure migrations run after table creation
            try setupDefaultTags() // Call to setup default tags
        } catch {
            print("❌ Database initialization failed: \(error)")
            // In a real app, you would handle this error more gracefully
            fatalError("Database initialization failed: \(error)")
        }
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Setup
    private func openDatabase() throws {
        let appGroupID = "group.com.sandbox.Aumeno"
        guard let fileURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw DatabaseError.openDatabaseFailed
        }
        let dbPath = fileURL.appendingPathComponent("aumeno.sqlite").path
        
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            throw DatabaseError.openDatabaseFailed
        }
        print("✅ Unified Database opened at shared container: \(dbPath)")
    }
    
    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }
    
    private func executeSQL(_ query: String) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    private func createTables() throws {
        try dbQueue.sync {
            // Schedules Table
            try executeSQL("""
            CREATE TABLE IF NOT EXISTS schedules (
                id TEXT PRIMARY KEY, title TEXT NOT NULL, startDateTime REAL NOT NULL, endDateTime REAL, note TEXT NOT NULL DEFAULT '',
                type TEXT NOT NULL DEFAULT 'task', source TEXT NOT NULL DEFAULT 'manual', workspaceID TEXT, channelID TEXT,
                channelName TEXT, slackTimestamp TEXT, slackLink TEXT, slackMessageText TEXT, workspaceColor TEXT,
                createdAt REAL NOT NULL, notificationSent INTEGER NOT NULL DEFAULT 1, location TEXT, links TEXT,
                tagID TEXT,
                isDone INTEGER NOT NULL DEFAULT 0
            );
            """)
            
            // Tags Table
            try executeSQL("""
            CREATE TABLE IF NOT EXISTS tags (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                color TEXT NOT NULL
            );
            """)
            
            // Deleted Messages Table
            try executeSQL("CREATE TABLE IF NOT EXISTS deleted_slack_messages (slackTimestamp TEXT PRIMARY KEY, deletedAt REAL NOT NULL);")
            
            // Configurations Table
            try executeSQL("""
            CREATE TABLE IF NOT EXISTS slack_configurations (
                id TEXT PRIMARY KEY, name TEXT NOT NULL, channelName TEXT, token TEXT NOT NULL, channelID TEXT NOT NULL,
                keywords TEXT, isEnabled INTEGER NOT NULL DEFAULT 1, createdAt REAL NOT NULL,
                color TEXT NOT NULL DEFAULT '#808080', userID TEXT, teamID TEXT
            );
            """)
            print("✅ All tables created/verified")
        }
    }
    
    // MARK: - Migrations
    private func migrateOldTables() throws {
        // This is where schema migrations for existing installations would go
        // For simplicity, we'll assume new installations or completely fresh databases for now.
        // A full migration system would check existing schema versions and apply incremental changes.
        
        // Add 'tagID' column if it doesn't exist
        try dbQueue.sync {
            if try !columnExists("tagID", in: "schedules") {
                try executeSQL("ALTER TABLE schedules ADD COLUMN tagID TEXT;")
            }
            // Existing 'tag' and 'tagColor' columns can remain but will not be used by the app's model.

            // Add 'teamID' column to 'slack_configurations' if it doesn't exist
            if try !columnExists("teamID", in: "slack_configurations") {
                try executeSQL("ALTER TABLE slack_configurations ADD COLUMN teamID TEXT;")
            }
        }
    }
    
    private func columnExists(_ columnName: String, in tableName: String) throws -> Bool {
        let query = "PRAGMA table_info(\(tableName));"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed("PRAGMA query failed") }
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1), String(cString: name) == columnName { return true }
        }
        return false
    }
    
    // MARK: - Tag CRUD
    func insertTag(_ tag: Tag) throws {
        try dbQueue.sync {
            let query = "INSERT OR REPLACE INTO tags (id, name, color) VALUES (?,?,?);"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_text(statement, 1, (tag.id as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 2, (tag.name as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 3, (tag.color as NSString).utf8String, -1, transient)
            
            if sqlite3_step(statement) != SQLITE_DONE { throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db))) }
        }
    }
    
    func fetchAllTags() throws -> [Tag] {
        try dbQueue.sync {
            let query = "SELECT id, name, color FROM tags ORDER BY name ASC;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            
            var tags: [Tag] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
                      let name = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
                      let color = sqlite3_column_text(statement, 2).map({ String(cString: $0) })
                else { continue }
                
                tags.append(Tag(id: id, name: name, color: color))
            }
            return tags
        }
    }
    
    func fetchTag(id: String) throws -> Tag? {
        try dbQueue.sync {
            let query = "SELECT id, name, color FROM tags WHERE id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                guard let id = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
                      let name = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
                      let color = sqlite3_column_text(statement, 2).map({ String(cString: $0) })
                else { return nil }
                return Tag(id: id, name: name, color: color)
            }
            return nil
        }
    }
    
    func deleteTag(id: String) throws {
        try dbQueue.sync {
            let query = "DELETE FROM tags WHERE id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) != SQLITE_DONE { throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db))) }
        }
    }
    
    private func setupDefaultTags() throws {
        // Define default tags
        let defaultTags = [
            Tag(id: "default-meeting", name: "회의", color: "#007AFF"), // Blue
            Tag(id: "default-mention", name: "언급됨", color: "#FFA500")  // Orange
        ]
        
        for tag in defaultTags {
            if (try? fetchTag(id: tag.id)) == nil { // Check if tag already exists
                try insertTag(tag)
                print("✅ [DatabaseManager] Inserted default tag: \(tag.name)")
            }
        }
    }
    
    // MARK: - Schedule CRUD
    func insertSchedule(_ schedule: Schedule) throws {
        try dbQueue.sync {
            let query = "INSERT OR REPLACE INTO schedules (id, title, startDateTime, endDateTime, note, type, source, workspaceID, channelID, channelName, slackTimestamp, slackLink, slackMessageText, workspaceColor, createdAt, notificationSent, location, links, tagID, isDone) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);"
            print("  [DatabaseManager] Preparing to execute query: \(query)")
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                print("  [DatabaseManager] ❌ Failed to prepare statement: \(errorMsg)")
                throw DatabaseError.prepareFailed(errorMsg)
            }
            print("  [DatabaseManager] Statement prepared successfully.")
            
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_text(statement, 1, (schedule.id as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 2, (schedule.title as NSString).utf8String, -1, transient)
            sqlite3_bind_double(statement, 3, schedule.startDateTime.timeIntervalSince1970)
            if let endDateTime = schedule.endDateTime {
                sqlite3_bind_double(statement, 4, endDateTime.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_text(statement, 5, (schedule.note as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 6, (schedule.type.rawValue as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 7, (schedule.source.rawValue as NSString).utf8String, -1, transient)
            
            if let val = schedule.workspaceID { sqlite3_bind_text(statement, 8, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 8) }
            if let val = schedule.channelID { sqlite3_bind_text(statement, 9, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 9) }
            if let val = schedule.channelName { sqlite3_bind_text(statement, 10, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 10) }
            if let val = schedule.slackTimestamp { sqlite3_bind_text(statement, 11, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 11) }
            if let val = schedule.slackLink { sqlite3_bind_text(statement, 12, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 12) }
            if let val = schedule.slackMessageText { sqlite3_bind_text(statement, 13, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 13) }
            if let val = schedule.workspaceColor { sqlite3_bind_text(statement, 14, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 14) }
            
            sqlite3_bind_double(statement, 15, schedule.createdAt.timeIntervalSince1970)
            sqlite3_bind_int(statement, 16, schedule.notificationSent ? 1 : 0)
            
            if let val = schedule.location { sqlite3_bind_text(statement, 17, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 17) }
            
            if let links = schedule.links, let data = try? JSONEncoder().encode(links), let json = String(data: data, encoding: .utf8) {
                sqlite3_bind_text(statement, 18, (json as NSString).utf8String, -1, transient)
            } else {
                sqlite3_bind_null(statement, 18)
            }
            
            if let val = schedule.tagID { sqlite3_bind_text(statement, 19, (val as NSString).utf8String, -1, transient) } else { sqlite3_bind_null(statement, 19) }
            
            sqlite3_bind_int(statement, 20, schedule.isDone ? 1 : 0)
            
            print("  [DatabaseManager] Attempting to step statement.")
            if sqlite3_step(statement) != SQLITE_DONE {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                print("  [DatabaseManager] ❌ Failed to step statement: \(errorMsg)")
                throw DatabaseError.stepFailed(errorMsg)
            }
            print("  [DatabaseManager] ✅ Statement stepped successfully.")
        }
    }
    
    func fetchAllSchedules() throws -> [Schedule] {
        try dbQueue.sync {
            let query = "SELECT id, title, startDateTime, endDateTime, note, type, source, workspaceID, channelID, channelName, slackTimestamp, slackLink, slackMessageText, workspaceColor, createdAt, notificationSent, location, links, tagID, isDone FROM schedules ORDER BY startDateTime DESC;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            
            var schedules: [Schedule] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
                      let title = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
                      let note = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
                      let typeRaw = sqlite3_column_text(statement, 5).map({ String(cString: $0) }),
                      let sourceRaw = sqlite3_column_text(statement, 6).map({ String(cString: $0) })
                else { continue }
                
                let startDateTime = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                let endDateTime: Date? = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
                
                schedules.append(Schedule(
                    id: id, title: title,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime,
                    note: note, type: ScheduleType(rawValue: typeRaw) ?? .task,
                    source: ScheduleSource(rawValue: sourceRaw) ?? .manual,
                    workspaceID: sqlite3_column_text(statement, 7).map { String(cString: $0) },
                    channelID: sqlite3_column_text(statement, 8).map { String(cString: $0) },
                    channelName: sqlite3_column_text(statement, 9).map { String(cString: $0) },
                    slackTimestamp: sqlite3_column_text(statement, 10).map { String(cString: $0) },
                    slackLink: sqlite3_column_text(statement, 11).map { String(cString: $0) },
                    slackMessageText: sqlite3_column_text(statement, 12).map { String(cString: $0) },
                    workspaceColor: sqlite3_column_text(statement, 13).map { String(cString: $0) },
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 14)),
                    notificationSent: sqlite3_column_int(statement, 15) == 1,
                    location: sqlite3_column_text(statement, 16).map { String(cString: $0) },
                    links: (sqlite3_column_text(statement, 17).map { String(cString: $0) })
                        .flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode([String].self, from: $0) },
                    tagID: sqlite3_column_text(statement, 18).map { String(cString: $0) }, // tagID retrieval
                    isDone: sqlite3_column_int(statement, 19) == 1 // Index adjusted
                ))
            }
            return schedules
        }
    }
    
    func updateSchedule(_ schedule: Schedule) throws { try insertSchedule(schedule) }
    
    func deleteSchedule(id: String) throws {
        try dbQueue.sync {
            let query = "DELETE FROM schedules WHERE id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) != SQLITE_DONE { throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db))) }
        }
    }
    
    func scheduleExists(id: String) throws -> Bool {
        try dbQueue.sync {
            let query = "SELECT 1 FROM schedules WHERE id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            return sqlite3_step(statement) == SQLITE_ROW
        }
    }
    
    // MARK: - Configuration CRUD
    
    func insertConfiguration(_ config: SlackConfiguration) throws {
        try dbQueue.sync {
            let query = "INSERT OR REPLACE INTO slack_configurations (id, name, channelName, token, channelID, keywords, isEnabled, createdAt, color, userID, teamID) VALUES (?,?,?,?,?,?,?,?,?,?,?);"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            
            let keywordsData = try JSONEncoder().encode(config.keywords)
            let keywordsString = String(data: keywordsData, encoding: .utf8) ?? "[]"
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_text(statement, 1, (config.id as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 2, (config.name as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 3, (config.channelName as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 4, (config.token as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 5, (config.channelID as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 6, (keywordsString as NSString).utf8String, -1, transient)
            sqlite3_bind_int(statement, 7, config.isEnabled ? 1 : 0)
            sqlite3_bind_double(statement, 8, config.createdAt.timeIntervalSince1970)
            sqlite3_bind_text(statement, 9, (config.color as NSString).utf8String, -1, transient)
            
            if let userID = config.userID { sqlite3_bind_text(statement, 10, (userID as NSString).utf8String, -1, transient) }
            else { sqlite3_bind_null(statement, 10) }

            if let teamID = config.teamID { sqlite3_bind_text(statement, 11, (teamID as NSString).utf8String, -1, transient) }
            else { sqlite3_bind_null(statement, 11) }
            
            if sqlite3_step(statement) != SQLITE_DONE { throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db))) }
        } // This closes dbQueue.sync for insertConfiguration
        
    } // This closes the insertConfiguration function
    
    func fetchAllConfigurations() throws -> [SlackConfiguration] {
        try dbQueue.sync {
            let query = "SELECT * FROM slack_configurations ORDER BY createdAt DESC;"
            var statement:OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            
            var configs: [SlackConfiguration] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = sqlite3_column_text(statement, 0).map({String(cString:$0)}),
                      let name = sqlite3_column_text(statement, 1).map({String(cString:$0)}),
                      let token = sqlite3_column_text(statement, 3).map({String(cString:$0)}),
                      let channelID = sqlite3_column_text(statement, 4).map({String(cString:$0)})
                else { continue }
                
                let channelName = sqlite3_column_text(statement, 2).map{String(cString:$0)} ?? ""
                let keywordsString = sqlite3_column_text(statement, 5).map{String(cString:$0)} ?? "[]"
                let keywords = (try? JSONDecoder().decode([String].self, from: keywordsString.data(using: .utf8) ?? Data())) ?? []
                let color = sqlite3_column_text(statement, 8).map{String(cString:$0)} ?? "#808080"
                let userID = sqlite3_column_text(statement, 9).map{String(cString:$0)}
                let teamID = sqlite3_column_text(statement, 10).map{String(cString:$0)}
                
                configs.append(SlackConfiguration(id: id, name: name, channelName: channelName, token: token, channelID: channelID, keywords: keywords, isEnabled: sqlite3_column_int(statement, 6) == 1, createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)), color: color, userID: userID, teamID: teamID))
            }
            return configs
        }
    }    
    func fetchEnabledConfigurations() throws -> [SlackConfiguration] { try fetchAllConfigurations().filter{$0.isEnabled} }
    func fetchConfiguration(id:String) throws -> SlackConfiguration? { try fetchAllConfigurations().first{$0.id==id} }
    func updateConfiguration(_ config: SlackConfiguration) throws { try insertConfiguration(config) }
    func deleteConfiguration(id:String) throws { try dbQueue.sync{let q="DELETE FROM slack_configurations WHERE id=?;";var s:OpaquePointer?;defer{sqlite3_finalize(s)};if sqlite3_prepare_v2(db,q,-1,&s,nil) != SQLITE_OK{throw DatabaseError.prepareFailed(String(cString:sqlite3_errmsg(db)))};sqlite3_bind_text(s,1,(id as NSString).utf8String,-1,nil);if sqlite3_step(s) != SQLITE_DONE{throw DatabaseError.stepFailed(String(cString:sqlite3_errmsg(db)))}}}
    func hasAnyConfiguration() throws -> Bool { return !(try fetchAllConfigurations().isEmpty) }
    
    func cleanupCorruptedConfigurations() throws {
        try dbQueue.sync {
            _ = try executeSQL("DELETE FROM slack_configurations WHERE name = '' OR token = '' OR channelID = '';")
        }
    }
    
    // MARK: - Deleted Message Tracking
    func recordDeletedSlackMessage(_ slackTimestamp: String) throws {
        try dbQueue.sync {
            let query = "INSERT OR IGNORE INTO deleted_slack_messages (slackTimestamp, deletedAt) VALUES (?, ?);"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            sqlite3_bind_text(statement, 1, (slackTimestamp as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
            if sqlite3_step(statement) != SQLITE_DONE { throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db))) }
        }
    }
    
    func isDeletedSlackMessage(_ slackTimestamp: String) throws -> Bool {
        try dbQueue.sync {
            let query = "SELECT 1 FROM deleted_slack_messages WHERE slackTimestamp = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            sqlite3_bind_text(statement, 1, (slackTimestamp as NSString).utf8String, -1, nil)
            return sqlite3_step(statement) == SQLITE_ROW
        }
    }
    
    func fetchUpcomingSchedules(within minutes: Int = 5) throws -> [Schedule] {
        try dbQueue.sync {
            let now = Date().timeIntervalSince1970
            let fiveMinutesLater = Date().addingTimeInterval(TimeInterval(minutes * 60)).timeIntervalSince1970
            
            let query = """
            SELECT id, title, startDateTime, endDateTime, note, type, source, workspaceID, channelID, channelName, slackTimestamp, slackLink, slackMessageText, workspaceColor, createdAt, notificationSent, location, links, tagID, isDone
            FROM schedules
            WHERE (notificationSent = 0)
            AND startDateTime > ?
            AND startDateTime <= ?
            AND (isDone = 0)
            ORDER BY startDateTime DESC;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            
            sqlite3_bind_double(statement, 1, now)
            sqlite3_bind_double(statement, 2, fiveMinutesLater)
            
            var schedules: [Schedule] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
                      let title = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
                      let note = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
                      let typeRaw = sqlite3_column_text(statement, 5).map({ String(cString: $0) }),
                      let sourceRaw = sqlite3_column_text(statement, 6).map({ String(cString: $0) })
                else { continue }
                
                let startDateTime = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                let endDateTime: Date? = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
                
                schedules.append(Schedule(
                    id: id, title: title,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime,
                    note: note, type: ScheduleType(rawValue: typeRaw) ?? .task,
                    source: ScheduleSource(rawValue: sourceRaw) ?? .manual,
                    workspaceID: sqlite3_column_text(statement, 7).map { String(cString: $0) },
                    channelID: sqlite3_column_text(statement, 8).map { String(cString: $0) },
                    channelName: sqlite3_column_text(statement, 9).map { String(cString: $0) },
                    slackTimestamp: sqlite3_column_text(statement, 10).map { String(cString: $0) },
                    slackLink: sqlite3_column_text(statement, 11).map { String(cString: $0) },
                    slackMessageText: sqlite3_column_text(statement, 12).map { String(cString: $0) },
                    workspaceColor: sqlite3_column_text(statement, 13).map { String(cString: $0) },
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 14)),
                    notificationSent: sqlite3_column_int(statement, 15) == 1,
                    location: sqlite3_column_text(statement, 16).map { String(cString: $0) },
                    links: (sqlite3_column_text(statement, 17).map { String(cString: $0) })
                        .flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode([String].self, from: $0) },
                    tagID: sqlite3_column_text(statement, 18).map { String(cString: $0) }, // tagID retrieval (index 18)
                    isDone: sqlite3_column_int(statement, 19) == 1 // Index adjusted to 19
                ))
            }
            return schedules
        }
    }
    
    func markScheduleNotificationSent(id: String) throws {
        try dbQueue.sync {
            let query = "UPDATE schedules SET notificationSent = 1 WHERE id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) != SQLITE_DONE { throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db))) }
        }
    }
    
    func toggleScheduleDone(id: String) throws {
        try dbQueue.sync {
            let query = "UPDATE schedules SET isDone = NOT isDone WHERE id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK { throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db))) }
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) != SQLITE_DONE { throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db))) }
        }
    }
}
