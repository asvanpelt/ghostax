import Foundation
import GhosttyTerminal
import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var workspace: Workspace?
    @Published var sidebarSelection: SidebarSection = .bookmarks
    @Published var tabs: [TerminalTab] = [TerminalTab(cwd: FileManager.default.homeDirectoryForCurrentUser.path)]
    @Published var activeTabID: TerminalTab.ID?
    @Published var bookmarks = BookmarkStore.load()
    @Published var gitStatus: GitStatusSnapshot?
    @Published var selectedGitFile: GitChangedFile?
    @Published var selectedGitDiff: String = ""
    @Published var isLoadingGit = false
    @Published var windowAccent: WindowAccent = .preset(.blue)
    @Published private var terminalStates: [TerminalPane.ID: TerminalViewState] = [:]

    private let gitService = GitService()

    init() {
        activeTabID = tabs.first?.id
        for tab in tabs {
            for pane in tab.panes {
                terminalStates[pane.id] = makeTerminalState(cwd: pane.cwd)
            }
        }
    }

    var activeTab: TerminalTab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    func chooseWorkspace() {
        guard let url = NativePanels.chooseDirectory() else { return }
        setWorkspace(url)
    }

    func setWorkspace(_ url: URL) {
        let normalizedURL = url.standardizedFileURL
        if workspace?.url.standardizedFileURL.path == normalizedURL.path {
            return
        }

        workspace = Workspace(url: normalizedURL)
        bookmarks.add(path: normalizedURL.path)
        sidebarSelection = .git
        if let saved = WorkspaceLayoutStore.load(path: normalizedURL.path), saved.panes.count > 1 {
            restore(saved, fallbackCwd: normalizedURL.path)
        } else {
            windowAccent = WindowAccent.stableColor(for: normalizedURL.path)
            resetDefaultProjectWorkspace(cwd: normalizedURL.path)
        }
        Task { await refreshGit() }
    }

    func setWindowAccent(_ accent: WindowAccent) {
        guard windowAccent != accent else { return }
        windowAccent = accent
        saveWorkspaceLayout()
    }

    func openTerminalTab(cwd: String? = nil) {
        let next = TerminalTab(cwd: cwd ?? activePane?.cwd ?? activeTab?.cwd ?? workspace?.url.path ?? FileManager.default.homeDirectoryForCurrentUser.path)
        tabs.append(next)
        for pane in next.panes {
            terminalStates[pane.id] = makeTerminalState(cwd: pane.cwd)
        }
        activeTabID = next.id
    }

    func resetTerminalWorkspace(cwd: String) {
        terminalStates.removeAll()
        let next = TerminalTab(cwd: cwd)
        tabs = [next]
        activeTabID = next.id
        for pane in next.panes {
            terminalStates[pane.id] = makeTerminalState(cwd: pane.cwd)
        }
        saveWorkspaceLayout()
    }

    func resetDefaultProjectWorkspace(cwd: String) {
        terminalStates.removeAll()

        let left = TerminalPane(cwd: cwd)
        let rightTop = TerminalPane(cwd: cwd)
        let rightBottom = TerminalPane(cwd: cwd)
        let layout = TerminalLayoutNode.split(
            TerminalSplit(
                axis: .vertical,
                first: .pane(left.id),
                second: .split(
                    TerminalSplit(
                        axis: .horizontal,
                        first: .pane(rightTop.id),
                        second: .pane(rightBottom.id)
                    )
                )
            )
        )
        let tab = TerminalTab(
            title: left.title,
            cwd: cwd,
            panes: [left, rightTop, rightBottom],
            layout: layout,
            activePaneID: left.id
        )

        tabs = [tab]
        activeTabID = tab.id
        for pane in tab.panes {
            terminalStates[pane.id] = makeTerminalState(cwd: pane.cwd)
        }
        saveWorkspaceLayout()
    }

    func closeTab(_ id: TerminalTab.ID) {
        guard tabs.count > 1 else { return }
        if let tab = tabs.first(where: { $0.id == id }) {
            for pane in tab.panes {
                terminalStates[pane.id] = nil
            }
        }
        tabs.removeAll { $0.id == id }
        if activeTabID == id {
            activeTabID = tabs.last?.id
        }
    }

    var activePane: TerminalPane? {
        guard let activeTab else { return nil }
        return activeTab.panes.first { $0.id == activeTab.activePaneID }
    }

    func terminalState(for pane: TerminalPane) -> TerminalViewState {
        if let state = terminalStates[pane.id] {
            return state
        }

        let state = makeTerminalState(cwd: pane.cwd)
        terminalStates[pane.id] = state
        return state
    }

    func updateActiveTabCwd(_ cwd: String) {
        guard let activeTabID, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[index].cwd = cwd
    }

    func activatePane(_ id: TerminalPane.ID) {
        guard let tabIndex = activeTabIndex else { return }
        guard tabs[tabIndex].panes.contains(where: { $0.id == id }) else { return }
        guard tabs[tabIndex].activePaneID != id else { return }
        tabs[tabIndex].activePaneID = id
        saveWorkspaceLayout()
    }

    func splitActivePane(axis: TerminalSplitAxis) {
        guard let tabIndex = activeTabIndex,
              let paneIndex = tabs[tabIndex].panes.firstIndex(where: { $0.id == tabs[tabIndex].activePaneID })
        else { return }

        let source = tabs[tabIndex].panes[paneIndex]
        let newPane = TerminalPane(cwd: source.cwd)
        let replacement = TerminalLayoutNode.split(
            TerminalSplit(
                axis: axis,
                first: .pane(source.id),
                second: .pane(newPane.id)
            )
        )

        tabs[tabIndex].panes.append(newPane)
        tabs[tabIndex].layout = tabs[tabIndex].layout.replacingPane(source.id, with: replacement)
        tabs[tabIndex].activePaneID = newPane.id
        terminalStates[newPane.id] = makeTerminalState(cwd: newPane.cwd)
        saveWorkspaceLayout()
    }

    func closePaneOrWindow() {
        guard let tabIndex = activeTabIndex else { return }
        if tabs[tabIndex].panes.count <= 1 {
            NSApplication.shared.keyWindow?.performClose(nil)
        } else {
            closeActivePane()
        }
    }

    func closeActivePane() {
        guard let tabIndex = activeTabIndex else { return }
        let activePaneID = tabs[tabIndex].activePaneID
        guard tabs[tabIndex].panes.count > 1 else { return }
        guard let nextLayout = tabs[tabIndex].layout.removingPane(activePaneID) else { return }

        terminalStates[activePaneID] = nil
        tabs[tabIndex].panes.removeAll { $0.id == activePaneID }
        tabs[tabIndex].layout = nextLayout

        let remainingPaneIDs = nextLayout.paneIDs
        if let firstRemaining = remainingPaneIDs.first {
            tabs[tabIndex].activePaneID = firstRemaining
            if let pane = tabs[tabIndex].panes.first(where: { $0.id == firstRemaining }) {
                tabs[tabIndex].cwd = pane.cwd
                tabs[tabIndex].title = pane.title
            }
        }

        saveWorkspaceLayout()
    }

    func updatePane(_ id: TerminalPane.ID, cwd: String) {
        guard let tabIndex = tabs.firstIndex(where: { tab in
            tab.panes.contains { $0.id == id }
        }), let paneIndex = tabs[tabIndex].panes.firstIndex(where: { $0.id == id })
        else { return }

        guard tabs[tabIndex].panes[paneIndex].cwd != cwd else { return }
        tabs[tabIndex].panes[paneIndex].cwd = cwd
        if tabs[tabIndex].activePaneID == id {
            tabs[tabIndex].cwd = cwd
        }
        saveWorkspaceLayout()
    }

    func updatePane(_ id: TerminalPane.ID, title: String) {
        guard !title.isEmpty,
              let tabIndex = tabs.firstIndex(where: { tab in
                  tab.panes.contains { $0.id == id }
              }), let paneIndex = tabs[tabIndex].panes.firstIndex(where: { $0.id == id })
        else { return }

        guard tabs[tabIndex].panes[paneIndex].title != title else { return }
        tabs[tabIndex].panes[paneIndex].title = title
        if tabs[tabIndex].activePaneID == id {
            tabs[tabIndex].title = title
        }
        saveWorkspaceLayout()
    }

    func refreshGit() async {
        guard let workspace else {
            gitStatus = nil
            selectedGitFile = nil
            selectedGitDiff = ""
            return
        }

        isLoadingGit = true
        defer { isLoadingGit = false }

        do {
            let status = try await gitService.status(at: workspace.url)
            gitStatus = status
            if selectedGitFile == nil {
                selectedGitFile = status.files.first
            }
            if let selectedGitFile {
                selectedGitDiff = try await gitService.diff(file: selectedGitFile, at: workspace.url)
            }
        } catch {
            gitStatus = GitStatusSnapshot(branch: "not a git repo", files: [], error: error.localizedDescription)
            selectedGitFile = nil
            selectedGitDiff = ""
        }
    }

    func selectGitFile(_ file: GitChangedFile) {
        selectedGitFile = file
        Task {
            guard let workspace else { return }
            selectedGitDiff = (try? await gitService.diff(file: file, at: workspace.url)) ?? ""
        }
    }

    func stageSelectedGitFile() {
        guard let workspace, let selectedGitFile else { return }
        Task {
            do {
                try await gitService.stage(file: selectedGitFile, at: workspace.url)
            } catch {
                gitStatus = GitStatusSnapshot(branch: gitStatus?.branch ?? "error", files: gitStatus?.files ?? [], error: error.localizedDescription)
            }
            await refreshGit()
        }
    }

    func unstageSelectedGitFile() {
        guard let workspace, let selectedGitFile else { return }
        Task {
            do {
                try await gitService.unstage(file: selectedGitFile, at: workspace.url)
            } catch {
                gitStatus = GitStatusSnapshot(branch: gitStatus?.branch ?? "error", files: gitStatus?.files ?? [], error: error.localizedDescription)
            }
            await refreshGit()
        }
    }

    func stageAllGitFiles() {
        guard let workspace else { return }
        Task {
            do {
                try await gitService.stageAll(at: workspace.url)
            } catch {
                gitStatus = GitStatusSnapshot(branch: gitStatus?.branch ?? "error", files: gitStatus?.files ?? [], error: error.localizedDescription)
            }
            await refreshGit()
        }
    }

    func unstageAllGitFiles() {
        guard let workspace else { return }
        Task {
            do {
                try await gitService.unstageAll(at: workspace.url)
            } catch {
                gitStatus = GitStatusSnapshot(branch: gitStatus?.branch ?? "error", files: gitStatus?.files ?? [], error: error.localizedDescription)
            }
            await refreshGit()
        }
    }

    func openSelectedGitFile() {
        guard let workspace, let selectedGitFile else { return }
        let url = workspace.url.appendingPathComponent(selectedGitFile.path)
        NSWorkspace.shared.open(url)
    }

    func openGitDiff(_ file: GitChangedFile) {
        guard let workspace else { return }
        Task {
            try? await gitService.openDiffInFileMerge(file: file, at: workspace.url)
        }
    }

    private func makeTerminalState(cwd: String) -> TerminalViewState {
        let state = TerminalViewState(
            terminalConfiguration: TerminalConfiguration { config in
                config.withFontSize(14)
                config.withCursorStyle(.block)
                config.withCursorStyleBlink(true)
                config.withWindowPaddingX(10)
                config.withWindowPaddingY(8)
            }
        )

        state.configuration = TerminalSurfaceOptions(
            backend: .exec,
            fontSize: 14,
            workingDirectory: cwd
        )

        return state
    }

    private var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return tabs.firstIndex { $0.id == activeTabID }
    }

    private func restore(_ saved: WorkspaceWindowLayout, fallbackCwd: String) {
        terminalStates.removeAll()
        windowAccent = saved.accent

        let panes = saved.panes.isEmpty ? [TerminalPane(cwd: fallbackCwd)] : saved.panes
        let paneIDs = Set(panes.map(\.id))
        let layoutPaneIDs = saved.layout.paneIDs
        let layout = layoutPaneIDs.allSatisfy { paneIDs.contains($0) } ? saved.layout : .pane(panes[0].id)
        let activePaneID = paneIDs.contains(saved.activePaneID) ? saved.activePaneID : panes[0].id
        let activePane = panes.first { $0.id == activePaneID } ?? panes[0]

        let tab = TerminalTab(
            title: activePane.title,
            cwd: activePane.cwd,
            panes: panes,
            layout: layout,
            activePaneID: activePaneID
        )

        tabs = [tab]
        activeTabID = tab.id
        for pane in panes {
            terminalStates[pane.id] = makeTerminalState(cwd: pane.cwd)
        }
    }

    private func saveWorkspaceLayout() {
        guard let workspace, let tab = activeTab else { return }
        WorkspaceLayoutStore.save(
            WorkspaceWindowLayout(
                panes: tab.panes,
                layout: tab.layout,
                activePaneID: tab.activePaneID,
                accent: windowAccent
            ),
            path: workspace.url.path
        )
    }
}
