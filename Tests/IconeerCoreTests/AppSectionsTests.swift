import Foundation
import Testing

@testable import IconeerCore

func app(_ name: String, _ support: Support = .supported, customized: Bool = false) -> InstalledApp {
    InstalledApp(
        url: URL(fileURLWithPath: "/Applications/\(name).app"), name: name, bundleID: nil,
        support: support, isCustomized: customized)
}

@Test func splitsAppsIntoSectionsKeepingTheirOrder() {
    let list = [
        app("Claude"), app("Discord", customized: true), app("Ghostty"), app("Safari", .system),
        app("Spotify", customized: true),
    ]

    let result = sections(of: list, filter: "")

    #expect(result.customized.map(\.name) == ["Discord", "Spotify"])
    #expect(result.apps.map(\.name) == ["Claude", "Ghostty"])
    #expect(result.unsupported.map(\.name) == ["Safari"])
}

@Test func customizedAppThatCannotBeChangedGoesToUnsupported() {
    let result = sections(of: [app("Xcode", .appStore, customized: true)], filter: "")

    #expect(result.customized.isEmpty)
    #expect(result.unsupported.map(\.name) == ["Xcode"])
}

@Test func filterIgnoresCaseAndAccents() {
    let list = [app("Música"), app("Discord"), app("Notes")]

    #expect(sections(of: list, filter: "MUSICA").apps.map(\.name) == ["Música"])
    #expect(sections(of: list, filter: "cord").apps.map(\.name) == ["Discord"])
    #expect(sections(of: list, filter: "zzz") == AppSections())
}

@Test func emptyOrBlankFilterShowsEveryApp() {
    let list = [app("Claude"), app("Discord")]

    #expect(sections(of: list, filter: "").apps.count == 2)
    #expect(sections(of: list, filter: "  ").apps.count == 2)
}
