import SwiftUI

public struct AppCategory: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var iconName: String
    public var colorName: String
    public var isBuiltIn: Bool

    public init(id: String, name: String, iconName: String, colorName: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorName = colorName
        self.isBuiltIn = isBuiltIn
    }

    public var color: Color {
        switch colorName.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "cyan": return .cyan
        case "pink": return .pink
        case "red": return .red
        case "yellow": return .yellow
        default: return .secondary
        }
    }

    public static let coding = AppCategory(
        id: "coding",
        name: "Yazılım & Kodlama",
        iconName: "chevron.left.forwardslash.chevron.right",
        colorName: "blue",
        isBuiltIn: true
    )

    public static let design = AppCategory(
        id: "design",
        name: "Tasarım & Görsel",
        iconName: "paintpalette.fill",
        colorName: "purple",
        isBuiltIn: true
    )

    public static let writing = AppCategory(
        id: "writing",
        name: "Yazı & Notlar",
        iconName: "doc.text.fill",
        colorName: "orange",
        isBuiltIn: true
    )

    public static let communication = AppCategory(
        id: "communication",
        name: "İletişim & Toplantı",
        iconName: "bubble.left.and.bubble.right.fill",
        colorName: "green",
        isBuiltIn: true
    )

    public static let browsing = AppCategory(
        id: "browsing",
        name: "Araştırma & Okuma",
        iconName: "safari.fill",
        colorName: "cyan",
        isBuiltIn: true
    )

    public static let entertainment = AppCategory(
        id: "entertainment",
        name: "Medya & Eğlence",
        iconName: "play.tv.fill",
        colorName: "pink",
        isBuiltIn: true
    )

    public static let other = AppCategory(
        id: "other",
        name: "Diğer",
        iconName: "tag.fill",
        colorName: "gray",
        isBuiltIn: true
    )

    public static let defaultCategories: [AppCategory] = [
        .coding,
        .design,
        .writing,
        .communication,
        .browsing,
        .entertainment,
        .other
    ]
}
