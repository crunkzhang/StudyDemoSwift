import Foundation

struct BundleFileStorageState: Codable {
    var currentVersion: String
    var lastHealthyVersion: String
    var sha256: String
    var consecutiveFailures: Int
    var lastCheckTime: TimeInterval
    var deviceId: String

    static let empty = BundleFileStorageState(
        currentVersion: "",
        lastHealthyVersion: "",
        sha256: "",
        consecutiveFailures: 0,
        lastCheckTime: 0,
        deviceId: UUID().uuidString
    )
}

final class BundleFileStorage {
    private let baseDir: URL
    private let metadataURL: URL
    private(set) var state: BundleFileStorageState

    var currentDir: URL { baseDir.appendingPathComponent("current", isDirectory: true) }
    var downloadingDir: URL { baseDir.appendingPathComponent("downloading", isDirectory: true) }

    var currentBundlePath: URL? {
        let url = currentDir.appendingPathComponent("main.jsbundle")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseDir = docs.appendingPathComponent("RNBundle", isDirectory: true)
        metadataURL = baseDir.appendingPathComponent("metadata.json")

        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: metadataURL),
           let loaded = try? JSONDecoder().decode(BundleFileStorageState.self, from: data) {
            state = loaded
        } else {
            state = .empty
            save()
        }
    }
}

extension BundleFileStorage {
    func incrementFailures() {
        state.consecutiveFailures += 1
        save()
    }

    func markHealthy() {
        state.consecutiveFailures = 0
        state.lastHealthyVersion = state.currentVersion
        save()
    }

    func updateCheckTime() {
        state.lastCheckTime = Date().timeIntervalSince1970
        save()
    }

    func shouldRollback() -> Bool {
        state.consecutiveFailures >= 3 && !state.currentVersion.isEmpty
    }

    func performRollback() {
        let bundlePath = currentDir.appendingPathComponent("main.jsbundle")
        try? FileManager.default.removeItem(at: bundlePath)
        state.currentVersion = ""
        state.sha256 = ""
        state.consecutiveFailures = 0
        save()
    }

    func install(tempFile: URL, version: String, sha256: String) throws {
        try FileManager.default.createDirectory(at: currentDir, withIntermediateDirectories: true)
        let destPath = currentDir.appendingPathComponent("main.jsbundle")
        if FileManager.default.fileExists(atPath: destPath.path) {
            try FileManager.default.removeItem(at: destPath)
        }
        try FileManager.default.moveItem(at: tempFile, to: destPath)

        state.currentVersion = version
        state.sha256 = sha256
        state.consecutiveFailures = 0
        save()
    }
}

// MARK: - Private

private extension BundleFileStorage {
    func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}
