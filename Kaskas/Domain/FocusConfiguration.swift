import Foundation

enum BreakBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case mountainLake
    case snowPeaks
    case aurora
    case desertDunes
    case cosmic
    case calmGradient
    case custom

    var id: Self { self }

    var assetName: String? {
        switch self {
        case .mountainLake: "BreakMountainLake"
        case .snowPeaks: "BreakSnowPeaks"
        case .aurora: "BreakAurora"
        case .desertDunes: "BreakDesertDunes"
        case .cosmic: "BreakCosmic"
        case .calmGradient, .custom: nil
        }
    }
}

enum BreakBackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case clear
    case frost

    var id: Self { self }
}

enum MicroReminderMascot: String, Codable, CaseIterable, Identifiable, Sendable {
    case flame

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .flame: "settings.microReminderMascot.flame"
        }
    }
}

enum MicroReminderColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case white
    case blue
    case mint
    case lavender
    case peach
    case pink
    case yellow
    case rainbow

    var id: Self { self }

    var titleKey: String { "settings.microReminderColor.\(rawValue)" }
}

struct FocusConfiguration: Codable, Equatable, Sendable {
    var focusDuration: TimeInterval
    var microReminderInterval: TimeInterval
    var breakDuration: TimeInterval
    var snoozeDuration: TimeInterval
    var breakBackground: BreakBackground
    var breakBackgroundStyle: BreakBackgroundStyle
    var breakOverlayDim: Double
    var microReminderMascot: MicroReminderMascot
    var microReminderColor: MicroReminderColor
    var customWallpaperPath: String?

    init(
        focusDuration: TimeInterval = 45 * 60,
        microReminderInterval: TimeInterval = 20 * 60,
        breakDuration: TimeInterval = 5 * 60,
        snoozeDuration: TimeInterval = 5 * 60,
        breakBackground: BreakBackground = .mountainLake,
        breakBackgroundStyle: BreakBackgroundStyle = .clear,
        breakOverlayDim: Double = 0.40,
        microReminderMascot: MicroReminderMascot = .flame,
        microReminderColor: MicroReminderColor = .peach,
        customWallpaperPath: String? = nil
    ) {
        self.focusDuration = max(1, focusDuration)
        self.microReminderInterval = max(1, microReminderInterval)
        self.breakDuration = max(1, breakDuration)
        self.snoozeDuration = max(1, snoozeDuration)
        self.breakBackground = breakBackground
        self.breakBackgroundStyle = breakBackgroundStyle
        self.breakOverlayDim = min(max(breakOverlayDim, 0.05), 0.90)
        self.microReminderMascot = microReminderMascot
        self.microReminderColor = microReminderColor
        self.customWallpaperPath = customWallpaperPath
    }

    private enum CodingKeys: String, CodingKey {
        case focusDuration
        case microReminderInterval
        case breakDuration
        case snoozeDuration
        case breakBackground
        case breakBackgroundStyle
        case breakOverlayDim
        case microReminderMascot
        case microReminderColor
        case customWallpaperPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            focusDuration: try container.decode(TimeInterval.self, forKey: .focusDuration),
            microReminderInterval: try container.decode(TimeInterval.self, forKey: .microReminderInterval),
            breakDuration: try container.decode(TimeInterval.self, forKey: .breakDuration),
            snoozeDuration: try container.decode(TimeInterval.self, forKey: .snoozeDuration),
            breakBackground: try container.decodeIfPresent(
                BreakBackground.self,
                forKey: .breakBackground
            ) ?? .mountainLake,
            breakBackgroundStyle: try container.decodeIfPresent(
                BreakBackgroundStyle.self,
                forKey: .breakBackgroundStyle
            ) ?? .clear,
            breakOverlayDim: try container.decodeIfPresent(
                Double.self,
                forKey: .breakOverlayDim
            ) ?? 0.40,
            microReminderMascot: (try? container.decode(
                MicroReminderMascot.self,
                forKey: .microReminderMascot
            )) ?? .flame,
            microReminderColor: try container.decodeIfPresent(
                MicroReminderColor.self,
                forKey: .microReminderColor
            ) ?? .peach,
            customWallpaperPath: try container.decodeIfPresent(
                String.self,
                forKey: .customWallpaperPath
            )
        )
    }
}
