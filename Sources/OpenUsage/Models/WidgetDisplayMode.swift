import Foundation

enum WidgetDisplayMode: String, Hashable, Sendable, CaseIterable {
    case used
    case remaining

    /// "Left" mirrors the legacy app's wording for remaining headroom.
    var label: String {
        switch self {
        case .used: return String(localized: "widgetDisplayMode.used", defaultValue: "Used")
        case .remaining: return String(localized: "widgetDisplayMode.left", defaultValue: "Left")
        }
    }

    mutating func toggle() {
        self = self == .used ? .remaining : .used
    }
}
