import SwiftUI
import AppKit

struct GitPanelView: View {
    @EnvironmentObject private var appState: AppState

    private var status: GitStatusSnapshot? { appState.gitStatus }
    private var files: [GitChangedFile] { status?.files ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            fileList
            Divider()
            diffPreview
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status?.branch ?? "No repository")
                        .font(.headline)
                        .lineLimit(1)
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await appState.refreshGit() }
                } label: {
                    Image(systemName: appState.isLoadingGit ? "clock.arrow.circlepath" : "arrow.clockwise")
                }
                .help("Refresh")
                .buttonStyle(.plain)
                .disabled(appState.workspace == nil || appState.isLoadingGit)
            }

            HStack(spacing: 10) {
                Button {
                    appState.stageSelectedGitFile()
                } label: {
                    Image(systemName: "plus.square")
                }
                .help("Stage selected file")
                .disabled(appState.selectedGitFile == nil)

                Button {
                    appState.unstageSelectedGitFile()
                } label: {
                    Image(systemName: "minus.square")
                }
                .help("Unstage selected file")
                .disabled(appState.selectedGitFile == nil)

                Button {
                    appState.stageAllGitFiles()
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                }
                .help("Stage all")
                .disabled(files.isEmpty)

                Button {
                    appState.unstageAllGitFiles()
                } label: {
                    Image(systemName: "tray.and.arrow.up")
                }
                .help("Unstage all")
                .disabled(status?.stagedFiles.isEmpty ?? true)

                Button {
                    appState.openSelectedGitFile()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .help("Open selected file")
                .disabled(appState.selectedGitFile == nil)

                Spacer()
            }
            .buttonStyle(.plain)

            if let error = status?.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
    }

    private var fileList: some View {
        List(selection: Binding(
            get: { appState.selectedGitFile?.id },
            set: { id in
                guard let file = files.first(where: { $0.id == id }) else { return }
                appState.selectGitFile(file)
            }
        )) {
            if files.isEmpty {
                Text(appState.workspace == nil ? "Open a project to inspect Git status." : "Working tree clean.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            if let staged = status?.stagedFiles, !staged.isEmpty {
                Section("Staged") {
                    ForEach(staged) { file in
                        GitFileRow(file: file)
                            .tag(file.id)
                            .onTapGesture {
                                appState.selectGitFile(file)
                                appState.openGitDiff(file)
                            }
                            .contextMenu { rowMenu(for: file) }
                    }
                }
            }

            if let unstaged = status?.unstagedFiles, !unstaged.isEmpty {
                Section("Changes") {
                    ForEach(unstaged) { file in
                        GitFileRow(file: file)
                            .tag(file.id)
                            .onTapGesture {
                                appState.selectGitFile(file)
                                appState.openGitDiff(file)
                            }
                            .contextMenu { rowMenu(for: file) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minHeight: 180)
    }

    private var diffPreview: some View {
        ScrollView {
            Text(appState.selectedGitDiff.isEmpty ? "Select a changed file to view its diff." : appState.selectedGitDiff)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(minHeight: 220)
    }

    private var summaryText: String {
        guard appState.workspace != nil else { return "No project selected" }
        guard let status else { return "Status not loaded" }
        if status.files.isEmpty { return "Clean" }
        return "\(status.stagedFiles.count) staged, \(status.unstagedFiles.count) changed"
    }

    private func openInZed(_ file: GitChangedFile) {
        guard let workspace = appState.workspace else { return }
        let fileURL = workspace.url.appendingPathComponent(file.path)
        let zedURL = URL(fileURLWithPath: "/Applications/Zed.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([fileURL], withApplicationAt: zedURL, configuration: config)
    }

    @ViewBuilder
    private func rowMenu(for file: GitChangedFile) -> some View {
        Button("Compare in FileMerge") {
            appState.openGitDiff(file)
        }

        Button("Open in Zed") {
            openInZed(file)
        }

        Divider()

        Button("Stage") {
            appState.selectGitFile(file)
            appState.stageSelectedGitFile()
        }
        Button("Unstage") {
            appState.selectGitFile(file)
            appState.unstageSelectedGitFile()
        }

        Divider()

        Button("Show in Finder") {
            guard let workspace = appState.workspace else { return }
            let url = workspace.url.appendingPathComponent(file.path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.path, forType: .string)
        }
    }
}

private struct GitFileRow: View {
    var file: GitChangedFile

    var body: some View {
        HStack(spacing: 8) {
            Text(file.displayStatus)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(fileName)
                    .lineLimit(1)
                if !folderPath.isEmpty {
                    Text(folderPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var fileName: String {
        URL(fileURLWithPath: file.path).lastPathComponent
    }

    private var folderPath: String {
        let path = file.path as NSString
        let folder = path.deletingLastPathComponent
        return folder == "." ? "" : folder
    }

    private var statusColor: Color {
        switch file.statusColorName {
        case "green": .green
        case "red": .red
        case "purple": .purple
        default: .orange
        }
    }
}
