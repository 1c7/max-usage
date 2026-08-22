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
            return String(localized: "languageSetting.system", defaultValue: "System", locale: LanguageSetting.current.effectiveLocale)
        case .en:
            return String(localized: "languageSetting.en", defaultValue: "English", locale: LanguageSetting.current.effectiveLocale)
        case .zhHans:
            return String(localized: "languageSetting.zhHans", defaultValue: "简体中文", locale: LanguageSetting.current.effectiveLocale)
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

    /// Determines the effective language code from system preferences.
    /// If the top preferred language is Chinese (any variant: zh-Hans, zh-Hant, zh-CN, etc.),
    /// returns "zh-Hans"; otherwise defaults to "en".
    static var systemEffectiveLanguageCode: String {
        guard let preferred = Locale.preferredLanguages.first else {
            return "en"
        }
        let lower = preferred.lowercased()
        return lower.hasPrefix("zh") ? "zh-Hans" : "en"
    }

    /// Applies the specified language setting app-wide (updates AppleLanguages, bundle localization,
    /// and posts change notification).
    @MainActor
    static func apply(_ setting: LanguageSetting) {
        let code = setting.effectiveLanguageCode
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        Bundle.setLanguage(code)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// Applies the current language setting app-wide.
    @MainActor
    static func applyCurrent() {
        apply(current)
    }
}
