import SwiftUI

struct SetAnalysisView: View {
    let recording: Recording
    let result: TrackingResult

    @AppStorage("defaultLift") private var defaultLift: LiftType = .barbellSquat
    @State private var lift: LiftType
    @State private var computed: SetAnalysis?
    @State private var player: PlayerModel?
    @State private var selectedRep = 0
    @State private var focusedFlag: RuleFlag?
    @State private var expandedCheck: String?

    init(recording: Recording, result: TrackingResult) {
        self.recording = recording
        self.result = result
        let saved = LiftType(rawValue: UserDefaults.standard.string(forKey: "defaultLift") ?? "")
        let variants = recording.family.variants
        _lift = State(initialValue: saved.flatMap { variants.contains($0) ? $0 : nil } ?? variants[0])
    }

    private var analysis: SetAnalysis { computed ?? SetAnalysis(lift: lift, reps: []) }

    private var rep: Rep? {
        analysis.reps.indices.contains(selectedRep) ? analysis.reps[selectedRep] : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if recording.family.variants.count > 1 { liftPicker }
                summary

                if computed == nil {
                    ProgressView().padding(.top, 40)
                } else if analysis.reps.isEmpty {
                    ContentUnavailableView(
                        "No reps detected",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text(recording.family == .bench
                            ? "No complete press was found in this clip. Keep your whole body and the bar in frame and make sure each rep touches the chest and locks out."
                            : "No complete squat was found in this clip. Keep your whole body in frame and make sure each rep goes all the way down and back up.")
                    )
                    .card()
                } else {
                    repTabs
                    if let rep {
                        videoCard(rep)
                        checklist(rep)
                        measurements(rep)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Set Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if player == nil { player = PlayerModel(url: recording.url) }
            loopCurrentRep()
        }
        .task(id: lift) {
            let result = result, lift = lift
            let analysis = await Task.detached(priority: .userInitiated) {
                SetAnalysis.run(on: result, lift: lift)
            }.value
            withAnimation { computed = analysis }
            loopCurrentRep()
        }
        .onChange(of: selectedRep) { _, _ in
            focusedFlag = nil
            expandedCheck = nil
            loopCurrentRep()
        }
        .onChange(of: lift) { _, newLift in
            defaultLift = newLift
            focusedFlag = nil
            expandedCheck = nil
        }
        .onDisappear { player?.teardown() }
    }

    private var liftPicker: some View {
        Picker("Lift", selection: $lift) {
            ForEach(recording.family.variants) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var summary: some View {
        HStack(spacing: 20) {
            ScoreRing(score: analysis.score, size: 112, lineWidth: 10)
            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if analysis.checksRun > 0 {
                    Text("\(analysis.checksRun - analysis.checksFailed) of \(analysis.checksRun) checks passed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    chip("\(analysis.reps.count) rep\(analysis.reps.count == 1 ? "" : "s")", systemImage: "repeat")
                    if let view = analysis.reps.first?.view {
                        chip(view.displayName, systemImage: "camera")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: 16)
    }

    private var headline: String {
        guard let score = analysis.score else { return "Nothing could be checked" }
        switch score {
        case 100: return "Clean set"
        case 85...: return "Solid set, small fixes"
        case 60..<85: return "A few things to work on"
        default: return "Form needs work"
        }
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private var repTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(analysis.reps) { r in
                    let selected = selectedRep == r.index
                    Button {
                        selectedRep = r.index
                    } label: {
                        VStack(spacing: 4) {
                            Text("Rep \(r.index + 1)").font(.caption.weight(.semibold))
                            Text(r.score.map { "\($0)" } ?? "–")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(Theme.scoreColor(r.score))
                        }
                        .frame(minWidth: 56)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? Theme.accent.opacity(0.18) : Theme.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected ? Theme.accent : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loopCurrentRep() {
        guard let rep, let player else { return }
        let end = max(rep.endTime, rep.startTime + 0.2)
        player.playLoop(rep.startTime...end)
    }

    private func show(_ flag: RuleFlag) {
        focusedFlag = flag
        guard let player else { return }
        player.clearLoop()
        player.pause()
        player.seek(to: result.frames[flag.frameIndex].timestamp)
    }

    @ViewBuilder
    private func videoCard(_ rep: Rep) -> some View {
        if let player {
            RepVideo(player: player, result: result, focusedFlag: focusedFlag) {
                focusedFlag = nil
                loopCurrentRep()
            }
        }
    }

    private func checklist(_ rep: Rep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Rep \(rep.index + 1) checks")
                Spacer()
                Text(String(format: "%.1fs – %.1fs", rep.startTime, rep.endTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ForEach(rep.checks.sorted { order($0) < order($1) }) { check in
                checkRow(check)
            }
        }
    }

    private func order(_ c: RuleCheck) -> Int {
        switch c.outcome {
        case .failed: return 0
        case .passed: return 1
        case .skipped: return 2
        }
    }

    @ViewBuilder
    private func checkRow(_ check: RuleCheck) -> some View {
        switch check.outcome {
        case .passed(let detail):
            row(icon: "checkmark.circle.fill", color: Theme.pass, title: check.rule.name, subtitle: detail)
                .card(padding: 12)
        case .skipped(let reason):
            row(icon: "minus.circle", color: Theme.skipped, title: check.rule.name, subtitle: "Not checked · \(reason)")
                .opacity(0.7)
                .card(padding: 12)
        case .failed(let flag):
            let expanded = expandedCheck == check.id
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.snappy) { expandedCheck = expanded ? nil : check.id }
                    show(flag)
                } label: {
                    HStack(alignment: .top) {
                        row(icon: "exclamationmark.triangle.fill", color: Theme.fail, title: flag.message, subtitle: flag.detail)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .padding(.top, 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel("Why this matters")
                        Text(flag.why).font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel("Try this instead")
                        Text(flag.fix).font(.subheadline.weight(.medium))
                    }
                    HStack {
                        Text(flag.citation).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Show frame") { show(flag) }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                    }
                }
            }
            .card(padding: 12)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(focusedFlag?.id == flag.id ? Theme.fail : .clear, lineWidth: 1.5)
            )
        }
    }

    private func row(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).font(.body)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func kneeRatio(_ m: SquatMeasurements) -> String? {
        guard let knees = m.kneeWidth, let ankles = m.ankleWidth, ankles > 0.0001 else { return nil }
        return String(format: "%.0f%%", knees / ankles * 100)
    }

    private func measurementItems(_ rep: Rep) -> [(String, String?)] {
        let degrees = { (v: Double?) in v.map { String(format: "%.0f°", $0) } }
        switch recording.family {
        case .squat:
            let m = result.measurements(at: rep.bottomFrame)
            return [
                ("Knee angle", degrees(m.kneeAngle)),
                ("Hip angle", degrees(m.hipAngle)),
                ("Torso lean", degrees(m.torsoLeanAngle)),
                ("Head angle", degrees(m.headAngle)),
                ("Knee width vs ankles", kneeRatio(m)),
            ]
        case .bench:
            let m = result.benchMeasurements(at: rep.bottomFrame)
            var elbowsBelow: Double?
            if let s = m.shoulderHeight, let e = m.elbowHeight, let arm = m.upperArmLength, arm > 0.01 {
                elbowsBelow = asin(max(-1, min(1, Double((s - e) / arm)))) * 180 / .pi
            }
            let lean = m.forearms.compactMap { v -> Double? in
                abs(v.dy) > 0.005 ? atan(Double(abs(v.dx) / abs(v.dy))) * 180 / .pi : nil
            }
            return [
                ("Elbow angle", degrees(m.elbowAngle)),
                ("Elbows below shoulders", degrees(elbowsBelow)),
                ("Forearm lean", degrees(lean.isEmpty ? nil : lean.reduce(0, +) / Double(lean.count))),
            ]
        }
    }

    private func measurements(_ rep: Rep) -> some View {
        let items = measurementItems(rep)
        return DisclosureGroup {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: 12) {
                ForEach(items, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).font(.caption2).foregroundStyle(.secondary)
                        Text(value ?? "–").font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            SectionLabel("Measurements at the bottom of the rep")
        }
        .tint(.secondary)
        .card(padding: 12)
    }
}

private struct RepVideo: View {
    let player: PlayerModel
    let result: TrackingResult
    let focusedFlag: RuleFlag?
    let onResumeLoop: () -> Void

    private var currentFrame: JointFrame? {
        if let focusedFlag { return result.frames[focusedFlag.frameIndex] }
        guard let index = result.frameIndex(at: player.currentTime) else { return nil }
        return result.frames[index]
    }

    var body: some View {
        ZStack {
            PlayerView(player: player.player)
            PoseOverlay(frame: currentFrame, videoSize: result.displaySize, highlight: Set(focusedFlag?.joints ?? []))
        }
        .aspectRatio(result.displaySize.width / max(result.displaySize.height, 1), contentMode: .fit)
        .frame(maxHeight: 460)
        .frame(maxWidth: .infinity)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(alignment: .topLeading) {
            if let flag = focusedFlag {
                Label(flag.detail, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.red.opacity(0.85), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(10)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                if focusedFlag != nil { onResumeLoop() } else { player.togglePlay() }
            } label: {
                Label(focusedFlag != nil ? "Resume loop" : (player.isPlaying ? "Pause" : "Play"),
                      systemImage: focusedFlag != nil ? "repeat" : (player.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(10)
        }
    }
}
