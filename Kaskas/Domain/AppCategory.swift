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
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        default: return .secondary
        }
    }

    public static let coding = AppCategory(
        id: "coding",
        name: "Yazılım",
        iconName: "chevron.left.forwardslash.chevron.right",
        colorName: "blue",
        isBuiltIn: true
    )

    public static let design = AppCategory(
        id: "design",
        name: "Tasarım",
        iconName: "paintpalette.fill",
        colorName: "purple",
        isBuiltIn: true
    )

    public static let writing = AppCategory(
        id: "writing",
        name: "Yazı",
        iconName: "doc.text.fill",
        colorName: "orange",
        isBuiltIn: true
    )

    public static let communication = AppCategory(
        id: "communication",
        name: "İletişim",
        iconName: "bubble.left.and.bubble.right.fill",
        colorName: "green",
        isBuiltIn: true
    )

    public static let browsing = AppCategory(
        id: "browsing",
        name: "İnternet",
        iconName: "safari.fill",
        colorName: "cyan",
        isBuiltIn: true
    )

    public static let entertainment = AppCategory(
        id: "entertainment",
        name: "Eğlence",
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

    public static let availableColors: [(name: String, color: Color)] = [
        ("blue", .blue),
        ("purple", .purple),
        ("indigo", .indigo),
        ("cyan", .cyan),
        ("teal", .teal),
        ("green", .green),
        ("mint", .mint),
        ("yellow", .yellow),
        ("orange", .orange),
        ("pink", .pink),
        ("red", .red),
        ("gray", .gray)
    ]

    public static let suggestedIcons: [String] = [
        // Geliştirme & Teknoloji
        "terminal.fill",
        "chevron.left.forwardslash.chevron.right",
        "cpu.fill",
        "server.rack",
        "keyboard.fill",
        "laptopcomputer",
        "desktopcomputer",
        "network",
        "command",

        // Tasarım & Sanat
        "paintpalette.fill",
        "paintbrush.fill",
        "pencil.tip.crop.circle.fill",
        "scissors",
        "cube.fill",
        "wand.and.stars",
        "swatchpalette.fill",
        "crop",
        "photo.fill",
        "camera.fill",

        // Okuma & Öğrenme
        "book.fill",
        "books.vertical.fill",
        "graduationcap.fill",
        "newspaper.fill",
        "bookmark.fill",
        "character.book.closed.fill",
        "text.book.closed.fill",
        "magnifyingglass",

        // Yazı & Ofis
        "doc.text.fill",
        "note.text",
        "pencil.and.outline",
        "folder.fill",
        "briefcase.fill",
        "archivebox.fill",
        "list.bullet.clipboard.fill",
        "tray.full.fill",
        "calendar",
        "clock.fill",

        // İletişim
        "bubble.left.and.bubble.right.fill",
        "message.fill",
        "envelope.fill",
        "phone.fill",
        "video.fill",
        "person.2.fill",
        "bell.fill",

        // Medya & Eğlence
        "play.tv.fill",
        "film.fill",
        "music.note",
        "headphones",
        "speaker.wave.2.fill",
        "mic.fill",
        "gamecontroller.fill",
        "dice.fill",
        "puzzlepiece.fill",

        // Finans & Ticaret
        "dollarsign.circle.fill",
        "chart.bar.xaxis",
        "chart.line.uptrend.xyaxis",
        "chart.pie.fill",
        "banknote.fill",
        "creditcard.fill",
        "cart.fill",
        "bag.fill",

        // Yaşam, Sağlık & Spor
        "figure.run",
        "dumbbell.fill",
        "heart.fill",
        "cup.and.saucer.fill",
        "fork.knife",
        "moon.fill",
        "sun.max.fill",
        "leaf.fill",

        // Araçlar & Genel
        "hammer.fill",
        "wrench.and.screwdriver.fill",
        "gearshape.fill",
        "lock.fill",
        "key.fill",
        "shield.fill",
        "sparkles",
        "star.fill",
        "flame.fill",
        "lightbulb.fill",
        "flag.fill",
        "tag.fill",
        "globe",
        "airplane",
        "car.fill"
    ]
}
