import CoreGraphics
import Foundation

struct SquatMeasurements {
    var leftKneeAngle: Double?
    var rightKneeAngle: Double?
    var leftHipAngle: Double?
    var rightHipAngle: Double?
    var hipHeight: CGFloat?
    var kneeHeight: CGFloat?
    var hipAboveKnee: CGFloat?
    var thighLength: CGFloat?
    var kneeWidth: CGFloat?
    var ankleWidth: CGFloat?
    var hipHeightDiff: CGFloat?
    var torsoLeanAngle: Double?
    var torsoLength: CGFloat?
    var shoulderWidth: CGFloat?
    var barX: CGFloat?
    var ankleX: CGFloat?
    var kneeX: CGFloat?
    var shoulderHeightDiff: CGFloat?
    var headAngle: Double?
    var neckPoint: CGPoint?
    var nosePoint: CGPoint?
    var hipPoint: CGPoint?

    var kneeAngle: Double? { Self.average(leftKneeAngle, rightKneeAngle) }
    var hipAngle: Double? { Self.average(leftHipAngle, rightHipAngle) }

    private static func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (x?, y?): return (x + y) / 2
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }

    static func from(_ frame: JointFrame, aspect: CGFloat) -> SquatMeasurements {
        var m = SquatMeasurements()
        let j = PoseGeometry.ruleJoints(frame, aspect: aspect)

        if let h = j[.leftHip], let k = j[.leftKnee], let a = j[.leftAnkle] {
            m.leftKneeAngle = AngleMath.angle(at: k, to: h, and: a)
        }
        if let h = j[.rightHip], let k = j[.rightKnee], let a = j[.rightAnkle] {
            m.rightKneeAngle = AngleMath.angle(at: k, to: h, and: a)
        }
        if let s = j[.leftShoulder], let h = j[.leftHip], let k = j[.leftKnee] {
            m.leftHipAngle = AngleMath.angle(at: h, to: s, and: k)
        }
        if let s = j[.rightShoulder], let h = j[.rightHip], let k = j[.rightKnee] {
            m.rightHipAngle = AngleMath.angle(at: h, to: s, and: k)
        }

        let hipMid = PoseGeometry.midpoint(j[.leftHip], j[.rightHip])
        let kneeMid = PoseGeometry.midpoint(j[.leftKnee], j[.rightKnee])
        let shoulderMid = PoseGeometry.midpoint(j[.leftShoulder], j[.rightShoulder])
        let ankleMid = PoseGeometry.midpoint(j[.leftAnkle], j[.rightAnkle])

        m.hipHeight = hipMid?.y
        m.kneeHeight = kneeMid?.y
        if let h = hipMid, let k = kneeMid { m.hipAboveKnee = h.y - k.y }
        m.kneeX = kneeMid?.x
        m.ankleX = ankleMid?.x
        m.barX = shoulderMid?.x

        let thighs = [
            j[.leftHip].flatMap { h in j[.leftKnee].map { PoseGeometry.distance(h, $0) } },
            j[.rightHip].flatMap { h in j[.rightKnee].map { PoseGeometry.distance(h, $0) } },
        ].compactMap { $0 }
        m.thighLength = thighs.max()

        if let hip = hipMid, let shoulder = shoulderMid {
            let above = CGPoint(x: hip.x, y: hip.y + 1)
            m.torsoLeanAngle = AngleMath.angle(at: hip, to: above, and: shoulder)
            m.torsoLength = PoseGeometry.distance(hip, shoulder)
        }

        if let ls = j[.leftShoulder], let rs = j[.rightShoulder] {
            m.shoulderWidth = PoseGeometry.distance(ls, rs)
            m.shoulderHeightDiff = abs(ls.y - rs.y)
        }
        if let lk = j[.leftKnee], let rk = j[.rightKnee] { m.kneeWidth = abs(lk.x - rk.x) }
        if let la = j[.leftAnkle], let ra = j[.rightAnkle] { m.ankleWidth = abs(la.x - ra.x) }
        if let lh = j[.leftHip], let rh = j[.rightHip] { m.hipHeightDiff = abs(lh.y - rh.y) }

        if let neck = j[.neck], let nose = j[.nose], let hip = hipMid {
            m.headAngle = AngleMath.angle(at: neck, to: nose, and: hip)
        }
        m.neckPoint = j[.neck]
        m.nosePoint = j[.nose]
        m.hipPoint = hipMid

        return m
    }
}
