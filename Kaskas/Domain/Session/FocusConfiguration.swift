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

enum MicroReminderDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case mascot
    case cursorIcon

    var id: Self { self }
    var titleKey: String { "settings.microReminderDisplayMode.\(rawValue)" }
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

    var activeHours: ActiveHoursSchedule
    var focusDuration: TimeInterval
    var microRemindersEnabled: Bool
    var microReminderDisplayMode: MicroReminderDisplayMode
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
    var meetingPauseIndicatorEnabled: Bool
    var pauseDuringMeetings: Bool
    var pauseWhileTyping: Bool
    var typingPauseIndicatorEnabled: Bool
    var pauseDuringVideo: Bool
    var videoPauseIndicatorEnabled: Bool
    var meetingCameraDetectionEnabled: Bool
    var meetingVirtualMicrophonesEnabled: Bool
    var meetingExcludedDeviceUIDs: [String]
    var meetingExcludedBundleIDs: [String]
    var videoExcludedBundleIDs: [String]
    var idleDetectionEnabled: Bool
    var idleThreshold: TimeInterval
    var menuBarDisplayMode: MenuBarDisplayMode
    var showInDock: Bool
    var breakWarningEnabled: Bool
    var breakWarningLeadTime: TimeInterval
    var notificationPosition: NotificationPosition
    var appLanguage: AppLanguage

    init(
        activeHours: ActiveHoursSchedule = ActiveHoursSchedule(),
        focusDuration: TimeInterval = 25 * 60,
        microRemindersEnabled: Bool = true,
        microReminderDisplayMode: MicroReminderDisplayMode = .mascot,
        microReminderInterval: TimeInterval = 20 * 60,
        breakDuration: TimeInterval = 5 * 60,
        longBreakEnabled: Bool = false,
        longBreakFrequency: Int = 3,
        longBreakDuration: TimeInterval = 10 * 60,
        snoozeDuration: TimeInterval = 5 * 60,
        breakBackground: BreakBackground = .snowPeaks,
        breakLayout: BreakLayout = .gentleBar,
        breakSoundEnabled: Bool = true,
        breakSound: BreakSound = .glass,
        breakEndSoundEnabled: Bool = true,
        breakEndSound: BreakSound = .glass,
        microReminderMascot: MicroReminderMascot = .flame,
        microReminderColor: MicroReminderColor = .white,
        customWallpaperPath: String? = nil,
        pauseDuringMeetings: Bool = true,
        meetingPauseIndicatorEnabled: Bool = true,
        pauseWhileTyping: Bool = true,
        typingPauseIndicatorEnabled: Bool = true,
        pauseDuringVideo: Bool = false,
        videoPauseIndicatorEnabled: Bool = true,
        meetingCameraDetectionEnabled: Bool = false,
        meetingVirtualMicrophonesEnabled: Bool = false,
        meetingExcludedDeviceUIDs: [String] = [],
        meetingExcludedBundleIDs: [String] = ["com.apple.QuickTimePlayerX", "com.apple.quicklook", "com.rogueamoeba.audiohijack", "com.rogueamoeba.Loopback", "com.apple.SpeechRecognitionCore.speechrecognitiond"],
        videoExcludedBundleIDs: [String] = ["com.spotify.client", "com.apple.Music", "com.apple.FinalCut", "com.blackmagic-design.DaVinciResolve", "com.endel.endel"],
        idleDetectionEnabled: Bool = true,
        idleThreshold: TimeInterval = 3 * 60,
        menuBarDisplayMode: MenuBarDisplayMode = .iconAndTimer,
        showInDock: Bool = false,
        breakWarningEnabled: Bool = true,
        breakWarningLeadTime: TimeInterval = 20,
        notificationPosition: NotificationPosition = .center,
        appLanguage: AppLanguage = FocusConfiguration.defaultLanguage
    ) {
        self.activeHours = activeHours.isValid ? activeHours : ActiveHoursSchedule()
        self.focusDuration = max(1, focusDuration)
        self.microRemindersEnabled = microRemindersEnabled
        self.microReminderDisplayMode = microReminderDisplayMode
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
        self.meetingPauseIndicatorEnabled = meetingPauseIndicatorEnabled
        self.pauseWhileTyping = pauseWhileTyping
        self.typingPauseIndicatorEnabled = typingPauseIndicatorEnabled
        self.pauseDuringVideo = pauseDuringVideo
        self.videoPauseIndicatorEnabled = videoPauseIndicatorEnabled
        self.meetingCameraDetectionEnabled = meetingCameraDetectionEnabled
        self.meetingVirtualMicrophonesEnabled = meetingVirtualMicrophonesEnabled
        self.meetingExcludedDeviceUIDs = meetingExcludedDeviceUIDs
        self.meetingExcludedBundleIDs = meetingExcludedBundleIDs
        self.videoExcludedBundleIDs = videoExcludedBundleIDs
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
        case activeHours
        case focusDuration
        case microRemindersEnabled
        case microReminderDisplayMode
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
        case meetingPauseIndicatorEnabled
        case pauseWhileTyping
        case typingPauseIndicatorEnabled
        case pauseDuringVideo
        case videoPauseIndicatorEnabled
        case meetingCameraDetectionEnabled
        case meetingVirtualMicrophonesEnabled
        case meetingExcludedDeviceUIDs
        case meetingExcludedBundleIDs
        case videoExcludedBundleIDs
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
        let defaults = FocusConfiguration()
        // A removed enum case or malformed field must not reset unrelated preferences.
        func value<T: Decodable>(_ key: CodingKeys, fallback: T) -> T {
            do {
                return try container.decodeIfPresent(T.self, forKey: key) ?? fallback
            } catch {
                NSLog("Kaskas: Could not restore setting %@: %@", key.stringValue, String(describing: error))
                return fallback
            }
        }
        self.init(
            activeHours: value(.activeHours, fallback: defaults.activeHours),
            focusDuration: value(.focusDuration, fallback: defaults.focusDuration),
            microRemindersEnabled: value(.microRemindersEnabled, fallback: defaults.microRemindersEnabled),
            microReminderDisplayMode: value(.microReminderDisplayMode, fallback: defaults.microReminderDisplayMode),
            microReminderInterval: value(.microReminderInterval, fallback: defaults.microReminderInterval),
            breakDuration: value(.breakDuration, fallback: defaults.breakDuration),
            longBreakEnabled: value(.longBreakEnabled, fallback: defaults.longBreakEnabled),
            longBreakFrequency: value(.longBreakFrequency, fallback: defaults.longBreakFrequency),
            longBreakDuration: value(.longBreakDuration, fallback: defaults.longBreakDuration),
            snoozeDuration: value(.snoozeDuration, fallback: defaults.snoozeDuration),
            breakBackground: value(.breakBackground, fallback: defaults.breakBackground),
            breakLayout: value(.breakLayout, fallback: defaults.breakLayout),
            breakSoundEnabled: value(.breakSoundEnabled, fallback: defaults.breakSoundEnabled),
            breakSound: value(.breakSound, fallback: defaults.breakSound),
            breakEndSoundEnabled: value(.breakEndSoundEnabled, fallback: defaults.breakEndSoundEnabled),
            breakEndSound: value(.breakEndSound, fallback: defaults.breakEndSound),
            microReminderMascot: value(.microReminderMascot, fallback: defaults.microReminderMascot),
            microReminderColor: value(.microReminderColor, fallback: defaults.microReminderColor),
            customWallpaperPath: value(.customWallpaperPath, fallback: defaults.customWallpaperPath),
            pauseDuringMeetings: value(.pauseDuringMeetings, fallback: defaults.pauseDuringMeetings),
            meetingPauseIndicatorEnabled: value(.meetingPauseIndicatorEnabled, fallback: defaults.meetingPauseIndicatorEnabled),
            pauseWhileTyping: value(.pauseWhileTyping, fallback: defaults.pauseWhileTyping),
            typingPauseIndicatorEnabled: value(.typingPauseIndicatorEnabled, fallback: defaults.typingPauseIndicatorEnabled),
            pauseDuringVideo: value(.pauseDuringVideo, fallback: defaults.pauseDuringVideo),
            videoPauseIndicatorEnabled: value(.videoPauseIndicatorEnabled, fallback: defaults.videoPauseIndicatorEnabled),
            meetingCameraDetectionEnabled: value(.meetingCameraDetectionEnabled, fallback: defaults.meetingCameraDetectionEnabled),
            meetingVirtualMicrophonesEnabled: value(.meetingVirtualMicrophonesEnabled, fallback: defaults.meetingVirtualMicrophonesEnabled),
            meetingExcludedDeviceUIDs: value(.meetingExcludedDeviceUIDs, fallback: defaults.meetingExcludedDeviceUIDs),
            meetingExcludedBundleIDs: value(.meetingExcludedBundleIDs, fallback: defaults.meetingExcludedBundleIDs),
            videoExcludedBundleIDs: value(.videoExcludedBundleIDs, fallback: defaults.videoExcludedBundleIDs),
            idleDetectionEnabled: value(.idleDetectionEnabled, fallback: defaults.idleDetectionEnabled),
            idleThreshold: value(.idleThreshold, fallback: defaults.idleThreshold),
            menuBarDisplayMode: value(.menuBarDisplayMode, fallback: defaults.menuBarDisplayMode),
            showInDock: value(.showInDock, fallback: defaults.showInDock),
            breakWarningEnabled: value(.breakWarningEnabled, fallback: defaults.breakWarningEnabled),
            breakWarningLeadTime: value(.breakWarningLeadTime, fallback: defaults.breakWarningLeadTime),
            notificationPosition: value(.notificationPosition, fallback: defaults.notificationPosition),
            appLanguage: value(.appLanguage, fallback: defaults.appLanguage)
        )
    }
}
