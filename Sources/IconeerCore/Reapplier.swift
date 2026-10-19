import Foundation

public struct Reapplied: Equatable, Sendable {
    public var customization: Customization
    public var error: ApplyError?
}

// An app update replaces the whole bundle, and the custom icon goes with it. Every customized
// app that is installed but no longer has its icon gets the stored image again. Apps that are
// not installed are skipped and keep their customization, in case they come back.
@MainActor
public func reapplyMissing(in store: CustomizationStore) throws -> [Reapplied] {
    try store.all().compactMap { customization in
        let app = URL(fileURLWithPath: customization.appPath)
        guard FileManager.default.fileExists(atPath: app.path), !isCustomized(app) else { return nil }
        do {
            try applyIcon(from: store.iconURL(of: customization), to: app)
            return Reapplied(customization: customization, error: nil)
        } catch {
            return Reapplied(customization: customization, error: error as? ApplyError ?? .writeFailed)
        }
    }
}

public func failureNotice(_ reapplied: Reapplied) -> String? {
    guard let error = reapplied.error else { return nil }
    let name = URL(fileURLWithPath: reapplied.customization.appPath).deletingPathExtension().lastPathComponent
    return String(localized: "Iconeer couldn't restore \(name)'s icon. \(IconeerService.message(for: error))")
}
