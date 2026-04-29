//
//  FulVideoView.swift
//  TimmyGramApp
//
//  Created by Vladimir Kolev on 28.04.26.
//
import SwiftUI
//import Combine

struct FullVideoView: View {
    @StateObject private var viewModel: VideoViewModel
    @State private var offset: CGSize = .zero
    @State private var currentIndex = 0
    var downloadManager = VideoDownloadManager.shared

    init(video: Video) {
        self._viewModel = StateObject(wrappedValue: VideoViewModel(startingWith: video))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                if !viewModel.videos.isEmpty && currentIndex < viewModel.videos.count,
                   let streamUrl = viewModel.videos[currentIndex].resolvedStreamUrl
                {
                    VideoPlayerView(videoURL: streamUrl)
                        .id(currentIndex)
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .overlay(alignment: .bottom) {
                            videoOverlay
                        }
                        .overlay {
                            if viewModel.isLoadingNext {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                            }
                        }
                        .offset(y: offset.height)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom),
                            removal: .move(edge: .top)
                        ))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    offset = gesture.translation
                                }
                                .onEnded { gesture in
                                    if gesture.translation.height < -50 {
                                        if currentIndex < viewModel.videos.count - 1 {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                currentIndex += 1
                                            }
                                        } else {
                                            Task {
                                                let success = await viewModel.fetchNextVideo()
                                                if success {
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        currentIndex += 1
                                                    }
                                                }
                                            }
                                        }
                                    } else if gesture.translation.height > 50
                                        && currentIndex > 0
                                    {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentIndex -= 1
                                        }
                                    }
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        offset = .zero
                                    }
                                }
                        )
                } else {
                    ProgressView()
                }
            }
        }
        .ignoresSafeArea()
        .toolbarVisibility(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(false)
    }

    private var currentTitle: String {
        guard !viewModel.videos.isEmpty && currentIndex < viewModel.videos.count else {
            return ""
        }
        return viewModel.videos[currentIndex].title
    }

    private var videoOverlay: some View {
        HStack(alignment: .bottom) {
            Text(currentTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .shadow(radius: 4)
                .lineLimit(2)

            Spacer()

            VStack(spacing: 20) {
                Button {
                    guard currentIndex < viewModel.videos.count else { return }
                    let video = viewModel.videos[currentIndex]
                    Task {
                        if let newLikes = await APIClient.likeVideo(videoId: video.id) {
                            viewModel.videos[currentIndex].likes_count = newLikes
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        if currentIndex < viewModel.videos.count {
                            Text("\(viewModel.videos[currentIndex].likes_count)")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                        Image(systemName: "heart.fill")
                            .font(.title)
                            .foregroundStyle(.pink)
                            .shadow(radius: 4)
                    }
                }

                Button {
                    guard currentIndex < viewModel.videos.count else { return }
                    let video = viewModel.videos[currentIndex]
                    Task { await downloadManager.download(video) }
                } label: {
                    Group {
                        if currentIndex < viewModel.videos.count && downloadManager.activeDownloads.contains(viewModel.videos[currentIndex].id) {
                            ProgressView()
                                .tint(.white)
                        } else if currentIndex < viewModel.videos.count && downloadManager.isDownloaded(viewModel.videos[currentIndex].id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                                .shadow(radius: 4)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                    }
                }
                .disabled(currentIndex < viewModel.videos.count && (downloadManager.isDownloaded(viewModel.videos[currentIndex].id) || downloadManager.activeDownloads.contains(viewModel.videos[currentIndex].id)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 48)
    }
}
