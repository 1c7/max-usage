import Foundation

/// Best-effort discovery of this Mac's LAN-facing IPv4 address, used to embed a directly-dialable
/// host in the LAN Sync pairing QR code so first pairing doesn't depend on mDNS resolving yet.
enum LocalNetworkAddress {
    /// The IPv4 address of the first active `en`-prefixed interface (Wi-Fi is conventionally `en0`
    /// on Macs), or `nil` when none is up — e.g. offline, or connected only over an interface this
    /// doesn't recognize.
    static func currentIPv4() -> String? {
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else { return nil }
        defer { freeifaddrs(ifaddrPointer) }

        var candidates: [(name: String, address: String)] = []
        for pointer in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let ifaAddr = interface.ifa_addr, ifaAddr.pointee.sa_family == UInt8(AF_INET) else { continue }
            guard interface.ifa_flags & UInt32(IFF_UP) != 0 else { continue }
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                ifaAddr, socklen_t(ifaAddr.pointee.sa_len),
                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST
            )
            guard result == 0 else { continue }
            candidates.append((name, String(cString: host)))
        }
        // en0 is conventionally Wi-Fi on Macs, so prefer it; otherwise take whatever's up.
        return candidates.first(where: { $0.name == "en0" })?.address ?? candidates.first?.address
    }
}
