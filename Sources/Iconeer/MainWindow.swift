import AppKit
import IconeerCore
import SwiftUI

@MainActor
func makeMainWindow(model: AppModel) -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false)
    window.title = "Iconeer"
    window.isReleasedWhenClosed = false
    window.contentViewController = NSHostingController(rootView: MainView(model: model))
    window.setContentSize(NSSize(width: 900, height: 600))
    window.center()
    return window
}

struct MainView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            let sections = model.sections
            List(selection: Binding(get: { model.selected?.url }, set: { model.select($0) })) {
                AppSection(title: "Customized", apps: sections.customized)
                AppSection(title: "Apps", apps: sections.apps)
                AppSection(title: "Can't Change", apps: sections.unsupported)
            }
            .searchable(text: $model.filter, placement: .sidebar, prompt: "Search apps")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                if let app = model.selected {
                    AppDetail(model: model, app: app)
                } else {
                    Text("Select an app to change its icon.").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let message = model.message {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(model.selected?.name ?? "Iconeer")
            .toolbar {
                Button {
                    model.reload()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh the app list (⌘R)")
            }
        }
        .frame(minWidth: 760, minHeight: 480)
    }
}

// A sidebar section; an empty one is left out.
struct AppSection: View {
    let title: LocalizedStringKey
    let apps: [InstalledApp]

    var body: some View {
        if !apps.isEmpty {
            Section(title) {
                ForEach(apps, id: \.url) { AppRow(app: $0).tag($0.url) }
            }
        }
    }
}

struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 24, height: 24)
            Text(app.name)
            Spacer()
            if let reason = unsupportedReason(app.support) {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
        }
        .opacity(app.support == .supported ? 1 : 0.5)
    }
}

func unsupportedReason(_ support: Support) -> String? {
    switch support {
    case .supported: nil
    case .appStore: String(localized: "App Store")
    case .system: String(localized: "System")
    case .notWritable: String(localized: "No permission")
    }
}

struct AppDetail: View {
    @ObservedObject var model: AppModel
    let app: InstalledApp

    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 48, height: 48)
            Text(app.name).font(.title2)
            Spacer()
            if app.support == .supported {
                Button("Choose Image…", action: model.applyFile)
                if app.isCustomized { Button("Revert", action: model.revert) }
            }
        }
        if app.support != .supported {
            Text(IconeerService.message(for: ApplyError.unsupported(app.support))).foregroundStyle(.secondary)
        } else {
            HStack {
                TextField("Search macOSicons", text: $model.query).onSubmit { Task { await model.search() } }
                Button("Search") { Task { await model.search() } }.disabled(model.query.isEmpty || model.isWorking)
                if model.isWorking { ProgressView().controlSize(.small) }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104))], spacing: 12) {
                    ForEach(model.results, id: \.objectID) { hit in
                        Button {
                            Task { await model.apply(hit) }
                        } label: {
                            ResultCell(hit: hit)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isWorking)
                    }
                }
                if model.nextPage != nil {
                    Button("Load More") { Task { await model.loadMore() } }.disabled(model.isWorking).padding(.top, 8)
                }
            }
        }
    }
}

struct ResultCell: View {
    let hit: SearchHit

    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: hit.pngURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 80, height: 80)
            Text(IconeerService.credit(of: hit)).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 104)
        .help("Apply this icon")
    }
}
