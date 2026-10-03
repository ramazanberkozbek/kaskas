import Foundation

enum BreakBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case ocean
    case mountainLake
    case snowPeaks
    case aurora
    case desertDunes
    case cosmic
    case custom

    var id: Self { self }

    var assetName: String? {
        switch self {
        case .ocean: "BreakOcean"
        case .mountainLake: "BreakMountainLake"
        case .snowPeaks: "BreakSnowPeaks"
        case .aurora: "BreakAurora"
        case .desertDunes: "BreakDesertDunes"
        case .cosmic: "BreakCosmic"
        case .custom: nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "calmGradient" {
            self = .ocean
        } else {
            self = BreakBackground(rawValue: raw) ?? .ocean
        }
    }
}

enum BreakLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case horizon
    case gentleBar

    var id: Self { self }
}

enum BreakSound: String, Codable, CaseIterable, Identifiable, Sendable {
    case glass = "Glass"
    case ping = "Ping"
    case pop = "Pop"
    case tink = "Tink"
    case hero = "Hero"

    var id: Self { self }
}

enum MicroReminderMascot: String, Codable, CaseIterable, Identifiable, Sendable {
    case flame
    case glasses

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .flame: "settings.microReminderMascot.flame"
        case .glasses: "settings.microReminderMascot.glasses"
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

enum MenuBarDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case iconAndTimer
    case iconOnly
    case timerOnly

    var id: Self { self }
}

enum NotificationPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case center
    case right

    var id: Self { self }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case turkish = "tr"

    var id: Self { self }

    var localeIdentifier: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? Locale.current.language.languageCode?.identifier ?? "en"
            return preferred.hasPrefix("tr") ? "tr" : "en"
        case .english:
            return "en"
        case .turkish:
            return "tr"
        }
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    var displayName: String {
        switch self {
        case .system:
            return AppLanguage.localizedString("settings.language.system", locale: locale)
        case .english:
            return "English"
        case .turkish:
            return "Türkçe"
        }
    }

    private static let lock = NSLock()
    private static var _currentLocale: Locale = FocusConfiguration.defaultLanguage.locale

    public static var currentLocale: Locale {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentLocale
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _currentLocale = newValue
        }
    }

    public static func localizedBundle(for locale: Locale) -> Bundle {
        let code = locale.language.languageCode?.identifier ?? (locale.identifier.hasPrefix("tr") ? "tr" : "en")
        let lang = code.hasPrefix("tr") ? "tr" : "en"
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    public static func localizedString(_ key: String, locale: Locale? = nil, defaultValue: String? = nil) -> String {
        let targetLocale = locale ?? currentLocale
        let bundle = localizedBundle(for: targetLocale)
        return bundle.localizedString(forKey: key, value: defaultValue ?? key, table: nil)
    }
}

public func localizedString(_ key: String, locale: Locale? = nil, defaultValue: String? = nil) -> String {
    AppLanguage.localizedString(key, locale: locale, defaultValue: defaultValue)
}


struct FocusConfiguration: Codable, Equatable, Sendable {
    static var defaultLanguage: AppLanguage {
        .system
    }

    var focusDuration: TimeInterval
    var microReminderInterval: TimeInterval
    var breakDuration: TimeInterval
    var longBreakEnabled: Bool
    var longBreakFrequency: Int
    var longBreakDuration: TimeInterval
    var snoozeDuration: TimeInterval
    var breakBackground: BreakBackground
    var breakLayout: BreakLayout
    var breakSoundEnabled: Bool
    var breakSound: BreakSound
    var breakEndSoundEnabled: Bool
    var breakEndSound: BreakSound
    var microReminderMascot: MicroReminderMascot
    var microReminderColor: MicroReminderColor
    var customWallpaperPath: String?
    var pauseDuringMeetings: Bool
    var idleDetectionEnabled: Bool
    var idleThreshold: TimeInterval
    var menuBarDisplayMode: MenuBarDisplayMode
    var showInDock: Bool
    var breakWarningEnabled: Bool
    var breakWarningLeadTime: TimeInterval
    var notificationPosition: NotificationPosition
    var appLanguage: AppLanguage

    init(
        focusDuration: TimeInterval = 45 * 60,
        microReminderInterval: TimeInterval = 20 * 60,
        breakDuration: TimeInterval = 5 * 60,
        longBreakEnabled: Bool = false,
        longBreakFrequency: Int = 3,
        longBreakDuration: TimeInterval = 10 * 60,
        snoozeDuration: TimeInterval = 5 * 60,
        breakBackground: BreakBackground = .mountainLake,
        breakLayout: BreakLayout = .horizon,
        breakSoundEnabled: Bool = false,
        breakSound: BreakSound = .glass,
        breakEndSoundEnabled: Bool = false,
        breakEndSound: BreakSound = .glass,
        microReminderMascot: MicroReminderMascot = .flame,
        microReminderColor: MicroReminderColor = .peach,
        customWallpaperPath: String? = nil,
        pauseDuringMeetings: Bool = true,
        idleDetectionEnabled: Bool = true,
        idleThreshold: TimeInterval = 3 * 60,
        menuBarDisplayMode: MenuBarDisplayMode = .iconAndTimer,
        showInDock: Bool = false,
        breakWarningEnabled: Bool = true,
        breakWarningLeadTime: TimeInterval = 20,
        notificationPosition: NotificationPosition = .center,
        appLanguage: AppLanguage = FocusConfiguration.defaultLanguage
    ) {
        self.focusDuration = max(1, focusDuration)
        self.microReminderInterval = max(1, microReminderInterval)
        self.breakDuration = max(1, breakDuration)
        self.longBreakEnabled = longBreakEnabled
        self.longBreakFrequency = max(1, longBreakFrequency)
        self.longBreakDuration = max(1, longBreakDuration)
        self.snoozeDuration = max(1, snoozeDuration)
        self.breakBackground = breakBackground
        self.breakLayout = breakLayout
        self.breakSoundEnabled = breakSoundEnabled
        self.breakSound = breakSound
        self.breakEndSoundEnabled = breakEndSoundEnabled
        self.breakEndSound = breakEndSound
        self.microReminderMascot = microReminderMascot
        self.microReminderColor = microReminderColor
        self.customWallpaperPath = customWallpaperPath
        self.pauseDuringMeetings = pauseDuringMeetings
        self.idleDetectionEnabled = idleDetectionEnabled
        self.idleThreshold = max(60, idleThreshold)
        self.menuBarDisplayMode = menuBarDisplayMode
        self.showInDock = showInDock
        self.breakWarningEnabled = breakWarningEnabled
        self.breakWarningLeadTime = min(60, max(5, (breakWarningLeadTime / 5).rounded() * 5))
        self.notificationPosition = notificationPosition
        self.appLanguage = appLanguage
    }

    private enum CodingKeys: String, CodingKey {
        case focusDuration
        case microReminderInterval
        case breakDuration
        case longBreakEnabled
        case longBreakFrequency
        case longBreakDuration
        case snoozeDuration
        case breakBackground
        case breakLayout
        case breakSoundEnabled
        case breakSound
        case breakEndSoundEnabled
        case breakEndSound
        case microReminderMascot
        case microReminderColor
        case customWallpaperPath
        case pauseDuringMeetings
        case idleDetectionEnabled
        case idleThreshold
        case menuBarDisplayMode
        case showInDock
        case breakWarningEnabled
        case breakWarningLeadTime
        case notificationPosition
        case appLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            focusDuration: try container.decode(TimeInterval.self, forKey: .focusDuration),
            microReminderInterval: try container.decode(TimeInterval.self, forKey: .microReminderInterval),
            breakDuration: try container.decode(TimeInterval.self, forKey: .breakDuration),
            longBreakEnabled: try container.decodeIfPresent(Bool.self, forKey: .longBreakEnabled) ?? false,
            longBreakFrequency: try container.decodeIfPresent(Int.self, forKey: .longBreakFrequency) ?? 3,
            longBreakDuration: try container.decodeIfPresent(TimeInterval.self, forKey: .longBreakDuration) ?? 10 * 60,
            snoozeDuration: try container.decode(TimeInterval.self, forKey: .snoozeDuration),
            breakBackground: try container.decodeIfPresent(
                BreakBackground.self,
                forKey: .breakBackground
            ) ?? .mountainLake,
            breakLayout: try container.decodeIfPresent(
                BreakLayout.self,
                forKey: .breakLayout
            ) ?? .horizon,
            breakSoundEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .breakSoundEnabled
            ) ?? false,
            breakSound: try container.decodeIfPresent(
                BreakSound.self,
                forKey: .breakSound
            ) ?? .glass,
            breakEndSoundEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .breakEndSoundEnabled
            ) ?? false,
            breakEndSound: try container.decodeIfPresent(
                BreakSound.self,
                forKey: .breakEndSound
            ) ?? .glass,
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
            ),
            pauseDuringMeetings: try container.decodeIfPresent(
                Bool.self,
                forKey: .pauseDuringMeetings
            ) ?? true,
            idleDetectionEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .idleDetectionEnabled
            ) ?? true,
            idleThreshold: try container.decodeIfPresent(
                TimeInterval.self,
                forKey: .idleThreshold
            ) ?? 3 * 60,
            menuBarDisplayMode: try container.decodeIfPresent(
                MenuBarDisplayMode.self,
                forKey: .menuBarDisplayMode
            ) ?? .iconAndTimer,
            showInDock: try container.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false,
            breakWarningEnabled: try container.decodeIfPresent(Bool.self, forKey: .breakWarningEnabled) ?? true,
            breakWarningLeadTime: try container.decodeIfPresent(TimeInterval.self, forKey: .breakWarningLeadTime) ?? 20,
            notificationPosition: try container.decodeIfPresent(NotificationPosition.self, forKey: .notificationPosition) ?? .center,
            appLanguage: try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? FocusConfiguration.defaultLanguage
        )
    }
}
