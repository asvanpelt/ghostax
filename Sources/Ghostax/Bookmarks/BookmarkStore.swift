import Foundation

struct BookmarkCategory: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var isCollapsed: Bool
}

struct BookmarkItem: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var categoryID: UUID?

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

struct BookmarkStore: Codable, Equatable {
    var categories: [BookmarkCategory]
    var items: [BookmarkItem]

    private static let defaultsKey = "ghostax.bookmarks.v1"

    static func load() -> BookmarkStore {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(BookmarkStore.self, from: data)
        else {
            return BookmarkStore(categories: [], items: [])
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    mutating func add(path: String, categoryID: UUID? = nil) {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !items.contains(where: { $0.path == normalized }) else { return }
        items.append(BookmarkItem(id: UUID(), path: normalized, categoryID: categoryID))
        save()
    }

    mutating func remove(_ item: BookmarkItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    mutating func move(_ item: BookmarkItem, direction: MoveDirection) {
        let sameCategory = items.enumerated()
            .filter { $0.element.categoryID == item.categoryID }
            .map(\.offset)
        guard let currentGlobalIndex = items.firstIndex(where: { $0.id == item.id }),
              let currentCategoryIndex = sameCategory.firstIndex(of: currentGlobalIndex)
        else { return }

        let targetCategoryIndex: Int
        switch direction {
        case .up:
            targetCategoryIndex = currentCategoryIndex - 1
        case .down:
            targetCategoryIndex = currentCategoryIndex + 1
        }

        guard sameCategory.indices.contains(targetCategoryIndex) else { return }
        items.swapAt(currentGlobalIndex, sameCategory[targetCategoryIndex])
        save()
    }

    func canMove(_ item: BookmarkItem, direction: MoveDirection) -> Bool {
        let categoryItems = items.filter { $0.categoryID == item.categoryID }
        guard let index = categoryItems.firstIndex(where: { $0.id == item.id }) else { return false }
        switch direction {
        case .up:
            return index > 0
        case .down:
            return index < categoryItems.count - 1
        }
    }

    mutating func assign(_ item: BookmarkItem, to categoryID: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].categoryID = categoryID
        save()
    }

    mutating func addCategory(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories.append(BookmarkCategory(id: UUID(), name: trimmed, isCollapsed: false))
        save()
    }

    mutating func removeCategory(_ category: BookmarkCategory) {
        categories.removeAll { $0.id == category.id }
        for index in items.indices where items[index].categoryID == category.id {
            items[index].categoryID = nil
        }
        save()
    }

    mutating func moveCategory(_ category: BookmarkCategory, direction: MoveDirection) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = index - 1
        case .down:
            targetIndex = index + 1
        }
        guard categories.indices.contains(targetIndex) else { return }
        categories.swapAt(index, targetIndex)
        save()
    }

    func canMoveCategory(_ category: BookmarkCategory, direction: MoveDirection) -> Bool {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return false }
        switch direction {
        case .up:
            return index > 0
        case .down:
            return index < categories.count - 1
        }
    }
}

enum MoveDirection {
    case up
    case down
}
