import Foundation

public protocol CatonDetectable: AnyObject {
    var onCatonDetected: ((CatonEvent) -> Void)? { get set }
    func start()
    func stop()
}
