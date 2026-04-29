import SwiftUI

struct VideoCardView: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuthenticatedImage(path: video.thumbnailUrl)
                .aspectRatio(3 / 4, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .clipped()

            Text(video.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .padding(5)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
