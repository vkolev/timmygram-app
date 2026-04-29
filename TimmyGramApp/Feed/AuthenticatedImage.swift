import SwiftUI

struct AuthenticatedImage: View {
    let path: String
    @State private var uiImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else if isLoading {
                Rectangle()
                    .foregroundStyle(.quaternary)
                    .overlay { ProgressView() }
            } else {
                Rectangle()
                    .foregroundStyle(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: path) {
            do {
                let data = try await APIClient.fetchImageData(path: path)
                uiImage = UIImage(data: data)
            } catch {}
            isLoading = false
        }
    }
}
