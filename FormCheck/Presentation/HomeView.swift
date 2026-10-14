import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting).font(.subheadline).foregroundStyle(.secondary)
                        Text("What are we checking today?").font(.title2.weight(.bold))
                    }

                    section("Starting Strength lifts", Exercise.lifts)
                    section("Ergonomics", Exercise.ergonomics)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FormCheck")
            .navigationDestination(for: Exercise.self) { exercise in
                if let family = exercise.family { LiftStartView(family: family) }
            }
        }
    }

    private var greeting: String {
        guard !auth.isGuest, let email = auth.displayName,
              let name = email.split(separator: "@").first else { return "Welcome" }
        return "Welcome, \(name)"
    }

    private func section(_ title: String, _ items: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items) { exercise in
                    if exercise.isAvailable {
                        NavigationLink(value: exercise) { ExerciseTile(exercise: exercise) }
                            .buttonStyle(.plain)
                    } else {
                        ExerciseTile(exercise: exercise)
                    }
                }
            }
        }
    }
}

private struct ExerciseTile: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(exercise.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .card(padding: 16)
        .contentShape(Rectangle())
    }
}
