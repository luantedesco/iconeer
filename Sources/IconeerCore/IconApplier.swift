import AppKit

public enum ApplyError: Error, Equatable {
    case unsupported(Support)
    case invalidImage
    case writeFailed
}

// A custom icon is the "Icon\r" file at the bundle's root plus a Finder info flag, both written
// by NSWorkspace. Nothing inside Contents/ changes, so the app's code signature stays valid.
public func customIconFile(of app: URL) -> URL {
    app.appendingPathComponent("Icon\r")
}

public func isCustomized(_ app: URL) -> Bool {
    FileManager.default.fileExists(atPath: customIconFile(of: app).path)
}

// setIcon fails now and then when called from several threads at once.
@MainActor
public func applyIcon(from image: URL, to app: URL) throws {
    guard let icon = NSImage(contentsOf: image), icon.isValid else { throw ApplyError.invalidImage }
    guard NSWorkspace.shared.setIcon(icon, forFile: app.path) else { throw ApplyError.writeFailed }
}

@MainActor
public func revertIcon(of app: URL) throws {
    guard NSWorkspace.shared.setIcon(nil, forFile: app.path) else { throw ApplyError.writeFailed }
}
