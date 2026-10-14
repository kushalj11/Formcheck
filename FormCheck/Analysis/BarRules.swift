import CoreGraphics
import Foundation

enum BarRules {
    static let driftThreshold: CGFloat = 0.25
    static let standingBand: CGFloat = 0.15
    static let tiltDegrees: Double = 6

    static let barPath = Rule(
        id: "bar.path",
        name: "Bar over mid-foot",
        message: "Bar drifted off mid-foot",
        why: "The bar is balanced only when it stays directly over the middle of the foot. Any drift forward or back has to be held by the back and costs strength out of the bottom.",
        fix: "Keep the bar over the middle of the foot for the whole rep, letting the back angle adjust to keep it there.",
        citation: "Starting Strength: bar balanced over mid-foot",
        views: [.diagonal, .side],
        joints: [.leftShoulder, .rightShoulder, .leftAnkle, .rightAnkle],
        check: checkBarPath
    )

    static let barLevel = Rule(
        id: "bar.level",
        name: "Bar level",
        message: "Bar tilted to one side at the bottom",
        why: "A tilted bar loads one leg more than the other, usually because of a hip shift or an uneven grip.",
        fix: "Center the bar on your back, grip it evenly on both sides, and keep your hips level as you descend.",
        citation: "Starting Strength: bar position",
        views: [.diagonal, .front],
        joints: [.leftShoulder, .rightShoulder],
        check: checkBarLevel
    )

    static func checkBarPath(rep: Rep, result: TrackingResult) -> Verdict {
        let range = rep.startFrame...rep.endFrame
        guard let scale = RuleMath.sagittalScale(rep.view) else { return .unknown("Needs a 45° camera angle") }
        guard let thigh = RuleMath.values(range, in: result, \.thighLength).max(), thigh > 0.01 else {
            return .unknown("Hip or knee wasn't tracked clearly enough")
        }
        let hips = RuleMath.values(range, in: result, \.hipHeight)
        guard let top = hips.max(), let low = hips.min(), top - low > 0.01 else {
            return .unknown("Hips weren't tracked through the rep")
        }

        var offsets: [(frame: Int, value: CGFloat, standing: Bool)] = []
        for i in range {
            let m = result.measurements(at: i)
            guard let bar = m.barX, let ankle = m.ankleX, let hip = m.hipHeight else { continue }
            offsets.append((i, (bar - ankle) / thigh / CGFloat(scale), hip >= top - (top - low) * standingBand))
        }
        guard let baseline = RuleMath.median(offsets.filter(\.standing).map { Double($0.value) }) else {
            return .unknown("Shoulders or ankles weren't tracked at lockout")
        }

        var worst: (frame: Int, drift: CGFloat)?
        for k in offsets.indices {
            let near = offsets[max(0, k - 1)...min(offsets.count - 1, k + 1)].map { Double($0.value) }
            guard let smoothed = RuleMath.median(near) else { continue }
            let drift = CGFloat(smoothed) - CGFloat(baseline)
            if worst == nil || abs(drift) > abs(worst!.drift) { worst = (offsets[k].frame, drift) }
        }
        guard let worst else { return .unknown("Shoulders or ankles weren't tracked") }

        let percent = Int((abs(worst.drift) * 100).rounded())
        if abs(worst.drift) > driftThreshold {
            let bottom = result.measurements(at: rep.bottomFrame)
            let facing: CGFloat = (bottom.kneeX ?? 0) >= (bottom.ankleX ?? 0) ? 1 : -1
            let direction = worst.drift * facing > 0 ? "forward of" : "behind"
            return .fail(frame: worst.frame, detail: "Bar drifted \(direction) mid-foot by \(percent)% of thigh length")
        }
        return .pass(detail: "Bar stayed over mid-foot (drift \(percent)% of thigh length)")
    }

    static func checkBarLevel(rep: Rep, result: TrackingResult) -> Verdict {
        let range = rep.startFrame...rep.endFrame
        guard let torso = RuleMath.median(RuleMath.values(range, in: result, \.torsoLength).map { Double($0) }),
              torso > 0.01 else {
            return .unknown("Shoulders or hips weren't tracked")
        }
        let width = max(RuleMath.values(range, in: result, \.shoulderWidth).map { Double($0) }.max() ?? 0, 0.7 * torso)
        let window = RuleMath.window(around: rep.bottomFrame, radius: 2, in: result)
        guard let drop = RuleMath.median(window.compactMap { result.measurements(at: $0).shoulderHeightDiff.map(Double.init) }) else {
            return .unknown("Both shoulders weren't visible at the bottom")
        }
        let tilt = atan(drop / width) * 180 / .pi
        if tilt > tiltDegrees {
            return .fail(frame: rep.bottomFrame, detail: String(format: "Bar tilted about %.0f° from level", tilt))
        }
        return .pass(detail: String(format: "Bar within %.0f° of level", tilt))
    }
}
