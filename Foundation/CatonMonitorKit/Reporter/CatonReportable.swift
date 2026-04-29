import Foundation

public protocol CatonReportable {
    func report(events: [CatonEvent], completion: @escaping (Bool) -> Void)
}
