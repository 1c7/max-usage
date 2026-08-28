import Foundation

/// Explicit language override for the whole app; `.system` follows macOS preferred language.
/// If the user's primary system language is Chinese, it displays Simplified Chinese (`zh-Hans`),
/// otherwise English (`en`).
enum LanguageSetting: String, Hashable, Sendable, CaseIterable, UserDefaultsBacked {
    case system
    case en
    case zhHans

    static let key = "language"
    static var fallback: LanguageSetting { .system }

    /// Posted by `applyCurrent()` when language is updated.
    static let didChangeNotification = Notification.Name("LanguageSettingDidChange")

    var label: String {
        switch self {
        case .system:
            return AppLocalization.string("languageSetting.system", defaultValue: "System")
        case .en:
            return AppLocalization.string("languageSetting.en", defaultValue: "English")
        case .zhHans:
            return AppLocalization.string("languageSetting.zhHans", defaultValue: "简体中文")
        }
    }

    /// The effective BCP-47 language tag used for bundle lookup and Locale creation.
    var effectiveLanguageCode: String {
        switch self {
        case .system:
            return Self.systemEffectiveLanguageCode
        case .en:
            return "en"
        case .zhHans:
            return "zh-Hans"
        }
    }

    var effectiveLocale: Locale {
        Locale(identifier: effectiveLanguageCode)
    }

    /// Determines the effective language code from macOS system preferences.
    /// Reads from the global system domain first to prevent being shadowed by app-level defaults.
    /// If the top preferred language is Chinese (zh-Hans, zh-Hant, zh-CN, zh-HK, etc.),
    /// returns "zh-Hans"; otherwise defaults to "en".
    static var systemEffectiveLanguageCode: String {
        let globalLanguages = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
        let preferred = globalLanguages?.first ?? Locale.preferredLanguages.first ?? "en"
        let lower = preferred.lowercased()
        return lower.hasPrefix("zh") ? "zh-Hans" : "en"
    }

    /// Applies the specified language setting app-wide (updates AppleLanguages, bundle localization,
    /// and posts change notification).
    @MainActor
    static func apply(_ setting: LanguageSetting) {
        switch setting {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .en:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .zhHans:
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        }
        let code = setting.effectiveLanguageCode
        Bundle.setLanguage(code)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// Applies the current language setting app-wide.
    @MainActor
    static func applyCurrent() {
        apply(current)
    }
}
