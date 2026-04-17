import Foundation

final class BundleVersionResolver {
}

extension BundleVersionResolver {
    func resolve(config: UpdateConfig, deviceId: String, appVersion: String, currentVersion: String) -> VersionResolveResult {
        let sortedVersions = config.bundles.keys.sorted(by: >)

        for version in sortedVersions {
            guard let bundle = config.bundles[version] else { continue }
            guard compareVersions(appVersion, isAtLeast: bundle.grayscale.minAppVersion) else { continue }
            guard version != currentVersion else { return .noUpdate }

            if bundle.grayscale.whitelist.contains(deviceId) {
                return .update(version: version, bundle: bundle)
            }

            if isInGrayscale(deviceId: deviceId, percentage: bundle.grayscale.percentage) {
                return .update(version: version, bundle: bundle)
            }
        }

        return .noUpdate
    }
}

// MARK: - Private

private extension BundleVersionResolver {
    func isInGrayscale(deviceId: String, percentage: Int) -> Bool {
        guard percentage > 0 else { return false }
        guard percentage < 100 else { return true }
        return abs(stableHash(deviceId)) % 100 < percentage
    }

    func stableHash(_ string: String) -> Int {
        let digest = Data(string.utf8).sha256Digest
        let value = digest.prefix(4).enumerated().reduce(0) { result, pair in
            result | (Int(pair.element) << (pair.offset * 8))
        }
        return abs(value)
    }

    func compareVersions(_ version: String, isAtLeast minVersion: String) -> Bool {
        let v1 = version.split(separator: ".").compactMap { Int($0) }
        let v2 = minVersion.split(separator: ".").compactMap { Int($0) }
        let count = max(v1.count, v2.count)
        for i in 0..<count {
            let a = i < v1.count ? v1[i] : 0
            let b = i < v2.count ? v2[i] : 0
            if a < b { return false }
            if a > b { return true }
        }
        return true
    }
}
