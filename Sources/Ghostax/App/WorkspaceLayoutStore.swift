import Foundation

struct WorkspaceWindowLayout: Codable {
    var panes: [TerminalPane]
    var layout: TerminalLayoutNode
    var activePaneID: TerminalPane.ID
    var accent: WindowAccent
}

enum WorkspaceLayoutStore {
    private static let prefix = "ghostax.workspaceLayout."

    static func load(path: String) -> WorkspaceWindowLayout? {
        guard let data = UserDefaults.standard.data(forKey: key(for: path)) else { return nil }
        return try? JSONDecoder().decode(WorkspaceWindowLayout.self, from: data)
    }

    static func save(_ layout: WorkspaceWindowLayout, path: String) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaults.standard.set(data, forKey: key(for: path))
    }

    static func setAccent(_ accent: WindowAccent, path: String) {
        if var layout = load(path: path) {
            layout.accent = accent
            save(layout, path: path)
        } else {
            let pane = TerminalPane(cwd: path)
            let layout = WorkspaceWindowLayout(
                panes: [pane],
                layout: .pane(pane.id),
                activePaneID: pane.id,
                accent: accent
            )
            save(layout, path: path)
        }
    }

    static func accent(for path: String) -> WindowAccent? {
        load(path: path)?.accent
    }

    private static func key(for path: String) -> String {
        let encoded = Data(path.utf8).base64EncodedString()
        return prefix + encoded
    }
}
