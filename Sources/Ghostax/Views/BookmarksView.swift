import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var newCategoryName = ""
    @State private var isAddingCategory = false
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button {
                    isAddingCategory.toggle()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Add category")
                .popover(isPresented: $isAddingCategory, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("New category")
                            .font(.headline)
                        TextField("Name", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                        HStack {
                            Spacer()
                            Button("Add") {
                                appState.bookmarks.addCategory(named: newCategoryName)
                                newCategoryName = ""
                                isAddingCategory = false
                            }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(12)
                }

                Button {
                    if let workspace = appState.workspace {
                        appState.bookmarks.add(path: workspace.url.path)
                    }
                } label: {
                    Image(systemName: "bookmark")
                }
                .help("Bookmark current project")
                .disabled(appState.workspace == nil)

                Button {
                    if let url = NativePanels.chooseDirectory() {
                        appState.bookmarks.add(path: url.path)
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(12)

            List {
                if appState.bookmarks.items.isEmpty {
                    Section("Folders") {
                        Text("No bookmarks yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(appState.bookmarks.categories) { category in
                    let items = appState.bookmarks.items.filter { $0.categoryID == category.id }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { item in
                                bookmarkRow(item)
                            }
                        } header: {
                            Text(category.name)
                                .contextMenu {
                                    Button("Move Up") {
                                        appState.bookmarks.moveCategory(category, direction: .up)
                                    }
                                    .disabled(!appState.bookmarks.canMoveCategory(category, direction: .up))
                                    Button("Move Down") {
                                        appState.bookmarks.moveCategory(category, direction: .down)
                                    }
                                    .disabled(!appState.bookmarks.canMoveCategory(category, direction: .down))
                                    Divider()
                                    Button("Remove Category") {
                                        appState.bookmarks.removeCategory(category)
                                    }
                                }
                        }
                    }
                }

                let uncategorized = appState.bookmarks.items.filter { $0.categoryID == nil }
                if !uncategorized.isEmpty {
                    Section(appState.bookmarks.categories.isEmpty ? "Folders" : "Uncategorized") {
                        ForEach(uncategorized) { item in
                            bookmarkRow(item)
                        }
                    }
                }
            }
        }
    }

    private func bookmarkRow(_ item: BookmarkItem) -> some View {
        BookmarkRow(item: item, isCurrent: isCurrentProject(item))
            .contentShape(Rectangle())
            .onTapGesture {
                openBookmark(item)
            }
            .contextMenu {
                Button("Open Here") {
                    appState.setWorkspace(URL(fileURLWithPath: item.path))
                }
                .disabled(isCurrentProject(item))
                Button("Open in New Window") {
                    openWindow(id: "project-window", value: item.path)
                }
                Divider()
                Button("Move Up") {
                    appState.bookmarks.move(item, direction: .up)
                }
                .disabled(!appState.bookmarks.canMove(item, direction: .up))
                Button("Move Down") {
                    appState.bookmarks.move(item, direction: .down)
                }
                .disabled(!appState.bookmarks.canMove(item, direction: .down))
                Menu("Category") {
                    Button("Uncategorized") {
                        appState.bookmarks.assign(item, to: nil)
                    }
                    if !appState.bookmarks.categories.isEmpty {
                        Divider()
                    }
                    ForEach(appState.bookmarks.categories) { category in
                        Button(category.name) {
                            appState.bookmarks.assign(item, to: category.id)
                        }
                    }
                }
                Menu("Color") {
                    let current = WorkspaceLayoutStore.accent(for: item.path)
                    ForEach(WindowAccent.allCases) { accent in
                        Button {
                            WorkspaceLayoutStore.setAccent(accent, path: item.path)
                            if appState.workspace?.url.standardizedFileURL.path == URL(fileURLWithPath: item.path).standardizedFileURL.path {
                                appState.setWindowAccent(accent)
                            }
                        } label: {
                            HStack {
                                if current == accent {
                                    Image(systemName: "checkmark")
                                }
                                Text(accent.rawValue.capitalized)
                            }
                        }
                    }
                    Divider()
                    Button("Default") {
                        let defaultAccent = WindowAccent.stableColor(for: item.path)
                        WorkspaceLayoutStore.setAccent(defaultAccent, path: item.path)
                        if appState.workspace?.url.standardizedFileURL.path == URL(fileURLWithPath: item.path).standardizedFileURL.path {
                            appState.setWindowAccent(defaultAccent)
                        }
                    }
                }
                Divider()
                Button("Remove") {
                    appState.bookmarks.remove(item)
                }
            }
    }

    private func openBookmark(_ item: BookmarkItem) {
        if isCurrentProject(item) {
            return
        }

        if appState.workspace == nil {
            appState.setWorkspace(URL(fileURLWithPath: item.path))
        } else {
            openWindow(id: "project-window", value: item.path)
        }
    }

    private func isCurrentProject(_ item: BookmarkItem) -> Bool {
        appState.workspace?.url.standardizedFileURL.path == URL(fileURLWithPath: item.path).standardizedFileURL.path
    }
}

private struct BookmarkRow: View {
    var item: BookmarkItem
    var isCurrent: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCurrent ? "folder.fill" : "folder")
                .foregroundStyle(isCurrent ? .primary : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .lineLimit(1)
            }
            Spacer()
            if isCurrent {
                Circle()
                    .fill(Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isCurrent ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : Color.clear)
        .help(item.path)
    }
}
