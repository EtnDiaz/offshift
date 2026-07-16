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
                Spacer()
                Button("Open protection") { openWindow(id: "protection") }
            }

            Text("Demo controls use deterministic fixture states. The production host will feed the same core only coarse local aggregate intervals.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

struct ProtectionWindowView: View {
    @ObservedObject var store: CompanionStore

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
        }
        .padding(24)
        .frame(width: 440)
    }
}
