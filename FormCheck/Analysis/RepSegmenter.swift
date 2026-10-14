import CoreGraphics
import Foundation

struct RepSignal {
    let height: (TrackingResult, Int) -> CGFloat?
    let scale: (TrackingResult, Int) -> CGFloat?
    let bendAngle: (TrackingResult, Int) -> Double?
    let minDrop: CGFloat
    let maxBottomAngle: Double

    static let squat = RepSignal(
        height: { $0.measurements(at: $1).hipHeight },
        scale: { $0.measurements(at: $1).thighLength },
        bendAngle: { $0.measurements(at: $1).kneeAngle },
        minDrop: 0.25,
        maxBottomAngle: 150
    )

    static let bench = RepSignal(
        height: { $0.benchMeasurements(at: $1).barHeight },
        scale: { $0.benchMeasurements(at: $1).upperArmLength },
        bendAngle: { $0.benchMeasurements(at: $1).elbowAngle },
        minDrop: 0.4,
        maxBottomAngle: 150
    )

    static func of(_ family: LiftFamily) -> RepSignal {
        switch family {
        case .squat: return .squat
        case .bench: return .bench
        }
    }
}

enum RepSegmenter {
    static let smoothingWindow = 5
    static let minDepthProminence: CGFloat = 0.06
    static let minFramesBetweenReps = 10

    static func segment(_ result: TrackingResult, family: LiftFamily = .squat) -> [Rep] {
        let signal = RepSignal.of(family)
        let frames = result.frames
        guard frames.count > smoothingWindow * 2 else { return [] }

        var smoothed = [CGFloat?](repeating: nil, count: frames.count)
        for i in frames.indices {
            let lo = max(0, i - smoothingWindow / 2)
            let hi = min(frames.count - 1, i + smoothingWindow / 2)
            let values = (lo...hi).compactMap { signal.height(result, $0) }
            if !values.isEmpty { smoothed[i] = values.reduce(0, +) / CGFloat(values.count) }
        }

        var bottomCandidates: [Int] = []
        for i in frames.indices {
            guard let v = smoothed[i] else { continue }
            let lo = max(0, i - minFramesBetweenReps / 2)
            let hi = min(frames.count - 1, i + minFramesBetweenReps / 2)
            let isLocalMin = (lo...hi).allSatisfy { j in
                guard let other = smoothed[j] else { return true }
                return other >= v
            }
            if isLocalMin { bottomCandidates.append(i) }
        }

        var bottoms: [Int] = []
        for c in bottomCandidates {
            if let last = bottoms.last, c - last < minFramesBetweenReps {
                if let vLast = smoothed[last], let vC = smoothed[c], vC < vLast {
                    bottoms[bottoms.count - 1] = c
                }
            } else {
                bottoms.append(c)
            }
        }

        bottoms = bottoms.filter { b in
            guard let vb = smoothed[b] else { return false }
            let before = smoothed[0..<b].compactMap { $0 }.max()
            let after = smoothed[(b + 1)...].compactMap { $0 }.max()
            let prominence = min(before ?? vb, after ?? vb) - vb
            return prominence >= minDepthProminence
        }

        bottoms = bottoms.filter { isRep(at: $0, in: result, smoothed: smoothed, signal: signal) }

        guard !bottoms.isEmpty else { return [] }

        var reps: [Rep] = []
        for (i, bottom) in bottoms.enumerated() {
            let prevBottom = i > 0 ? bottoms[i - 1] : 0
            let nextBottom = i < bottoms.count - 1 ? bottoms[i + 1] : frames.count - 1

            let start = standingPoint(smoothed, from: bottom, downTo: prevBottom, direction: -1)
            let end = standingPoint(smoothed, from: bottom, downTo: nextBottom, direction: 1)

            reps.append(Rep(
                index: i,
                startFrame: start,
                endFrame: end,
                bottomFrame: bottom,
                startTime: frames[start].timestamp,
                endTime: frames[end].timestamp
            ))
        }
        return reps
    }

    private static func isRep(at bottom: Int, in result: TrackingResult, smoothed: [CGFloat?], signal: RepSignal) -> Bool {
        let near = max(0, bottom - 3)...min(result.frames.count - 1, bottom + 3)
        let bends = near.compactMap { signal.bendAngle(result, $0) }
        let lengths = result.frames.indices.compactMap { signal.scale(result, $0) }
        guard let bend = bends.min(), let length = lengths.max(), length > 0.01,
              let low = smoothed[bottom] else { return true }
        let top = smoothed.compactMap { $0 }.max() ?? low
        return bend <= signal.maxBottomAngle && (top - low) / length >= signal.minDrop
    }

    private static func standingPoint(_ smoothed: [CGFloat?], from bottom: Int, downTo limit: Int, direction: Int) -> Int {
        var best = bottom
        var bestValue = smoothed[bottom] ?? 0
        var i = bottom
        while (direction < 0 && i > limit) || (direction > 0 && i < limit) {
            i += direction
            if let v = smoothed[i], v > bestValue {
                bestValue = v
                best = i
            }
        }
        return best
    }
}
