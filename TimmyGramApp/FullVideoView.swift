//
//  FulVideoView.swift
//  TimmyGramApp
//
//  Created by Vladimir Kolev on 28.04.26.
//
import SwiftUI
//import Combine

struct FullVideoView: View {
    let currentVideo: Video
    @ObservedObject private var viewModel: VideoViewModel
    @State private var offset: CGSize = .zero
    @State private var currentIndex: Int
    
    init(currentVideo: Video, viewModel: VideoViewModel) {
        self.currentVideo = currentVideo
        self.viewModel = viewModel
        self._currentIndex = State(
            initialValue: viewModel.videos
                .firstIndex(where: { $0.id == currentVideo.id }) ?? 0
        )
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
                                    if gesture.translation.height < -50
                                        && currentIndex < viewModel.videos.count - 1
                                    {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentIndex += 1
                                        }
                                        viewModel.preloadNextVideo()
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
                Button {} label: {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundStyle(.pink)
                        .shadow(radius: 4)
                }

                Button {} label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 48)
    }
}
