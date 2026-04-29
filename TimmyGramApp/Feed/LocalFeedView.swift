import SwiftUI

struct LocalFeedView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Downloads",
                systemImage: "arrow.down.circle",
                description: Text("Downloaded videos will appear here.")
            )
            .navigationTitle("Local Feed")
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .background(ContentView.appGradient.ignoresSafeArea())
        }
    }
}
