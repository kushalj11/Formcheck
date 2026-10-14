import SwiftUI

enum Theme {
    static let accent = Color.orange
    static let pass = Color.green
    static let fail = Color.red
    static let skipped = Color.secondary
    static let card = Color(.secondarySystemBackground)
    static let cornerRadius: CGFloat = 14

    static func scoreColor(_ score: Int?) -> Color {
        guard let score else { return .secondary }
        switch score {
        case 85...: return pass
        case 60..<85: return .yellow
        default: return fail
        }
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
    }
}

struct ScoreRing: View {
    let score: Int?
    var size: CGFloat = 130
    var lineWidth: CGFloat = 11
    var caption: String? = "FORM SCORE"

    var body: some View {
        ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(score ?? 0) / 100)
                .stroke(Theme.scoreColor(score), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: score)
            VStack(spacing: 0) {
                Text(score.map(String.init) ?? "–")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                if let caption {
                    Text(caption).font(.system(size: max(8, size * 0.075), weight: .semibold)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
