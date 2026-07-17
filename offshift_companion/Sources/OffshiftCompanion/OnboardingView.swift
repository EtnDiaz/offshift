import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: CompanionStore
    let onComplete: () -> Void
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OffshiftBrandMarkView(size: 120)
                .frame(maxWidth: .infinity)

            if step == 0 {
                welcome
            } else {
                permissions
            }
        }
        .padding(32)
        .frame(width: 480)
    }

    private var welcome: some View {
        Group {
            Text("Leave work with your work intact")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Offshift lives in your menu bar. It never reads code, prompts, terminal output, filenames, screen content, or your calendar.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                Label("Local aggregate active and idle timing only", systemImage: "checkmark.circle")
                Label("A clear pause and off switch", systemImage: "checkmark.circle")
                Label("No permissions are enabled yet", systemImage: "checkmark.circle")
            }
            .foregroundStyle(.secondary)
            HStack {
                Button("Not now") { finish(enableLocalCare: false) }
                Spacer()
                Button("Set up local care") { step = 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var permissions: some View {
        Group {
            Text("Choose your local signals")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Turning on care starts only aggregate local timing. It does not grant macOS permissions.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Optional Focus Status")
                    .font(.headline)
                Text(store.focusStatusSettings.summary)
                    .foregroundStyle(.secondary)
                if store.focusStatusSettings.canRequestAuthorization {
                    Button("Allow Focus Status") {
                        store.focusStatusSettings.requestAuthorization()
                    }
                }
                Text("Offshift reads only whether a Focus is on. It never learns its name and it never starts a care screen by itself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Accessibility is not requested here. It is needed only if you later turn on the optional local Lock Screen rule in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Back") { step = 0 }
                Spacer()
                Button("Keep Offshift off") { finish(enableLocalCare: false) }
                Button("Turn on local care") { finish(enableLocalCare: true) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func finish(enableLocalCare: Bool) {
        store.completeOnboarding(enableLocalCare: enableLocalCare)
        onComplete()
    }
}
