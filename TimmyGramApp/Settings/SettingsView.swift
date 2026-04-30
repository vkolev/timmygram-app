import SwiftUI

struct SettingsView: View {
    var onResetConfiguration: () -> Void

    @State private var showResetConfirmation = false
    @State private var isUnlocked = false
    @State private var enteredPin = ""
    @State private var pinError = false
    @State private var pinIsSet = false
    @AppStorage("deviceName") private var deviceName = ""
    @AppStorage("deviceDescription") private var deviceDescription = ""

    var body: some View {
        NavigationStack {
            if pinIsSet && !isUnlocked {
                pinEntryView
                    .navigationTitle("Settings")
                    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                    .background(ContentView.appGradient.ignoresSafeArea())
            } else {
                settingsContent
            }
        }
        .onAppear {
            pinIsSet = KeychainService.loadSettingsPin() != nil
            isUnlocked = false
            enteredPin = ""
            pinError = false
        }
    }

    private var pinEntryView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Enter PIN")
                .font(.title)
                .fontWeight(.bold)

            Text("Enter the settings PIN to continue.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            SecureField("PIN", text: $enteredPin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 120)
                .multilineTextAlignment(.center)
                .onChange(of: enteredPin) { _, newValue in
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(4))
                    if filtered != newValue { enteredPin = filtered }
                    pinError = false
                }

            if pinError {
                Text("Incorrect PIN")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Button {
                if enteredPin == KeychainService.loadSettingsPin() {
                    isUnlocked = true
                    enteredPin = ""
                } else {
                    pinError = true
                    enteredPin = ""
                }
            } label: {
                Text("Unlock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(enteredPin.count < 4)

            Spacer()
        }
    }

    private var settingsContent: some View {
        List {
            Section("Device") {
                TextField("Device Name", text: $deviceName)
                TextField("Device Description", text: $deviceDescription)
            }

            Section("Settings Protection") {
                if pinIsSet {
                    Label("PIN Protected", systemImage: "lock.fill")
                    Button("Remove PIN", role: .destructive) {
                        KeychainService.deleteSettingsPin()
                        pinIsSet = false
                    }
                } else {
                    Label("No PIN Set", systemImage: "lock.open")
                        .foregroundStyle(.secondary)
                }
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
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .scrollContentBackground(.hidden)
        .background(ContentView.appGradient.ignoresSafeArea())
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
