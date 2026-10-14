import CoreGraphics
import Foundation

enum SquatRules {
    static let depthToleranceDegrees: Double = 5
    static let lockoutDegrees: Double = 160
    static let backAngleChangeDegrees: Double = 12
    static let kneeCaveRatio: CGFloat = 0.85
    static let hipLevelThreshold: CGFloat = 0.1

    static let headTiltDegrees: Double = 25
    static let stanceRange: ClosedRange<Double> = 0.7...1.5
    static let minDescentSeconds: Double = 0.4

    static let depth = Rule(
        id: "squat.depth",
        name: "Depth",
        message: "Squat stopped above parallel",
        why: "Squatting below parallel lets the hamstrings and glutes stretch fully, so they drive the weight up and balance the stress on the knee. Stopping above parallel shifts more of the load to the front of the knee and trains a shorter range of motion.",
        fix: "Lower until the hip crease is just below the top of the knee.",
        citation: "Starting Strength: squat depth",
        views: [.side, .diagonal, .front],
        joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
        check: checkDepth
    )

    static let lockout = Rule(
        id: "squat.lockout",
        name: "Lockout",
        message: "Hips and knees weren't fully extended at the top",
        why: "A rep is complete only when the hips and knees are both fully extended. Stopping short reduces the range of motion and skips the finish of the hip drive.",
        fix: "Finish each rep by driving the hips forward until you're standing tall with the knees straight.",
        citation: "Starting Strength: finishing the rep",
        views: [.side, .diagonal, .front],
        joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
        check: checkLockout
    )

    static let backAngle = Rule(
        id: "squat.backAngle",
        name: "Back angle",
        message: "Chest dropped as the hips rose out of the bottom",
        why: "When the hips rise faster than the chest, the back becomes more horizontal and the squat turns into a good morning. The load shifts to the lower back and the bar moves forward of mid-foot.",
        fix: "Drive the hips straight up out of the bottom and keep the chest rising with them, holding the same back angle until you're past the sticking point.",
        citation: "Starting Strength: hip drive and back angle",
        views: [.diagonal, .side],
        joints: [.leftShoulder, .rightShoulder, .leftHip, .rightHip],
        check: checkBackAngle
    )

    static let kneeCave = Rule(
        id: "squat.kneeCave",
        name: "Knee tracking",
        message: "Knees caved inward",
        why: "Knees that collapse inward twist the knee joint under load and take the adductors and hip rotators out of the lift.",
        fix: "Push the knees out so they stay in line with the toes on the way down and on the way up.",
        citation: "Starting Strength: knees out over the toes",
        views: [.diagonal, .front],
        joints: [.leftKnee, .rightKnee, .leftAnkle, .rightAnkle],
        check: checkKneeCave
    )

    static let symmetry = Rule(
        id: "squat.symmetry",
        name: "Left/right balance",
        message: "One hip sat lower than the other at the bottom",
        why: "An uneven bottom position usually comes from a hip shift that puts more of the load on one leg. Repeated over many sets, it can build a side-to-side imbalance.",
        fix: "Set your feet evenly and push through both feet equally out of the bottom.",
        citation: "Starting Strength: balance over mid-foot",
        views: [.diagonal, .front],
        joints: [.leftHip, .rightHip],
        check: checkSymmetry
    )

    static let head = Rule(
        id: "squat.head",
        name: "Head position",
        message: "Head tilted back to look up at the bottom",
        why: "Looking up extends the neck and pulls the chest up out of position, which makes it harder to keep the back angle and the bar over mid-foot.",
        fix: "Keep your eyes on a spot on the floor a few feet ahead for the whole rep, so the neck stays in line with the back.",
        citation: "Starting Strength: eye gaze and neck position",
        views: [.diagonal, .side],
        joints: [.nose, .neck, .leftShoulder, .rightShoulder],
        check: checkHead
    )

    static let stance = Rule(
        id: "squat.stance",
        name: "Stance width",
        message: "Stance wasn't about shoulder width",
        why: "Heels about shoulder width apart give the hips room to sit down between the thighs and let the knees track out over the toes.",
        fix: "Set your heels about shoulder width apart with the toes pointed out about 30°.",
        citation: "Starting Strength: the stance",
        views: [.diagonal, .front],
        joints: [.leftAnkle, .rightAnkle, .leftShoulder, .rightShoulder],
        check: checkStance
    )

    static let pace = Rule(
        id: "squat.pace",
        name: "Controlled descent",
        message: "Dropped into the bottom too fast",
        why: "Dropping uncontrolled makes it hard to hit the same depth every rep and puts the knees and lower back in a loose position at the bottom.",
        fix: "Descend under control at a steady speed, then drive straight back up out of the bottom.",
        citation: "Starting Strength: the descent",
        views: [.side, .diagonal, .front],
        joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
        check: checkPace
    )

    static func checkDepth(rep: Rep, result: TrackingResult) -> Verdict {
        guard let thigh = RuleMath.values(rep.startFrame...rep.endFrame, in: result, \.thighLength).max(),
              thigh > 0.01 else {
            return .unknown("Hip or knee wasn't tracked clearly enough")
        }
        let window = RuleMath.window(around: rep.bottomFrame, radius: 3, in: result)
        let samples = window.compactMap { i in result.measurements(at: i).hipAboveKnee.map { (i, $0) } }
        guard let lowest = samples.min(by: { $0.1 < $1.1 }) else {
            return .unknown("Hip or knee wasn't tracked at the bottom")
        }
        let degrees = asin(max(-1, min(1, Double(lowest.1 / thigh)))) * 180 / .pi
        if degrees > depthToleranceDegrees {
            return .fail(frame: lowest.0, detail: String(format: "Thigh stopped %.0f° above parallel", degrees))
        }
        return .pass(detail: degrees <= 0
            ? String(format: "Thigh reached %.0f° below parallel", -degrees)
            : "Thigh reached parallel")
    }

    static func checkLockout(rep: Rep, result: TrackingResult) -> Verdict {
        let ascent = rep.bottomFrame...rep.endFrame
        let hips = RuleMath.values(ascent, in: result, \.hipAngle)
        let knees = RuleMath.values(ascent, in: result, \.kneeAngle)
        guard let hip = hips.max(), let knee = knees.max() else {
            return .unknown("Hips or knees weren't tracked at the top")
        }
        let detail = String(format: "Hip %.0f° and knee %.0f° at the top", hip, knee)
        if hip < lockoutDegrees || knee < lockoutDegrees {
            return .fail(frame: rep.endFrame, detail: detail)
        }
        return .pass(detail: detail)
    }

    static func checkBackAngle(rep: Rep, result: TrackingResult) -> Verdict {
        guard let scale = RuleMath.sagittalScale(rep.view) else { return .unknown("Needs a 45° camera angle") }
        func trueLean(_ frames: ClosedRange<Int>) -> Double? {
            RuleMath.median(frames.compactMap { result.measurements(at: $0).torsoLeanAngle }).map {
                atan(tan($0 * .pi / 180) / scale) * 180 / .pi
            }
        }
        guard let bottomLean = trueLean(RuleMath.window(around: rep.bottomFrame, radius: 2, in: result)) else {
            return .unknown("Shoulders or hips weren't tracked at the bottom")
        }
        guard let early = RuleMath.earlyAscentFrame(rep: rep, in: result) else {
            return .unknown("Couldn't find the start of the ascent")
        }
        guard let earlyLean = trueLean(RuleMath.window(around: early, radius: 2, in: result)) else {
            return .unknown("Shoulders or hips weren't tracked coming up")
        }
        let change = earlyLean - bottomLean
        if change > backAngleChangeDegrees {
            return .fail(frame: early, detail: String(format: "Torso tipped %.0f° further forward coming up", change))
        }
        return .pass(detail: change <= 0
            ? "Chest rose with the hips"
            : String(format: "Torso tipped %.0f° forward, within the limit", change))
    }

    static func checkKneeCave(rep: Rep, result: TrackingResult) -> Verdict {
        let range = rep.startFrame...rep.endFrame
        guard let thigh = RuleMath.values(range, in: result, \.thighLength).max(), thigh > 0.01 else {
            return .unknown("Hip or knee wasn't tracked clearly enough")
        }
        let hips = RuleMath.values(range, in: result, \.hipHeight)
        guard let top = hips.max(), let low = hips.min(), top - low > 0.01 else {
            return .unknown("Hips weren't tracked through the rep")
        }

        var standing: [Double] = []
        var squatting: [(frame: Int, ratio: Double)] = []
        for i in range {
            let m = result.measurements(at: i)
            guard let knees = m.kneeWidth, let ankles = m.ankleWidth, ankles > thigh * 0.15,
                  let hip = m.hipHeight else { continue }
            let ratio = Double(knees / ankles)
            if hip >= top - (top - low) * 0.15 { standing.append(ratio) }
            if hip <= low + (top - low) * 0.5 { squatting.append((i, ratio)) }
        }
        guard !squatting.isEmpty else { return .unknown("Both knees and ankles weren't visible at the bottom") }

        let baseline = RuleMath.median(standing) ?? 1
        var worst: (frame: Int, change: Double)?
        for k in squatting.indices {
            let near = squatting[max(0, k - 1)...min(squatting.count - 1, k + 1)].map(\.ratio)
            guard let smoothed = RuleMath.median(near) else { continue }
            let change = smoothed / baseline
            if worst == nil || change < worst!.change { worst = (squatting[k].frame, change) }
        }
        guard let worst else { return .unknown("Both knees and ankles weren't visible at the bottom") }

        let percent = Int((abs(1 - worst.change) * 100).rounded())
        if worst.change < Double(kneeCaveRatio) {
            return .fail(frame: worst.frame, detail: "Knees moved \(percent)% closer together than when standing")
        }
        return .pass(detail: worst.change >= 1
            ? "Knees pushed \(percent)% wider than when standing"
            : "Knees stayed in line with the feet")
    }

    static func checkSymmetry(rep: Rep, result: TrackingResult) -> Verdict {
        guard let thigh = RuleMath.values(rep.startFrame...rep.endFrame, in: result, \.thighLength).max(), thigh > 0.01 else {
            return .unknown("Hip or knee wasn't tracked clearly enough")
        }
        let window = RuleMath.window(around: rep.bottomFrame, radius: 2, in: result)
        guard let diff = RuleMath.median(window.compactMap { result.measurements(at: $0).hipHeightDiff.map { Double($0 / thigh) } }) else {
            return .unknown("Both hips weren't visible at the bottom")
        }
        let percent = Int((diff * 100).rounded())
        if diff > Double(hipLevelThreshold) {
            return .fail(frame: rep.bottomFrame, detail: "Hip heights differed by \(percent)% of thigh length")
        }
        return .pass(detail: "Hips stayed level (within \(percent)% of thigh length)")
    }

    static func checkHead(rep: Rep, result: TrackingResult) -> Verdict {
        guard let scale = RuleMath.sagittalScale(rep.view) else { return .unknown("Needs a 45° camera angle") }
        let bottom = result.measurements(at: rep.bottomFrame)
        guard let knee = bottom.kneeX, let ankle = bottom.ankleX else {
            return .unknown("Knees or ankles weren't tracked at the bottom")
        }
        let facing: Double = knee >= ankle ? 1 : -1

        func headTilt(_ i: Int) -> Double? {
            let m = result.measurements(at: i)
            guard let neck = m.neckPoint, let nose = m.nosePoint, let hip = m.hipPoint else { return nil }
            let torso = (x: Double(neck.x - hip.x) / scale, y: Double(neck.y - hip.y))
            let head = (x: Double(nose.x - neck.x) / scale, y: Double(nose.y - neck.y))
            let cross = torso.x * head.y - torso.y * head.x
            let dot = torso.x * head.x + torso.y * head.y
            return -atan2(cross, dot) * 180 / .pi * facing
        }

        let standing = RuleMath.standingFrames(rep: rep, in: result).compactMap(headTilt)
        let atBottom = RuleMath.window(around: rep.bottomFrame, radius: 2, in: result).compactMap(headTilt)
        guard let baseline = RuleMath.median(standing), let low = RuleMath.median(atBottom) else {
            return .unknown("Head or neck wasn't tracked clearly enough")
        }
        let tiltBack = baseline - low
        if tiltBack > headTiltDegrees {
            return .fail(frame: rep.bottomFrame, detail: String(format: "Head tilted back %.0f° compared with standing", tiltBack))
        }
        return .pass(detail: "Neck stayed in line with the back")
    }

    static func checkStance(rep: Rep, result: TrackingResult) -> Verdict {
        let ratios = RuleMath.standingFrames(rep: rep, in: result).compactMap { i -> Double? in
            let m = result.measurements(at: i)
            guard let ankles = m.ankleWidth, let shoulders = m.shoulderWidth,
                  let torso = m.torsoLength, shoulders > torso * 0.2 else { return nil }
            return Double(ankles / shoulders)
        }
        guard let ratio = RuleMath.median(ratios) else { return .unknown("Ankles or shoulders weren't visible while standing") }
        let detail = String(format: "Heels were %.1f× shoulder width apart", ratio)
        if !stanceRange.contains(ratio) {
            return .fail(frame: rep.startFrame, detail: detail)
        }
        return .pass(detail: detail)
    }

    static func checkPace(rep: Rep, result: TrackingResult) -> Verdict {
        let standing = RuleMath.standingFrames(rep: rep, in: result).filter { $0 < rep.bottomFrame }
        guard let leftTop = standing.max() else { return .unknown("The start of the descent wasn't in the clip") }
        let seconds = result.frames[rep.bottomFrame].timestamp - result.frames[leftTop].timestamp
        let detail = String(format: "Descent took %.1f s", seconds)
        if seconds < minDescentSeconds {
            return .fail(frame: rep.bottomFrame, detail: detail)
        }
        return .pass(detail: detail)
    }
}
