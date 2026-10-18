import AppKit

public enum DockRefresh: Equatable, Sendable {
    case refreshed
    // The Dock keeps the old icon of a running app until it quits.
    case afterNextLaunch
}

// Touching the bundle and restarting the Dock makes it show the new icon of an app that is not
// running; restarting the Dock alone is not enough.
public func refreshDock(
    for app: URL,
    isRunning: (URL) -> Bool = isAppRunning,
    run: (String, [String]) -> Void = runTool
) -> DockRefresh {
    if isRunning(app) { return .afterNextLaunch }
    try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: app.path)
    run("/usr/bin/killall", ["Dock"])
    return .refreshed
}

public func isAppRunning(_ app: URL) -> Bool {
    let target = app.resolvingSymlinksInPath().standardizedFileURL
    return NSWorkspace.shared.runningApplications.contains {
        $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == target
    }
}

public func runTool(_ path: String, _ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
}
