import SwiftUI

struct CompanionDashboardView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
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

            HStack {
                Button("Routine") { store.simulateRoutine() }
                Button("Drift") { store.simulateDrift() }
                Button("Protect") {
                    store.simulateProtect()
                    openWindow(id: "protection")
                }
                Button("Late-session fixture") {
                    store.simulateLateSessionRisk()
                    openWindow(id: "protection")
                }
                Spacer()
                Button("Open protection") { openWindow(id: "protection") }
            }

            Text("The companion samples only aggregate active/idle time locally. The buttons remain deterministic fixtures; the late-session fixture combines quiet hours, repeated snoozes, and a configured early start without inferring fatigue.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

struct ProtectionWindowView: View {
    @ObservedObject var store: CompanionStore
    @State private var showingWindDownConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Time to protect your wind-down")
                .font(.title2.weight(.semibold))
            Text("This is a local, cancellable intervention. It cannot end your work, access your code, or lock your Mac from ChatGPT.")
                .foregroundStyle(.secondary)
            Text(store.countdownText)
                .font(.callout)

            HStack {
                Button("Take 5") { store.simulateRoutine() }
                    .buttonStyle(.borderedProminent)
                Button("On call for 15 min") { store.grantOnCallOverride() }
                Button("Cancel countdown") { store.cancelPreLockCountdown() }
            }

            Toggle("Enable local Lock Screen rule", isOn: Binding(
                get: { store.lockRuleEnabled },
                set: { store.setLockRuleEnabled($0) }
            ))
            .disabled(true)

            Text("This build keeps the rule disabled. Enabling a real system Lock Screen action requires a separate, local consent flow and a reviewed adapter.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Home Assistant wind-down")
                    .font(.headline)
                Text("The only scene this build can run is the locally configured wind-down scene. ChatGPT and the Worker never receive the endpoint or token.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Run wind-down scene") {
                    showingWindDownConfirmation = true
                }
                .disabled(!store.canRunWindDown)
                .confirmationDialog(
                    "Run your local wind-down scene?",
                    isPresented: $showingWindDownConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Run wind-down scene") { store.runWindDownScene() }
                } message: {
                    Text("This sends one request to the Home Assistant endpoint configured only on this Mac. It does not lock your Mac or end your work.")
                }
                Text(store.windDownStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let onCallMessage = store.onCallMessage {
                Text(onCallMessage)
                    .font(.caption)
            }
        }
        .padding(24)
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

    var body: some View {
        Form {
            Section("Protection") {
                Text("Lock Screen is disabled in this build.")
                Text("A production rule must be configured locally with explicit thresholds, a visible countdown, cancel, and bounded on-call override.")
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
        .padding(24)
        .frame(width: 520)
    }
}
