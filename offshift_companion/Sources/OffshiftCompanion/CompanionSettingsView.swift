import OffshiftCompanionCore
import SwiftUI

struct CompanionSettingsView: View {
    @ObservedObject var store: CompanionStore
    @State private var showingLockScreenConfirmation = false

    var body: some View {
        TabView {
            careTab
                .tabItem { Label("Care", systemImage: "moon.stars") }
            protectionTab
                .tabItem { Label("Protection", systemImage: "lock.shield") }
            homeTab
                .tabItem { Label("Home", systemImage: "house") }
            privacyTab
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding(24)
        .frame(width: 620, height: 470)
        .confirmationDialog(
            "Enable the local Lock Screen rule?",
            isPresented: $showingLockScreenConfirmation,
            titleVisibility: .visible
        ) {
            Button("Enable local rule") {
                store.lockScreenSettings.enableAfterLocalConfirmation()
            }
        } message: {
            Text("Only when the local companion remains in Protect, Offshift will first show a visible black care screen, then one 10-second countdown and post macOS's Lock Screen shortcut. You can cancel the countdown or choose one 15-minute on-call override. ChatGPT and the Worker cannot trigger this rule.")
        }
    }

    private var careTab: some View {
        Form {
            Section("Care on this Mac") {
                Picker("Offshift", selection: Binding(
                    get: { store.careMode },
                    set: { store.setCareMode($0) }
                )) {
                    Text("Sleep care is on").tag(OffshiftCareMode.sleep)
                    Text("Offshift is off").tag(OffshiftCareMode.off)
                }
                Text(store.localControlSummary)
                    .foregroundStyle(.secondary)

                if store.isPaused {
                    Button("Resume Offshift") { store.resumeOffshift() }
                } else if store.isOffshiftEnabled {
                    Button(store.pauseActionLabel) { store.pauseUntilTomorrow() }
                } else {
                    Button("Turn Offshift on") { store.resumeOffshift() }
                }
                if store.isOffshiftEnabled {
                    Button("Turn Offshift off", role: .destructive) { store.disableOffshift() }
                }
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
                HStack {
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
                }
                Text(store.nightCareSettings.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var protectionTab: some View {
        Form {
            Section("Optional local rule") {
                Text("Off by default. It is configured and evaluated only on this Mac.")
                    .foregroundStyle(.secondary)
                if store.lockRuleEnabled {
                    Label("Enabled on this Mac", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Button("Disable local Lock Screen rule", role: .destructive) {
                        store.lockScreenSettings.disableImmediately()
                    }
                } else {
                    Button("Enable local Lock Screen rule…") {
                        showingLockScreenConfirmation = true
                    }
                }
            }

            Section("What will happen") {
                Text("1. Offshift notices a sustained local pattern.")
                Text("2. A black care screen explains why and offers Reset, Pause, On call, and Cancel.")
                Text("3. Only after that screen is visible can one 10-second local countdown begin.")
            }

            Section("Permission") {
                Text(store.lockScreenSettings.accessibilityStatus)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var homeTab: some View {
        Form {
            Section("Home Assistant wind-down") {
                Text("Optional. Offshift can invoke one locally mapped scene: scene.offshift_wind_down.")
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
            }
        }
    }

    private var privacyTab: some View {
        Form {
            Section("What stays local") {
                Label("Aggregate active and idle timing", systemImage: "checkmark")
                Label("Your pause, Offshift mode, and quiet hours", systemImage: "checkmark")
                Label("Home Assistant token in this Mac's Keychain", systemImage: "checkmark")
            }
            Section("What Offshift does not read") {
                Text("Code, prompts, terminal output, filenames, screen content, camera frames, Apple Screen Time, or your calendar.")
                    .foregroundStyle(.secondary)
            }
            Section("Outside this Mac") {
                Text("ChatGPT and MCP can explain or prepare a plan. They cannot open a local care screen, invoke the Lock Screen, run a Home Assistant scene, or change these settings.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
