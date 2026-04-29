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

    var body: some View {
        if showDeviceInfo {
            deviceInfoStep
        } else {
            scannerStep
        }
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

    private func finishOnboarding() {
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
