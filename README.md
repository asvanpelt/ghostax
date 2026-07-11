# Ghostax

Native macOS terminal workspace built with SwiftUI and [Ghostty](https://ghostty.org) (via [libghostty-spm](https://github.com/Lakr233/libghostty-spm)).

Ghostax started as a ground-up reimagining of the workflows I had in my modified version of [Terax](https://github.com/asvanpelt/terax-ai), but without reusing any of its code. The initial scaffold was generated with Codex; the rest has been shaped interactively with Claude Code.

## What it does

- Embedded Ghostty terminal with horizontal/vertical splits and per-pane cwd
- Project-based workspaces — each window is one project
- Sidebar with three tabs: **Bookmarks**, **Files**, and **Git**
- Bookmarks with categories, drag reorder, and per-project accent color
- File browser with copy/paste, rename, trash, drag-and-drop from Finder, and opens text files in Zed
- Git panel: branch, staged/unstaged files, inline diff preview, stage/unstage, and FileMerge integration for side-by-side comparison
- Persistent layout per project (splits, panes, active pane, accent color)
- Ad-hoc code-signed install to /Applications

## Requirements

- macOS 14+
- Swift 6.2+
- [Ghostty.app](https://ghostty.org) installed in /Applications (for terminfo and shell integration resources)
- [Zed](https://zed.dev) in /Applications (for file editing, optional)

## Build & Install

```bash
# Development build
swift build
Scripts/run-dev-app.sh

# Release build + install to /Applications
Scripts/install.sh
```

`install.sh` compiles in release mode, assembles the .app bundle with Ghostty resources, signs ad-hoc, and copies to /Applications.

## Architecture

SwiftUI app shell with AppKit where needed (NSOpenPanel, NSPasteboard, NSWorkspace). Terminal rendering is isolated behind `TerminalSurface`, which embeds Ghostty through `GhosttyTerminal` using the `.exec` backend — each pane runs a real local shell. Git operations use the system `/usr/bin/git` for compatibility with user config, hooks, and credentials.

## Project structure

```
Sources/Ghostax/
  GhostaxApp.swift          App entry, window, keyboard shortcuts
  App/
    AppState.swift           Central state: workspace, tabs, panes, git, bookmarks
    SidebarSection.swift     Sidebar tab enum (Bookmarks, Files, Git)
    WindowAccent.swift       Project color palette
    Workspace.swift          Project model
    WorkspaceLayoutStore.swift  Per-project layout persistence
    NativePanels.swift       NSOpenPanel wrapper
  Terminal/
    TerminalModels.swift     Tab, pane, split tree models
    TerminalSurface.swift    Ghostty NSViewRepresentable bridge
  Bookmarks/
    BookmarkStore.swift      Bookmark + category storage
  Git/
    GitModels.swift          Status snapshot, changed file model
    GitService.swift         Async git CLI wrapper + FileMerge integration
  Views/
    AppShellView.swift       Main layout (sidebar + terminal)
    SidebarView.swift        Sidebar container + project header
    BookmarksView.swift      Bookmark list with categories
    FileBrowserView.swift    File tree browser
    GitPanelView.swift       Git status + diff panel
    TerminalWorkspaceView.swift  Terminal split renderer
    ToolbarView.swift        Top toolbar
Resources/
  Info.plist                 App bundle metadata
Scripts/
  run-dev-app.sh             Dev build + launch
  install.sh                 Release build + install to /Applications
```
