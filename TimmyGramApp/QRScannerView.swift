import SwiftUI
import Vision
import VisionKit

struct QRScannerView: UIViewControllerRepresentable {
    var onQRCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onQRCodeScanned: onQRCodeScanned)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onQRCodeScanned: (String) -> Void
        private var hasScanned = false

        init(onQRCodeScanned: @escaping (String) -> Void) {
            self.onQRCodeScanned = onQRCodeScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !hasScanned else { return }
            switch item {
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    hasScanned = true
                    dataScanner.stopScanning()
                    onQRCodeScanned(payload)
                }
            default:
                break
            }
        }
    }
}
