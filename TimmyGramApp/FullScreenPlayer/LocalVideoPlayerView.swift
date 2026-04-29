import AVFoundation
import AVKit
import SwiftUI

struct LocalVideoPlayerView: View {
    let video: Video

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                let fileURL = VideoDownloadManager.shared.localStreamURL(for: video.id)
                LocalPlayerView(videoURL: fileURL)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .overlay(alignment: .bottom) {
                        Text(video.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 48)
                    }
            }
        }
        .ignoresSafeArea()
        .toolbarVisibility(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(false)
    }
}

private struct LocalPlayerView: UIViewControllerRepresentable {
    let videoURL: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let controller = AVPlayerViewController()
        let item = AVPlayerItem(url: videoURL)
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

        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        uiViewController.player?.pause()
        if let observer = coordinator.loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    class Coordinator {
        var loopObserver: Any?
    }
}
