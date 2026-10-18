import Foundation
import Testing

@testable import IconeerCore

func portugueseStrings() throws -> [String: String] {
    let url = projectRoot.appendingPathComponent("Resources/pt-BR.lproj/Localizable.strings")
    return try #require(NSDictionary(contentsOf: url) as? [String: String])
}

// The English text is the key, so every literal shown to the user must appear in the pt-BR file.
// Interpolated texts are covered by the core test below, with their %@ and %lld keys.
@Test func everyInterfaceTextHasAPortugueseTranslation() throws {
    let translations = try portugueseStrings()
    let pattern = try Regex(
        #"(?:String\(localized: |Text\(|Button\(|Section\(|Label\(|TextField\(|SecureField\(|\.help\(|prompt: |title: )"([^"\\]+)""#)
    let sources = projectRoot.appendingPathComponent("Sources")
    var missing: [String] = []
    for file in try FileManager.default.subpathsOfDirectory(atPath: sources.path) where file.hasSuffix(".swift") {
        let code = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
        for match in code.matches(of: pattern) {
            let key = String(match.output[1].substring ?? "")
            if key != "Iconeer" && translations[key] == nil { missing.append("\(file): \(key)") }
        }
    }

    #expect(missing.isEmpty, "\(missing)")
}

@Test func everyCoreMessageHasAPortugueseTranslation() throws {
    let translations = try portugueseStrings()
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

    for key in keys { #expect(translations[key] != nil, "\(key)") }
}

@Test func translationsKeepTheirPlaceholders() throws {
    func placeholders(_ text: String) -> [String] { text.matches(of: /%(@|lld)/).map { String($0.output.0) }.sorted() }

    for (key, value) in try portugueseStrings() {
        #expect(placeholders(key) == placeholders(value), "\(key)")
    }
}

@Test func infoPlistDeclaresEnglishAndPortuguese() throws {
    let data = try Data(contentsOf: projectRoot.appendingPathComponent("Resources/Info.plist"))
    let info = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(info["CFBundleDevelopmentRegion"] as? String == "en")
    #expect(info["CFBundleLocalizations"] as? [String] == ["en", "pt-BR"])
}
