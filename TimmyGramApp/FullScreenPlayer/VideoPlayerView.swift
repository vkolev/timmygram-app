//
//  VideoPlayerView.swift
//  TimmyGramApp
//
//  Created by Vladimir Kolev on 28.04.26.
//
import AVFoundation
import AVKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "VideoPlayer")

struct VideoPlayerView: UIViewControllerRepresentable {
    let videoURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let controller = AVPlayerViewController()

        let asset = makeAuthenticatedAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        controller.player = player
        controller.showsPlaybackControls = false
        controller.exitsFullScreenWhenPlaybackEnds = false

        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        logger.info("Playing video: \(videoURL.absoluteString)")
        player.play()
        return controller
    }

    func updateUIViewController(
        _ uiViewController: AVPlayerViewController,
        context: Context
    ) {}

    static func dismantleUIViewController(
        _ uiViewController: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        uiViewController.player?.pause()
        if let observer = coordinator.loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func makeAuthenticatedAsset(url: URL) -> AVURLAsset {
        guard let config = KeychainService.loadConfig() else {
            return AVURLAsset(url: url)
        }
        let headers = ["Authorization": "Bearer \(config.token)"]
        return AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    }

    class Coordinator {
        var loopObserver: Any?
    }
}
