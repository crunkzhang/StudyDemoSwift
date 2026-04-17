import Foundation

enum BundleEventType: String {
    case checkUpdate = "check_update"
    case updateAvailable = "update_available"
    case downloadStart = "download_start"
    case downloadSuccess = "download_success"
    case downloadFail = "download_fail"
    case loadSuccess = "load_success"
    case loadFail = "load_fail"
    case rollback = "rollback"
    case applyImmediate = "apply_immediate"
    case noUpdate = "no_update"
    case configFetchFail = "config_fetch_fail"
    case pollingStart = "polling_start"

    var tag: String {
        switch self {
        case .checkUpdate, .configFetchFail, .pollingStart:
            return "[RNBundle][Check]"
        case .noUpdate, .updateAvailable:
            return "[RNBundle][Resolve]"
        case .downloadStart, .downloadSuccess, .downloadFail:
            return "[RNBundle][Download]"
        case .loadSuccess, .loadFail:
            return "[RNBundle][Health]"
        case .rollback:
            return "[RNBundle][Rollback]"
        case .applyImmediate:
            return "[RNBundle][Install]"
        }
    }
}

struct BundleEvent {
    let type: BundleEventType
    let params: [String: Any]

    init(_ type: BundleEventType, _ params: [String: Any] = [:]) {
        self.type = type
        self.params = params
    }
}

protocol BundleEventReporter {
    func report(_ event: BundleEvent)
}

final class ConsoleBundleReporter: BundleEventReporter {
    func report(_ event: BundleEvent) {
        let paramsStr = event.params.map { "\($0.key)=\($0.value)" }.joined(separator: " | ")
        if paramsStr.isEmpty {
            print("\(event.type.tag) \(event.type.rawValue)")
        } else {
            print("\(event.type.tag) \(event.type.rawValue) | \(paramsStr)")
        }
    }
}
