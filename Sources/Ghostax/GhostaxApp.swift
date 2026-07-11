import AppKit
import SwiftUI

extension Notification.Name {
    static let ghostaxClosePane = Notification.Name("ghostaxClosePane")
    static let ghostaxSplitVertical = Notification.Name("ghostaxSplitVertical")
    static let ghostaxSplitHorizontal = Notification.Name("ghostaxSplitHorizontal")
}

@main
struct GhostaxApp: App {
    @NSApplicationDelegateAdaptor(GhostaxApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "project-window", for: String.self) { $projectPath in
            AppShellView(initialProjectPath: projectPath)
                .frame(minWidth: 360, minHeight: 600)
                .background(NewWindowBridge(appDelegate: appDelegate))
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
    var openNewWindow: (() -> Void)?

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
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if flags == .command {
                switch event.keyCode {
                case 2: // Cmd+D
                    NotificationCenter.default.post(name: .ghostaxSplitVertical, object: nil)
                    return nil
                case 12:
                    Task { @MainActor in
                        NSApplication.shared.terminate(nil)
                    }
                    return nil
                case 13:
                    NotificationCenter.default.post(name: .ghostaxClosePane, object: nil)
                    return nil
                case 45: // Cmd+N
                    self?.openNewWindow?()
                    return nil
                default:
                    return event
                }
            }

            if flags == [.command, .shift] {
                switch event.keyCode {
                case 2: // Cmd+Shift+D
                    NotificationCenter.default.post(name: .ghostaxSplitHorizontal, object: nil)
                    return nil
                default:
                    return event
                }
            }

            return event
        }
    }
}

private struct NewWindowBridge: View {
    let appDelegate: GhostaxApplicationDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .onAppear {
                appDelegate.openNewWindow = { [openWindow] in
                    openWindow(id: "project-window")
                }
            }
    }
}