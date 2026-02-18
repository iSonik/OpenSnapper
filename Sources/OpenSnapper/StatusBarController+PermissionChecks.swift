import CoreGraphics
import Foundation
import SQLite3

extension StatusBarController {
    private enum ScreenCapturePermissionCacheDefaults {
        static let ttlSeconds: TimeInterval = 0.75
    }

    var hasScreenCapturePermission: Bool {
        if
            let cached = cachedScreenCapturePermission,
            let cachedAt = cachedScreenCapturePermissionAt,
            Date().timeIntervalSince(cachedAt) <= ScreenCapturePermissionCacheDefaults.ttlSeconds
        {
            return cached
        }
        let resolved = resolveScreenCapturePermission()
        cachedScreenCapturePermission = resolved
        cachedScreenCapturePermissionAt = Date()
        return resolved
    }

    func invalidateScreenCapturePermissionCache() {
        cachedScreenCapturePermission = nil
        cachedScreenCapturePermissionAt = nil
    }

    private func resolveScreenCapturePermission() -> Bool {
        if let tccAuthorized = tccScreenCaptureAuthorized() {
            return tccAuthorized
        }
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    private func tccScreenCaptureAuthorized() -> Bool? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let dbPaths = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
        ]

        for path in dbPaths {
            if let authValue = tccAuthValue(dbPath: path, bundleID: bundleID) {
                return authValue == 2
            }
        }
        return nil
    }

    private func tccAuthValue(dbPath: String, bundleID: String) -> Int32? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT auth_value
        FROM access
        WHERE service = 'kTCCServiceScreenCapture'
          AND client = ?
        ORDER BY last_modified DESC
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bundleID, -1, sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        return sqlite3_column_int(statement, 0)
    }
}
