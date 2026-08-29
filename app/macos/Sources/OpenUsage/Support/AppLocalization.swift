import Foundation
import SwiftUI

/// Centralized, foolproof localization resolver that strictly respects the user's `LanguageSetting`.
/// Directly reads from the corresponding `.lproj` bundle without relying on implicit system Locale fallback.
enum AppLocalization {
    /// Resolves a localized string key against the active language setting.
    static func string(_ key: String, defaultValue: String) -> String {
        let code = LanguageSetting.current.effectiveLanguageCode // "zh-Hans" or "en"
        
        let searchBundles: [Bundle] = [
            Bundle.openUsageResources,
            Bundle.main
        ]
        
        for bundle in searchBundles {
            for lprojName in [code, code.lowercased(), "zh-Hans", "zh-hans", "en"] {
                if lprojName.lowercased().hasPrefix(code.prefix(2).lowercased()) {
                    if let path = bundle.path(forResource: lprojName, ofType: "lproj"),
                       let langBundle = Bundle(path: path) {
                        let localized = langBundle.localizedString(forKey: key, value: nil, table: nil)
                        if localized != key && !localized.isEmpty {
                            return localized
                        }
                    }
                }
            }
        }
        
        return defaultValue
    }
}
