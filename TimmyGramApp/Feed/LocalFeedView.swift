import SwiftUI

struct LocalFeedView: View {
    var downloadManager = VideoDownloadManager.shared
    @State private var selectedVideo: Video?

    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.downloadedVideos.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloaded videos will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(downloadManager.downloadedVideos) { video in
                                LocalVideoCardView(video: video)
                                    .onTapGesture {
                                        selectedVideo = video
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Local Feed")
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(ContentView.appGradient.ignoresSafeArea())
            .navigationDestination(item: $selectedVideo) { video in
                let index = downloadManager.downloadedVideos.firstIndex(of: video) ?? 0
                LocalVideoPlayerView(videos: downloadManager.downloadedVideos, startIndex: index)
            }
        }
    }
}

private struct LocalVideoCardView: View {
    let video: Video
    var downloadManager = VideoDownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailImage
                .aspectRatio(3 / 4, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .clipped()

            HStack {
                Text(video.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Spacer()

                Button {
                    downloadManager.delete(video.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .padding(5)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        let url = downloadManager.localThumbnailURL(for: video.id)
        if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
        } else {
            Rectangle()
                .foregroundStyle(.quaternary)
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                        .font(.largeTitle)
                }
        }
    }
}
