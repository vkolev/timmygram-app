import OSLog
import SwiftUI
import VisionKit

private let logger = Logger(subsystem: "net.vkolev.TimmyGramApp", category: "Onboarding")

struct OnboardingView: View {
    var onConfigured: () -> Void

    @State private var showScanner = false
    @State private var errorMessage: String?
    @State private var showDeviceInfo = false
    @AppStorage("deviceName") private var deviceName = ""
    @AppStorage("deviceDescription") private var deviceDescription = ""
    @State private var showPinSetup = false
    @State private var serverUrl = ""
    @State private var setupPin = ""
    @State private var settingsPin = ""
    @State private var isConnecting = false

    var body: some View {
        Group {
            if showDeviceInfo {
                deviceInfoStep
            } else if showPinSetup {
                pinSetupStep
            } else {
                scannerStep
            }
        }
        .background(ContentView.appGradient.ignoresSafeArea())
    }

    private var scannerStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Welcome to TimmyGram")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Scan a QR code to connect to your server.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                errorMessage = nil
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(!DataScannerViewController.isSupported)

            if !DataScannerViewController.isSupported {
                Text("Camera scanning is not supported on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
            }
            .padding(.horizontal, 40)

            Button {
                errorMessage = nil
                showPinSetup = true
            } label: {
                Label("Setup with PIN", systemImage: "key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 40)

            Spacer()
        }
        .fullScreenCover(isPresented: $showScanner) {
            ZStack(alignment: .topTrailing) {
                QRScannerView { payload in
                    handleScannedPayload(payload)
                }
                .ignoresSafeArea()

                Button {
                    showScanner = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
                .padding()
            }
        }
    }

    private var deviceInfoStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "iphone.gen3")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Name Your Device")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Give this device a name and description so you can identify it on the server.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 16) {
                TextField("Device Name", text: $deviceName)
                    .textFieldStyle(.roundedBorder)

                TextField("Device Description (optional)", text: $deviceDescription)
                    .textFieldStyle(.roundedBorder)

                Divider()
                    .padding(.vertical, 4)

                Text("Protect Settings")
                    .font(.headline)

                Text("Set a 4-digit PIN to prevent children from changing settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("4-Digit PIN (optional)", text: $settingsPin)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .onChange(of: settingsPin) { _, newValue in
                        let filtered = String(newValue.filter { $0.isNumber }.prefix(4))
                        if filtered != newValue { settingsPin = filtered }
                    }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button {
                finishOnboarding()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)

            Button {
                deviceName = ""
                deviceDescription = ""
                settingsPin = ""
                finishOnboarding()
            } label: {
                Text("Skip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var pinSetupStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Setup with PIN")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Enter your server URL and the 6-digit PIN provided by the server administrator.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 16) {
                TextField("Server URL", text: $serverUrl)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("6-Digit PIN", text: $setupPin)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .onChange(of: setupPin) { _, newValue in
                        let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
                        if filtered != newValue { setupPin = filtered }
                    }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button {
                connectWithPin()
            } label: {
                if isConnecting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(serverUrl.isEmpty || setupPin.count != 6 || isConnecting)

            Button {
                showPinSetup = false
                errorMessage = nil
            } label: {
                Text("Back")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func connectWithPin() {
        let trimmedUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseUrl = URL(string: trimmedUrl) else {
            errorMessage = "Invalid server URL."
            return
        }

        let pin = setupPin
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                // Placeholder: POST {serverUrl}/api/v1/auth/pin with {"pin": "..."}
                // Expected response: {"token": "<jwt_token>"}
                let endpoint = baseUrl.appendingPathComponent("api/v1/auth/pin")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body = ["pin": pin]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    errorMessage = "Connection failed. Check your URL and PIN."
                    isConnecting = false
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let token = json["token"] as? String else {
                    errorMessage = "Invalid server response."
                    isConnecting = false
                    return
                }

                let config = ServerConfig(serverUrl: trimmedUrl, token: token)
                try KeychainService.save(config: config)
                logger.info("Config saved via PIN setup")

                isConnecting = false
                showPinSetup = false
                showDeviceInfo = true
            } catch {
                errorMessage = "Connection failed: \(error.localizedDescription)"
                isConnecting = false
            }
        }
    }

    private func finishOnboarding() {
        if settingsPin.count == 4 {
            try? KeychainService.saveSettingsPin(settingsPin)
        }
        Task {
            try? await APIClient.pingDevice()
        }
        onConfigured()
    }

    private func handleScannedPayload(_ payload: String) {
        logger.info("QR code scanned, raw payload: \(payload)")

        guard let data = payload.data(using: .utf8) else {
            logger.error("Failed to convert payload to data")
            errorMessage = "Invalid QR code content."
            showScanner = false
            return
        }

        do {
            logger.info("Data before encoding: \(data)")
            let config = try JSONDecoder().decode(ServerConfig.self, from: data)
            logger.info("Decoded config — serverUrl: \(config.serverUrl)")

            guard URL(string: config.serverUrl) != nil else {
                logger.error("Invalid URL: \(config.serverUrl)")
                errorMessage = "The server URL in the QR code is invalid."
                showScanner = false
                return
            }

            try KeychainService.save(config: config)
            logger.info("Config saved to Keychain")
            showScanner = false
            showDeviceInfo = true
        } catch is DecodingError {
            logger.error("Decoding failed for payload: \(payload)")
            errorMessage = "QR code does not contain valid server configuration."
            showScanner = false
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
            showScanner = false
        }
    }
}

#Preview {
    OnboardingView(onConfigured: {})
}
