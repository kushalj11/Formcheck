import CoreGraphics
import Foundation

struct TrackingSummary {
    var totalFrames = 0
    var framesWithPose = 0
    var framesFailed = 0
    var longestGapFrames = 0
    var meanConfidence: Float = 0
    var perJointRate: [JointName: Double] = [:]
    var processingSeconds: Double = 0
    var lastErrorMessage: String?

    var detectionRate: Double {
        totalFrames == 0 ? 0 : Double(framesWithPose) / Double(totalFrames)
    }
    var processingFPS: Double {
        processingSeconds == 0 ? 0 : Double(totalFrames) / processingSeconds
    }
}

struct TrackingResult {
    var frames: [JointFrame] { didSet { cache = MeasurementCache() } }
    var displaySize: CGSize { didSet { cache = MeasurementCache() } }
    var summary: TrackingSummary
    private var cache = MeasurementCache()

    init(frames: [JointFrame], displaySize: CGSize, summary: TrackingSummary) {
        self.frames = frames
        self.displaySize = displaySize
        self.summary = summary
    }

    var aspect: CGFloat { displaySize.height > 0 ? displaySize.width / displaySize.height : 1 }

    func measurements(at index: Int) -> SquatMeasurements {
        cache.squat { frames.map { SquatMeasurements.from($0, aspect: aspect) } }[index]
    }

    func benchMeasurements(at index: Int) -> BenchMeasurements {
        cache.bench { frames.map { BenchMeasurements.from($0, aspect: aspect) } }[index]
    }

    func frameIndex(at time: TimeInterval) -> Int? {
        guard !frames.isEmpty else { return nil }
        var lo = 0, hi = frames.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if frames[mid].timestamp < time { lo = mid + 1 } else { hi = mid }
        }
        if lo > 0, abs(frames[lo - 1].timestamp - time) <= abs(frames[lo].timestamp - time) {
            return lo - 1
        }
        return lo
    }

    func bottomFrameIndex(family: LiftFamily) -> Int? {
        switch family {
        case .squat: return lowestHipFrameIndex()
        case .bench:
            return frames.indices
                .compactMap { i in benchMeasurements(at: i).barHeight.map { (i, $0) } }
                .min { $0.1 < $1.1 }?.0
        }
    }

    func lowestHipFrameIndex() -> Int? {
        var best: (index: Int, y: CGFloat)?
        for (i, f) in frames.enumerated() {
            let ys = [f.joints[.leftHip], f.joints[.rightHip]].compactMap { $0?.y }
            guard !ys.isEmpty else { continue }
            let y = ys.reduce(0, +) / CGFloat(ys.count)
            if best == nil || y < best!.y { best = (i, y) }
        }
        return best?.index
    }
}

final class MeasurementCache: @unchecked Sendable {
    private let lock = NSLock()
    private var squatValues: [SquatMeasurements]?
    private var benchValues: [BenchMeasurements]?

    func squat(_ compute: () -> [SquatMeasurements]) -> [SquatMeasurements] {
        lock.lock()
        defer { lock.unlock() }
        if let squatValues { return squatValues }
        let values = compute()
        squatValues = values
        return values
    }

    func bench(_ compute: () -> [BenchMeasurements]) -> [BenchMeasurements] {
        lock.lock()
        defer { lock.unlock() }
        if let benchValues { return benchValues }
        let values = compute()
        benchValues = values
        return values
    }
}
