# Ghostax Handoff

## User Goal

Build a fresh native macOS app in a new folder, without Terax source code, inspired by selected Terax workflows. The terminal should use embedded Ghostty/libghostty for the terminal surface. Terax AI features are intentionally low priority and excluded from the MVP.

## Project Location

`/Users/jorgeveron/Proyectos/ghostax`

## Chosen MVP

- `T1` Ghostty embedded terminal surface with tabs
- `T2` Horizontal and vertical splits
- `T3` Per-tab cwd and basic restore
- `T4` Shell integration for cwd and prompt boundaries
- `T6` Search, copy/paste, links, file/folder drag
- `T7` Themes, fonts, cursor, profiles
- `W1` Project picker
- `W3` Bookmarks with categories
- `W5` Persistent project layout
- `G1` Git branch/status
- `G2` Git changed-files panel with stage/unstage
- `G3` Git diff viewer
- `A0` No AI in the MVP

## Clarified Meaning

`T4` means shell integration: invisible shell signals such as OSC 7 and OSC 133 so the app can track current directory, command start/end, prompt boundaries, and exit codes without scraping prompt text.

`T5` command blocks was discussed but not chosen for the MVP. It would group each command and its output as selectable UI blocks, similar to Warp/Terax block mode. Defer it.

## Current Implementation State

The project is a Swift Package executable using SwiftUI and AppKit.

Implemented:

- SwiftUI app entrypoint
- Native window shell
- Sidebar with Bookmarks and Git sections
- Project folder picker via `NSOpenPanel`
- Bookmark storage in `UserDefaults`
- Bookmark categories data model and simple category creation
- Terminal tab model and tab bar
- `TerminalSurface` placeholder
- Git branch/status via `/usr/bin/git`
- Git changed-files list
- Git diff viewer
- Stage selected file via `git add -- <path>`
- Unstage selected file via `git restore --staged -- <path>`

Not implemented yet:

- Real Ghostty/libghostty terminal embedding
- Real PTY lifecycle in the app
- Terminal splits
- Layout persistence
- Shell integration parsing
- Terminal search/link handling
- Themes/profiles
- App bundle packaging

## Important Architecture Decision

Keep Ghostty isolated behind:

`Sources/Ghostax/Terminal/TerminalSurface.swift`

The surrounding app should own tabs, splits, cwd, workspace, bookmarks, and Git panels. Ghostty/libghostty should only replace the terminal leaf view.

## Ghostty Integration Notes

Relevant references:

- `https://github.com/ghostty-org/ghostty`
- `https://github.com/ghostty-org/ghostling`
- `https://swiftpackageregistry.com/Lakr233/libghostty-spm`
- `https://mitchellh.com/writing/libghostty-is-coming`

Observed direction:

- Ghostty macOS app is SwiftUI/AppKit plus Metal/CoreText.
- Ghostty core is Zig.
- `libghostty` / `libghostty-vt` is the embedding path, but it does not provide the complete Terax-like app shell.
- Do not try to fork Ghostty wholesale for the whole product.
- Preferred path: SwiftUI app shell plus embedded Ghostty/libghostty terminal leaf.

The current machine has Swift 6.2 available, but `xcodebuild` reports only Command Line Tools are active, not full Xcode. Avoid adding binary XCFramework dependencies until Xcode is available or the package is validated.

## Build

```bash
cd /Users/jorgeveron/Proyectos/ghostax
swift build
```

Last verified: `swift build` passed cleanly.

## Git State

The repository was initialized with `git init`.

Initial files are untracked. Nothing has been staged or committed yet.

## Next Recommended Steps

1. Add a real app packaging path: Xcode project, XcodeGen, Tuist, or SwiftPM app bundle workflow.
2. Validate GhosttyKit/libghostty on this machine once full Xcode is available.
3. Replace only `TerminalSurface` with an `NSViewRepresentable` Ghostty terminal surface.
4. Add PTY/session lifecycle and connect tab cwd.
5. Implement split tree model before deep terminal polish.
6. Add shell integration parsing for OSC 7 and OSC 133.
7. Expand Git panel stage/unstage UX, including staged diffs and deleted/renamed files.

## Constraint

Terax is a behavior reference only. Do not copy Terax source code into this repo.
