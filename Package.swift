// swift-tools-version: 6.2
import Foundation
import PackageDescription

// With only the Command Line Tools installed, the test build sometimes misses the Swift Testing
// macro plugin ("plugin for module 'TestingMacros' not found"); loading it by path avoids that.
let testingMacros = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
let testSettings: [SwiftSetting] =
    FileManager.default.fileExists(atPath: testingMacros)
    ? [.unsafeFlags(["-load-plugin-library", testingMacros])] : []

let package = Package(
    name: "Iconeer",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "IconeerCore"),
        .testTarget(name: "IconeerCoreTests", dependencies: ["IconeerCore"], swiftSettings: testSettings),
    ]
)
