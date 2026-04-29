import Foundation

nonisolated
struct Video: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let thumbnailUrl: String
    let streamUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case thumbnailUrl = "thumbnail_url"
        case streamUrl = "stream_url"
    }

    var resolvedThumbnailUrl: URL? {
        resolveUrl(thumbnailUrl)
    }

    var resolvedStreamUrl: URL? {
        resolveUrl(streamUrl)
    }

    private func resolveUrl(_ path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }
        guard let config = KeychainService.loadConfig(),
              let baseUrl = URL(string: config.serverUrl) else {
            return nil
        }
        return URL(string: path, relativeTo: baseUrl)
    }
}
