import OSLog
import SwiftUI

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "Feed")

struct FeedView: View {
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @StateObject private var viewModel = VideoViewModel()
    @State private var selectedVideo: Video?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(videos) { video in
                        VideoCardView(video: video)
                            .onAppear {
                                if video.id == videos.last?.id {
                                    Task { await loadMore() }
                                }
                            }
                            .onTapGesture {
                                viewModel.loadVideos(videos, startingFrom: video)
                                selectedVideo = video
                            }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Feed")
            .task { await loadMore() }
            .refreshable { await refresh() }
            .navigationDestination(item: $selectedVideo) { video in
                FullVideoView(currentVideo: video, viewModel: viewModel)
            }
        }
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let newVideos = try await APIClient.fetchFeed()
            logger.info("Loaded \(newVideos.count) videos, total: \(videos.count + newVideos.count)")
            videos.append(contentsOf: newVideos)
        } catch {
            logger.error("Failed to load feed: \(error)")
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            videos = try await APIClient.fetchFeed()
        } catch {
            logger.error("Failed to refresh feed: \(error)")
        }
    }
}
