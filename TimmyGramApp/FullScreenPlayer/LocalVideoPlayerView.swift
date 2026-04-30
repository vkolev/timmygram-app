import AVFoundation
import AVKit
import SwiftUI

struct LocalVideoPlayerView: View {
    let videos: [Video]
    let startIndex: Int
    @State private var currentIndex: Int
    @State private var offset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss

    init(videos: [Video], startIndex: Int) {
        self.videos = videos
        self.startIndex = startIndex
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                if currentIndex < videos.count {
                    let video = videos[currentIndex]
                    let fileURL = VideoDownloadManager.shared.localStreamURL(for: video.id)
                    LocalPlayerView(videoURL: fileURL)
                        .id(currentIndex)
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
                        .offset(y: offset.height)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    offset = gesture.translation
                                }
                                .onEnded { gesture in
                                    if gesture.translation.height < -50 {
                                        if currentIndex < videos.count - 1 {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                currentIndex += 1
                                            }
                                        } else {
                                            dismiss()
                                            return
                                        }
                                    } else if gesture.translation.height > 50 && currentIndex > 0 {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentIndex -= 1
                                        }
                                    }
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        offset = .zero
                                    }
                                }
                        )
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
