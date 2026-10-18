import Foundation

public enum Support: Equatable, Sendable {
    case supported
    case appStore
    case system
    case notWritable
}

public struct InstalledApp: Equatable, Sendable {
    public var url: URL
    public var name: String
    public var bundleID: String?
    public var support: Support
    public var isCustomized: Bool
}

// Apps under the given folders and their subfolders, sorted by name. Bundles inside a bundle
// (helpers, plug-ins) are not listed.
public func scanApps(in roots: [URL]) -> [InstalledApp] {
    var apps: [InstalledApp] = []
    for root in roots {
        guard let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
        for case let url as URL in items where url.pathExtension == "app" {
            items.skipDescendants()
            apps.append(
                InstalledApp(
                    url: url, name: url.deletingPathExtension().lastPathComponent,
                    bundleID: Bundle(url: url)?.bundleIdentifier,
                    support: support(of: url), isCustomized: isCustomized(url)))
        }
    }
    return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

// The rules run in this order, and the first match is the reason shown to the user. Apps from
// the App Store and from /System (Safari is a link into the system Cryptex) reject writes even
// from root, so they are never tried.
public func support(of app: URL) -> Support {
    let real = app.resolvingSymlinksInPath()
    if FileManager.default.fileExists(atPath: real.appendingPathComponent("Contents/_MASReceipt").path) { return .appStore }
    if real.path.hasPrefix("/System/") { return .system }
    if !FileManager.default.isWritableFile(atPath: real.path) { return .notWritable }
    return .supported
}
