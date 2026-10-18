// swift-tools-version: 6.2
import Foundation
import PackageDescription

// With the Command Line Tools as the active toolchain, the test build sometimes misses the Swift
// Testing macro plugin ("plugin for module 'TestingMacros' not found"); loading it by path avoids
// that. With Xcode active the plugin is found, and loading the Command Line Tools one breaks the
// build, so the flag is only added when no Xcode is selected.
let commandLineTools = "/Library/Developer/CommandLineTools"
let developerDir =
    ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
    ?? (try? FileManager.default.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link")) ?? commandLineTools
let testingMacros = commandLineTools + "/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
let testSettings: [SwiftSetting] =
    developerDir.hasPrefix(commandLineTools) && FileManager.default.fileExists(atPath: testingMacros)
    ? [.unsafeFlags(["-load-plugin-library", testingMacros])] : []

let package = Package(
    name: "Iconeer",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "IconeerCore"),
        .executableTarget(name: "Iconeer", dependencies: ["IconeerCore"]),
        .testTarget(name: "IconeerCoreTests", dependencies: ["IconeerCore"], swiftSettings: testSettings),
    ]
)
