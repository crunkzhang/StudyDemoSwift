import Foundation

public final class RNBundleUpdater {
    public static let shared = RNBundleUpdater()

    private static let versionKey = "RNBundleUpdater.version"

    public var remoteBaseURL: String = ""

    private var localBundleDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RNBundle", isDirectory: true)
    }

    var downloadedBundlePath: URL? {
        let url = localBundleDir.appendingPathComponent("main.jsbundle")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private init() {}

    public func checkUpdate() {
        guard !remoteBaseURL.isEmpty else { return }
        let versionURL = URL(string: "\(remoteBaseURL)/version.json")!

        URLSession.shared.dataTask(with: versionURL) { [weak self] data, _, error in
            guard let self, let data, error == nil else {
                print("[BundleUpdater] version check failed: \(error?.localizedDescription ?? "no data")")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let remoteVersion = json["version"] as? Int else {
                print("[BundleUpdater] invalid version.json")
                return
            }

            let localVersion = UserDefaults.standard.integer(forKey: Self.versionKey)
            guard remoteVersion > localVersion else {
                print("[BundleUpdater] already up to date (v\(localVersion))")
                return
            }

            print("[BundleUpdater] new version found: v\(remoteVersion), downloading...")
            self.downloadBundle(version: remoteVersion)
        }.resume()
    }

    private func downloadBundle(version: Int) {
        let bundleURL = URL(string: "\(remoteBaseURL)/main.jsbundle")!

        URLSession.shared.downloadTask(with: bundleURL) { [weak self] tempURL, _, error in
            guard let self, let tempURL, error == nil else {
                print("[BundleUpdater] download failed: \(error?.localizedDescription ?? "unknown")")
                return
            }

            do {
                try FileManager.default.createDirectory(at: self.localBundleDir, withIntermediateDirectories: true)

                let dest = self.localBundleDir.appendingPathComponent("main.jsbundle")
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: tempURL, to: dest)

                UserDefaults.standard.set(version, forKey: Self.versionKey)
                print("[BundleUpdater] v\(version) downloaded, will take effect on next launch")
            } catch {
                print("[BundleUpdater] save failed: \(error)")
            }
        }.resume()
    }
}
