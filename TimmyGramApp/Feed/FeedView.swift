import OSLog
import SwiftUI

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "Feed")

struct FeedView: View {
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @State private var selectedVideo: Video?
    @State private var nextPage: String?
    @State private var hasLoadedInitialPage = false

    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty && isLoading {
                    ContentUnavailableView {
                        ProgressView()
                            .controlSize(.large)
                    } description: {
                        Text("Loading feed…")
                    }
                } else {
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
                                        selectedVideo = video
                                    }
                            }

                            if isLoading {
                                ProgressView()
                                    .padding()
                            } else if hasLoadedInitialPage && nextPage == nil && !videos.isEmpty {
                                Text("You're all caught up!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 24)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Feed")
            .task { await loadMore() }
            .refreshable { await refresh() }
            .navigationDestination(item: $selectedVideo) { video in
                FullVideoView(video: video)
            }
        }
    }

    private func loadMore() async {
        guard !isLoading else { return }
        if hasLoadedInitialPage && nextPage == nil { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let feedPage = try await APIClient.fetchFeed(page: nextPage)
            logger.info("Loaded page \(feedPage.page) with \(feedPage.videos.count) videos")
            videos.append(contentsOf: feedPage.videos)
            nextPage = feedPage.nextPage
            hasLoadedInitialPage = true
        } catch {
            logger.error("Failed to load feed: \(error)")
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let feedPage = try await APIClient.fetchFeed()
            videos = feedPage.videos
            nextPage = feedPage.nextPage
            hasLoadedInitialPage = true
        } catch {
            logger.error("Failed to refresh feed: \(error)")
        }
    }
}
