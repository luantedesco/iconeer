import AppKit
import IconeerCore
import SwiftUI

@MainActor
func makeSettingsWindow(model: AppModel) -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
        styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = String(localized: "Iconeer Settings")
    window.isReleasedWhenClosed = false
    window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
    window.center()
    return window
}

// The API key is optional: it is needed only to search the macOSicons catalog.
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                SecureField("API key", text: $model.keyDraft, prompt: Text(model.hasKey ? "A key is saved" : "Paste your key"))
                    .onSubmit(model.saveKey)
                HStack {
                    Link("Create a key at macosicons.com/developers", destination: URL(string: "https://macosicons.com/developers")!)
                    Spacer()
                    Button("Clear", action: model.clearKey).disabled(!model.hasKey)
                    Button("Save", action: model.saveKey).disabled(model.keyDraft.isEmpty).keyboardShortcut(.defaultAction)
                }
            } header: {
                Text("macOSicons API key")
            } footer: {
                Text("Optional. Needed only to search the catalog; Choose Image… works without it. Iconeer keeps it in your Keychain.")
                    .foregroundStyle(.secondary)
            }
            Section("Icon credits and terms") {
                Text(IconeerService.terms).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
