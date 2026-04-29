import Foundation

public final class CatonDiskStore: CatonStorable {

    private let directory: URL
    private let queue = DispatchQueue(label: "CatonMonitorKit.DiskStore")
    private let maxEvents: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(maxEvents: Int = 200) {
        self.maxEvents = maxEvents
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("CatonMonitorKit", isDirectory: true)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save(_ event: CatonEvent) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.directory.appendingPathComponent("\(event.id.uuidString).json")
            if let data = try? self.encoder.encode(event) {
                try? data.write(to: fileURL, options: .atomic)
            }
            self.trimIfNeeded()
        }
    }

    public func loadAll() -> [CatonEvent] {
        return queue.sync {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            ) else { return [] }

            return files
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> CatonEvent? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return try? decoder.decode(CatonEvent.self, from: data)
                }
                .sorted { $0.timestamp < $1.timestamp }
        }
    }

    public func remove(ids: [UUID]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            for id in ids {
                let fileURL = self.directory.appendingPathComponent("\(id.uuidString).json")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    public func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let files = try? FileManager.default.contentsOfDirectory(
                at: self.directory, includingPropertiesForKeys: nil
            ) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - 清理

    private func trimIfNeeded() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        if jsonFiles.count > maxEvents {
            let sorted = jsonFiles.sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return dateA < dateB
            }
            let toDelete = sorted.prefix(jsonFiles.count - maxEvents)
            for file in toDelete {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
