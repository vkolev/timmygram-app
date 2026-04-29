import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "Downloads")

@MainActor
@Observable
final class VideoDownloadManager {
    static let shared = VideoDownloadManager()

    private(set) var downloadedVideos: [Video] = []
    private(set) var activeDownloads: Set<Int> = []

    private let fileManager = FileManager.default

    private init() {
        loadIndex()
    }

    // MARK: - Public

    var downloadsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func isDownloaded(_ videoId: Int) -> Bool {
        downloadedVideos.contains { $0.id == videoId }
    }

    func localStreamURL(for videoId: Int) -> URL {
        downloadsDirectory.appendingPathComponent("\(videoId).mp4")
    }

    func localThumbnailURL(for videoId: Int) -> URL {
        downloadsDirectory.appendingPathComponent("\(videoId).jpg")
    }

    func download(_ video: Video) async {
        guard !isDownloaded(video.id), !activeDownloads.contains(video.id) else { return }
        activeDownloads.insert(video.id)
        defer { activeDownloads.remove(video.id) }

        do {
            guard let streamURL = video.resolvedStreamUrl else { throw DownloadError.invalidURL }
            try await downloadFile(from: streamURL, to: localStreamURL(for: video.id), authenticated: true)

            if let thumbURL = video.resolvedThumbnailUrl {
                try? await downloadFile(from: thumbURL, to: localThumbnailURL(for: video.id), authenticated: true)
            }

            downloadedVideos.append(video)
            saveIndex()
            logger.info("Downloaded video: \(video.title)")
        } catch {
            logger.error("Failed to download video \(video.id): \(error)")
            try? fileManager.removeItem(at: localStreamURL(for: video.id))
            try? fileManager.removeItem(at: localThumbnailURL(for: video.id))
        }
    }

    func delete(_ videoId: Int) {
        try? fileManager.removeItem(at: localStreamURL(for: videoId))
        try? fileManager.removeItem(at: localThumbnailURL(for: videoId))
        downloadedVideos.removeAll { $0.id == videoId }
        saveIndex()
        logger.info("Deleted downloaded video \(videoId)")
    }

    // MARK: - Private

    private var indexURL: URL {
        downloadsDirectory.appendingPathComponent("index.json")
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let videos = try? JSONDecoder().decode([Video].self, from: data) else {
            return
        }
        downloadedVideos = videos.filter { fileManager.fileExists(atPath: localStreamURL(for: $0.id).path) }
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(downloadedVideos) else { return }
        try? data.write(to: indexURL)
    }

    private func downloadFile(from remoteURL: URL, to localURL: URL, authenticated: Bool) async throws {
        var request = URLRequest(url: remoteURL)
        if authenticated, let config = KeychainService.loadConfig() {
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
            request.setValue(UIDevice.current.identifierForVendor?.uuidString ?? "", forHTTPHeaderField: "X-Device-ID")
        }

        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.serverError
        }

        if fileManager.fileExists(atPath: localURL.path) {
            try fileManager.removeItem(at: localURL)
        }
        try fileManager.moveItem(at: tempURL, to: localURL)
    }
}

private enum DownloadError: Error {
    case invalidURL
    case serverError
}
