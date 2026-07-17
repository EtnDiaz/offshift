import SwiftUI
import OffshiftCompanionCore

struct ProtectionWindowView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.dismissWindow) private var dismissWindow
    @AccessibilityFocusState private var isCareMessageFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    RedCardCodexSleepMascotView(size: 270)
                    Text(store.careHeadline)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .accessibilityFocused($isCareMessageFocused)
                    Text(store.careMessage)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: 760)
                    Text("Nothing here closes Codex, your terminal, or your work.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))

                    VStack(spacing: 10) {
                        Text("Why now")
                            .font(.headline)
                        Text(store.careReason)
                        Text(store.countdownText)
                            .accessibilityLabel("Lock Screen status: \(store.countdownText)")
                    }
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: 720)

                    VStack(spacing: 12) {
                        Button("Start a 5-minute reset") { takeFiveAndDismiss() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .keyboardShortcut(.defaultAction)
                            .accessibilityHint("Closes this local care surface and starts a five-minute reset. Your work stays open.")
                        Button(store.pauseActionLabel) { pauseAndDismiss() }
                            .buttonStyle(.bordered)
                        if store.isProtectState {
                            HStack {
                                Button("On call for 15 min") { grantOnCallAndDismiss() }
                                Button("Cancel countdown") { store.cancelPreLockCountdown() }
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("This is a gentle night nudge. It cannot start a Lock Screen countdown.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }

                    if let onCallMessage = store.onCallMessage {
                        Text(onCallMessage)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Button("Turn Offshift off", role: .destructive) { turnOffAndDismiss() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 48)
        }
        .background(InterventionWindowConfigurator(onProtectionWindowReady: {
            store.protectionSurfaceDidBecomeVisible()
        }))
        .onAppear { isCareMessageFocused = true }
        .onDisappear { store.protectionSurfaceDidDisappear() }
    }

    private func takeFiveAndDismiss() {
        store.takeFive()
        dismissWindow(id: "protection")
    }

    private func pauseAndDismiss() {
        store.pauseUntilTomorrow()
        dismissWindow(id: "protection")
    }

    private func grantOnCallAndDismiss() {
        guard store.grantOnCallOverride() else { return }
        dismissWindow(id: "protection")
    }

    private func turnOffAndDismiss() {
        store.disableOffshift()
        dismissWindow(id: "protection")
    }
}

struct MenuBarContent: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Offshift is \(store.isOffshiftEnabled ? "on" : "off")")
        Button("Show Today") { openWindow(id: "dashboard") }
        SettingsLink { Text("Settings…") }
        #if DEBUG
        Divider()
        Button("Developer: care screen") {
            store.showDeveloperCarePreview()
            openWindow(id: "protection")
        }
        #endif
        Divider()
        Button("Quit Offshift") { NSApplication.shared.terminate(nil) }
    }
}
