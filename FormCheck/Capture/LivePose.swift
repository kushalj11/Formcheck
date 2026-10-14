import Foundation

@MainActor
final class LivePose: ObservableObject {
    @Published private(set) var frame: JointFrame?
    @Published private(set) var imageSize = CGSize(width: 9, height: 16)
    @Published private(set) var phase: RepPhase = .setup
    @Published private(set) var cue: String

    static let setupCueInterval: TimeInterval = 4

    let family: LiftFamily
    private var tracker: RepPhaseTracker
    private var setupStarted: TimeInterval = 0

    init(family: LiftFamily) {
        self.family = family
        tracker = RepPhaseTracker(family: family)
        cue = RepPhase.setup.cues(for: family)[0]
    }

    func ingest(_ frame: JointFrame, size: CGSize) {
        self.frame = frame
        imageSize = size
        guard frame.hasPose else { return }

        let aspect = size.height > 0 ? size.width / size.height : 1
        let previous = phase
        phase = tracker.update(frame, aspect: aspect)
        if phase == .setup, previous != .setup { setupStarted = frame.timestamp }

        let cues = phase.cues(for: family)
        let index = phase == .setup ? Int((frame.timestamp - setupStarted) / Self.setupCueInterval) % cues.count : 0
        if cue != cues[index] { cue = cues[index] }
    }
}
