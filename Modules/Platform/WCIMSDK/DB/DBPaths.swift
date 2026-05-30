import Foundation

/// IM 物理库按 userId 隔离 — Documents/IM/{userId}/{session,message}.db
public enum DBPaths {

    public static func userIMDirectory(userId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("IM/\(userId)", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public static func sessionDBPath(userId: String) -> String {
        userIMDirectory(userId: userId).appendingPathComponent("session.db").path
    }

    public static func messageDBPath(userId: String) -> String {
        userIMDirectory(userId: userId).appendingPathComponent("message.db").path
    }
}
