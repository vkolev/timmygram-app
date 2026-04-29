import SwiftUI

struct SettingsView: View {
    var onResetConfiguration: () -> Void

    @State private var showResetConfirmation = false
    @AppStorage("deviceName") private var deviceName = ""
    @AppStorage("deviceDescription") private var deviceDescription = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Device") {
                    TextField("Device Name", text: $deviceName)
                    TextField("Device Description", text: $deviceDescription)
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
