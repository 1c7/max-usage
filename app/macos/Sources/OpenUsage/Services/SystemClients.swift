import Darwin
import Foundation
import Security

protocol EnvironmentReading: Sendable {
    func value(for name: String) -> String?
}

struct ProcessEnvironmentReader: EnvironmentReading {
    var processEnvironment: [String: String] = ProcessInfo.processInfo.environment
    var shellEnvironment: LoginShellEnvironment = .shared
    var launchSnapshot: @Sendable () -> ShellEnvironmentSnapshot? = { ShellEnvironmentSnapshotStore.launchSnapshot }

    private static let identityKeys = Set(ShellEnvironmentSnapshot.capturedKeys)

    func value(for name: String) -> String? {
        // The process environment first (set by launchd, `launchctl setenv`, or a terminal launch),
        // then the captured login-shell environment — so keys a user exports in their shell profile
        // still resolve in a packaged app launched from Finder/Dock. See `LoginShellEnvironment`.
        if let value = processEnvironment[name]?.nilIfEmpty {
            return value
        }
        // Identity-relevant keys (provider home overrides, OAuth endpoint switches) resolve from the
        // persisted shell-environment snapshot when one exists: those facts — including "verifiably
        // NOT exported" — are frozen for the whole session, so every reader (the launch account pass
        // at init, the provider auth stores and log scanners whenever they run) sees the same home
        // overrides no matter when the async login-shell capture lands. Without the pin, an export
        // changed since the last launch would split them: identity read from the snapshot's home,
        // usage fetched from the freshly captured one, mis-stamping the shared snapshot cache. A
        // changed export applies from the next launch (the snapshot refresh task persists and logs
        // it). Every other key reads the live capture as before.
        if Self.identityKeys.contains(name), let snapshot = launchSnapshot() {
            return snapshot.values[name]?.nilIfEmpty
        }
        return shellEnvironment.value(for: name)
    }
}

protocol TextFileAccessing: Sendable {
    func exists(_ path: String) -> Bool
    /// Read a UTF-8 file when it exists. `nil` means the path is absent; permission, encoding, and
    /// other failures still throw so credential callers do not confuse broken storage with logout.
    func readTextIfPresent(_ path: String) throws -> String?
    func readText(_ path: String) throws -> String
    func writeText(_ path: String, _ text: String) throws
    /// Remove the file at `path`. A missing file is not an error — the caller wants the key gone, and
    /// it already is. Used by the in-app API-key editor's Remove / Clear-override actions.
    func remove(_ path: String) throws
}

extension TextFileAccessing {
    /// Compatibility path for test doubles. The production accessor classifies the read error directly
    /// so it does not have an exists-then-read race.
    func readTextIfPresent(_ path: String) throws -> String? {
        guard exists(path) else { return nil }
        return try readText(path)
    }
}

struct LocalTextFileAccessor: TextFileAccessing {
    /// Credential and token files must never be readable by another local account. Write through a
    /// private temporary file in the destination directory, flush it, then rename it over the target:
    /// the final replacement is atomic and has mode 0600 from the moment it becomes addressable.
    private static let privateFileMode = mode_t(S_IRUSR | S_IWUSR)

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: expandHome(path))
    }

    func readText(_ path: String) throws -> String {
        try String(contentsOfFile: expandHome(path), encoding: .utf8)
    }

    func readTextIfPresent(_ path: String) throws -> String? {
        do {
            return try readText(path)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    func writeText(_ path: String, _ text: String) throws {
        let expanded = expandHome(path)
        let parent = URL(fileURLWithPath: expanded).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let destination = URL(fileURLWithPath: expanded)
        let temporary = parent.appendingPathComponent(
            ".\(destination.lastPathComponent).\(UUID().uuidString).tmp"
        )
        let descriptor = temporary.path.withCString {
            Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, Self.privateFileMode)
        }
        guard descriptor >= 0 else { throw Self.currentPOSIXError() }

        var descriptorIsOpen = true
        var temporaryExists = true
        defer {
            if descriptorIsOpen { _ = Darwin.close(descriptor) }
            if temporaryExists {
                temporary.path.withCString { _ = Darwin.unlink($0) }
            }
        }

        // A process umask may only remove permissions at creation. Reassert the exact private mode on
        // the still-unpublished inode before writing or renaming it into place.
        guard Darwin.fchmod(descriptor, Self.privateFileMode) == 0 else {
            throw Self.currentPOSIXError()
        }
        try Self.writeAll(Data(text.utf8), to: descriptor)
        guard Darwin.fsync(descriptor) == 0 else { throw Self.currentPOSIXError() }
        let closeResult = Darwin.close(descriptor)
        descriptorIsOpen = false
        guard closeResult == 0 else { throw Self.currentPOSIXError() }

        let renameResult = temporary.path.withCString { source in
            expanded.withCString { destination in
                Darwin.rename(source, destination)
            }
        }
        guard renameResult == 0 else { throw Self.currentPOSIXError() }
        temporaryExists = false
    }

    func remove(_ path: String) throws {
        let expanded = expandHome(path)
        guard FileManager.default.fileExists(atPath: expanded) else { return }
        try FileManager.default.removeItem(atPath: expanded)
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let result = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    buffer.count - offset
                )
                if result < 0 {
                    if errno == EINTR { continue }
                    throw currentPOSIXError()
                }
                guard result > 0 else { throw POSIXError(.EIO) }
                offset += result
            }
        }
    }

    private static func currentPOSIXError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}

protocol SQLiteAccessing: Sendable {
    func queryValue(path: String, sql: String) throws -> String?
    func execute(path: String, sql: String) throws
}

struct SQLiteCLIAccessor: SQLiteAccessing {
    var processRunner: ProcessRunning

    init(processRunner: ProcessRunning = SystemProcessRunner()) {
        self.processRunner = processRunner
    }

    func queryValue(path: String, sql: String) throws -> String? {
        // A normal sqlite3 open can create a missing database. Credential probes must be read-only and
        // side-effect free, so absence returns nil before a process is launched.
        guard try databaseExists(path) else { return nil }
        let result = try run(path: path, sql: sql, readOnly: true)
        guard result.succeeded else {
            throw SQLiteError.queryFailed(result.stderr)
        }
        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func execute(path: String, sql: String) throws {
        let result = try run(path: path, sql: sql)
        guard result.succeeded else {
            throw SQLiteError.queryFailed(result.stderr)
        }
    }

    private func run(path: String, sql: String, readOnly: Bool = false) throws -> ProcessResult {
        var arguments = ["-batch", "-noheader"]
        if readOnly { arguments.append("-readonly") }
        arguments += [
            "-cmd", ".timeout 1000",
            expandHome(path),
            sql
        ]
        return try processRunner.run(
            executable: "/usr/bin/sqlite3",
            arguments: arguments,
            environment: [:],
            timeout: 5
        )
    }

    private func databaseExists(_ path: String) throws -> Bool {
        do {
            _ = try FileManager.default.attributesOfItem(atPath: expandHome(path))
            return true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return false
        }
    }
}

enum SQLiteError: Error, LocalizedError, Equatable {
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .queryFailed(let message):
            return message.isEmpty ? "SQLite query failed." : message
        }
    }
}

protocol KeychainAccessing: Sendable {
    func readGenericPassword(service: String) throws -> String?
    func writeGenericPassword(service: String, value: String) throws
    func readGenericPasswordForCurrentUser(service: String) throws -> String?
    func writeGenericPasswordForCurrentUser(service: String, value: String) throws
    /// Read a generic password scoped to an explicit account (`-a`). Used when another app stored the
    /// item under a known account name (e.g. Antigravity's `agy` token under service `gemini`,
    /// account `antigravity`) rather than the current user.
    func readGenericPassword(service: String, account: String) throws -> String?
    /// Whether an item exists for `service`, without reading its secret. `nil` means the probe
    /// itself failed (locked keychain, denied) — the caller picks its own safe side, which is not
    /// the same for every caller. A protocol requirement on purpose: as a plain extension method it
    /// dispatched to the decrypting fallback for `any KeychainAccessing` values even when the
    /// concrete type was `SecurityKeychainAccessor`, so the "existence check" performed the exact
    /// secret read (and keychain prompt) the probe exists to avoid.
    func genericPasswordExists(service: String) -> Bool?
}

extension KeychainAccessing {
    func readGenericPasswordForCurrentUser(service: String) throws -> String? {
        try readGenericPassword(service: service)
    }

    func writeGenericPasswordForCurrentUser(service: String, value: String) throws {
        try writeGenericPassword(service: service, value: value)
    }

    /// Default for mocks that don't model accounts: fall back to the service-only lookup. The real
    /// `SecurityKeychainAccessor` overrides this to pass `-a <account>`.
    func readGenericPassword(service: String, account: String) throws -> String? {
        try readGenericPassword(service: service)
    }

    /// Mock-only default: "unknown". Test doubles that model stored items override this from their
    /// item tables; the production accessor satisfies the requirement with its promptless native
    /// probe. Never falls back to a decrypting read — that is the bug this default replaces.
    func genericPasswordExists(service: String) -> Bool? { nil }
}

struct SecurityKeychainAccessor: KeychainAccessing {
    let processRunner: ProcessRunning

    init(processRunner: ProcessRunning = SystemProcessRunner()) {
        self.processRunner = processRunner
    }

    // `security find-generic-password` exit codes: 44 (errSecItemNotFound) is the legitimate "no
    // credential stored" case. 45 (errSecAuthDenied — the user clicked Deny, or UI interaction was
    // not allowed) and 51 (unlock/interaction family) mean a prompt was shown and NOT accepted; a
    // retry just shows it again. Any other non-zero exit is a real failure (locked keychain, access
    // denied after the fact) that must not be silently rendered as "not signed in".
    private static let itemNotFoundExitCode: Int32 = 44
    private static let accessDeniedExitCodes: Set<Int32> = [45, 51]

    func readGenericPassword(service: String) throws -> String? {
        try readPassword(["find-generic-password", "-s", service, "-w"], service: service)
    }

    /// Attributes-only existence probe used on the launch path: an in-process Security-framework
    /// query (no subprocess, returns in microseconds) that never requests the secret and forbids
    /// any UI, so it can neither trigger an unlock prompt nor stall launch. A failed probe (locked
    /// keychain, denied) reports `nil` ("unknown"), never a definite answer, so callers can pick
    /// their safe side.
    func genericPasswordExists(service: String) -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        switch SecItemCopyMatching(query as CFDictionary, nil) {
        case errSecSuccess: return true
        case errSecItemNotFound: return false
        default: return nil
        }
    }

    func readGenericPasswordForCurrentUser(service: String) throws -> String? {
        try readPassword(["find-generic-password", "-a", currentUserAccount(), "-s", service, "-w"], service: service)
    }

    func readGenericPassword(service: String, account: String) throws -> String? {
        try readPassword(["find-generic-password", "-a", account, "-s", service, "-w"], service: service)
    }

    private func readPassword(_ arguments: [String], service: String) throws -> String? {
        let result: ProcessResult
        do {
            result = try processRunner.run(
                executable: "/usr/bin/security",
                arguments: arguments,
                environment: [:],
                timeout: 5
            )
        } catch ProcessRunnerError.timedOut {
            // Not a slow tool: the access prompt was up and went unanswered for the whole window.
            // The user experience is identical to a denial, so classify it as one and let callers
            // back off — an immediate retry would spawn the next prompt.
            throw KeychainError.accessDenied("prompt unanswered (read timed out) for service '\(service)'")
        }
        guard result.succeeded else {
            if result.exitCode == Self.itemNotFoundExitCode { return nil }
            if Self.accessDeniedExitCodes.contains(result.exitCode) {
                throw KeychainError.accessDenied(result.stderr)
            }
            // Log loudly here so a locked/denied keychain is diagnosable even though current callers
            // `try?` this back to nil ("not signed in"). Surfacing a distinct user-facing "keychain
            // locked" message needs the auth-load chains to propagate the throw (folded into H1).
            AppLog.warn(.keychain, "read failed for service '\(service)' (exit \(result.exitCode))")
            throw KeychainError.readFailed(result.stderr)
        }
        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func writeGenericPassword(service: String, value: String) throws {
        try writePassword(service: service, account: nil, value: value)
    }

    func writeGenericPasswordForCurrentUser(service: String, value: String) throws {
        try writePassword(service: service, account: currentUserAccount(), value: value)
    }

    // In-process (SecItemAdd/SecItemUpdate), unlike the read paths above: a subprocess invocation
    // would pass the secret as a plaintext argument, readable by any other process owned by the same
    // user via `ps`/`sysctl KERN_PROCARGS2` for the subprocess's lifetime. Reads don't have this
    // exposure (the secret comes back on stdout, never in argv), so they're left on `security` for now.
    private func writePassword(service: String, account: String?, value: String) throws {
        guard let secretData = value.data(using: .utf8) else {
            throw KeychainError.writeFailed("Unable to encode secret.")
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: secretData] as CFDictionary)
        if updateStatus == errSecItemNotFound {
            query[kSecValueData as String] = secretData
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.writeFailed(Self.errorMessage(addStatus))
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.writeFailed(Self.errorMessage(updateStatus))
        }
    }

    private static func errorMessage(_ status: OSStatus) -> String {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain write failed (status \(status))."
    }

    private func currentUserAccount() -> String {
        ProcessInfo.processInfo.environment["USER"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ?? NSUserName()
    }
}

enum KeychainError: Error, LocalizedError {
    case writeFailed(String)
    case readFailed(String)
    /// A prompt was shown and not accepted: the user clicked Deny, interaction was not allowed, or
    /// the read timed out with the prompt still up. Distinct from `readFailed` because the right
    /// response is to stop reading the keychain for a cooldown — an immediate retry re-fires the
    /// prompt, and a loader that walks several service candidates stacks one dialog per attempt.
    case accessDenied(String)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let message):
            return message.isEmpty ? "Keychain write failed." : message
        case .readFailed(let message):
            return message.isEmpty ? "Keychain read failed." : message
        case .accessDenied(let message):
            return message.isEmpty ? "Keychain access denied." : message
        }
    }
}

/// App-wide memory of the most recent denied/unanswered keychain read. Auth stores are short-lived
/// structs recreated every refresh, so without shared state each refresh cycle would re-fire the
/// prompt — Claude Code's keychain item currently carries a partition list that denies every reader
/// but Anthropic's own (anthropics/claude-code #77697), making every decrypt attempt a fresh dialog.
/// One denial suppresses further keychain reads indefinitely and the suppression is persisted, so
/// neither the next refresh cycle nor an app relaunch re-fires the prompt; only `reset()` (Settings
/// → Advanced, "Retry Claude Code Keychain Read") re-enables reads, for when the item has actually
/// been repaired. Successful reads never touch this state.
final class KeychainReadBackoff: @unchecked Sendable {
    static let shared = KeychainReadBackoff()
    static let persistedDenialKey = "openusage.keychain.deniedAt.v1"

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var deniedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let interval = defaults.object(forKey: Self.persistedDenialKey) as? TimeInterval {
            deniedAt = Date(timeIntervalSince1970: interval)
        }
    }

    func recordDenial(now: Date) {
        lock.lock()
        deniedAt = now
        lock.unlock()
        defaults.set(now.timeIntervalSince1970, forKey: Self.persistedDenialKey)
    }

    func isActive(now: Date) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        // Defaults are the source of truth; the in-memory date is just a cache. Syncing both ways
        // keeps every instance in agreement (a `reset()` from one is visible to the others), which
        // also covers a reset landing between refresh cycles.
        if let interval = defaults.object(forKey: Self.persistedDenialKey) as? TimeInterval {
            if deniedAt == nil {
                deniedAt = Date(timeIntervalSince1970: interval)
            }
        } else {
            deniedAt = nil
        }
        return deniedAt != nil
    }

    func reset() {
        lock.lock()
        deniedAt = nil
        lock.unlock()
        defaults.removeObject(forKey: Self.persistedDenialKey)
    }
}

func expandHome(_ path: String) -> String {
    guard path == "~" || path.hasPrefix("~/") else { return path }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path == "~" { return home }
    return home + String(path.dropFirst())
}
