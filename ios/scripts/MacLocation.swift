// Prints this Mac's current location as "latitude,longitude" (Wi-Fi based, from Location
// Services). Used by use-mac-location.sh to give the iOS Simulator the Mac's real position.
import CoreLocation
import Foundation

final class Finder: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var started = false

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        locationManagerDidChangeAuthorization(manager)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            fail("Location access is off for this app. Turn it on in System Settings › Privacy & Security › Location Services.")
        default:
            if !started {
                started = true
                manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        let line = String(format: "%.6f,%.6f", location.coordinate.latitude, location.coordinate.longitude)
        print(line)
        // When started with `open`, stdout isn't the terminal, so also write to the file the
        // script reads.
        if let path = ProcessInfo.processInfo.environment["MAC_LOCATION_OUT"] ?? CommandLine.arguments.dropFirst().first {
            try? (line + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
        FileHandle.standardError.write("accuracy ±\(Int(location.horizontalAccuracy)) m\n".data(using: .utf8)!)
        exit(0)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown { return }
        fail("Couldn't get the Mac's location: \(error.localizedDescription)")
    }

    private func fail(_ message: String) -> Never {
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
        if let path = CommandLine.arguments.dropFirst().first {
            try? ("error: " + message + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
        exit(1)
    }
}

import AppKit
// A regular app (not a bare command-line tool), so macOS can show the location permission prompt.
NSApplication.shared.setActivationPolicy(.accessory)
let finder = Finder()
finder.start()
DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
    FileHandle.standardError.write("Timed out waiting for the Mac's location.\n".data(using: .utf8)!)
    exit(1)
}
NSApplication.shared.run()
