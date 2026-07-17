import SwiftUI
import OffshiftCompanionCore

struct ProtectionWindowView: View {
    @ObservedObject var store: CompanionStore
    let onDismiss: () -> Void
    @AccessibilityFocusState private var isCareMessageFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    if store.isDeveloperCarePreview {
                        Label("Preview — Lock Screen and smart-home actions are disabled", systemImage: "eye")
                            .font(.headline)
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.09), in: Capsule())
                            .accessibilityLabel("Developer preview. Lock Screen and smart-home actions are disabled.")
                    }
                    RedCardCodexSleepMascotView(size: 310)
                    Text(store.careHeadline)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .accessibilityFocused($isCareMessageFocused)
                    Text(store.careMessage)
                        .font(.system(size: 23, weight: .regular, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: 820)
                    Text("Nothing here closes Codex, your terminal, or your work.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))

                    VStack(spacing: 8) {
                        Text("Why now")
                            .font(.headline)
                        Text(store.careReason)
                        if store.hasActivePreLockCountdown || store.isDeveloperCarePreview {
                            Text(store.countdownText)
                                .accessibilityLabel("Lock Screen status: \(store.countdownText)")
                        }
                    }
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: 720)

                    VStack(spacing: 14) {
                        Button("Start a 5-minute reset") { takeFiveAndDismiss() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .keyboardShortcut(.defaultAction)
                            .accessibilityHint("Closes this local care surface and starts a five-minute reset. Your work stays open.")
                        if store.hasActivePreLockCountdown {
                            Button("Cancel Lock Screen countdown") { store.cancelPreLockCountdown() }
                                .buttonStyle(.bordered)
                                .accessibilityHint("Cancels the active local Lock Screen countdown.")
                        } else if store.isProtectState {
                            Button("I’m on call — 15 minutes") { grantOnCallAndDismiss() }
                                .buttonStyle(.bordered)
                                .accessibilityHint("Pauses Offshift nudges for fifteen minutes, then returns to your local settings.")
                        } else {
                            Button(store.pauseActionLabel) { pauseAndDismiss() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                    if let onCallMessage = store.onCallMessage {
                        Text(onCallMessage)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Button("Turn Offshift off", role: .destructive) { turnOffAndDismiss() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Emergency exit: press Escape four times")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.48))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 56)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 64)
        }
        .background(InterventionWindowConfigurator(
            requiresMonitorCover: store.careScreenRequiresMonitorCover,
            shouldKeepPresented: { store.shouldKeepProtectionSurfacePresented },
            onProtectionWindowReady: {
                store.protectionSurfaceDidBecomeVisible()
            }
        ))
        .onAppear { isCareMessageFocused = true }
        .onDisappear { store.protectionSurfaceDidDisappear() }
    }

    private func takeFiveAndDismiss() {
        store.takeFive()
        onDismiss()
    }

    private func pauseAndDismiss() {
        store.pauseUntilTomorrow()
        onDismiss()
    }

    private func grantOnCallAndDismiss() {
        guard store.grantOnCallOverride() else { return }
        onDismiss()
    }

    private func turnOffAndDismiss() {
        store.disableOffshift()
        onDismiss()
    }
}

struct StatusPopoverView: View {
    @ObservedObject var store: CompanionStore
    let openToday: () -> Void
    let openSettings: () -> Void
    let showDeveloperCare: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.isOffshiftEnabled ? "Offshift is on" : "Offshift is off")
                .font(.headline)
            Text(store.localControlSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            Button("Open Today", action: openToday)
            Button("Settings…", action: openSettings)
            #if DEBUG
            Divider()
            Button("Developer: care screen", action: showDeveloperCare)
            #endif
            Divider()
            Button("Quit Offshift", role: .destructive, action: quit)
        }
        .padding(14)
        .frame(width: 280, alignment: .leading)
    }
}
