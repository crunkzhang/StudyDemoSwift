import Foundation
import WCDBSwift

public final class SessionDB {
    private let db: Database
    private let table = "sessions"

    public init(userId: String) {
        let path = DBPaths.sessionDBPath(userId: userId)
        self.db = Database(at: path)
        try? db.create(table: table, of: SessionModel.self)
    }

    // MARK: - Read

    public func fetchAll() -> [SessionModel] {
        (try? db.getObjects(fromTable: table)) ?? []
    }

    public func fetch(sessionIds: [String]) -> [SessionModel] {
        guard !sessionIds.isEmpty else { return [] }
        return (try? db.getObjects(
            fromTable: table,
            where: SessionModel.Properties.sessionId.in(sessionIds)
        )) ?? []
    }

    // MARK: - Write (在事务内调用)

    public func upsert(_ sessions: [SessionModel]) throws {
        try db.insertOrReplace(sessions, intoTable: table)
    }

    public func delete(sessionIds: [String]) throws {
        try db.delete(
            fromTable: table,
            where: SessionModel.Properties.sessionId.in(sessionIds)
        )
    }

    // MARK: - Transaction

    public func runTransaction(_ block: @escaping () throws -> Void) throws {
        try db.run(transaction: { _ in
            try block()
        })
    }
}
