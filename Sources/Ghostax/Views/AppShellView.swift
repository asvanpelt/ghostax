import SwiftUI

struct AppShellView: View {
    @StateObject private var appState = AppState()
    var initialProjectPath: String? = nil

    var body: some View {
        GeometryReader { proxy in
            let sidebarMode = SidebarDisplayMode(width: proxy.size.width)

            HStack(spacing: 0) {
                if sidebarMode != .hidden {
                    SidebarView(isCompact: sidebarMode == .compact)
                        .frame(width: sidebarMode.width)
                        .background(Color(nsColor: .underPageBackgroundColor))

                    Divider()
                }

                TerminalWorkspaceView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .underPageBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(appState)
        .task {
            if let initialProjectPath, appState.workspace == nil {
                appState.setWorkspace(URL(fileURLWithPath: initialProjectPath))
            }
            await appState.refreshGit()
        }
    }
}

private enum SidebarDisplayMode: Equatable {
    case hidden
    case compact
    case regular

    init(width: CGFloat) {
        if width < 520 {
            self = .hidden
        } else if width < 760 {
            self = .compact
        } else {
            self = .regular
        }
    }

    var width: CGFloat {
        switch self {
        case .hidden:
            0
        case .compact:
            184
        case .regular:
            260
        }
    }
}
