import Foundation

public protocol NetLoggable {
    func didStart(_ request: URLRequest)
    func didSucceed(_ request: URLRequest, response: HTTPURLResponse, data: Data)
    func didFail(_ request: URLRequest, error: Error)
    func didRetry(_ request: URLRequest, attempt: Int, error: Error)
    func didCancel(_ request: URLRequest)
}

public extension NetLoggable {
    func didStart(_ request: URLRequest) {}
    func didSucceed(_ request: URLRequest, response: HTTPURLResponse, data: Data) {}
    func didFail(_ request: URLRequest, error: Error) {}
    func didRetry(_ request: URLRequest, attempt: Int, error: Error) {}
    func didCancel(_ request: URLRequest) {}
}
