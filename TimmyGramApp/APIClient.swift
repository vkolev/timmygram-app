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
        return request
    }

    static func pingDevice() async throws {
        guard var request = prepareRequest(path: "/api/v1/devices/ping", method: "POST") else {
            throw APIError.notConfigured
        }

        let body = DevicePingRequest(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
            deviceName: UIDevice.current.name
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    static func fetchFeed() async throws -> [Video] {
        guard let request = prepareRequest(path: "/api/v1/feed") else {
            throw APIError.notConfigured
        }

        logger.info("Fetching feed from \(request.url?.absoluteString ?? "nil")")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("Feed request failed with status \(code)")
            throw APIError.requestFailed
        }

        logger.info("Feed response: \(String(data: data, encoding: .utf8) ?? "nil")")
        let feedResponse = try JSONDecoder().decode(FeedResponse.self, from: data)
        return feedResponse.videos
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
    
    static func fetchNextVideo(completion: @escaping (Result<Video, Error>) -> Void) throws {
        guard let request = prepareRequest(path: "/api/v1/next") else {
            throw APIError.notConfigured
        }
        
        URLSession.shared.dataTask(with: request) {data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            do {
                let video = try JSONDecoder().decode(Video.self, from: data)
                completion(.success(video))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum APIError: Error {
    case notConfigured
    case requestFailed
}

private struct FeedResponse: Decodable {
    let videos: [Video]
}

private struct DevicePingRequest: Encodable {
    let deviceId: String
    let deviceName: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
    }
}
