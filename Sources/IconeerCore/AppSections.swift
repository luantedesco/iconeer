import Foundation

public struct AppSections: Equatable, Sendable {
    public var customized: [InstalledApp] = []
    public var apps: [InstalledApp] = []
    public var unsupported: [InstalledApp] = []
}

// The sidebar list: apps whose name contains the filter, ignoring case and accents, split into
// sections. An app that can't be changed goes to `unsupported` even when it has a custom icon,
// because no action on it is available.
public func sections(of apps: [InstalledApp], filter: String) -> AppSections {
    let filter = filter.trimmingCharacters(in: .whitespaces)
    var result = AppSections()
    for app in apps where filter.isEmpty || app.name.range(of: filter, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
        if app.support != .supported {
            result.unsupported.append(app)
        } else if app.isCustomized {
            result.customized.append(app)
        } else {
            result.apps.append(app)
        }
    }
    return result
}
