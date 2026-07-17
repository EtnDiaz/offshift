import OffshiftCompanionCore
import SwiftUI

struct CompanionDashboardView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .top, spacing: 20) {
                    OffshiftBrandMarkView(size: 132)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Offshift")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("A local nudge to leave the work loop with your work intact.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    StatePill(title: store.stateLabel)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text("Today")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(store.todayHeadline)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.todayMessage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 620, alignment: .leading)

                    HStack(spacing: 12) {
                        Button(store.todayPrimaryActionTitle) {
                            handlePrimaryAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)

                        if store.isOffshiftEnabled, !store.isPaused {
                            Button("Pause notices for 15 min") {
                                store.pauseNoticesForFifteenMinutes()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }

                    DisclosureGroup("Why now?") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.reasons, id: \.self) { reason in
                                Text(reason)
                            }
                            Text("Only aggregate local active and idle timing is used. Offshift never reads code, prompts, terminal output, filenames, or screen content.")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                        .padding(.top, 4)
                    }
                    .font(.headline)
                    .frame(maxWidth: 680, alignment: .leading)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Label(store.localControlSummary, systemImage: store.isOffshiftEnabled ? "checkmark.circle" : "pause.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(36)
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .onChange(of: store.protectionPresentationToken) { _, _ in
            openWindow(id: "protection")
        }
    }

    private func handlePrimaryAction() {
        if !store.isOffshiftEnabled || store.isPaused {
            store.resumeOffshift()
        } else {
            store.takeFive()
        }
    }
}

private struct StatePill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary, in: Capsule())
    }
}
