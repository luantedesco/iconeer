import Foundation
import Testing

@testable import IconeerCore

@Test func customizationSurvivesReloadingTheStore() throws {
    let directory = try temporaryFolder()
    let app = URL(fileURLWithPath: "/Applications/Sample.app")
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    try CustomizationStore(directory: directory).add(
        app: app, bundleID: "test.sample", image: sampleIcon,
        source: .catalog(objectID: "abc", appName: "Sample", author: "Someone"), at: date)

    let reloaded = CustomizationStore(directory: directory)
    let saved = try #require(try reloaded.all().first)
    #expect(saved.appPath == app.path)
    #expect(saved.bundleID == "test.sample")
    #expect(saved.source == .catalog(objectID: "abc", appName: "Sample", author: "Someone"))
    #expect(saved.appliedAt == date)
    #expect(FileManager.default.contentsEqual(atPath: reloaded.iconURL(of: saved).path, andPath: sampleIcon.path))
}

@Test func fileSourceIsKept() throws {
    let store = CustomizationStore(directory: try temporaryFolder())

    try store.add(
        app: URL(fileURLWithPath: "/Applications/Sample.app"), bundleID: nil, image: sampleIcon,
        source: .file(originalName: "AlertStopIcon.icns"))

    #expect(try store.all().first?.source == .file(originalName: "AlertStopIcon.icns"))
}

@Test func addingAgainReplacesTheCustomizationAndItsImage() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    let app = URL(fileURLWithPath: "/Applications/Sample.app")
    let first = try store.add(app: app, bundleID: nil, image: sampleIcon, source: .file(originalName: "a.icns"))

    try store.add(app: app, bundleID: nil, image: sampleIcon, source: .file(originalName: "b.icns"))

    #expect(try store.all().map(\.source) == [.file(originalName: "b.icns")])
    #expect(!FileManager.default.fileExists(atPath: store.iconURL(of: first).path))
}

@Test func removeDeletesRecordAndImage() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    let app = URL(fileURLWithPath: "/Applications/Sample.app")
    let saved = try store.add(app: app, bundleID: nil, image: sampleIcon, source: .file(originalName: "a.icns"))

    try store.remove(app: app)

    #expect(try store.all().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: store.iconURL(of: saved).path))
}

@Test func missingFileIsAnEmptyStore() throws {
    #expect(try CustomizationStore(directory: try temporaryFolder()).all().isEmpty)
}

@Test func unreadableFileIsNeitherReadNorOverwritten() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    let garbage = Data("not json".utf8)
    try garbage.write(to: store.file)

    #expect(throws: StoreError.unreadable) { try store.all() }
    #expect(throws: StoreError.unreadable) {
        try store.add(
            app: URL(fileURLWithPath: "/Applications/Sample.app"), bundleID: nil, image: sampleIcon,
            source: .file(originalName: "a.icns"))
    }
    #expect(throws: StoreError.unreadable) { try store.remove(app: URL(fileURLWithPath: "/Applications/Sample.app")) }
    #expect(try Data(contentsOf: store.file) == garbage)
}
