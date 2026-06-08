import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "APIClient")

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

enum APIClient {
    static var httpClient: HTTPClient = URLSession.shared

    static func prepareRequest(path: String, method: String = "GET") -> URLRequest? {
        guard let config = KeychainService.loadConfig(),
              let baseUrl = URL(string: config.serverUrl),
              let url = URL(string: path, relativeTo: baseUrl) else {
            logger.error("Failed to build URL for path: \(path)")
            return nil
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        if deviceId == nil {
            logger.warning("identifierForVendor is nil while preparing request for path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId ?? "", forHTTPHeaderField: "X-Device-ID")
        return request
    }

    static func pingDevice(
        httpClient: HTTPClient? = nil,
        deviceIdProvider: () async -> String? = { await DeviceIdentifier.waitForIdentifier() },
        configProvider: () -> ServerConfig? = { KeychainService.loadConfig() },
        deviceNameFallback: String? = nil,
        defaults: UserDefaults = .standard,
        maxAttempts: Int = 3
    ) async throws {
        let client = httpClient ?? Self.httpClient

        guard let deviceId = await deviceIdProvider(), !deviceId.isEmpty else {
            logger.error("Device identifier unavailable after polling")
            throw APIError.deviceIdentifierUnavailable
        }

        guard let config = configProvider(),
              let baseUrl = URL(string: config.serverUrl),
              let url = URL(string: "/api/v1/devices/ping", relativeTo: baseUrl) else {
            throw APIError.notConfigured
        }

        let storedName = defaults.string(forKey: "deviceName") ?? ""
        let fallbackName: String
        if let provided = deviceNameFallback {
            fallbackName = provided
        } else {
            fallbackName = await MainActor.run { UIDevice.current.name }
        }
        let effectiveName = storedName.isEmpty ? fallbackName : storedName
        let description = defaults.string(forKey: "deviceDescription") ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        let body = DevicePingRequest(
            deviceId: deviceId,
            deviceName: effectiveName,
            deviceDescription: description
        )
        request.httpBody = try JSONEncoder().encode(body)

        let backoffs: [TimeInterval] = [0.5, 1.0, 2.0]

        for attempt in 0..<maxAttempts {
            do {
                let (_, response) = try await client.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.requestFailed
                }

                let status = httpResponse.statusCode
                if (200...299).contains(status) {
                    return
                }

                if (400...499).contains(status) {
                    logger.error("Ping failed with non-retryable status \(status)")
                    throw APIError.requestFailed
                }

                logger.error("Ping attempt \(attempt + 1) failed with status \(status)")
                if attempt == maxAttempts - 1 {
                    throw APIError.requestFailed
                }
            } catch let error as APIError {
                throw error
            } catch {
                logger.error("Ping attempt \(attempt + 1) network error: \(error.localizedDescription)")
                if attempt == maxAttempts - 1 {
                    throw APIError.networkUnavailable
                }
            }

            let delay = backoffs[min(attempt, backoffs.count - 1)]
            try? await Task.sleep(for: .seconds(delay))
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
    case deviceIdentifierUnavailable
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured: "API not configured"
        case .requestFailed: "Request failed"
        case .forbidden(let message): message
        case .deviceIdentifierUnavailable: "Could not determine device identifier. Please try again."
        case .networkUnavailable: "Could not reach the server. Check your connection and try again."
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

struct DevicePingRequest: Encodable {
    let deviceId: String
    let deviceName: String
    let deviceDescription: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
        case deviceDescription = "device_description"
    }
}
