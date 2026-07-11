import Foundation

struct TerminalPane: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var cwd: String

    init(id: UUID = UUID(), title: String = "Terminal", cwd: String) {
        self.id = id
        self.title = title
        self.cwd = cwd
    }
}

enum TerminalSplitAxis: String, Equatable, Codable {
    case horizontal
    case vertical
}

struct TerminalSplit: Identifiable, Equatable, Codable {
    let id: UUID
    var axis: TerminalSplitAxis
    var first: TerminalLayoutNode
    var second: TerminalLayoutNode

    init(
        id: UUID = UUID(),
        axis: TerminalSplitAxis,
        first: TerminalLayoutNode,
        second: TerminalLayoutNode
    ) {
        self.id = id
        self.axis = axis
        self.first = first
        self.second = second
    }
}

indirect enum TerminalLayoutNode: Equatable, Codable {
    case pane(TerminalPane.ID)
    case split(TerminalSplit)

    func replacingPane(_ paneID: TerminalPane.ID, with replacement: TerminalLayoutNode) -> TerminalLayoutNode {
        switch self {
        case let .pane(id):
            return id == paneID ? replacement : self
        case let .split(split):
            return .split(
                TerminalSplit(
                    id: split.id,
                    axis: split.axis,
                    first: split.first.replacingPane(paneID, with: replacement),
                    second: split.second.replacingPane(paneID, with: replacement)
                )
            )
        }
    }

    func removingPane(_ paneID: TerminalPane.ID) -> TerminalLayoutNode? {
        switch self {
        case let .pane(id):
            return id == paneID ? nil : self
        case let .split(split):
            let first = split.first.removingPane(paneID)
            let second = split.second.removingPane(paneID)

            switch (first, second) {
            case let (.some(first), .some(second)):
                return .split(TerminalSplit(id: split.id, axis: split.axis, first: first, second: second))
            case let (.some(first), .none):
                return first
            case let (.none, .some(second)):
                return second
            case (.none, .none):
                return nil
            }
        }
    }

    var paneIDs: [TerminalPane.ID] {
        switch self {
        case let .pane(id):
            return [id]
        case let .split(split):
            return split.first.paneIDs + split.second.paneIDs
        }
    }
}

struct TerminalTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var cwd: String
    var panes: [TerminalPane]
    var layout: TerminalLayoutNode
    var activePaneID: TerminalPane.ID

    init(id: UUID = UUID(), title: String = "Terminal", cwd: String) {
        let pane = TerminalPane(title: title, cwd: cwd)
        self.id = id
        self.title = title
        self.cwd = cwd
        panes = [pane]
        layout = .pane(pane.id)
        activePaneID = pane.id
    }

    init(
        id: UUID = UUID(),
        title: String,
        cwd: String,
        panes: [TerminalPane],
        layout: TerminalLayoutNode,
        activePaneID: TerminalPane.ID
    ) {
        self.id = id
        self.title = title
        self.cwd = cwd
        self.panes = panes
        self.layout = layout
        self.activePaneID = activePaneID
    }
}

enum TerminalBackend: String {
    case ghosttyEmbedded = "Ghostty Embedded"
    case placeholder = "Placeholder"
}
