import SwiftUI

@main
struct TimmyGramAppApp: App {
    @State private var isConfigured = KeychainService.loadConfig() != nil

    var body: some Scene {
        WindowGroup {
            if isConfigured {
                ContentView {
                    isConfigured = false
                }
            } else {
                OnboardingView {
                    isConfigured = true
                }
            }
        }
    }
}
