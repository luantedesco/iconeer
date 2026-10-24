import AppKit
import IconeerCore
import ServiceManagement

// Iconeer lives only in the menu bar: it never shows in the Dock or Cmd+Tab, and its window opens
// from the menu bar icon. Closing the window does not quit it, so it keeps reapplying icons while
// it runs. Only Quit ends it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var settings: NSWindow!
    private var model: AppModel!
    private var monitor: BackgroundMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let service = IconeerService(
            dataDirectory: support.appendingPathComponent("Iconeer"),
            roots: [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")])
        let model = AppModel(service: service)
        self.model = model
        window = makeMainWindow(model: model)
        settings = makeSettingsWindow(model: model)
        model.openSettings = { [weak self] in self?.openSettings() }
        NSApp.mainMenu = makeMainMenu()
        let notifier = Notifier()
        notifier.requestPermission()
        monitor = BackgroundMonitor(service: service, notifier: notifier)
        monitor.onChange = { model.reload() }
        monitor.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "Iconeer")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: String(localized: "Open Iconeer"), action: #selector(openWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ","))
        let login = NSMenuItem(title: String(localized: "Open at Login"), action: #selector(toggleOpenAtLogin(_:)), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openWindow() { show(window) }
    @objc private func openSettings() {
        if !settings.isVisible { settings.center() }
        show(settings)
    }
    @objc private func refresh() { model.reload() }

    // Reapplying only happens while Iconeer runs, so starting with the Mac keeps it going after a restart.
    @objc private func toggleOpenAtLogin(_ item: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            try service.status == .enabled ? service.unregister() : service.register()
        } catch {
            NSApp.activate()
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = String(localized: "Open at Login couldn't be changed.")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        item.state = service.status == .enabled ? .on : .off
    }

    private func show(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    // Edit gives the text fields Copy and Paste; without it, ⌘V does nothing in the key field.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            main.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
        }
        func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            return item
        }
        submenu(
            "Iconeer",
            [
                item(String(localized: "Settings…"), #selector(openSettings), ","), .separator(),
                item(String(localized: "Quit Iconeer"), #selector(NSApplication.terminate(_:)), "q"),
            ])
        submenu(
            String(localized: "Edit"),
            [
                item(String(localized: "Undo"), Selector(("undo:")), "z"),
                item(String(localized: "Redo"), Selector(("redo:")), "z", [.command, .shift]),
                .separator(),
                item(String(localized: "Cut"), #selector(NSText.cut(_:)), "x"),
                item(String(localized: "Copy"), #selector(NSText.copy(_:)), "c"),
                item(String(localized: "Paste"), #selector(NSText.paste(_:)), "v"),
                item(String(localized: "Select All"), #selector(NSText.selectAll(_:)), "a"),
            ])
        submenu(String(localized: "View"), [item(String(localized: "Refresh"), #selector(refresh), "r")])
        submenu(String(localized: "Window"), [item(String(localized: "Close"), #selector(NSWindow.performClose(_:)), "w")])
        return main
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openWindow()
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
