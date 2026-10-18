import Foundation
import Testing

let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Test func infoPlistTargetsMacOS26AsAMenuBarApp() throws {
    let data = try Data(contentsOf: projectRoot.appendingPathComponent("Resources/Info.plist"))
    let info = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(info["LSMinimumSystemVersion"] as? String == "26.0")
    #expect(info["LSUIElement"] as? Bool == true)
    #expect(info["CFBundleExecutable"] as? String == "Iconeer")
    #expect(info["CFBundleIconFile"] as? String == "AppIcon")
}

@Test func packageTargetsMacOS26() throws {
    let manifest = try String(contentsOf: projectRoot.appendingPathComponent("Package.swift"), encoding: .utf8)

    #expect(manifest.contains("platforms: [.macOS(.v26)]"))
}
