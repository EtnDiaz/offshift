import OffshiftCompanionCore
import SwiftUI

struct CompanionDashboardView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                RedCardCodexSleepMascotView(size: 68)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offshift companion")
                        .font(.title2.weight(.semibold))
                    Text("Local, explainable work-pattern protection")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(store.stateLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }

            GroupBox("Next step") {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.isProtectState ? "A clearer pause is ready" : "A gentle check-in is ready")
                            .font(.headline)
                        Text("Open the full-screen care message when you want to step away. It never closes Codex or touches your work.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open care screen") { openWindow(id: "protection") }
                        .buttonStyle(.borderedProminent)
                }
            }

            GroupBox("What Offshift noticed") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.reasons, id: \.self) { reason in
                        Text(reason.replacingOccurrences(of: "Activity", with: "activity"))
                    }
                    Text("Only aggregate local timing is used. No code, prompts, terminal output, or screen content is collected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.samplingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Your control") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.localControlSummary)
                    Picker("Offshift mode", selection: Binding(
                        get: { store.careMode },
                        set: { store.setCareMode($0) }
                    )) {
                        Text("Sleep care").tag(OffshiftCareMode.sleep)
                        Text("Off").tag(OffshiftCareMode.off)
                    }
                    .pickerStyle(.segmented)
                    Text(store.nightCareSettings.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !store.nightCareSettings.isEnabled {
                        Button("Enable night care (11 PM–7 AM)") {
                            store.nightCareSettings.setEnabled(true)
                        }
                    }
                    Text("These controls work only on this Mac. ChatGPT cannot pause, resume, or turn Offshift off for you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        if store.isPaused {
                            Button("Resume Offshift") { store.resumeOffshift() }
                                .buttonStyle(.borderedProminent)
                            Button("Turn Offshift off", role: .destructive) { store.disableOffshift() }
                        } else if store.isOffshiftEnabled {
                            Button(store.pauseActionLabel) { store.pauseUntilTomorrow() }
                            Button("Turn Offshift off", role: .destructive) { store.disableOffshift() }
                        } else {
                            Button("Turn Offshift on") { store.resumeOffshift() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            #if DEBUG
            GroupBox("Developer fixtures") {
                HStack {
                    Button("Routine") { store.simulateRoutine() }
                    Button("Drift") { store.simulateDrift() }
                    Button("Protect") { store.simulateProtect() }
                    Button("Gentle night nudge") { store.simulateGentleNightCareNudge() }
                    Button("Late-session fixture") { store.simulateLateSessionRisk() }
                }
            }
            #endif

            Text("The companion samples only aggregate active/idle time locally. It never inspects code, prompts, terminal output, or screen content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .onChange(of: store.protectionPresentationToken) { _, _ in
            openWindow(id: "protection")
        }
    }
}

struct ProtectionWindowView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.dismissWindow) private var dismissWindow
    @AccessibilityFocusState private var isCareMessageFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                RedCardCodexSleepMascotView(size: 150)
                Text(store.careHeadline)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .accessibilityFocused($isCareMessageFocused)
                Text(store.careMessage)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: 620)
                Text("Nothing here closes Codex, your terminal, or your work.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(spacing: 10) {
                    Text(store.careReason)
                    Text(store.countdownText)
                        .accessibilityLabel("Lock Screen status: \(store.countdownText)")
                }
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: 580)

                VStack(spacing: 12) {
                    Button("Start a 5-minute break and leave") { takeFiveAndDismiss() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityHint("Closes this screen and starts a five-minute local break.")
                    Button(store.pauseActionLabel) { pauseAndDismiss() }
                        .buttonStyle(.bordered)
                    Button("Turn Offshift off", role: .destructive) { turnOffAndDismiss() }
                        .buttonStyle(.bordered)
                    if store.isProtectState {
                        HStack {
                            Button("On call for 15 min") { grantOnCallAndDismiss() }
                            Button("Cancel countdown") { store.cancelPreLockCountdown() }
                            if store.canStartCountdown {
                                Button("Start 10-second countdown") { store.startPreLockCountdown() }
                            }
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
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(48)
        }
        .background(InterventionWindowConfigurator())
        .onAppear { isCareMessageFocused = true }
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
        Text("State: \(store.stateLabel)")
        Button("Show dashboard") { openWindow(id: "dashboard") }
        Button("Show protection") { openWindow(id: "protection") }
        Divider()
        Button("Quit Offshift") { NSApplication.shared.terminate(nil) }
    }
}

struct CompanionSettingsView: View {
    @ObservedObject var store: CompanionStore
    @State private var showingLockScreenConfirmation = false

    var body: some View {
        Form {
            Section("Offshift control") {
                Text(store.localControlSummary)
                Picker("Offshift mode", selection: Binding(
                    get: { store.careMode },
                    set: { store.setCareMode($0) }
                )) {
                    Text("Sleep care").tag(OffshiftCareMode.sleep)
                    Text("Off").tag(OffshiftCareMode.off)
                }
                Text("A pause immediately cancels the local countdown and prevents scenes or Lock Screen actions until tomorrow. Turning Offshift off also stops local sampling.")
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
            Section("Protection") {
                Text("A local rule can use the macOS Lock Screen shortcut only after explicit confirmation.")
                Text("Rule: when the local policy remains Protect, show a black full-screen intervention, then start one visible 10-second countdown. Cancel and a bounded 15-minute on-call override remain available.")
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
            Section("Night care") {
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
            Section("Current state") {
                Text(store.stateLabel)
            }
            Section("Home Assistant wind-down") {
                Text("Configure this only on your Mac. Offshift invokes exactly one mapped scene: scene.offshift_wind_down.")
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
        .frame(width: 520)
    }
}
