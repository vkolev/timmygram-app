import Foundation
import UIKit

enum DeviceIdentifier {
    static func waitForIdentifier(timeout: TimeInterval = 2.0) async -> String? {
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }

        let pollInterval: TimeInterval = 0.1
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            try? await Task.sleep(for: .seconds(pollInterval))
            if let id = UIDevice.current.identifierForVendor?.uuidString {
                return id
            }
        }

        return nil
    }
}
