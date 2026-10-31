import SwiftUI

@main
struct CardRenameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var engine = Engine.shared

    var body: some Scene {
        // MenuBarExtra writes this binding back on every update: passing $engine.showMenuBarIcon
        // republishes the engine each time and loops at full CPU. Only store real changes.
        MenuBarExtra(isInserted: Binding(get: { engine.showMenuBarIcon },
                                         set: { if $0 != engine.showMenuBarIcon { engine.showMenuBarIcon = $0 } })) {
            PanelView(engine: engine)
        } label: {
            Image(systemName: engine.enabled ? "sdcard.fill" : "sdcard")
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar icon can be hidden (notch, crowded menu bar, Bartender...).
/// Opening the app again, or launching it for the first time, shows the same panel in a window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !UserDefaults.standard.bool(forKey: "launchedBefore") {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
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
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct PanelView: View {
    // No @State here: it is a macro in the current SDK and the Command Line Tools ship without its plugin.
    @ObservedObject var engine: Engine
    var inWindow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Card Rename").font(.headline)
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

            Button("Rename cards now") { Task { await engine.renameNow() } }

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
