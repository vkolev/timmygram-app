//
//  VideoViewModel.swift
//  TimmyGramApp
//
//  Created by Vladimir Kolev on 28.04.26.
//
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "VideoViewModel")

@MainActor
class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []

    func loadVideos(_ feedVideos: [Video], startingFrom video: Video) {
        videos = feedVideos
        logger.info("Loaded \(feedVideos.count) videos into player")
    }

    func preloadNextVideo() {
        Task {
            do {
                try APIClient.fetchNextVideo { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let video):
                            self?.videos.append(video)
                            logger.info("Preloaded next video: \(video.title)")
                        case .failure(let error):
                            logger.error("Failed to preload: \(error)")
                        }
                    }
                }
            } catch {
                logger.error("Failed to prepare next video request: \(error)")
            }
        }
    }
}
