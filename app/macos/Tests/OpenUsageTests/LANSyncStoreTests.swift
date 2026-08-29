import XCTest
@testable import OpenUsage

/// Covers `LANSyncStore`'s pairing handshake and bearer-token auth — the security-relevant logic
/// behind the LAN-reachable `LANSyncServer` (expiry, one-shot tokens, hashed-at-rest storage).
@MainActor
final class LANSyncStoreTests: XCTestCase {
    private func makeStore(now: @escaping () -> Date = Date.init) -> LANSyncStore {
        let suiteName = "LANSyncStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return LANSyncStore(defaults: defaults, now: now)
    }

    func testCompletePairingWithoutSessionFails() {
        let store = makeStore()
        XCTAssertNil(store.completePairing(presentedToken: "anything", deviceName: "Pixel"))
    }

    func testCompletePairingWithWrongTokenFails() {
        let store = makeStore()
        let session = store.beginPairing(host: "192.168.1.10", port: 6737)
        XCTAssertNil(store.completePairing(presentedToken: session.token + "x", deviceName: "Pixel"))
        // A failed attempt doesn't consume the session — the right token still works afterward.
        XCTAssertNotNil(store.completePairing(presentedToken: session.token, deviceName: "Pixel"))
    }

    func testSuccessfulPairingIssuesAWorkingBearerToken() {
        let store = makeStore()
        let session = store.beginPairing(host: "192.168.1.10", port: 6737)
        guard let deviceToken = store.completePairing(presentedToken: session.token, deviceName: "Pixel 9") else {
            return XCTFail("expected a device token")
        }
        XCTAssertTrue(store.authenticate(bearerToken: deviceToken))
        XCTAssertEqual(store.devices.count, 1)
        XCTAssertEqual(store.devices.first?.name, "Pixel 9")
        // The plaintext token is never persisted alongside the device record.
        XCTAssertNotEqual(store.devices.first?.tokenHash, deviceToken)
    }

    func testPairingSessionIsSingleUse() {
        let store = makeStore()
        let session = store.beginPairing(host: "192.168.1.10", port: 6737)
        XCTAssertNotNil(store.completePairing(presentedToken: session.token, deviceName: "Pixel"))
        // Re-presenting the same (now-consumed) token mints nothing further.
        XCTAssertNil(store.completePairing(presentedToken: session.token, deviceName: "Pixel"))
        XCTAssertEqual(store.devices.count, 1)
    }

    func testExpiredPairingSessionFails() {
        var clock = Date()
        let store = makeStore(now: { clock })
        let session = store.beginPairing(host: "192.168.1.10", port: 6737)
        XCTAssertFalse(session.isExpired(now: clock))

        clock = clock.addingTimeInterval(121) // past the 2-minute pairing window

        XCTAssertNil(store.completePairing(presentedToken: session.token, deviceName: "Pixel"))
        XCTAssertTrue(store.devices.isEmpty)
    }

    func testAuthenticateRejectsUnknownToken() {
        let store = makeStore()
        XCTAssertFalse(store.authenticate(bearerToken: "not-a-real-token"))
    }

    func testAuthenticateStampsLastSeen() {
        let store = makeStore()
        let session = store.beginPairing(host: "192.168.1.10", port: 6737)
        guard let deviceToken = store.completePairing(presentedToken: session.token, deviceName: "Pixel") else {
            return XCTFail("expected a device token")
        }
        XCTAssertNil(store.devices.first?.lastSeenAt)
        XCTAssertTrue(store.authenticate(bearerToken: deviceToken))
        XCTAssertNotNil(store.devices.first?.lastSeenAt)
    }

    func testRemoveDeviceRevokesItsToken() {
        let store = makeStore()
        let session = store.beginPairing(host: "192.168.1.10", port: 6737)
        guard let deviceToken = store.completePairing(presentedToken: session.token, deviceName: "Pixel"),
              let deviceID = store.devices.first?.id else {
            return XCTFail("expected a paired device")
        }
        store.removeDevice(id: deviceID)
        XCTAssertFalse(store.authenticate(bearerToken: deviceToken))
        XCTAssertTrue(store.devices.isEmpty)
    }

    func testDisablingClearsAnInProgressPairingSession() {
        let store = makeStore()
        store.enabled = true
        _ = store.beginPairing(host: "192.168.1.10", port: 6737)
        XCTAssertNotNil(store.pairingSession)
        store.enabled = false
        XCTAssertNil(store.pairingSession)
    }

    func testResetToDefaultsForgetsEveryDevice() {
        let store = makeStore()
        let session = store.beginPairing(host: "192.168.1.10", port: 6737)
        _ = store.completePairing(presentedToken: session.token, deviceName: "Pixel")
        store.enabled = true

        store.resetToDefaults()

        XCTAssertFalse(store.enabled)
        XCTAssertTrue(store.devices.isEmpty)
    }
}
