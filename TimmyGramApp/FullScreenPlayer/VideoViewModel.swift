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
    @Published var isLoadingNext = false

    init(startingWith video: Video) {
        videos = [video]
        logger.info("Starting player with video: \(video.title)")
    }

    func fetchNextVideo() async -> Bool {
        isLoadingNext = true
        defer { isLoadingNext = false }
        do {
            let video = try await APIClient.fetchNextVideo()
            videos.append(video)
            logger.info("Fetched next video: \(video.title)")
            return true
        } catch {
            logger.error("Failed to fetch next video: \(error)")
            return false
        }
    }
}
