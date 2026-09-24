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

struct FocusConfiguration: Codable, Equatable, Sendable {
    var focusDuration: TimeInterval
    var microReminderInterval: TimeInterval
    var breakDuration: TimeInterval
    var snoozeDuration: TimeInterval
    var breakBackground: BreakBackground
    var breakBackgroundStyle: BreakBackgroundStyle
    var breakOverlayDim: Double
    var customWallpaperPath: String?

    init(
        focusDuration: TimeInterval = 45 * 60,
        microReminderInterval: TimeInterval = 20 * 60,
        breakDuration: TimeInterval = 5 * 60,
        snoozeDuration: TimeInterval = 5 * 60,
        breakBackground: BreakBackground = .mountainLake,
        breakBackgroundStyle: BreakBackgroundStyle = .clear,
        breakOverlayDim: Double = 0.40,
        customWallpaperPath: String? = nil
    ) {
        self.focusDuration = max(1, focusDuration)
        self.microReminderInterval = max(1, microReminderInterval)
        self.breakDuration = max(1, breakDuration)
        self.snoozeDuration = max(1, snoozeDuration)
        self.breakBackground = breakBackground
        self.breakBackgroundStyle = breakBackgroundStyle
        self.breakOverlayDim = min(max(breakOverlayDim, 0.05), 0.90)
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
            customWallpaperPath: try container.decodeIfPresent(
                String.self,
                forKey: .customWallpaperPath
            )
        )
    }
}
