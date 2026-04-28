import Foundation

struct ServerConfig: Codable {
    let serverUrl: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case serverUrl = "server_url"
        case token
    }
}
