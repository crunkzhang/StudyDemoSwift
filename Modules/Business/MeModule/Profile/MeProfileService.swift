import Foundation
import WeChatNetAPI

struct MeProfileHeaderData {
    let statusText: String
    let avatarURL: URL?
}

final class MeProfileService {
    private let api = APIClient()

    func fetchHeaderData() async -> MeProfileHeaderData {
        do {
            let resp = try await api.sendRaw(GetRandomDogImage())
            return MeProfileHeaderData(
                statusText: "状态 · 今日狗狗在线",
                avatarURL: URL(string: resp.message)
            )
        } catch {
            return MeProfileHeaderData(
                statusText: "状态 · 未知",
                avatarURL: nil
            )
        }
    }
}
