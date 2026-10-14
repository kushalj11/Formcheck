import SwiftUI

struct TrackingReportView: View {
    let summary: TrackingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Frames analyzed", "\(summary.totalFrames)")
            row("Frames with a pose", "\(summary.framesWithPose)  (\(percent(summary.detectionRate)))")
            row("Frames that failed to process", "\(summary.framesFailed)")
            row("Longest run with no pose", "\(summary.longestGapFrames) frames")
            row("Average confidence", percent(Double(summary.meanConfidence)))
            row("Processing time", String(format: "%.1f s  (%.0f frames/s)", summary.processingSeconds, summary.processingFPS))

            if summary.framesFailed > 0, let message = summary.lastErrorMessage {
                Divider().padding(.vertical, 4)
                Text("Most recent error").font(.footnote.weight(.semibold))
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Divider().padding(.vertical, 4)
            Text("Per-joint detection rate").font(.footnote.weight(.semibold))
            ForEach(JointName.allCases, id: \.self) { name in
                let rate = summary.perJointRate[name] ?? 0
                HStack {
                    Text(name.displayName)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 104, alignment: .leading)
                    ProgressView(value: rate).tint(rate > 0.9 ? .green : rate > 0.6 ? .yellow : .red)
                    Text(percent(rate))
                        .font(.caption.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.subheadline)
    }

    private func percent(_ v: Double) -> String { String(format: "%.0f%%", v * 100) }
}
