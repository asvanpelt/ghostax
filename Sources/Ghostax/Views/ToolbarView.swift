import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            Button {
                appState.chooseWorkspace()
            } label: {
                Label("Open Project", systemImage: "folder")
            }

            if let workspace = appState.workspace {
                Text(workspace.name)
                    .font(.headline)
                Text(workspace.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No project selected")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.openTerminalTab()
            } label: {
                Label("New Tab", systemImage: "plus")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .frame(height: 44)
    }
}
