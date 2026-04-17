import Foundation

final class BundleDownloader {
    enum DownloadError: Error {
        case networkError(Error)
        case sha256Mismatch(expected: String, actual: String)
        case fileError(Error)
    }

    private let store: BundleFileStorage

    init(store: BundleFileStorage) {
        self.store = store
    }
}

extension BundleDownloader {
    func download(bundle: BundleInfo, version: String, completion: @escaping (Result<Void, DownloadError>) -> Void) {
        guard let url = URL(string: bundle.url) else {
            completion(.failure(.networkError(
                NSError(domain: "BundleDownloader", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            )))
            return
        }

        let downloadingDir = store.downloadingDir
        try? FileManager.default.createDirectory(at: downloadingDir, withIntermediateDirectories: true)
        let tmpPath = downloadingDir.appendingPathComponent("main.jsbundle.tmp")

        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self else { return }

            if let error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let tempURL else {
                completion(.failure(.networkError(
                    NSError(domain: "BundleDownloader", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "No temp file"])
                )))
                return
            }

            do {
                if FileManager.default.fileExists(atPath: tmpPath.path) {
                    try FileManager.default.removeItem(at: tmpPath)
                }
                try FileManager.default.moveItem(at: tempURL, to: tmpPath)

                let actualHash = self.sha256(of: tmpPath)
                guard actualHash == bundle.sha256 else {
                    try? FileManager.default.removeItem(at: tmpPath)
                    completion(.failure(.sha256Mismatch(expected: bundle.sha256, actual: actualHash)))
                    return
                }

                try self.store.install(tempFile: tmpPath, version: version, sha256: bundle.sha256)
                completion(.success(()))
            } catch {
                try? FileManager.default.removeItem(at: tmpPath)
                completion(.failure(.fileError(error)))
            }
        }.resume()
    }
}

// MARK: - Private

private extension BundleDownloader {
    func sha256(of url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        return data.sha256String
    }
}
