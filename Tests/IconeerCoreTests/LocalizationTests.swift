import Foundation
import Testing

@testable import IconeerCore

// Every Resources/<language>.lproj/Localizable.strings, by language code. English is the key and has no file.
func allTranslations() throws -> [String: [String: String]] {
    let resources = projectRoot.appendingPathComponent("Resources")
    var result: [String: [String: String]] = [:]
    for folder in try FileManager.default.contentsOfDirectory(atPath: resources.path) where folder.hasSuffix(".lproj") {
        let url = resources.appendingPathComponent("\(folder)/Localizable.strings")
        result[String(folder.dropLast(".lproj".count))] = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(folder)")
    }
    return result
}

// The English text is the key, so every literal shown to the user must appear in every language.
// Interpolated texts are covered by the core test below, with their %@ and %lld keys.
@Test func everyInterfaceTextHasATranslation() throws {
    let translations = try allTranslations()
    let pattern = try Regex(
        #"(?:String\(localized: |Text\(|Button\(|Section\(|Label\(|TextField\(|SecureField\(|\.help\(|prompt: |title: )"([^"\\]+)""#)
    let sources = projectRoot.appendingPathComponent("Sources")
    var missing: [String] = []
    for file in try FileManager.default.subpathsOfDirectory(atPath: sources.path) where file.hasSuffix(".swift") {
        let code = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
        for match in code.matches(of: pattern) {
            let key = String(match.output[1].substring ?? "")
            for (language, strings) in translations where key != "Iconeer" && strings[key] == nil {
                missing.append("\(language) \(file): \(key)")
            }
        }
    }

    #expect(missing.isEmpty, "\(missing)")
}

@Test func everyCoreMessageHasATranslation() throws {
    let translations = try allTranslations()
    let errors: [Error] = [
        ApplyError.unsupported(.appStore), ApplyError.unsupported(.system), ApplyError.unsupported(.notWritable),
        ApplyError.invalidImage, ApplyError.writeFailed, APIError.missingKey, APIError.invalidKey,
        APIError.quotaExceeded, APIError.invalidResponse,
    ]
    let keys =
        errors.map { IconeerService.message(for: $0) } + [
            IconeerService.terms, "by %@ · macOSicons.com", "macOSicons error %lld.", "macOSicons error %lld: %@.",
            "Iconeer couldn't restore %@'s icon. %@",
        ]

    for (language, strings) in translations {
        for key in keys { #expect(strings[key] != nil, "\(language): \(key)") }
    }
}

@Test func translationsKeepTheirPlaceholders() throws {
    func placeholders(_ text: String) -> [String] { text.matches(of: /%(@|lld)/).map { String($0.output.0) }.sorted() }

    for (language, strings) in try allTranslations() {
        for (key, value) in strings { #expect(placeholders(key) == placeholders(value), "\(language): \(key)") }
    }
}

@Test func infoPlistDeclaresEveryLanguage() throws {
    let data = try Data(contentsOf: projectRoot.appendingPathComponent("Resources/Info.plist"))
    let info = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(info["CFBundleDevelopmentRegion"] as? String == "en")
    #expect(info["CFBundleLocalizations"] as? [String] == ["en"] + (try allTranslations().keys.sorted()))
}
