import AppKit
import CoreImage
import SwiftUI

struct LANSyncSettingsSection: View {
    @Bindable var lanSync: LANSyncStore
    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular
    @State private var isPresentingPairingSheet = false
    @State private var pairingError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: density.headerToCardSpacing) {
            HStack(spacing: 5) {
                Text("Phone Sync")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "info.circle")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .hoverTooltip(String(
                        localized: "lanSync.infoTooltip",
                        defaultValue: "Lets the MaxUsage Android app show a read-only copy of these quotas over your local Wi-Fi. Nothing leaves your local network, and the phone never needs its own sign-in."
                    ))
            }
            .padding(.horizontal, 8)

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Text("Allow Phone Sync")
                    Spacer(minLength: 8)
                    Toggle("", isOn: $lanSync.enabled)
                        .settingsSwitchStyle()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, density.controlRowPadding)
                Text("Starts a local-network-only server so a paired phone can poll your quotas. Off by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if lanSync.enabled { enabledContent }
            }
            .cardSurface()
        }
        .sheet(isPresented: $isPresentingPairingSheet) {
            PairingQRSheet(lanSync: lanSync)
        }
    }

    @ViewBuilder
    private var enabledContent: some View {
        Divider()
        if let pairingError {
            inlineNotice(pairingError)
        }
        if lanSync.devices.isEmpty {
            Text("No phones paired yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ForEach(lanSync.devices) { device in
                deviceRow(device)
            }
        }
        Divider()
        Button {
            startPairing()
        } label: {
            Text("Add Phone…").frame(maxWidth: .infinity)
        }
        .glassButtonStyle()
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .padding(.vertical, density.controlRowPadding)
    }

    private func startPairing() {
        guard LocalNetworkAddress.currentIPv4() != nil else {
            pairingError = String(
                localized: "lanSync.noNetwork",
                defaultValue: "Connect this Mac to Wi-Fi to pair a phone."
            )
            return
        }
        pairingError = nil
        isPresentingPairingSheet = true
    }

    private func deviceRow(_ device: LANPairedDevice) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(lastSeenLabel(device, now: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                lanSync.removeDevice(id: device.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .hoverTooltip(String(localized: "lanSync.removeDevice", defaultValue: "Remove"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, density.controlRowPadding)
    }

    private func lastSeenLabel(_ device: LANPairedDevice, now: Date) -> String {
        guard let lastSeenAt = device.lastSeenAt else {
            return String(localized: "lanSync.neverSeen", defaultValue: "Not connected yet")
        }
        let seconds = max(0, now.timeIntervalSince(lastSeenAt))
        if seconds < 60 {
            return String(localized: "lanSync.lastSeen.justNow", defaultValue: "Active just now")
        }
        if seconds < 3_600 {
            let minutes = max(1, Int(seconds / 60))
            return String(localized: "lanSync.lastSeen.minutes", defaultValue: "Last seen \(minutes)m ago")
        }
        if seconds < 86_400 {
            let hours = max(1, Int(seconds / 3_600))
            return String(localized: "lanSync.lastSeen.hours", defaultValue: "Last seen \(hours)h ago")
        }
        let days = max(1, Int(seconds / 86_400))
        return String(localized: "lanSync.lastSeen.days", defaultValue: "Last seen \(days)d ago")
    }

    private func inlineNotice(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.notice)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The QR pairing sheet: renders `LANSyncStore.pairingSession` as a scannable code and counts down
/// to its two-minute expiry. There's no channel back from a successful phone scan to this sheet, so
/// it just shows the paired-devices list growing once the sheet is dismissed.
private struct PairingQRSheet: View {
    @Bindable var lanSync: LANSyncStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Scan with the MaxUsage Android App")
                .font(.headline)
            Group {
                if let session = lanSync.pairingSession {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if session.isExpired(now: context.date) {
                            expiredContent
                        } else {
                            qrContent(session: session, now: context.date)
                        }
                    }
                } else {
                    expiredContent
                }
            }
            .frame(width: 220, height: 220)
            Text("Open the app, tap Pair with Mac, and scan this code while it's on screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Button("Done") { dismiss() }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear { regenerate() }
        .onDisappear { lanSync.cancelPairing() }
    }

    private func qrContent(session: LANPairingSession, now: Date) -> some View {
        VStack(spacing: 12) {
            if let image = Self.qrImage(from: session.qrPayload(macName: Host.current().localizedName ?? "This Mac")) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 180, height: 180)
            }
            Text("Expires in \(max(0, Int(session.expiresAt.timeIntervalSince(now))))s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var expiredContent: some View {
        VStack(spacing: 12) {
            Text("Code expired")
                .foregroundStyle(.secondary)
            Button("Generate New Code") { regenerate() }
        }
    }

    private func regenerate() {
        guard let host = LocalNetworkAddress.currentIPv4() else { return }
        lanSync.beginPairing(host: host, port: LANSyncServer.port)
    }

    private static func qrImage(from data: Data) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let rep = NSCIImageRep(ciImage: transformed)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
