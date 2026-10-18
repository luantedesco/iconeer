import Foundation
import Testing

@testable import IconeerCore

func temporaryFolder() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@discardableResult
func fakeApp(_ path: String, in root: URL, bundleID: String? = nil) throws -> URL {
    let app = root.appendingPathComponent(path)
    let contents = app.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    if let bundleID {
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": bundleID], format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
    }
    return app
}

@Test func listsAppsInSubfoldersButNotBundlesInsideApps() throws {
    let root = try temporaryFolder()
    try fakeApp("Plain.app", in: root, bundleID: "test.plain")
    try fakeApp("Utilities/Nested.app", in: root)
    try fakeApp("Plain.app/Contents/Helpers/Inner.app", in: root)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("Folder"), withIntermediateDirectories: true)

    let apps = scanApps(in: [root])

    #expect(apps.map(\.name) == ["Nested", "Plain"])
    #expect(apps.first { $0.name == "Plain" }?.bundleID == "test.plain")
}

@Test func scansEveryRoot() throws {
    let first = try temporaryFolder()
    let second = try temporaryFolder()
    try fakeApp("A.app", in: first)
    try fakeApp("B.app", in: second)

    #expect(scanApps(in: [first, second]).map(\.name) == ["A", "B"])
}

@Test func appStoreReceiptMarksAppStore() throws {
    let app = try fakeApp("Store.app", in: try temporaryFolder())
    try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/_MASReceipt"), withIntermediateDirectories: true)

    #expect(support(of: app) == .appStore)
}

@Test func linkIntoSystemMarksSystem() throws {
    let link = try temporaryFolder().appendingPathComponent("Calculator.app")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/System/Applications/Calculator.app"))

    #expect(support(of: link) == .system)
    #expect(scanApps(in: [link.deletingLastPathComponent()]).first?.support == .system)
}

@Test func readOnlyBundleMarksNotWritable() throws {
    let app = try fakeApp("Locked.app", in: try temporaryFolder())
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: app.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: app.path) }

    #expect(support(of: app) == .notWritable)
}

@Test func writableBundleIsSupported() throws {
    #expect(support(of: try fakeApp("Plain.app", in: try temporaryFolder())) == .supported)
}

@Test func iconFileMarksCustomized() throws {
    let root = try temporaryFolder()
    let custom = try fakeApp("Custom.app", in: root)
    try fakeApp("Plain.app", in: root)
    FileManager.default.createFile(atPath: customIconFile(of: custom).path, contents: Data())

    let apps = scanApps(in: [root])

    #expect(apps.first { $0.name == "Custom" }?.isCustomized == true)
    #expect(apps.first { $0.name == "Plain" }?.isCustomized == false)
}
