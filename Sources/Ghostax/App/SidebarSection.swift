enum SidebarSection: String, CaseIterable, Identifiable {
    case bookmarks = "Bookmarks"
    case files = "Files"
    case git = "Git"

    var id: String { rawValue }
}
