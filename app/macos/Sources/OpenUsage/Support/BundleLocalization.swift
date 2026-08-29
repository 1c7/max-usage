import Foundation
import ObjectiveC

private final class BundleLocalizationToken {}

extension Bundle {
    private nonisolated(unsafe) static var isLocalizationSwizzled = false
    private nonisolated(unsafe) static var currentLanguageBundle: Bundle?

    /// Sets the active localization language code ("en", "zh-Hans", etc.).
    /// Finds the corresponding `.lproj` in `Bundle.main`, `Bundle.openUsageResources`,
    /// or module bundles and redirects `localizedString(forKey:value:table:)` calls to that table.
    static func setLanguage(_ languageCode: String) {
        let searchBundles: [Bundle] = [
            Bundle.main,
            Bundle.openUsageResources,
            Bundle(for: BundleLocalizationToken.self)
        ]

        var targetBundle: Bundle?
        for b in searchBundles {
            if let path = b.path(forResource: languageCode, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                targetBundle = bundle
                break
            }
            if let stringsPath = b.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: languageCode) {
                let lprojPath = (stringsPath as NSString).deletingLastPathComponent
                if let bundle = Bundle(path: lprojPath) {
                    targetBundle = bundle
                    break
                }
            }
        }

        currentLanguageBundle = targetBundle
        swizzleLocalizedStringIfNeeded()
    }

    private static func swizzleLocalizedStringIfNeeded() {
        guard !isLocalizationSwizzled else { return }
        isLocalizationSwizzled = true
        let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
        let swizzledSelector = #selector(Bundle.openUsage_localizedString(forKey:value:table:))
        guard let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func openUsage_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let customBundle = Bundle.currentLanguageBundle, self != customBundle {
            let isAppOrResourceBundle = self == Bundle.main
                || self == Bundle.openUsageResources
                || self == Bundle(for: BundleLocalizationToken.self)
                || (self.bundleIdentifier?.contains("OpenUsage") == true)
                || self.bundleURL.lastPathComponent.contains("OpenUsage")

            if isAppOrResourceBundle {
                return customBundle.openUsage_localizedString(forKey: key, value: value, table: tableName)
            }
        }
        return self.openUsage_localizedString(forKey: key, value: value, table: tableName)
    }
}
