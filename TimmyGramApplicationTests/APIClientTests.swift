import Foundation
import Testing
import os
@testable import TimmyGramApp

private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    struct Response {
        let statusCode: Int
        let data: Data
        let throwError: Error?

        static func ok(_ body: String = "{}") -> Response {
            Response(statusCode: 200, data: Data(body.utf8), throwError: nil)
        }
        static func status(_ code: Int) -> Response {
            Response(statusCode: code, data: Data(), throwError: nil)
        }
        static func networkError(_ error: Error) -> Response {
            Response(statusCode: 0, data: Data(), throwError: error)
        }
    }

    private let lock = OSAllocatedUnfairLock()
    private var queue: [Response]
    private var _capturedRequests: [URLRequest] = []

    var capturedRequests: [URLRequest] {
        lock.withLock { _capturedRequests }
    }

    init(_ responses: [Response]) {
        self.queue = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try lock.withLock {
            _capturedRequests.append(request)

            guard !queue.isEmpty else {
                throw URLError(.badServerResponse)
            }
            let response = queue.removeFirst()

            if let error = response.throwError {
                throw error
            }

            let urlResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response.data, urlResponse)
        }
    }
}

private struct TestContext {
    let config: ServerConfig
    let defaults: UserDefaults

    init(
        serverUrl: String = "https://example.test",
        token: String = "test-token",
        deviceName: String? = "iPhone of Timmy",
        deviceDescription: String? = "Kid bedroom"
    ) {
        self.config = ServerConfig(serverUrl: serverUrl, token: token)
        let suiteName = "APIClientTests-\(UUID().uuidString)"
        self.defaults = UserDefaults(suiteName: suiteName)!
        if let deviceName { defaults.set(deviceName, forKey: "deviceName") }
        if let deviceDescription { defaults.set(deviceDescription, forKey: "deviceDescription") }
    }
}

private struct DecodedPingBody: Decodable {
    let deviceId: String
    let deviceName: String
    let deviceDescription: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
        case deviceDescription = "device_description"
    }
}

private func decodeBody(_ request: URLRequest) -> DecodedPingBody? {
    guard let body = request.httpBody else { return nil }
    return try? JSONDecoder().decode(DecodedPingBody.self, from: body)
}

@Suite("APIClient.pingDevice")
struct APIClientPingTests {

    @Test("succeeds on first attempt and sends the expected body")
    func succeedsFirstAttempt() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([.ok()])

        try await APIClient.pingDevice(
            httpClient: mock,
            deviceIdProvider: { "device-uuid-123" },
            configProvider: { ctx.config },
            deviceNameFallback: "Fallback",
            defaults: ctx.defaults,
            maxAttempts: 3
        )

        #expect(mock.capturedRequests.count == 1)
        let body = try #require(decodeBody(mock.capturedRequests[0]))
        #expect(body.deviceId == "device-uuid-123")
        #expect(body.deviceName == "iPhone of Timmy")
        #expect(body.deviceDescription == "Kid bedroom")

        let request = mock.capturedRequests[0]
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "X-Device-ID") == "device-uuid-123")
        #expect(request.url?.absoluteString == "https://example.test/api/v1/devices/ping")
    }

    @Test("retries on 503 and succeeds on second attempt")
    func retriesOn5xx() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([.status(503), .ok()])

        try await APIClient.pingDevice(
            httpClient: mock,
            deviceIdProvider: { "device-uuid-123" },
            configProvider: { ctx.config },
            deviceNameFallback: "Fallback",
            defaults: ctx.defaults,
            maxAttempts: 3
        )

        #expect(mock.capturedRequests.count == 2)
    }

    @Test("throws .requestFailed after exhausting retries on 500")
    func exhaustsRetries() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([.status(500), .status(500), .status(500)])

        await #expect(throws: APIError.self) {
            try await APIClient.pingDevice(
                httpClient: mock,
                deviceIdProvider: { "device-uuid-123" },
                configProvider: { ctx.config },
                deviceNameFallback: "Fallback",
                defaults: ctx.defaults,
                maxAttempts: 3
            )
        }
        #expect(mock.capturedRequests.count == 3)
    }

    @Test("does not retry on 401")
    func doesNotRetryOn4xx() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([.status(401), .ok(), .ok()])

        await #expect(throws: APIError.self) {
            try await APIClient.pingDevice(
                httpClient: mock,
                deviceIdProvider: { "device-uuid-123" },
                configProvider: { ctx.config },
                deviceNameFallback: "Fallback",
                defaults: ctx.defaults,
                maxAttempts: 3
            )
        }
        #expect(mock.capturedRequests.count == 1)
    }

    @Test("throws .notConfigured when no server config available")
    func notConfigured() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([.ok()])

        do {
            try await APIClient.pingDevice(
                httpClient: mock,
                deviceIdProvider: { "device-uuid-123" },
                configProvider: { nil },
                deviceNameFallback: "Fallback",
                defaults: ctx.defaults,
                maxAttempts: 3
            )
            Issue.record("expected .notConfigured to be thrown")
        } catch let error as APIError {
            if case .notConfigured = error { } else {
                Issue.record("expected .notConfigured, got \(error)")
            }
        }
        #expect(mock.capturedRequests.isEmpty)
    }

    @Test("throws .deviceIdentifierUnavailable when identifierForVendor stays nil")
    func deviceIdentifierUnavailable() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([.ok()])

        do {
            try await APIClient.pingDevice(
                httpClient: mock,
                deviceIdProvider: { nil },
                configProvider: { ctx.config },
                deviceNameFallback: "Fallback",
                defaults: ctx.defaults,
                maxAttempts: 3
            )
            Issue.record("expected .deviceIdentifierUnavailable to be thrown")
        } catch let error as APIError {
            if case .deviceIdentifierUnavailable = error { } else {
                Issue.record("expected .deviceIdentifierUnavailable, got \(error)")
            }
        }
        #expect(mock.capturedRequests.isEmpty)
    }

    @Test("falls back to provided device name when UserDefaults value is empty")
    func emptyDeviceNameFallback() async throws {
        let ctx = TestContext(deviceName: "")
        let mock = MockHTTPClient([.ok()])

        try await APIClient.pingDevice(
            httpClient: mock,
            deviceIdProvider: { "device-uuid-123" },
            configProvider: { ctx.config },
            deviceNameFallback: "Default Name",
            defaults: ctx.defaults,
            maxAttempts: 3
        )

        let body = try #require(decodeBody(mock.capturedRequests[0]))
        #expect(body.deviceName == "Default Name")
    }

    @Test("retries on transport error then succeeds")
    func retriesOnNetworkError() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([
            .networkError(URLError(.notConnectedToInternet)),
            .ok()
        ])

        try await APIClient.pingDevice(
            httpClient: mock,
            deviceIdProvider: { "device-uuid-123" },
            configProvider: { ctx.config },
            deviceNameFallback: "Fallback",
            defaults: ctx.defaults,
            maxAttempts: 3
        )

        #expect(mock.capturedRequests.count == 2)
    }

    @Test("throws .networkUnavailable when all attempts are transport failures")
    func networkUnavailable() async throws {
        let ctx = TestContext()
        let mock = MockHTTPClient([
            .networkError(URLError(.timedOut)),
            .networkError(URLError(.timedOut)),
            .networkError(URLError(.timedOut))
        ])

        do {
            try await APIClient.pingDevice(
                httpClient: mock,
                deviceIdProvider: { "device-uuid-123" },
                configProvider: { ctx.config },
                deviceNameFallback: "Fallback",
                defaults: ctx.defaults,
                maxAttempts: 3
            )
            Issue.record("expected .networkUnavailable to be thrown")
        } catch let error as APIError {
            if case .networkUnavailable = error { } else {
                Issue.record("expected .networkUnavailable, got \(error)")
            }
        }
        #expect(mock.capturedRequests.count == 3)
    }
}
