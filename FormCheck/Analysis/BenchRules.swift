import CoreGraphics
import Foundation

enum BenchRules {
    static let touchToleranceDegrees: Double = -5
    static let lockoutDegrees: Double = 160
    static let shoulderOffsetThreshold: CGFloat = 0.4
    static let forearmDegrees: Double = 20
    static let levelThreshold: CGFloat = 0.15
    static let hipRiseThreshold: CGFloat = 0.2

    static let touch = Rule(
        id: "bench.touch",
        name: "Touch the chest",
        message: "Bar stopped short of the chest",
        why: "A rep that stops above the chest skips the bottom of the range, where the chest and shoulders work hardest, and makes every rep easier than it looks.",
        fix: "Lower the bar under control until it touches the lower chest, then press.",
        citation: "Starting Strength: the bench press, range of motion",
        views: [.side, .diagonal, .front],
        joints: [.leftShoulder, .rightShoulder, .leftElbow, .rightElbow],
        check: checkTouch
    )

    static let lockout = Rule(
        id: "bench.lockout",
        name: "Lockout",
        message: "Elbows weren't fully locked at the top",
        why: "A rep is complete only when the elbows are straight and the bar is supported by the skeleton rather than the muscles.",
        fix: "Press until the elbows are fully straight before starting the next rep.",
        citation: "Starting Strength: finishing the bench press",
        views: [.side, .diagonal, .front],
        joints: [.leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist],
        check: checkLockout
    )

    static let barOverShoulder = Rule(
        id: "bench.barOverShoulder",
        name: "Bar over shoulders",
        message: "Bar finished away from over the shoulders",
        why: "The bar is balanced at the top only when it sits directly over the shoulder joints. Anywhere else the shoulders have to hold it in place.",
        fix: "Press the bar back toward your face on the way up so it finishes directly over the shoulders.",
        citation: "Starting Strength: bench press bar path",
        views: [.diagonal, .side],
        joints: [.leftShoulder, .rightShoulder, .leftWrist, .rightWrist],
        check: checkBarOverShoulder
    )

    static let forearms = Rule(
        id: "bench.forearms",
        name: "Forearms vertical",
        message: "Wrists weren't stacked over the elbows at the bottom",
        why: "Forearms that lean put the bar out of line with the elbows, so the press has to fight a lever arm instead of pushing straight up.",
        fix: "Adjust your grip and elbow position so the forearms are vertical with the bar on the chest.",
        citation: "Starting Strength: grip and forearm position",
        views: [.diagonal, .side],
        joints: [.leftElbow, .rightElbow, .leftWrist, .rightWrist],
        check: checkForearms
    )

    static let barLevel = Rule(
        id: "bench.level",
        name: "Bar level",
        message: "Bar tilted to one side",
        why: "A tilted bar means one arm is pressing more than the other, which loads one shoulder harder.",
        fix: "Center your grip on the bar and press both sides up at the same speed.",
        citation: "Starting Strength: the grip",
        views: [.diagonal, .front],
        joints: [.leftWrist, .rightWrist],
        check: checkBarLevel
    )

    static let hips = Rule(
        id: "bench.hips",
        name: "Hips on the bench",
        message: "Hips came off the bench",
        why: "Lifting the hips shortens the range of motion and turns the press into a decline press. It also puts strain on the lower back.",
        fix: "Keep your hips down on the bench and drive with the legs into the floor without raising them.",
        citation: "Starting Strength: bench press setup",
        views: [.side, .diagonal, .front],
        joints: [.leftHip, .rightHip],
        check: checkHips
    )

    private static func upperArm(_ rep: Rep, _ result: TrackingResult) -> CGFloat? {
        let arms = (rep.startFrame...rep.endFrame).compactMap { result.benchMeasurements(at: $0).upperArmLength }
        guard let longest = arms.max(), longest > 0.01 else { return nil }
        return longest
    }

    private static func topFrames(_ rep: Rep, _ result: TrackingResult) -> [Int] {
        let bars = (rep.startFrame...rep.endFrame).map { (i: $0, h: result.benchMeasurements(at: $0).barHeight) }
        let heights = bars.compactMap(\.h)
        guard let top = heights.max(), let low = heights.min(), top - low > 0.01 else { return [] }
        return bars.filter { ($0.h ?? -1) >= top - (top - low) * 0.15 }.map(\.i)
    }

    static func checkTouch(rep: Rep, result: TrackingResult) -> Verdict {
        guard let arm = upperArm(rep, result) else { return .unknown("Shoulders or elbows weren't tracked clearly enough") }
        let angles = RuleMath.window(around: rep.bottomFrame, radius: 3, in: result).compactMap { i -> (Int, Double)? in
            let m = result.benchMeasurements(at: i)
            guard let shoulder = m.shoulderHeight, let elbow = m.elbowHeight else { return nil }
            let below = asin(max(-1, min(1, Double((shoulder - elbow) / arm)))) * 180 / .pi
            return (i, below)
        }
        guard let deepest = angles.max(by: { $0.1 < $1.1 }) else {
            return .unknown("Shoulders or elbows weren't tracked at the bottom")
        }
        if deepest.1 < touchToleranceDegrees {
            return .fail(frame: deepest.0, detail: String(format: "Elbows stopped %.0f° above shoulder level", -deepest.1))
        }
        return .pass(detail: deepest.1 >= 0
            ? String(format: "Elbows reached %.0f° below shoulder level", deepest.1)
            : "Elbows reached shoulder level")
    }

    static func checkLockout(rep: Rep, result: TrackingResult) -> Verdict {
        let angles = (rep.bottomFrame...rep.endFrame).compactMap { result.benchMeasurements(at: $0).elbowAngle }
        guard let best = angles.max() else { return .unknown("Arms weren't tracked at the top") }
        let detail = String(format: "Elbows reached %.0f° at the top", best)
        if best < lockoutDegrees { return .fail(frame: rep.endFrame, detail: detail) }
        return .pass(detail: detail)
    }

    static func checkBarOverShoulder(rep: Rep, result: TrackingResult) -> Verdict {
        guard let scale = RuleMath.sagittalScale(rep.view) else { return .unknown("Needs a 45° camera angle") }
        guard let arm = upperArm(rep, result) else { return .unknown("Shoulders or elbows weren't tracked clearly enough") }
        let offsets = topFrames(rep, result).compactMap { i -> Double? in
            let m = result.benchMeasurements(at: i)
            guard let bar = m.barX, let shoulder = m.shoulderX else { return nil }
            return Double((bar - shoulder) / arm) / scale
        }
        guard let offset = RuleMath.median(offsets) else { return .unknown("Wrists or shoulders weren't tracked at lockout") }
        let percent = Int((abs(offset) * 100).rounded())
        if abs(offset) > Double(shoulderOffsetThreshold) {
            let m = result.benchMeasurements(at: rep.endFrame)
            let footward = (m.hipX ?? 0) >= (m.shoulderX ?? 0) ? 1.0 : -1.0
            let side = offset * footward > 0 ? "toward the feet" : "toward the face"
            return .fail(frame: rep.endFrame, detail: "Bar locked out \(side), \(percent)% of an upper arm length from the shoulders")
        }
        return .pass(detail: "Bar finished over the shoulders (within \(percent)% of an upper arm length)")
    }

    static func checkForearms(rep: Rep, result: TrackingResult) -> Verdict {
        guard let scale = RuleMath.sagittalScale(rep.view) else { return .unknown("Needs a 45° camera angle") }
        let leans = RuleMath.window(around: rep.bottomFrame, radius: 2, in: result).flatMap { i -> [Double] in
            result.benchMeasurements(at: i).forearms.compactMap { v in
                guard abs(v.dy) > 0.005 else { return nil }
                return atan(Double(abs(v.dx)) / scale / Double(abs(v.dy))) * 180 / .pi
            }
        }
        guard let lean = RuleMath.median(leans) else { return .unknown("Elbows or wrists weren't tracked at the bottom") }
        let detail = String(format: "Forearms leaned %.0f° from vertical", lean)
        if lean > forearmDegrees { return .fail(frame: rep.bottomFrame, detail: detail) }
        return .pass(detail: detail)
    }

    static func checkBarLevel(rep: Rep, result: TrackingResult) -> Verdict {
        guard let arm = upperArm(rep, result) else { return .unknown("Shoulders or elbows weren't tracked clearly enough") }
        let diffs = (rep.startFrame...rep.endFrame).compactMap { i -> (Int, Double)? in
            result.benchMeasurements(at: i).wristHeightDiff.map { (i, Double($0 / arm)) }
        }
        guard !diffs.isEmpty else { return .unknown("Both wrists weren't visible") }
        var worst: (frame: Int, diff: Double)?
        for k in diffs.indices {
            let near = diffs[max(0, k - 1)...min(diffs.count - 1, k + 1)].map(\.1)
            guard let smoothed = RuleMath.median(near) else { continue }
            if worst == nil || smoothed > worst!.diff { worst = (diffs[k].0, smoothed) }
        }
        guard let worst else { return .unknown("Both wrists weren't visible") }
        let percent = Int((worst.diff * 100).rounded())
        if worst.diff > Double(levelThreshold) {
            return .fail(frame: worst.frame, detail: "One side of the bar sat \(percent)% of an upper arm length lower")
        }
        return .pass(detail: "Bar stayed level (within \(percent)% of an upper arm length)")
    }

    static func checkHips(rep: Rep, result: TrackingResult) -> Verdict {
        guard let arm = upperArm(rep, result) else { return .unknown("Shoulders or elbows weren't tracked clearly enough") }
        let resting = topFrames(rep, result).compactMap { result.benchMeasurements(at: $0).hipHeight }.map(Double.init)
        let during = (rep.bottomFrame...rep.endFrame).compactMap { i in result.benchMeasurements(at: i).hipHeight.map { (i, Double($0)) } }
        guard let baseline = RuleMath.median(resting), let highest = during.max(by: { $0.1 < $1.1 }) else {
            return .unknown("Hips weren't tracked")
        }
        let rise = (highest.1 - baseline) / Double(arm)
        let percent = Int((max(0, rise) * 100).rounded())
        if rise > Double(hipRiseThreshold) {
            return .fail(frame: highest.0, detail: "Hips rose \(percent)% of an upper arm length during the press")
        }
        return .pass(detail: "Hips stayed on the bench")
    }
}
