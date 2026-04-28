import SwiftUI

struct SettingsView: View {
    var onResetConfiguration: () -> Void

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Settings coming soon")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Configuration", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset Configuration?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    KeychainService.deleteConfig()
                    onResetConfiguration()
                }
            } message: {
                Text("This will remove the server configuration and return to the onboarding screen.")
            }
        }
    }
}
