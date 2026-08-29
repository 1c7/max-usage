import Foundation
import Network

/// LAN-facing counterpart to `LocalUsageServer`: the same read-only usage data, but reachable from
/// other devices on the local network — the paired Android app — rather than only this Mac.
///
/// Off by default; starts only while `LANSyncStore.enabled` is on. Advertises itself over Bonjour as
/// `_maxusage._tcp` so the phone can find it without the user typing an IP address. Every route
/// except `/v1/health` and `/v1/pair` requires `Authorization: Bearer <token>` naming an
/// already-paired device — unlike the loopback-only `LocalUsageServer`, this listener is reachable by
/// anything else on the same Wi-Fi, so it cannot hand out usage numbers unauthenticated.
@MainActor
final class LANSyncServer {
    static let port: UInt16 = 6737
    static let serviceType = "_maxusage._tcp"
    private static let maxConcurrentConnections = 16
    private static let headLimit = 16_384
    private static let maxBodyLength = 4_096

    private let store: LANSyncStore
    private let usageState: @MainActor () -> LocalUsageAPI.State
    private let macName: String
    private let queue = DispatchQueue(label: "openusage.lan-sync")
    private var listener: NWListener?
    private var activeConnections = 0

    init(store: LANSyncStore, usageState: @escaping @MainActor () -> LocalUsageAPI.State, macName: String) {
        self.store = store
        self.usageState = usageState
        self.macName = macName
    }

    /// `port` defaults to `Self.port`; tests override it to run against a fixed high port instead
    /// of colliding with a real running app.
    func start(port: UInt16 = LANSyncServer.port) {
        guard listener == nil, let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = false

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: nwPort)
        } catch {
            AppLog.info(.lanSync, "disabled: \(error.localizedDescription)")
            return
        }
        listener.service = NWListener.Service(name: macName, type: Self.serviceType)
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                AppLog.info(.lanSync, "disabled: \(error.localizedDescription)")
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        listener.start(queue: queue)
        self.listener = listener
        AppLog.info(.lanSync, "started on port \(port)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        guard activeConnections < Self.maxConcurrentConnections else {
            Self.send(Self.error(503, "server_busy"), over: connection)
            return
        }
        activeConnections += 1
        receiveHead(connection, buffered: Data())
    }

    /// Reads until the end of the request head (`\r\n\r\n`), then hands any bytes already read past
    /// that point to `receiveBody` as a head start on the body (pipelined reads can include both in
    /// one `receive` callback).
    private func receiveHead(_ connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.headLimit) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else {
                    connection.cancel()
                    return
                }
                var buffered = buffered
                if let data { buffered.append(data) }
                if let headEnd = buffered.range(of: Data("\r\n\r\n".utf8)) {
                    let head = String(data: buffered[..<headEnd.lowerBound], encoding: .utf8) ?? ""
                    let leftover = Data(buffered[headEnd.upperBound...])
                    self.finishHead(connection, head: head, leftover: leftover)
                } else if error != nil || isComplete || buffered.count >= Self.headLimit {
                    self.finish(connection, with: nil)
                } else {
                    self.receiveHead(connection, buffered: buffered)
                }
            }
        }
    }

    private func finishHead(_ connection: NWConnection, head: String, leftover: Data) {
        let contentLength = Self.headerValue(head, name: "content-length").flatMap(Int.init) ?? 0
        guard contentLength > 0 else {
            finish(connection, with: route(head: head, body: nil))
            return
        }
        let needed = min(contentLength, Self.maxBodyLength)
        receiveBody(connection, head: head, buffered: leftover, needed: needed)
    }

    private func receiveBody(_ connection: NWConnection, head: String, buffered: Data, needed: Int) {
        guard buffered.count < needed else {
            finish(connection, with: route(head: head, body: buffered.prefix(needed)))
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: needed - buffered.count) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else {
                    connection.cancel()
                    return
                }
                var buffered = buffered
                if let data { buffered.append(data) }
                if buffered.count >= needed || error != nil || isComplete {
                    self.finish(connection, with: self.route(head: head, body: buffered))
                } else {
                    self.receiveBody(connection, head: head, buffered: buffered, needed: needed)
                }
            }
        }
    }

    private func route(head: String, body: Data?) -> LocalUsageAPI.Response {
        let (method, path) = LocalUsageServer.parseRequestLine(head)
        AppLog.debug(.lanSync, "\(method) \(path)")

        if method == "OPTIONS" {
            return LocalUsageAPI.Response(status: 204, body: nil)
        }

        let segments = path.split(separator: "?", maxSplits: 1)[0].split(separator: "/").map(String.init)

        switch (method, segments) {
        case ("GET", ["v1", "health"]):
            let payload: [String: Any] = ["status": "ok", "name": macName]
            return LocalUsageAPI.Response(status: 200, body: try? JSONSerialization.data(withJSONObject: payload))

        case ("POST", ["v1", "pair"]):
            return handlePair(body: body)

        default:
            guard let token = Self.bearerToken(head), store.authenticate(bearerToken: token) else {
                return Self.error(401, "unauthorized")
            }
            return LocalUsageAPI.respond(method: method, path: path, state: usageState())
        }
    }

    private func handlePair(body: Data?) -> LocalUsageAPI.Response {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let token = json["pairingToken"] as? String else {
            return Self.error(400, "invalid_request")
        }
        let deviceName = (json["deviceName"] as? String) ?? "Phone"
        guard let deviceToken = store.completePairing(presentedToken: token, deviceName: deviceName) else {
            return Self.error(403, "pairing_failed")
        }
        let payload: [String: Any] = ["deviceToken": deviceToken, "macName": macName]
        return LocalUsageAPI.Response(status: 200, body: try? JSONSerialization.data(withJSONObject: payload))
    }

    private static func bearerToken(_ head: String) -> String? {
        guard let value = headerValue(head, name: "authorization"), value.lowercased().hasPrefix("bearer ") else {
            return nil
        }
        return String(value.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespaces)
    }

    /// Case-insensitive header lookup over the raw request head (request line + `Name: value` lines).
    private static func headerValue(_ head: String, name: String) -> String? {
        for line in head.split(separator: "\r\n").dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            guard key == name else { continue }
            return String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func error(_ status: Int, _ code: String) -> LocalUsageAPI.Response {
        LocalUsageAPI.Response(status: status, body: Data(#"{"error":"\#(code)"}"#.utf8))
    }

    private func finish(_ connection: NWConnection, with response: LocalUsageAPI.Response?) {
        activeConnections -= 1
        if let response {
            Self.send(response, over: connection)
        } else {
            connection.cancel()
        }
    }

    private nonisolated static func send(_ response: LocalUsageAPI.Response, over connection: NWConnection) {
        let reason: String = switch response.status {
        case 200: "OK"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 503: "Service Unavailable"
        default: "OK"
        }
        var head = "HTTP/1.1 \(response.status) \(reason)\r\n"
        head += "Connection: close\r\n"
        if let body = response.body {
            head += "Content-Type: application/json\r\n"
            head += "Content-Length: \(body.count)\r\n\r\n"
            connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in
                connection.cancel()
            })
        } else {
            head += "Content-Length: 0\r\n\r\n"
            connection.send(content: Data(head.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
