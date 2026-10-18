import CryptoKit
import Foundation
import Testing

@testable import IconeerCore

let sampleIcon = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns")

// A minimal app signed ad hoc in a temporary directory, so the tests never touch a real install.
// Copies of system apps do not work here: their signature does not verify outside /System.
func signedAppCopy() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let app = dir.appendingPathComponent("Sample.app")
    let macOS = app.appendingPathComponent("Contents/MacOS")
    try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: macOS.appendingPathComponent("Sample"))
    let info: [String: Any] = [
        "CFBundleIdentifier": "test.iconeer.sample", "CFBundleExecutable": "Sample",
        "CFBundlePackageType": "APPL", "CFBundleName": "Sample",
    ]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: app.appendingPathComponent("Contents/Info.plist"))
    try tool("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
    return app
}

@discardableResult
func tool(_ path: String, _ args: [String]) throws -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.standardError = FileHandle.nullDevice
    try p.run()
    p.waitUntilExit()
    return p.terminationStatus
}

// Hash of every file under Contents/, by relative path.
func contentsDigest(of app: URL) throws -> [String: String] {
    let contents = app.appendingPathComponent("Contents")
    var digest: [String: String] = [:]
    let files = FileManager.default.enumerator(at: contents, includingPropertiesForKeys: [.isRegularFileKey])!
    for case let file as URL in files where (try file.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
        let hash = SHA256.hash(data: try Data(contentsOf: file))
        digest[file.path.replacingOccurrences(of: contents.path, with: "")] = hash.description
    }
    return digest
}

func codesignVerifies(_ app: URL) throws -> Bool {
    try tool("/usr/bin/codesign", ["--verify", "--deep", app.path]) == 0
}

@MainActor @Test func applyWritesIconAtRootAndKeepsSignature() throws {
    let app = try signedAppCopy()
    try #require(try codesignVerifies(app))
    let before = try contentsDigest(of: app)

    try applyIcon(from: sampleIcon, to: app)

    #expect(isCustomized(app))
    #expect(try contentsDigest(of: app) == before)
    #expect(try codesignVerifies(app))
}

@MainActor @Test func revertRemovesIcon() throws {
    let app = try signedAppCopy()
    try applyIcon(from: sampleIcon, to: app)

    try revertIcon(of: app)

    #expect(!isCustomized(app))
    #expect(try codesignVerifies(app))
}

@MainActor @Test func applyRejectsFileThatIsNotAnImage() throws {
    let app = try signedAppCopy()
    let text = app.deletingLastPathComponent().appendingPathComponent("not-an-image.png")
    try Data("hello".utf8).write(to: text)

    #expect(throws: ApplyError.invalidImage) { try applyIcon(from: text, to: app) }
    #expect(!isCustomized(app))
}
