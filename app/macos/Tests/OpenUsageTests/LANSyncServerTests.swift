import XCTest
@testable import OpenUsage

/// End-to-end coverage of `LANSyncServer` over a real loopback socket: unauthenticated routes,
/// the pairing handshake, and bearer-token gating on the usage passthrough. Runs against a fixed
/// high port rather than `LANSyncServer.port` so it can't collide with a real running app.
@MainActor
final class LANSyncServerTests: XCTestCase {
    private static let testPort: UInt16 = 17_699

    private func makeSnapshotState() -> LocalUsageAPI.State {
        LocalUsageAPI.State(
            enabledOrderedIDs: ["claude"],
            knownIDs: ["claude"],
            snapshots: [
                "claude": ProviderSnapshot(
                    providerID: "claude",
                    displayName: "Claude",
                    plan: "Pro",
                    lines: [.progress(label: "Session", used: 42, limit: 100, format: .percent)],
                    refreshedAt: Date()
                ),
            ]
        )
    }

    private func startServer() -> (store: LANSyncStore, server: LANSyncServer) {
        let store = LANSyncStore(defaults: UserDefaults(suiteName: "LANSyncServerTests.\(UUID().uuidString)")!)
        let server = LANSyncServer(
            store: store,
            usageState: { [weak self] in self?.makeSnapshotState() ?? LocalUsageAPI.State(enabledOrderedIDs: [], knownIDs: [], snapshots: [:]) },
            macName: "Test Mac"
        )
        server.start(port: Self.testPort)
        return (store, server)
    }

    private func url(_ path: String) -> URL {
        URL(string: "http://127.0.0.1:\(Self.testPort)\(path)")!
    }

    /// The listener's `start(queue:)` returns before the socket is actually bound. Rather than a
    /// fixed sleep, poll `/v1/health` until it answers (or fail after a couple of seconds) so the
    /// suite isn't flaky under load and doesn't wait longer than it needs to on a fast machine.
    private func waitUntilReady() async throws {
        for _ in 0..<40 {
            if let (_, response) = try? await URLSession.shared.data(from: url("/v1/health")),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("server never became ready on port \(Self.testPort)")
    }

    func testHealthRequiresNoAuth() async throws {
        let (_, server) = startServer()
        defer { server.stop() }
        try await waitUntilReady()

        let (data, response) = try await URLSession.shared.data(from: url("/v1/health"))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["status"] as? String, "ok")
        XCTAssertEqual(json["name"] as? String, "Test Mac")
    }

    func testLimitsWithoutTokenIsUnauthorized() async throws {
        let (_, server) = startServer()
        defer { server.stop() }
        try await waitUntilReady()

        let (_, response) = try await URLSession.shared.data(from: url("/v1/limits"))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 401)
    }

    func testPairThenAuthenticatedLimitsSucceeds() async throws {
        let (store, server) = startServer()
        defer { server.stop() }
        try await waitUntilReady()

        let session = store.beginPairing(host: "127.0.0.1", port: Self.testPort)
        var pairRequest = URLRequest(url: url("/v1/pair"))
        pairRequest.httpMethod = "POST"
        pairRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "pairingToken": session.token, "deviceName": "Test Phone",
        ])

        let (pairData, pairResponse) = try await URLSession.shared.data(for: pairRequest)
        XCTAssertEqual((pairResponse as? HTTPURLResponse)?.statusCode, 200)
        let pairJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: pairData) as? [String: Any])
        let deviceToken = try XCTUnwrap(pairJSON["deviceToken"] as? String)

        var limitsRequest = URLRequest(url: url("/v1/limits"))
        limitsRequest.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        let (limitsData, limitsResponse) = try await URLSession.shared.data(for: limitsRequest)
        XCTAssertEqual((limitsResponse as? HTTPURLResponse)?.statusCode, 200)
        let limitsJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: limitsData) as? [String: Any])
        XCTAssertEqual(limitsJSON["schema"] as? String, "openusage.limits.v1")
        XCTAssertNotNil((limitsJSON["providers"] as? [String: Any])?["claude"])

        // A device the phone forgot (wrong token entirely) still gets 401.
        var badRequest = URLRequest(url: url("/v1/limits"))
        badRequest.setValue("Bearer not-a-real-token", forHTTPHeaderField: "Authorization")
        let (_, badResponse) = try await URLSession.shared.data(for: badRequest)
        XCTAssertEqual((badResponse as? HTTPURLResponse)?.statusCode, 401)
    }

    func testPairingWithWrongTokenIsForbidden() async throws {
        let (store, server) = startServer()
        defer { server.stop() }
        try await waitUntilReady()

        _ = store.beginPairing(host: "127.0.0.1", port: Self.testPort)
        var request = URLRequest(url: url("/v1/pair"))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["pairingToken": "wrong", "deviceName": "Phone"])

        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 403)
    }
}
