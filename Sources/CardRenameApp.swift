import Combine
import SwiftUI

@main
struct CardRenameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The menu bar item and the window are AppKit objects owned by AppDelegate.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

/// Classic NSStatusItem rather than SwiftUI's MenuBarExtra: it gets its own autosave name
/// ("CardRename" instead of the generic "Item-0"), so menu bar managers such as Ice can list it.
///
/// The icon can still be hidden (notch, crowded menu bar, the "Show icon" setting...).
/// Opening the app again, or launching it for the first time, shows the same panel in a window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var window: NSWindow?
    private var watchers = Set<AnyCancellable>()
    private var visibilityWatch: NSKeyValueObservation?

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = Engine.shared

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "CardRename"
        statusItem.behavior = .removalAllowed   // Cmd-drag out of the menu bar hides it
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        statusItem.button?.toolTip = "Card Rename"

        let panel = NSHostingController(rootView: PanelView(engine: engine))
        panel.sizingOptions = .preferredContentSize
        popover.contentViewController = panel
        popover.behavior = .transient

        engine.$enabled
            .sink { [weak self] on in
                let image = NSImage(systemSymbolName: on ? "sdcard.fill" : "sdcard", accessibilityDescription: "Card Rename")
                image?.isTemplate = true
                self?.statusItem.button?.image = image
            }
            .store(in: &watchers)
        engine.$showMenuBarIcon
            .sink { [weak self] show in
                if self?.statusItem.isVisible != show { self?.statusItem.isVisible = show }
            }
            .store(in: &watchers)
        visibilityWatch = statusItem.observe(\.isVisible) { item, _ in
            let visible = item.isVisible
            Task { @MainActor in
                if Engine.shared.showMenuBarIcon != visible { Engine.shared.showMenuBarIcon = visible }
            }
        }

        LabrollStore.shared.openWindow = { [weak self] in self?.showLabrollWindow() }

        if !UserDefaults.standard.bool(forKey: "launchedBefore") {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    @MainActor @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @MainActor func showWindow() {
        if window == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                                  backing: .buffered, defer: false)
            window.title = "Card Rename"
            window.isReleasedWhenClosed = false
            let content = NSHostingView(rootView: PanelView(engine: .shared, inWindow: true))
            window.contentView = content
            window.setContentSize(content.fittingSize)   // size first, so center() uses the real size
            window.center()
            self.window = window
        }
        if let window { opened(window) }
    }

    private var labrollWindow: NSWindow?

    /// Clips of a card renamed LABROLL C### _YYYYMMDD _CAMID, copied or renamed in place.
    @MainActor func showLabrollWindow() {
        popover.performClose(nil)
        if labrollWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Labroll"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LabrollView(store: .shared))
            window.setFrameAutosaveName("Labroll")
            if !window.setFrameUsingName("Labroll") { window.center() }
            labrollWindow = window
        }
        if let labrollWindow { opened(labrollWindow) }
    }

    /// Windows open (minimised included). While any is, the app shows in the Dock and the app switcher.
    private var openWindows = Set<NSWindow>()

    @MainActor private func opened(_ window: NSWindow) {
        if openWindows.insert(window).inserted {
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose),
                                                   name: NSWindow.willCloseNotification, object: window)
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        openWindows.remove(window)
        if openWindows.isEmpty { NSApp.setActivationPolicy(.accessory) }
    }
}

struct PanelView: View {
    // No @State here: it is a macro in the current SDK and the Command Line Tools ship without its plugin.
    @ObservedObject var engine: Engine
    var inWindow = false

    static let version: String = {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "?"
        return "v\(short) (\(info["CFBundleVersion"] as? String ?? "?"))"
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Card Rename").font(.headline)
                Text(Self.version).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if engine.busy { ProgressView().controlSize(.small) }
            }

            if inWindow {
                Text("Card Rename runs in the menu bar (SD card icon). If the icon is hidden, open the app again from Applications to show this window.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Rename cards automatically", isOn: $engine.enabled)
                .toggleStyle(.switch)

            HStack {
                Button("Rename cards now") { Task { await engine.renameNow() } }
                Spacer()
                Button("Labroll…") { LabrollStore.shared.openWindow?() }
                    .help("Rename the clips of a card A001C001_YYYYMMDD_CAMID, copied or in place")
            }

            Divider()

            Text("Recent renames").font(.subheadline).foregroundStyle(.secondary)
            if engine.recent.isEmpty {
                Text("None yet").foregroundStyle(.secondary)
            }
            ForEach(engine.recent.prefix(8)) { entry in
                HStack {
                    Text(entry.timeLabel).monospacedDigit().foregroundStyle(.secondary)
                    Text("\(entry.old) → \(entry.new)")
                    Spacer()
                    if entry.undone {
                        Text("undone").foregroundStyle(.secondary)
                    } else if engine.isMounted(entry) {
                        Button("Clips") { engine.sendToLabroll(entry) }
                            .help("List this card's clips in the Labroll window")
                        Button("Undo") { Task { await engine.undo(entry) } }
                    } else {
                        Text("not mounted").foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            DisclosureGroup("Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default card names, comma separated").font(.caption).foregroundStyle(.secondary)
                    TextField("UNTITLED, NO NAME, DJI", text: $engine.defaultNames)
                    Toggle("Ask for a name when clips have no reel ID", isOn: $engine.askWhenNoReel)
                    Toggle("Name cards without reel ID after the labroll", isOn: $engine.labrollForNoReel)
                    Text("A001_GOPRO from the Labroll window's next labroll and Cam ID; the card's clips are listed there once it is ready.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle("Eject the card after renaming", isOn: $engine.ejectAfterRename)
                    Text("""
                        After a rename, eject the card and insert it again before offloading. \
                        Until then Finder and offload apps can often not see a new card mounted \
                        with a duplicate "Untitled" name.
                        """)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle("Open at login", isOn: Binding(get: { engine.openAtLogin },
                                                          set: { engine.setOpenAtLogin($0) }))
                    Toggle("Show icon in menu bar", isOn: $engine.showMenuBarIcon)
                    if !engine.showMenuBarIcon {
                        Text("Cards are still renamed. Open the app again from Applications to show this window.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 6)
            }

            Divider()

            HStack {
                Button("Open log") { engine.openLog() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
