import Foundation
import WeChatNetAPI

struct MeProfileDTO: Decodable {
    let nickname: String
    let wechatID: String
}

struct GetProfile: APIEndpoint {
    typealias DataType = MeProfileDTO
    let path = "/profile/me"
}

// MARK: - Debug（非标准响应格式，使用 NetEndpoint）
struct DogImageResp: Decodable {
    let message: String
    let status: String
}

struct GetRandomDogImage: NetEndpoint {
    typealias Response = DogImageResp
    let path = "/api/breeds/image/random"
    let method: HTTPMethod = .get
    var requiresAuth: Bool { false }
}
