import Foundation
import IconeerCore

// While Iconeer runs, puts back every custom icon an app update removed: once at launch, for
// updates that happened while it was closed, then every 30 seconds.
@MainActor
final class BackgroundMonitor {
    static let interval: TimeInterval = 30
    let service: IconeerService
    let notifier: Notifier
    var onChange: () -> Void = {}
    private var timer: Timer?
    // A failure repeats on every check until the user acts; it is notified once per app, and
    // once for an unreadable store.
    private var notified: Set<String> = []
    private static let storeKey = "customizations.json"

    init(service: IconeerService, notifier: Notifier) {
        self.service = service
        self.notifier = notifier
    }

    func start() {
        service.cache.purge()
        check()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func check() {
        let results: [Reapplied]
        do {
            results = try reapplyMissing(in: service.store)
            notified.remove(Self.storeKey)
        } catch {
            if notified.insert(Self.storeKey).inserted { notifier.post(IconeerService.message(for: error)) }
            return
        }
        guard !results.isEmpty else { return }
        for result in results {
            let path = result.customization.appPath
            if let notice = failureNotice(result) {
                if notified.insert(path).inserted { notifier.post(notice) }
            } else {
                notified.remove(path)
                _ = refreshDock(for: URL(fileURLWithPath: path))
            }
        }
        onChange()
    }
}
