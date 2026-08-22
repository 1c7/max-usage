import Foundation
@testable import OpenUsage
import XCTest

final class LanguageSettingTests: XCTestCase {
    private var originalLanguage: String?

    override func setUp() {
        super.setUp()
        originalLanguage = UserDefaults.standard.string(forKey: LanguageSetting.key)
    }

    override func tearDown() {
        if let original = originalLanguage {
            UserDefaults.standard.set(original, forKey: LanguageSetting.key)
        } else {
            UserDefaults.standard.removeObject(forKey: LanguageSetting.key)
        }
        super.tearDown()
    }

    func testDefaultSettingIsSystem() {
        UserDefaults.standard.removeObject(forKey: LanguageSetting.key)
        XCTAssertEqual(LanguageSetting.current, .system)
        XCTAssertEqual(LanguageSetting.fallback, .system)
    }

    func testEffectiveLanguageCodes() {
        XCTAssertEqual(LanguageSetting.en.effectiveLanguageCode, "en")
        XCTAssertEqual(LanguageSetting.zhHans.effectiveLanguageCode, "zh-Hans")
        XCTAssertTrue(
            LanguageSetting.system.effectiveLanguageCode == "en" ||
            LanguageSetting.system.effectiveLanguageCode == "zh-Hans"
        )
    }

    func testEffectiveLocale() {
        XCTAssertEqual(LanguageSetting.en.effectiveLocale.identifier, "en")
        XCTAssertEqual(LanguageSetting.zhHans.effectiveLocale.identifier, "zh-Hans")
    }

    func testPersistence() {
        UserDefaults.standard.set(LanguageSetting.zhHans.rawValue, forKey: LanguageSetting.key)
        XCTAssertEqual(LanguageSetting.current, .zhHans)

        UserDefaults.standard.set(LanguageSetting.en.rawValue, forKey: LanguageSetting.key)
        XCTAssertEqual(LanguageSetting.current, .en)

        UserDefaults.standard.set(LanguageSetting.system.rawValue, forKey: LanguageSetting.key)
        XCTAssertEqual(LanguageSetting.current, .system)
    }

    @MainActor
    func testApplyCurrentUpdatesBundleAndPostsNotification() {
        nonisolated(unsafe) var notificationFired = false
        let observer = NotificationCenter.default.addObserver(
            forName: LanguageSetting.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            notificationFired = true
        }

        UserDefaults.standard.set(LanguageSetting.en.rawValue, forKey: LanguageSetting.key)
        LanguageSetting.applyCurrent()
        XCTAssertTrue(notificationFired)

        let enString = String(localized: "languageSetting.system", defaultValue: "System", locale: LanguageSetting.current.effectiveLocale)
        XCTAssertEqual(enString, "System")

        UserDefaults.standard.set(LanguageSetting.zhHans.rawValue, forKey: LanguageSetting.key)
        LanguageSetting.applyCurrent()

        let mainString = Bundle.main.localizedString(forKey: "languageSetting.system", value: "System", table: nil)
        XCTAssertEqual(mainString, "跟随系统")

        let resourceString = Bundle.openUsageResources.localizedString(forKey: "languageSetting.system", value: "System", table: nil)
        XCTAssertEqual(resourceString, "跟随系统")

        let zhEnString = String(localized: "languageSetting.en", defaultValue: "English", locale: LanguageSetting.current.effectiveLocale)
        XCTAssertEqual(zhEnString, "English")

        let zhHansString = String(localized: "languageSetting.zhHans", defaultValue: "简体中文", locale: LanguageSetting.current.effectiveLocale)
        XCTAssertEqual(zhHansString, "简体中文")

        NotificationCenter.default.removeObserver(observer)
    }
}
