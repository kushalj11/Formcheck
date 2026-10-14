import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("defaultLift") private var defaultLift: LiftType = .barbellSquat
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.accent.opacity(0.18))
                            Text(initial)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.isGuest ? "Guest" : (auth.displayName ?? "Signed in"))
                                .font(.headline)
                            Text(auth.isGuest ? "Using FormCheck without an account" : "Account stored on this device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker("Default squat", selection: $defaultLift) {
                        ForEach(LiftFamily.squat.variants) { Text($0.displayName).tag($0) }
                    }
                    ForEach(LiftType.allCases) { lift in
                        NavigationLink {
                            RulesView(lift: lift)
                        } label: {
                            LabeledContent {
                                Text("\(lift.rules.count) checks")
                            } label: {
                                Label("\(lift.displayName) rules", systemImage: "checklist")
                            }
                        }
                    }
                } header: {
                    Text("Analysis")
                } footer: {
                    Text("Your form score is the percentage of checks passed across every rep. Checks that can't be judged from your camera angle aren't counted.")
                }

                Section("Filming tips") {
                    tip("camera.viewfinder", "45° angle", "Place the phone at a 45° angle to your front so every check can run on one clip.")
                    tip("figure.stand", "Whole body in frame", "Keep your head and feet in frame for the whole set.")
                    tip("iphone", "Steady at hip height", "Prop the phone at about hip height, 6 to 10 feet away.")
                    tip("bed.double", "Bench press", "Set the phone at bench height, 45° from your side toward your head.")
                }

                Section {
                    Button(auth.isGuest ? "Exit guest mode" : "Sign Out", role: .destructive) {
                        confirmSignOut = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Sign out of FormCheck?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
            } message: {
                Text("Your recordings stay on this device.")
            }
        }
    }

    private var initial: String {
        guard !auth.isGuest, let first = auth.displayName?.first else { return "?" }
        return String(first).uppercased()
    }

    private func tip(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RulesView: View {
    let lift: LiftType

    var body: some View {
        List(lift.rules) { rule in
            VStack(alignment: .leading, spacing: 8) {
                Text(rule.name).font(.headline)
                Text(rule.why).font(.subheadline)
                Text("Fix: \(rule.fix)").font(.subheadline).foregroundStyle(.secondary)
                Text(rule.citation).font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
        }
        .navigationTitle(lift.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
