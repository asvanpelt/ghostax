import SwiftUI

struct AccentColorMenu: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ForEach(WindowAccent.allPresets) { accent in
            Button {
                appState.setWindowAccent(accent)
            } label: {
                HStack {
                    Image(systemName: appState.windowAccent == accent ? "checkmark.circle.fill" : "circle.fill")
                    Text(accent.displayName)
                }
            }
        }

        Divider()

        Button("Custom Hex...") {
            promptForHexColor { hex in
                let accent = WindowAccent.custom(hex)
                appState.setWindowAccent(accent)
                if let path = appState.workspace?.url.path {
                    WorkspaceLayoutStore.setAccent(accent, path: path)
                }
            }
        }

        Divider()

        Button("Default") {
            if let path = appState.workspace?.url.path {
                appState.setWindowAccent(WindowAccent.stableColor(for: path))
            }
        }
    }
}

struct BookmarkAccentMenu: View {
    @EnvironmentObject private var appState: AppState
    var item: BookmarkItem

    var body: some View {
        let current = WorkspaceLayoutStore.accent(for: item.path)

        ForEach(WindowAccent.allPresets) { accent in
            Button {
                WorkspaceLayoutStore.setAccent(accent, path: item.path)
                if isCurrentProject {
                    appState.setWindowAccent(accent)
                }
            } label: {
                HStack {
                    if current == accent {
                        Image(systemName: "checkmark")
                    }
                    Text(accent.displayName)
                }
            }
        }

        Divider()

        Button("Custom Hex...") {
            promptForHexColor { hex in
                let accent = WindowAccent.custom(hex)
                WorkspaceLayoutStore.setAccent(accent, path: item.path)
                if isCurrentProject {
                    appState.setWindowAccent(accent)
                }
            }
        }

        Divider()

        Button("Default") {
            let defaultAccent = WindowAccent.stableColor(for: item.path)
            WorkspaceLayoutStore.setAccent(defaultAccent, path: item.path)
            if isCurrentProject {
                appState.setWindowAccent(defaultAccent)
            }
        }
    }

    private var isCurrentProject: Bool {
        appState.workspace?.url.standardizedFileURL.path == URL(fileURLWithPath: item.path).standardizedFileURL.path
    }
}

@MainActor
private func promptForHexColor(completion: @escaping (String) -> Void) {
    let alert = NSAlert()
    alert.messageText = "Custom Color"
    alert.informativeText = "Enter a hex color code (e.g. #FF6B35):"
    alert.addButton(withTitle: "Apply")
    alert.addButton(withTitle: "Cancel")

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    field.placeholderString = "#FF6B35"
    alert.accessoryView = field

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        let hex = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hex.isEmpty {
            completion(hex)
        }
    }
}
