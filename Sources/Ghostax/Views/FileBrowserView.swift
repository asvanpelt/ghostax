import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @EnvironmentObject private var appState: AppState
    @State private var expandedDirs: Set<String> = []
    @State private var selection: String?

    var body: some View {
        if let workspace = appState.workspace {
            List {
                FileTreeNode(
                    url: workspace.url,
                    depth: 0,
                    expandedDirs: $expandedDirs,
                    selection: $selection
                )
            }
            .listStyle(.sidebar)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers, into: workspace.url)
            }
        } else {
            VStack {
                Spacer()
                Text("No project open")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], into targetDir: URL) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let sourceURL = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                let dest = targetDir.appendingPathComponent(sourceURL.lastPathComponent)
                try? FileManager.default.copyItem(at: sourceURL, to: dest)
            }
            handled = true
        }
        return handled
    }
}

private struct FileTreeNode: View {
    let url: URL
    let depth: Int
    @Binding var expandedDirs: Set<String>
    @Binding var selection: String?

    var body: some View {
        let entries = listDirectory(url)

        ForEach(entries, id: \.path) { entry in
            let isDir = entry.hasDirectoryPath
            let isExpanded = expandedDirs.contains(entry.path)
            let isSelected = selection == entry.path

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    if isDir {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 10)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    Image(systemName: isDir ? (isExpanded ? "folder.fill" : "folder") : fileIcon(for: entry))
                        .foregroundStyle(isDir ? Color.accentColor : .secondary)
                        .font(.system(size: 13))

                    Text(entry.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .padding(.vertical, 3)
                .padding(.leading, CGFloat(depth) * 12)
                .contentShape(Rectangle())
                .listRowBackground(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : Color.clear)
                .onTapGesture {
                    selection = entry.path
                    if isDir {
                        if isExpanded {
                            expandedDirs.remove(entry.path)
                        } else {
                            expandedDirs.insert(entry.path)
                        }
                    } else {
                        openFile(entry)
                    }
                }
                .contextMenu {
                    fileContextMenu(entry, isDir: isDir)
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    let target = isDir ? entry : entry.deletingLastPathComponent()
                    return handleLocalDrop(providers, into: target)
                }
            }

            if isDir && isExpanded {
                FileTreeNode(
                    url: entry,
                    depth: depth + 1,
                    expandedDirs: $expandedDirs,
                    selection: $selection
                )
            }
        }
    }

    @ViewBuilder
    private func fileContextMenu(_ url: URL, isDir: Bool) -> some View {
        if !isDir {
            Button("Open in Zed") {
                openInZed(url)
            }

            Button("Open with Default App") {
                NSWorkspace.shared.open(url)
            }

            Divider()
        }

        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }

        Divider()

        Button("Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }

        if isDir {
            Button("Paste") {
                pasteFromClipboard(into: url)
            }
        }

        Divider()

        Button("Rename…") {
            renameFile(url)
        }

        Button("Move to Trash") {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }

        if isDir {
            Divider()
            Button("New File…") {
                createNewFile(in: url)
            }
            Button("New Folder…") {
                createNewFolder(in: url)
            }
        }
    }

    private func listDirectory(_ dir: URL) -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.sorted { a, b in
            let aDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let bDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if aDir != bDir { return aDir }
            return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
        }
    }

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "swift": "swift"
        case "js", "ts", "jsx", "tsx": "doc.text"
        case "json": "curlybraces"
        case "html", "htm": "chevron.left.forwardslash.chevron.right"
        case "css", "scss": "paintbrush"
        case "md", "txt": "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico": "photo"
        case "pdf": "doc.richtext"
        case "zip", "tar", "gz": "archivebox"
        case "sh", "zsh", "bash": "terminal"
        case "yml", "yaml", "toml": "gearshape"
        case "py": "doc.text"
        case "rb": "doc.text"
        case "rs": "doc.text"
        case "go": "doc.text"
        case "c", "cpp", "h", "hpp", "m": "doc.text"
        default: "doc"
        }
    }

    private func openFile(_ url: URL) {
        if isTextFile(url) {
            openInZed(url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInZed(_ url: URL) {
        let zedURL = URL(fileURLWithPath: "/Applications/Zed.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: zedURL, configuration: config)
    }

    private func isTextFile(_ url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if type.conforms(to: .text) || type.conforms(to: .sourceCode)
                || type.conforms(to: .script) || type.conforms(to: .shellScript)
                || type.conforms(to: .propertyList) || type.conforms(to: .json)
                || type.conforms(to: .xml) || type.conforms(to: .yaml) {
                return true
            }
        }

        let textExtensions: Set<String> = [
            "swift", "js", "ts", "jsx", "tsx", "mjs", "cjs",
            "py", "rb", "rs", "go", "c", "cpp", "h", "hpp", "m", "mm",
            "java", "kt", "kts", "scala", "cs", "fs",
            "html", "htm", "css", "scss", "sass", "less",
            "json", "xml", "yaml", "yml", "toml", "ini", "cfg", "conf",
            "md", "txt", "rst", "tex", "log",
            "sh", "zsh", "bash", "fish", "ps1",
            "sql", "graphql", "gql",
            "vue", "svelte", "astro",
            "dockerfile", "makefile", "cmake",
            "gitignore", "gitattributes", "editorconfig",
            "env", "envrc", "lock", "plist",
            "r", "lua", "zig", "nim", "ex", "exs", "erl", "hrl",
            "php", "pl", "pm", "dart", "v", "hs",
        ]

        let ext = url.pathExtension.lowercased()
        if textExtensions.contains(ext) { return true }

        let knownName = url.lastPathComponent.lowercased()
        let textFilenames: Set<String> = [
            "makefile", "dockerfile", "containerfile", "vagrantfile",
            "gemfile", "rakefile", "procfile", "brewfile",
            ".gitignore", ".gitattributes", ".editorconfig",
            ".env", ".envrc", "license", "readme", "changelog",
            "claude.md",
        ]
        if textFilenames.contains(knownName) { return true }

        if ext.isEmpty {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let sample = data.prefix(8192) as Data?,
               sample.allSatisfy({ $0 == 0x09 || $0 == 0x0A || $0 == 0x0D || (0x20...0x7E).contains($0) || $0 >= 0x80 }) {
                return true
            }
        }

        return false
    }

    private func pasteFromClipboard(into targetDir: URL) {
        guard let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return }
        let fm = FileManager.default
        for source in urls {
            let dest = targetDir.appendingPathComponent(source.lastPathComponent)
            try? fm.copyItem(at: source, to: dest)
        }
    }

    private func handleLocalDrop(_ providers: [NSItemProvider], into targetDir: URL) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let sourceURL = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                let dest = targetDir.appendingPathComponent(sourceURL.lastPathComponent)
                try? FileManager.default.copyItem(at: sourceURL, to: dest)
            }
            handled = true
        }
        return handled
    }

    private func renameFile(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = url.lastPathComponent
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != url.lastPathComponent else { return }
        let dest = url.deletingLastPathComponent().appendingPathComponent(newName)
        try? FileManager.default.moveItem(at: url, to: dest)
    }

    private func createNewFile(in dir: URL) {
        let alert = NSAlert()
        alert.messageText = "New File"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "filename.txt"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: nil)
    }

    private func createNewFolder(in dir: URL) {
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "folder name"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent(name), withIntermediateDirectories: false)
    }
}
