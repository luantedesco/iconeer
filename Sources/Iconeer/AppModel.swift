import AppKit
import IconeerCore
import UniformTypeIdentifiers

// State of the main and Settings windows, on top of IconeerService.
@MainActor
final class AppModel: ObservableObject {
    let service: IconeerService
    @Published var apps: [InstalledApp] = []
    @Published var selected: InstalledApp?
    @Published var query = ""
    @Published var results: [SearchHit] = []
    @Published var nextPage: Int?
    @Published var message: String?
    @Published var isWorking = false
    @Published var filter = ""
    @Published var keyDraft = ""
    @Published var hasKey: Bool
    // Opens the Settings window when a search needs the API key.
    var openSettings: () -> Void = {}

    init(service: IconeerService) {
        self.service = service
        hasKey = service.hasKey
        reload()
    }

    var sections: AppSections { IconeerCore.sections(of: apps, filter: filter) }

    func reload() {
        apps = service.apps()
        selected = apps.first { $0.url == selected?.url }
    }

    func select(_ url: URL?) {
        selected = apps.first { $0.url == url }
        query = selected.map(service.defaultQuery(for:)) ?? ""
        results = []
        nextPage = nil
        message = nil
    }

    func saveKey() {
        do {
            try service.saveKey(keyDraft)
            keyDraft = ""
            hasKey = service.hasKey
        } catch {
            report(error)
        }
    }

    func clearKey() {
        service.deleteKey()
        hasKey = service.hasKey
    }

    func search() async {
        await work {
            let page = try await self.service.search(self.query)
            self.results = page.hits
            self.nextPage = IconeerService.nextPage(after: page)
            if self.results.isEmpty { self.message = String(localized: "No icons found for \"\(self.query)\".") }
        }
    }

    func loadMore() async {
        guard let next = nextPage else { return }
        await work {
            let page = try await self.service.search(self.query, page: next)
            self.results += page.hits
            self.nextPage = IconeerService.nextPage(after: page)
        }
    }

    func apply(_ hit: SearchHit) async {
        guard let app = selected else { return }
        await work { self.done(try await self.service.apply(hit, to: app), app) }
    }

    func applyFile() {
        guard let app = selected else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .icns]
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do { done(try service.apply(file: file, to: app), app) } catch { report(error) }
    }

    func revert() {
        guard let app = selected else { return }
        do { done(try service.revert(app), app) } catch { report(error) }
    }

    private func done(_ refresh: DockRefresh, _ app: InstalledApp) {
        message =
            refresh == .refreshed
            ? String(localized: "\(app.name)'s icon changed.")
            : String(localized: "\(app.name) is open: the Dock shows the new icon the next time it opens.")
        reload()
    }

    private func work(_ task: @escaping () async throws -> Void) async {
        isWorking = true
        message = nil
        do { try await task() } catch {
            report(error)
            if case APIError.missingKey = error { openSettings() }
        }
        isWorking = false
    }

    private func report(_ error: Error) {
        logger.error("\(String(describing: error), privacy: .public)")
        message = IconeerService.message(for: error)
    }
}
