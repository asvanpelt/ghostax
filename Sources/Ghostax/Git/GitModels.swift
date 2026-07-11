import Foundation

struct GitStatusSnapshot: Equatable {
    var branch: String
    var files: [GitChangedFile]
    var error: String?

    var stagedFiles: [GitChangedFile] {
        files.filter(\.hasStagedChanges)
    }

    var unstagedFiles: [GitChangedFile] {
        files.filter(\.hasUnstagedChanges)
    }
}

struct GitChangedFile: Identifiable, Equatable {
    var id: String { path }
    var path: String
    var indexStatus: String
    var workTreeStatus: String

    var statusLabel: String {
        "\(indexStatus)\(workTreeStatus)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayStatus: String {
        statusLabel.isEmpty ? "?" : statusLabel
    }

    var hasStagedChanges: Bool {
        indexStatus != " " && indexStatus != "?"
    }

    var hasUnstagedChanges: Bool {
        workTreeStatus != " " || indexStatus == "?"
    }

    var statusColorName: String {
        if indexStatus == "A" || workTreeStatus == "A" || indexStatus == "?" {
            return "green"
        }
        if indexStatus == "D" || workTreeStatus == "D" {
            return "red"
        }
        if indexStatus == "R" || workTreeStatus == "R" {
            return "purple"
        }
        return "orange"
    }
}
