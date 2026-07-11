import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    var isCompact = false

    var body: some View {
        VStack(spacing: 0) {
            ProjectWindowHeader(isCompact: isCompact)

            Divider()

            Picker("", selection: $appState.sidebarSelection) {
                ForEach(SidebarSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            switch appState.sidebarSelection {
            case .bookmarks:
                BookmarksView(isCompact: isCompact)
            case .files:
                FileBrowserView()
            case .git:
                GitPanelView()
            }
        }
    }
}

private struct ProjectWindowHeader: View {
    @EnvironmentObject private var appState: AppState
    var isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    appState.chooseWorkspace()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Open project")
                .buttonStyle(.plain)

                if !isCompact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.workspace?.name ?? "No project")
                            .font(.headline)
                            .lineLimit(1)
                        Text(appState.workspace?.url.path ?? "Select a folder")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                } else {
                    Text(appState.workspace?.name ?? "Project")
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Spacer()

                Button {
                    appState.splitActivePane(axis: .vertical)
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                }
                .help("Split vertically")
                .buttonStyle(.plain)

                Button {
                    appState.splitActivePane(axis: .horizontal)
                } label: {
                    Image(systemName: "rectangle.split.1x2")
                }
                .help("Split horizontally")
                .buttonStyle(.plain)

                Button {
                    appState.closeActivePane()
                } label: {
                    Image(systemName: "xmark.square")
                }
                .help("Close active pane")
                .buttonStyle(.plain)
                .disabled((appState.activeTab?.panes.count ?? 0) < 2)
            }
        }
        .padding(12)
        .foregroundStyle(.white)
        .background(appState.windowAccent.color)
        .contextMenu {
            AccentColorMenu()
        }
    }
}
