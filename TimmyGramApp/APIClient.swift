import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "APIClient")

enum APIClient {
    static func prepareRequest(path: String, method: String = "GET") -> URLRequest? {
        guard let config = KeychainService.loadConfig(),
              let baseUrl = URL(string: config.serverUrl),
              let url = URL(string: path, relativeTo: baseUrl) else {
            logger.error("Failed to build URL for path: \(path)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UIDevice.current.identifierForVendor?.uuidString ?? "", forHTTPHeaderField: "X-Device-ID")
        return request
    }

    static func pingDevice() async throws {
        guard var request = prepareRequest(path: "/api/v1/devices/ping", method: "POST") else {
            throw APIError.notConfigured
        }

        let storedName = UserDefaults.standard.string(forKey: "deviceName") ?? ""
        let effectiveName = storedName.isEmpty ? UIDevice.current.name : storedName
        let description = UserDefaults.standard.string(forKey: "deviceDescription") ?? ""

        let body = DevicePingRequest(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
            deviceName: effectiveName,
            deviceDescription: description
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    static func fetchFeed(page: String? = nil) async throws -> FeedPage {
        let path = page ?? "/api/v1/feed"
        guard let request = prepareRequest(path: path) else {
            throw APIError.notConfigured
        }

        logger.info("Fetching feed from \(request.url?.absoluteString ?? "nil")")

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        if httpResponse?.statusCode == 403 {
            let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Access denied"
            throw APIError.forbidden(message)
        }
        guard let httpResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = httpResponse?.statusCode ?? -1
            logger.error("Feed request failed with status \(code)")
            throw APIError.requestFailed
        }

        logger.info("Feed response: \(String(data: data, encoding: .utf8) ?? "nil")")
        return try JSONDecoder().decode(FeedPage.self, from: data)
    }

    static func fetchImageData(path: String) async throws -> Data {
        guard let request = prepareRequest(path: path) else {
            throw APIError.notConfigured
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return data
    }
    
    static func likeVideo(videoId: Int) async -> Int? {
        guard let request = prepareRequest(path: "/api/v1/videos/\(videoId)/likes", method: "POST") else {
            return nil
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let likes = json["likes_count"] as? Int else {
            return nil
        }

        return likes
    }

    static func fetchNextVideo() async throws -> Video {
        guard let request = prepareRequest(path: "/api/v1/next") else {
            throw APIError.notConfigured
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        logger.info("Response for next: \(response)")

        let httpResponse = response as? HTTPURLResponse
        if httpResponse?.statusCode == 403 {
            let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Access denied"
            throw APIError.forbidden(message)
        }
        guard let httpResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try JSONDecoder().decode(VideoResponse.self, from: data).video
    }
}

enum APIError: LocalizedError {
    case notConfigured
    case requestFailed
    case forbidden(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "API not configured"
        case .requestFailed: "Request failed"
        case .forbidden(let message): message
        }
    }

    var isForbidden: Bool {
        if case .forbidden = self { return true }
        return false
    }
}

private struct APIErrorResponse: Decodable {
    let error: String
}

struct FeedPage: Decodable {
    let videos: [Video]
    let page: Int
    let nextPage: String?

    enum CodingKeys: String, CodingKey {
        case videos
        case page
        case nextPage = "next_page"
    }
}

private struct VideoResponse: Decodable {
    let video: Video
}

private struct DevicePingRequest: Encodable {
    let deviceId: String
    let deviceName: String
    let deviceDescription: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
        case deviceDescription = "device_description"
    }
}
