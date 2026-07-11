# Architecture Notes

## Native App Shape

Ghostax is a macOS-first SwiftUI application. AppKit is used only where SwiftUI does not expose enough native behavior, such as `NSOpenPanel`. The embedded terminal surface comes from `GhosttyTerminal`, which wraps the AppKit/Metal `libghostty` view.

## Terminal Boundary

`TerminalSurface` is the only UI leaf that knows about Ghostty. The surrounding workspace model owns tabs, cwd, future split trees, and layout persistence.

Current integration:

1. `Package.swift` depends on `Lakr233/libghostty-spm`.
2. `AppState` owns one `TerminalViewState` per terminal pane.
3. `TerminalSurface` renders `TerminalSurfaceView` with the `.exec` backend.
4. Each pane passes its cwd into `TerminalSurfaceOptions.workingDirectory`.
5. Ghostty-reported title and cwd are fed back into the pane and tab model.
6. Each window owns its own `AppState`; visible tabs were removed in favor of multi-window workspaces.
7. A single internal tab contains a recursive split layout tree, so horizontal and vertical splits can host independent Ghostty sessions.
8. Workspace layouts persist per project path: panes, split tree, active pane, cwd, and window accent.

Next terminal work:

1. Add split resize handles.
2. Persist selected workspace/window restoration across app launches.
3. Expose terminal search, copy/paste, link handling, theme/profile controls.
4. Validate shell integration events for prompt navigation and command status.

## Git Boundary

`GitService` calls `/usr/bin/git` asynchronously. This keeps the MVP compatible with real developer environments. Stage, unstage, and diff should remain CLI-backed until a specific performance bottleneck appears.

The Git UI lives in the sidebar, not in terminal splits. It groups staged and unstaged files, keeps the terminal area dedicated to Ghostty, and exposes compact actions for refresh, stage/unstage selected, stage/unstage all, open file, and diff preview.

## Terax Parity Rules

Terax is a reference for product behavior, not a source dependency. Do not copy source files from Terax into this repo.
