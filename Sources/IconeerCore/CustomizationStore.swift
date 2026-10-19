import Foundation

public enum IconSource: Codable, Equatable, Sendable {
    case catalog(objectID: String, appName: String, author: String?)
    case file(originalName: String)
}

public struct Customization: Codable, Equatable, Sendable {
    public var appPath: String
    public var bundleID: String?
    public var iconFile: String
    public var source: IconSource
    public var appliedAt: Date
}

public enum StoreError: Error, Equatable {
    // customizations.json exists but can't be decoded.
    case unreadable
}

// customizations.json plus a copy of each applied image in icons/. The image is kept for as
// long as the customization exists, so reapplying after an app update needs no download.
public struct CustomizationStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    var file: URL { directory.appendingPathComponent("customizations.json") }
    var icons: URL { directory.appendingPathComponent("icons") }

    // A missing file is an empty store. A file that can't be decoded throws, so that adding or
    // removing never writes over customizations that are still there.
    public func all() throws -> [Customization] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        guard let data = try? Data(contentsOf: file),
            let list = try? JSONDecoder().decode([Customization].self, from: data)
        else { throw StoreError.unreadable }
        return list
    }

    public func iconURL(of customization: Customization) -> URL {
        icons.appendingPathComponent(customization.iconFile)
    }

    // Replaces any previous customization of the same app, and its image.
    @discardableResult
    public func add(app: URL, bundleID: String?, image: URL, source: IconSource, at date: Date = Date()) throws -> Customization {
        let list = try all()
        try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
        let iconFile = UUID().uuidString + "." + image.pathExtension
        try FileManager.default.copyItem(at: image, to: icons.appendingPathComponent(iconFile))
        deleteImages(of: app, in: list)
        let customization = Customization(appPath: app.path, bundleID: bundleID, iconFile: iconFile, source: source, appliedAt: date)
        try write(list.filter { $0.appPath != app.path } + [customization])
        return customization
    }

    public func remove(app: URL) throws {
        let list = try all()
        deleteImages(of: app, in: list)
        try write(list.filter { $0.appPath != app.path })
    }

    private func deleteImages(of app: URL, in list: [Customization]) {
        for old in list where old.appPath == app.path {
            try? FileManager.default.removeItem(at: iconURL(of: old))
        }
    }

    func write(_ list: [Customization]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(list).write(to: file, options: .atomic)
    }
}
