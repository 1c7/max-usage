import XCTest
@testable import OpenUsage

/// Regression coverage for the stacked-keychain-prompt storm. Claude Code's keychain item carries a
/// partition list that denies every reader but Anthropic's own (anthropics/claude-code #77697), so
/// every decrypt attempt the auth store makes can surface a password dialog — and the loader used to
/// make up to four attempts per refresh (two read variants × two service candidates), re-firing on
/// every refresh cycle. The guard rails: probe before decrypting, abort the pass on the first
/// denial, and suppress further reads — persisted across relaunches, cleared only by the manual
/// Settings retry — instead of re-prompting on the next cycle.
final class KeychainPromptGuardTests: XCTestCase {
    private static let credentialsJSON =
        #"{"claudeAiOauth":{"accessToken":"token-1","refreshToken":"refresh-1","expiresAt":4102444800000,"subscriptionType":"max","scopes":["user:profile"]}}"#

    func testGenericPasswordExistsThroughProtocolDoesNotDecrypt() {
        // `genericPasswordExists` used to live only in a protocol extension whose default fell back
        // to a decrypting read, so any `any KeychainAccessing` caller (e.g. `DefaultAccountObserver`)
        // performed the secret read the probe exists to avoid. As a protocol requirement, dynamic
        // dispatch must reach the mock's item table without a single decrypt attempt.
        let keychain = ServiceKeychain()
        let anyKeychain: KeychainAccessing = keychain

        XCTAssertEqual(anyKeychain.genericPasswordExists(service: "svc"), false)
        XCTAssertEqual(keychain.decryptAttempts, [])
    }

    func testSecurityAccessorClassifiesDenialAndTimeoutSeparately() {
        // Timeout: the access prompt was up and unanswered — a denial, not a generic failure.
        let timedOut = SecurityKeychainAccessor(processRunner: StubProcessRunner(
            result: .failure(ProcessRunnerError.timedOut(executable: "/usr/bin/security", timeout: 5))
        ))
        XCTAssertThrowsError(try timedOut.readGenericPassword(service: "svc")) { error in
            guard case KeychainError.accessDenied = error else { return XCTFail("expected accessDenied, got \(error)") }
        }

        // Exit 45 (errSecAuthDenied): the user clicked Deny.
        let denied = SecurityKeychainAccessor(processRunner: StubProcessRunner(
            result: .success(ProcessResult(exitCode: 45, stdout: "", stderr: "User interaction is not allowed."))
        ))
        XCTAssertThrowsError(try denied.readGenericPassword(service: "svc")) { error in
            guard case KeychainError.accessDenied = error else { return XCTFail("expected accessDenied, got \(error)") }
        }

        // Exit 44 stays "no credential stored"; anything else stays a plain read failure.
        let missing = SecurityKeychainAccessor(processRunner: StubProcessRunner(
            result: .success(ProcessResult(exitCode: 44, stdout: "", stderr: ""))
        ))
        XCTAssertNil(try missing.readGenericPassword(service: "svc"))

        let failed = SecurityKeychainAccessor(processRunner: StubProcessRunner(
            result: .success(ProcessResult(exitCode: 1, stdout: "", stderr: "boom"))
        ))
        XCTAssertThrowsError(try failed.readGenericPassword(service: "svc")) { error in
            guard case KeychainError.readFailed = error else { return XCTFail("expected readFailed, got \(error)") }
        }
    }

    func testProbeSkipsDecryptForMissingServiceCandidate() {
        // With CLAUDE_CONFIG_DIR set the loader has two service candidates (hash-suffixed + base),
        // but only one item exists. The probe must skip the missing one without a single decrypt
        // attempt, and the hit on the base service must stop the pass before the legacy variant.
        let base = "Claude Code-credentials"
        let keychain = ServiceKeychain()
        keychain.currentUserValues[base] = Self.credentialsJSON
        let store = ClaudeAuthStore(
            environment: FakeEnvironment(["CLAUDE_CONFIG_DIR": "/tmp/claude-alt"]),
            files: FakeFiles(),
            keychain: keychain
        )

        let candidates = store.loadCredentialCandidates()

        XCTAssertEqual(candidates.first?.source.label, "keychainCurrentUser")
        XCTAssertEqual(keychain.decryptAttempts, ["currentUser(\(base))"])
    }

    func testDenialAbortsPassAndSuppressesUntilReset() {
        let base = "Claude Code-credentials"
        let keychain = ServiceKeychain()
        keychain.deniedServices.insert(base)
        let clock = MutableClock(Date(timeIntervalSince1970: 1_000_000))
        let backoff = KeychainReadBackoff(defaults: Self.isolatedDefaults())
        let store = ClaudeAuthStore(
            environment: FakeEnvironment(),
            files: FakeFiles(),
            keychain: keychain,
            keychainBackoff: backoff,
            now: { clock.now }
        )

        // First pass: exactly one decrypt attempt — the denial aborts before the legacy variant of
        // the same service (and any further candidates) can fire another dialog.
        XCTAssertTrue(store.loadCredentialCandidates().isEmpty)
        XCTAssertEqual(keychain.decryptAttempts, ["currentUser(\(base))"])

        // Suppression is indefinite: every retry on the partition-list item is just another
        // password dialog, so later refresh cycles never touch the keychain again — not after a
        // minute, not after hours, not after a relaunch.
        clock.now = clock.now.addingTimeInterval(60)
        XCTAssertTrue(store.loadCredentialCandidates().isEmpty)
        XCTAssertEqual(keychain.decryptAttempts.count, 1)
        clock.now = clock.now.addingTimeInterval(60 * 60 * 24)
        XCTAssertTrue(store.loadCredentialCandidates().isEmpty)
        XCTAssertEqual(keychain.decryptAttempts.count, 1)

        // Reset (Settings → Advanced → "Retry Claude Code Keychain Read") is the only way back:
        // the next pass consults the keychain again, so a repaired item is picked up.
        backoff.reset()
        _ = store.loadCredentialCandidates()
        XCTAssertEqual(keychain.decryptAttempts.count, 2)
    }

    func testDenialPersistsAcrossRelaunch() {
        // The denial must survive an app relaunch: a fresh backoff instance reading the same
        // defaults suite stays suppressed, otherwise the first refresh after every launch would
        // re-fire the very popup the suppression exists to prevent.
        let defaults = UserDefaults(suiteName: "keychain-backoff-relaunch-\(UUID().uuidString)")!
        let firstLaunch = KeychainReadBackoff(defaults: defaults)
        XCTAssertFalse(firstLaunch.isActive(now: Date()))
        firstLaunch.recordDenial(now: Date(timeIntervalSince1970: 1_000_000))

        let secondLaunch = KeychainReadBackoff(defaults: defaults)
        XCTAssertTrue(secondLaunch.isActive(now: Date(timeIntervalSince1970: 1_000_000 + 60)))

        secondLaunch.reset()
        XCTAssertFalse(secondLaunch.isActive(now: Date()))
        XCTAssertFalse(firstLaunch.isActive(now: Date()))
        XCTAssertNil(defaults.object(forKey: KeychainReadBackoff.persistedDenialKey))
    }

    private static func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "keychain-backoff-\(UUID().uuidString)")!
    }
}

/// Sendable test clock: `now` closures are `@Sendable`, so the test mutates time through a lock-free
/// box rather than a captured var (same pattern as the production `FileHandleBox`).
private final class MutableClock: @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}

private final class StubProcessRunner: ProcessRunning, @unchecked Sendable {
    var result: Result<ProcessResult, Error>

    init(result: Result<ProcessResult, Error>) {
        self.result = result
    }

    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) throws -> ProcessResult {
        try result.get()
    }
}
