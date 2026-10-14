import SwiftUI

struct PlaybackView: View {
    enum AnalysisState {
        case running(Double)
        case done(TrackingResult)
        case failed(String)
    }

    let recording: Recording
    @State private var model: PlayerModel
    @State private var analysis: AnalysisState = .running(0)
    @State private var showOverlay = true
    @State private var showDetails = false
    @State private var showReport = false
    @State private var showSetAnalysis = false

    init(recording: Recording) {
        self.recording = recording
        _model = State(initialValue: PlayerModel(url: recording.url))
    }

    private var result: TrackingResult? {
        if case .done(let r) = analysis { return r }
        return nil
    }

    private var currentIndex: Int? { result?.frameIndex(at: model.currentTime) }
    private var currentFrame: JointFrame? { currentIndex.flatMap { result?.frames[$0] } }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                PlayerView(player: model.player)
                if showOverlay {
                    PoseOverlay(frame: currentFrame, videoSize: model.videoSize)
                }
            }
            .background(.black)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) { status }
            .overlay(alignment: .topLeading) { if showDetails { details } }

            controls
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show joints", systemImage: "figure.stand", isOn: $showOverlay)
                    Toggle("Frame details", systemImage: "info.circle", isOn: $showDetails)
                    Button("Tracking report", systemImage: "list.bullet.rectangle") { showReport = true }
                        .disabled(result == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await runAnalysis() }
        .onDisappear { model.pause() }
        .navigationDestination(isPresented: $showSetAnalysis) {
            if let result { SetAnalysisView(recording: recording, result: result) }
        }
        .sheet(isPresented: $showReport) {
            NavigationStack {
                ScrollView {
                    if let result { TrackingReportView(summary: result.summary) }
                }
                .navigationTitle("Tracking report")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showReport = false } } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var status: some View {
        switch analysis {
        case .running(let p):
            VStack(alignment: .leading, spacing: 6) {
                Text("Tracking joints… \(Int(p * 100))%").font(.caption.weight(.semibold))
                ProgressView(value: p).tint(Theme.accent)
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: 260)
            .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
            .environment(\.colorScheme, .dark)
            .padding(.top, 12)
        case .failed(let m):
            Label(m, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(10)
                .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                .padding(12)
        case .done:
            if let e = model.loadError {
                Text(e).font(.caption).foregroundStyle(.red).padding(12)
            }
        }
    }

    @ViewBuilder private var details: some View {
        if let f = currentFrame, let i = currentIndex, let result {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "Frame %d  ·  %.2f s", i, f.timestamp))
                Text(f.hasPose ? String(format: "%d joints  ·  %.0f%% confidence", f.joints.count, f.confidence * 100) : "No body detected in this frame")
                    .foregroundStyle(f.hasPose ? .white : .orange)
                switch recording.family {
                case .squat:
                    let m = result.measurements(at: i)
                    if let knee = m.kneeAngle { Text(String(format: "Knee %.0f°", knee)) }
                    if let hip = m.hipAngle { Text(String(format: "Hip %.0f°", hip)) }
                case .bench:
                    if let elbow = result.benchMeasurements(at: i).elbowAngle { Text(String(format: "Elbow %.0f°", elbow)) }
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)
            .padding(8)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .padding(10)
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Slider(
                    value: Binding(get: { model.currentTime }, set: { model.seek(to: $0) }),
                    in: 0...max(model.duration, 0.01)
                )
                .tint(Theme.accent)
                HStack {
                    Text(timeString(model.currentTime))
                    Spacer()
                    Text(timeString(model.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    if let i = result?.bottomFrameIndex(family: recording.family), let t = result?.frames[i].timestamp {
                        model.pause()
                        model.seek(to: t)
                    }
                } label: {
                    Image(systemName: "arrow.down.to.line").frame(width: 44, height: 44)
                }
                .disabled(result == nil)
                .accessibilityLabel("Jump to bottom")

                Spacer()
                Button { model.step(by: -1) } label: { Image(systemName: "backward.frame.fill").frame(width: 44, height: 44) }
                Button { model.togglePlay() } label: {
                    Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.accent)
                }
                Button { model.step(by: 1) } label: { Image(systemName: "forward.frame.fill").frame(width: 44, height: 44) }
                Spacer()

                Button { showOverlay.toggle() } label: {
                    Image(systemName: showOverlay ? "figure.stand" : "figure.stand.line.dotted.figure.stand")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(showOverlay ? "Hide joints" : "Show joints")
            }
            .font(.title3)
            .foregroundStyle(.primary)

            Button {
                model.pause()
                showSetAnalysis = true
            } label: {
                HStack {
                    if result == nil {
                        ProgressView().tint(.white)
                        Text("Tracking…")
                    } else {
                        Image(systemName: "chart.bar.doc.horizontal")
                        Text("Analyze Set")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(result == nil)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    private func timeString(_ s: Double) -> String {
        guard s.isFinite else { return "0:00.0" }
        return String(format: "%d:%04.1f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }

    private func runAnalysis() async {
        guard result == nil else { return }
        do {
            let r = try await PoseDetector.analyze(url: recording.url) { p in
                Task { @MainActor in
                    if case .running = analysis { analysis = .running(p) }
                }
            }
            analysis = .done(r)
        } catch is CancellationError {
        } catch {
            analysis = .failed(error.localizedDescription)
        }
    }
}
