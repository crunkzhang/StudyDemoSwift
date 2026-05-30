import Foundation

public enum GameLoadState {
    case idle
    case downloading
    case ready
    case failed(reason: String)
}
