import SwiftUI

@main
struct CardRenameApp: App {
    @ObservedObject private var engine = Engine.shared

    var body: some Scene {
        MenuBarExtra {
            PanelView(engine: engine)
        } label: {
            Image(systemName: engine.enabled ? "sdcard.fill" : "sdcard")
        }
        .menuBarExtraStyle(.window)
    }
}

struct PanelView: View {
    // No @State here: it is a macro in the current SDK and the Command Line Tools ship without its plugin.
    @ObservedObject var engine: Engine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Card Rename").font(.headline)
                Spacer()
                if engine.busy { ProgressView().controlSize(.small) }
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
