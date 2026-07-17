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
                    OffshiftBrandMarkView(size: 270)
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
        Divider()
        Button("Quit Offshift") { NSApplication.shared.terminate(nil) }
    }
}

struct CompanionSettingsView: View {
    @ObservedObject var store: CompanionStore
    @State private var showingLockScreenConfirmation = false

    var body: some View {
        Form {
            Section("Care on this Mac") {
                Text("Choose when Offshift is allowed to care for you. These controls never affect Codex, your terminal, or your work.")
                    .foregroundStyle(.secondary)
                Picker("Offshift mode", selection: Binding(
                    get: { store.careMode },
                    set: { store.setCareMode($0) }
                )) {
                    Text("Sleep care is on").tag(OffshiftCareMode.sleep)
                    Text("Offshift is off").tag(OffshiftCareMode.off)
                }
                Text(store.localControlSummary)
                Text("A pause immediately cancels a local countdown and prevents scenes or Lock Screen actions until tomorrow. Turning Offshift off also stops local sampling.")
                    .foregroundStyle(.secondary)
                if store.isPaused {
                    HStack {
                        Button("Resume Offshift") { store.resumeOffshift() }
                        Button("Turn Offshift off", role: .destructive) { store.disableOffshift() }
                    }
                } else if store.isOffshiftEnabled {
                    HStack {
                        Button(store.pauseActionLabel) { store.pauseUntilTomorrow() }
                        Button("Turn Offshift off", role: .destructive) { store.disableOffshift() }
                    }
                } else {
                    Button("Turn Offshift on") { store.resumeOffshift() }
                }
            }
            Section("Optional Lock Screen rule") {
                Text("A local rule can use the macOS Lock Screen shortcut only after your explicit confirmation.")
                Text("When the local policy remains Protect, Offshift first shows the black care screen. Only after it is visible can a single 10-second countdown begin. Cancel and a bounded 15-minute on-call override remain available.")
                    .foregroundStyle(.secondary)
                if store.lockRuleEnabled {
                    Text("Enabled only on this Mac.")
                    Button("Disable local Lock Screen rule", role: .destructive) {
                        store.lockScreenSettings.disableImmediately()
                    }
                } else {
                    Button("Enable local Lock Screen rule…") {
                        showingLockScreenConfirmation = true
                    }
                }
                Text(store.lockScreenSettings.accessibilityStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Night context") {
                Toggle("Enable nightly care", isOn: Binding(
                    get: { store.nightCareSettings.isEnabled },
                    set: { store.nightCareSettings.setEnabled($0) }
                ))
                Toggle("I have an early start tomorrow", isOn: Binding(
                    get: { store.nightCareSettings.hasEarlyStartTomorrow },
                    set: { store.nightCareSettings.setEarlyStartTomorrow($0) }
                ))
                Text("Quiet hours add context to sustained local activity. Time alone never opens protection or triggers a Lock Screen action.")
                    .foregroundStyle(.secondary)
                Picker("Starts", selection: Binding(
                    get: { store.nightCareSettings.startHour },
                    set: { store.nightCareSettings.setStartHour($0) }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(NightCareSettings.hourLabel(hour)).tag(hour)
                    }
                }
                Picker("Ends", selection: Binding(
                    get: { store.nightCareSettings.endHour },
                    set: { store.nightCareSettings.setEndHour($0) }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(NightCareSettings.hourLabel(hour)).tag(hour)
                    }
                }
                Text(store.nightCareSettings.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Home Assistant wind-down") {
                Text("Optional. Configure this only on your Mac. Offshift can invoke one mapped scene: scene.offshift_wind_down.")
                    .foregroundStyle(.secondary)
                TextField("Base URL", text: Binding(
                    get: { store.homeAssistantSettings.endpointText },
                    set: { store.homeAssistantSettings.endpointText = $0 }
                ))
                    .textContentType(.URL)
                SecureField("Long-lived access token", text: Binding(
                    get: { store.homeAssistantSettings.tokenDraft },
                    set: { store.homeAssistantSettings.tokenDraft = $0 }
                ))
                HStack {
                    Button("Save local configuration") { store.homeAssistantSettings.save() }
                    Button("Remove configuration", role: .destructive) { store.homeAssistantSettings.clear() }
                }
                if let message = store.homeAssistantSettings.settingsMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("The token stays in this Mac's Keychain and is never included in ChatGPT, MCP, Worker, or audit payloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            "Enable the local Lock Screen rule?",
            isPresented: $showingLockScreenConfirmation,
            titleVisibility: .visible
        ) {
            Button("Enable local rule") {
                store.lockScreenSettings.enableAfterLocalConfirmation()
            }
        } message: {
            Text("Only when the local companion remains in Protect, Offshift will show a black full-screen intervention, then one visible 10-second countdown and post macOS's Lock Screen shortcut. You can cancel the countdown or use one 15-minute on-call override. ChatGPT and the Worker cannot trigger this rule.")
        }
        .padding(24)
        .frame(width: 600)
    }
}
