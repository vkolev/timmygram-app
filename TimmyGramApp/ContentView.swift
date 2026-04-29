//
//  ContentView.swift
//  TimmyGramApp
//
//  Created by Vladimir Kolev on 28.04.26.
//

import SwiftUI

struct ContentView: View {
    var onResetConfiguration: () -> Void

    static let appGradient = LinearGradient(
        colors: [Color.orange.opacity(0.15), Color.purple.opacity(0.15)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        TabView {
            Tab("Feed", systemImage: "play.rectangle.fill") {
                FeedView()
            }

            Tab("Local", systemImage: "arrow.down.circle.fill") {
                LocalFeedView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView(onResetConfiguration: onResetConfiguration)
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
    }
}

#Preview {
    ContentView(onResetConfiguration: {})
}
