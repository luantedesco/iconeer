import Foundation
import Testing

@testable import IconeerCore

// A customized app whose bundle was just replaced by an update: recorded, but no Icon\r.
@MainActor func updatedApp(in store: CustomizationStore) throws -> URL {
    let app = try signedAppCopy()
    try applyIcon(from: sampleIcon, to: app)
    try store.add(app: app, bundleID: nil, image: sampleIcon, source: .file(originalName: "a.icns"))
    try revertIcon(of: app)
    return app
}

@MainActor @Test func iconLostInAnUpdateIsReapplied() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    let app = try updatedApp(in: store)

    let result = reapplyMissing(in: store)

    #expect(result.map(\.customization.appPath) == [app.path])
    #expect(result.first?.error == nil)
    #expect(isCustomized(app))
    #expect(try codesignVerifies(app))
}

@MainActor @Test func appsThatKeptTheirIconAreLeftAlone() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    let app = try updatedApp(in: store)
    try applyIcon(from: sampleIcon, to: app)

    #expect(reapplyMissing(in: store).isEmpty)
}

@MainActor @Test func uninstalledAppIsSkippedAndKeepsItsCustomization() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    let app = try updatedApp(in: store)
    try FileManager.default.removeItem(at: app)

    #expect(reapplyMissing(in: store).isEmpty)
    #expect(store.all().count == 1)
}

@MainActor @Test func failureCarriesTheCause() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    _ = try updatedApp(in: store)
    try FileManager.default.removeItem(at: store.iconURL(of: store.all()[0]))

    #expect(reapplyMissing(in: store).first?.error == .invalidImage)
}

@MainActor @Test func failureNoticeNamesTheAppAndTheCause() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    _ = try updatedApp(in: store)
    try FileManager.default.removeItem(at: store.iconURL(of: store.all()[0]))

    let notice = try #require(reapplyMissing(in: store).first.flatMap(failureNotice))

    #expect(notice.contains("Sample"))
    #expect(notice.contains(IconeerService.message(for: ApplyError.invalidImage)))
}

@MainActor @Test func successHasNoNotice() throws {
    let store = CustomizationStore(directory: try temporaryFolder())
    _ = try updatedApp(in: store)

    #expect(reapplyMissing(in: store).compactMap(failureNotice).isEmpty)
}
