import GhosttyTerminal
import SwiftUI

struct TerminalSurface: View {
    var pane: TerminalPane
    var isActive: Bool
    @ObservedObject var state: TerminalViewState
    var onActivate: () -> Void
    var onTitleChange: (String) -> Void
    var onCwdChange: (String) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TerminalSurfaceView(context: state)
            .terminalFocusOnAppear($isFocused)
            .onTapGesture {
                onActivate()
                isFocused = true
            }
            .onReceive(state.$title) { title in
                DispatchQueue.main.async {
                    onTitleChange(title)
                }
            }
            .onReceive(state.$workingDirectory.compactMap { $0 }) { cwd in
                DispatchQueue.main.async {
                    onCwdChange(cwd)
                }
            }
            .id(pane.id)
            .overlay(alignment: .topLeading) {
                if isActive {
                    Rectangle()
                        .stroke(Color(nsColor: .quaternaryLabelColor), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black, ignoresSafeAreaEdges: [.bottom, .horizontal])
    }
}
