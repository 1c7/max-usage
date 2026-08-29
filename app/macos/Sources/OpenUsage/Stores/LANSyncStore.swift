import CryptoKit
import Foundation
import Observation

/// A phone that completed pairing: identified by a hash of its bearer token (never the token
/// itself), so the persisted list is safe to keep in `UserDefaults`.
struct LANPairedDevice: Codable, Identifiable, Sendable, Equatable {
    let id: String
    var name: String
    let tokenHash: String
    let pairedAt: Date
    var lastSeenAt: Date?
}

/// A pairing window started from Settings: a short-lived token shown as a QR code that a phone
/// exchanges for a long-lived bearer token via `POST /v1/pair`. Expires after two minutes so a QR
/// left visible can't be scanned later by someone else on the network.
struct LANPairingSession: Sendable, Equatable {
    let token: String
    let expiresAt: Date
    let host: String
    let port: UInt16

    func isExpired(now: Date = Date()) -> Bool { now >= expiresAt }

    /// The JSON payload encoded into the QR code. Carries the host/port directly (not just a
    /// service name) so first pairing works even before the phone's mDNS discovery resolves this
    /// Mac.
    func qrPayload(macName: String) -> Data {
        let payload: [String: Any] = [
            "v": 1,
            "host": host,
            "port": Int(port),
            "token": token,
            "name": macName,
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
}

/// Settings state for LAN Sync: whether the LAN-facing usage listener runs at all, the devices that
/// have paired with it, and any in-progress pairing window. Bearer tokens are generated here and
/// handed back to the phone once; only their SHA-256 hash is ever persisted, so a leaked defaults
/// domain doesn't leak working credentials.
@MainActor
@Observable
final class LANSyncStore {
    private static let enabledKey = "openusage.lanSync.enabled.v1"
    private static let devicesKey = "openusage.lanSync.devices.v1"
    private static let pairingTTL: TimeInterval = 120

    private let defaults: UserDefaults
    private let now: () -> Date

    var enabled: Bool {
        didSet {
            guard enabled != oldValue else { return }
            defaults.set(enabled, forKey: Self.enabledKey)
            if !enabled { pairingSession = nil }
            onEnabledChange?(enabled)
        }
    }
    private(set) var devices: [LANPairedDevice] {
        didSet { persistDevices() }
    }
    private(set) var pairingSession: LANPairingSession?
    /// Lets `AppContainer` start/stop the LAN listener when this flips, without this store holding a
    /// reference to `LANSyncServer` (which holds a reference back to this store).
    var onEnabledChange: ((Bool) -> Void)?

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        self.enabled = defaults.bool(forKey: Self.enabledKey, default: false)
        self.devices = Self.loadDevices(defaults: defaults)
    }

    /// Starts (or restarts) a two-minute pairing window at the given host/port.
    @discardableResult
    func beginPairing(host: String, port: UInt16) -> LANPairingSession {
        let session = LANPairingSession(
            token: Self.randomToken(byteCount: 16),
            expiresAt: now().addingTimeInterval(Self.pairingTTL),
            host: host,
            port: port
        )
        pairingSession = session
        return session
    }

    func cancelPairing() {
        pairingSession = nil
    }

    /// Exchanges a still-valid, matching pairing token for a new device's bearer token, consuming
    /// the session so it can only ever mint one device. A wrong token leaves the session untouched
    /// (a mistyped/garbled scan shouldn't burn the window), but an expired one is always dropped.
    func completePairing(presentedToken: String, deviceName: String) -> String? {
        guard let session = pairingSession, !session.isExpired(now: now()) else {
            pairingSession = nil
            return nil
        }
        guard session.token == presentedToken else { return nil }
        pairingSession = nil
        let token = Self.randomToken(byteCount: 32)
        let device = LANPairedDevice(
            id: UUID().uuidString,
            name: deviceName.isEmpty ? "Phone" : deviceName,
            tokenHash: Self.hash(token),
            pairedAt: now(),
            lastSeenAt: nil
        )
        devices.append(device)
        return token
    }

    /// Validates a bearer token from an incoming LAN request. On success, stamps the device's
    /// `lastSeenAt` so Settings can show "last seen" for each paired phone.
    @discardableResult
    func authenticate(bearerToken: String) -> Bool {
        let hash = Self.hash(bearerToken)
        guard let index = devices.firstIndex(where: { $0.tokenHash == hash }) else { return false }
        devices[index].lastSeenAt = now()
        return true
    }

    func removeDevice(id: String) {
        devices.removeAll { $0.id == id }
    }

    /// The Settings "Reset All Settings" path: turns the feature off and forgets every paired phone.
    func resetToDefaults() {
        enabled = false
        devices = []
    }

    private func persistDevices() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: Self.devicesKey)
    }

    private static func loadDevices(defaults: UserDefaults) -> [LANPairedDevice] {
        guard let data = defaults.data(forKey: devicesKey) else { return [] }
        return (try? JSONDecoder().decode([LANPairedDevice].self, from: data)) ?? []
    }

    private static func randomToken(byteCount: Int) -> String {
        Data((0..<byteCount).map { _ in UInt8.random(in: .min ... .max) })
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func hash(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
