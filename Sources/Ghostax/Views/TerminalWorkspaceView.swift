import SwiftUI

struct TerminalWorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let tab = appState.activeTab {
            TerminalLayoutView(
                node: tab.layout,
                panes: Dictionary(uniqueKeysWithValues: tab.panes.map { ($0.id, $0) }),
                activePaneID: tab.activePaneID
            )
        }
    }
}

private struct TerminalLayoutView: View {
    @EnvironmentObject private var appState: AppState

    var node: TerminalLayoutNode
    var panes: [TerminalPane.ID: TerminalPane]
    var activePaneID: TerminalPane.ID

    var body: some View {
        switch node {
        case let .pane(id):
            if let pane = panes[id] {
                TerminalSurface(
                    pane: pane,
                    isActive: pane.id == activePaneID,
                    state: appState.terminalState(for: pane),
                    onActivate: { appState.activatePane(pane.id) },
                    onTitleChange: { appState.updatePane(pane.id, title: $0) },
                    onCwdChange: { appState.updatePane(pane.id, cwd: $0) }
                )
            }
        case let .split(split):
            switch split.axis {
            case .horizontal:
                VStack(spacing: 1) {
                    TerminalLayoutView(node: split.first, panes: panes, activePaneID: activePaneID)
                    TerminalLayoutView(node: split.second, panes: panes, activePaneID: activePaneID)
                }
                .background(Color(nsColor: .separatorColor))
            case .vertical:
                HStack(spacing: 1) {
                    TerminalLayoutView(node: split.first, panes: panes, activePaneID: activePaneID)
                    TerminalLayoutView(node: split.second, panes: panes, activePaneID: activePaneID)
                }
                .background(Color(nsColor: .separatorColor))
            }
        }
    }
}
