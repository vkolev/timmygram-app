//
//  ContentView.swift
//  TimmyGramApp
//
//  Created by Vladimir Kolev on 28.04.26.
//

import SwiftUI

struct ContentView: View {
    var onResetConfiguration: () -> Void

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
    }
}

#Preview {
    ContentView(onResetConfiguration: {})
}
