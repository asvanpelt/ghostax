import SwiftUI

enum WindowAccent: Identifiable, Equatable, Codable, Hashable {
    case preset(PresetAccent)
    case custom(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self),
           let legacy = PresetAccent(rawValue: raw) {
            self = .preset(legacy)
            return
        }
        let nested = try decoder.container(keyedBy: CodingKeys.self)
        if let p = try? nested.decode(PresetAccent.self, forKey: .preset) {
            self = .preset(p)
        } else if let hex = try? nested.decode(String.self, forKey: .custom) {
            self = .custom(hex)
        } else {
            self = .preset(.blue)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case preset, custom
    }

    var id: String {
        switch self {
        case .preset(let p): return p.rawValue
        case .custom(let hex): return "custom:\(hex)"
        }
    }

    var color: Color {
        switch self {
        case .preset(let p): return p.color
        case .custom(let hex): return Color(hex: hex)
        }
    }

    var displayName: String {
        switch self {
        case .preset(let p): return p.rawValue.capitalized
        case .custom(let hex): return hex.uppercased()
        }
    }

    static var allPresets: [WindowAccent] {
        PresetAccent.allCases.map { .preset($0) }
    }

    static func stableColor(for path: String) -> WindowAccent {
        let presets = PresetAccent.allCases
        let value = abs(path.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return .preset(presets[value % presets.count])
    }
}

enum PresetAccent: String, CaseIterable, Identifiable, Codable {
    case blue
    case cyan
    case teal
    case green
    case lime
    case yellow
    case orange
    case red
    case pink
    case magenta
    case purple
    case indigo
    case slate
    case graphite

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:
            Color(red: 0.19, green: 0.43, blue: 0.72)
        case .cyan:
            Color(red: 0.10, green: 0.55, blue: 0.67)
        case .teal:
            Color(red: 0.15, green: 0.52, blue: 0.52)
        case .green:
            Color(red: 0.18, green: 0.52, blue: 0.35)
        case .lime:
            Color(red: 0.38, green: 0.54, blue: 0.18)
        case .yellow:
            Color(red: 0.65, green: 0.53, blue: 0.15)
        case .orange:
            Color(red: 0.75, green: 0.39, blue: 0.16)
        case .red:
            Color(red: 0.72, green: 0.22, blue: 0.22)
        case .pink:
            Color(red: 0.70, green: 0.25, blue: 0.45)
        case .magenta:
            Color(red: 0.65, green: 0.25, blue: 0.60)
        case .purple:
            Color(red: 0.43, green: 0.31, blue: 0.72)
        case .indigo:
            Color(red: 0.30, green: 0.28, blue: 0.65)
        case .slate:
            Color(red: 0.28, green: 0.34, blue: 0.40)
        case .graphite:
            Color(red: 0.35, green: 0.35, blue: 0.35)
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
