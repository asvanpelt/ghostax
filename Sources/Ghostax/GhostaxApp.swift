import AppKit
import SwiftUI

extension Notification.Name {
    static let ghostaxOpenNewWindow = Notification.Name("ghostaxOpenNewWindow")
}

@main
struct GhostaxApp: App {
    @NSApplicationDelegateAdaptor(GhostaxApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "project-window", for: String.self) { $projectPath in
            AppShellView(initialProjectPath: projectPath)
                .frame(minWidth: 360, minHeight: 420)
                .background(NewWindowShortcutBridge())
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            GhostaxCommands()
        }
    }
}

struct GhostaxCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "project-window")
            }
            .keyboardShortcut("n", modifiers: [.command])
        }
    }
}

final class GhostaxApplicationDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let application = notification.object as? NSApplication else { return }
        application.setActivationPolicy(.regular)
        application.activate(ignoringOtherApps: true)
        installGlobalAppShortcuts()
    }

    func applicationWillTerminate(_: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    private func installGlobalAppShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .command else { return event }

            switch event.keyCode {
            case 12:
                Task { @MainActor in
                    NSApplication.shared.terminate(nil)
                }
                return nil
            case 13:
                Task { @MainActor in
                    NSApplication.shared.keyWindow?.performClose(nil)
                }
                return nil
            case 45:
                NotificationCenter.default.post(name: .ghostaxOpenNewWindow, object: nil)
                return nil
            default:
                return event
            }
        }
    }
}

private struct NewWindowShortcutBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .ghostaxOpenNewWindow)) { _ in
                openWindow(id: "project-window")
            }
    }
}
