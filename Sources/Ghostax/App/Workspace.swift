import Foundation

struct Workspace: Equatable {
    var url: URL

    var name: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}
