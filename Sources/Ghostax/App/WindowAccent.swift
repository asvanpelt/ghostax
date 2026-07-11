import SwiftUI

enum WindowAccent: String, CaseIterable, Identifiable, Codable {
    case blue
    case green
    case orange
    case pink
    case purple
    case slate

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:
            Color(red: 0.19, green: 0.43, blue: 0.72)
        case .green:
            Color(red: 0.18, green: 0.52, blue: 0.35)
        case .orange:
            Color(red: 0.75, green: 0.39, blue: 0.16)
        case .pink:
            Color(red: 0.70, green: 0.25, blue: 0.45)
        case .purple:
            Color(red: 0.43, green: 0.31, blue: 0.72)
        case .slate:
            Color(red: 0.28, green: 0.34, blue: 0.40)
        }
    }

    static func stableColor(for path: String) -> WindowAccent {
        let accents = WindowAccent.allCases
        let value = abs(path.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return accents[value % accents.count]
    }
}
