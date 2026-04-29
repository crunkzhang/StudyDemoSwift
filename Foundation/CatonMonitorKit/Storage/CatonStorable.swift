import Foundation

public protocol CatonStorable {
    func save(_ event: CatonEvent)
    func loadAll() -> [CatonEvent]
    func remove(ids: [UUID])
    func clear()
}
