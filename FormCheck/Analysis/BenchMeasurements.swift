import CoreGraphics
import Foundation

struct BenchMeasurements {
    var barHeight: CGFloat?
    var barX: CGFloat?
    var shoulderHeight: CGFloat?
    var shoulderX: CGFloat?
    var elbowHeight: CGFloat?
    var hipHeight: CGFloat?
    var hipX: CGFloat?
    var elbowAngle: Double?
    var upperArmLength: CGFloat?
    var forearms: [CGVector] = []
    var wristHeightDiff: CGFloat?

    static func from(_ frame: JointFrame, aspect: CGFloat) -> BenchMeasurements {
        var m = BenchMeasurements()
        let j = PoseGeometry.ruleJoints(frame, aspect: aspect)
        let mid = PoseGeometry.midpoint
        let dist = PoseGeometry.distance

        let bar = mid(j[.leftWrist], j[.rightWrist])
        let shoulders = mid(j[.leftShoulder], j[.rightShoulder])
        let elbows = mid(j[.leftElbow], j[.rightElbow])
        let hips = mid(j[.leftHip], j[.rightHip])
        m.barHeight = bar?.y
        m.barX = bar?.x
        m.shoulderHeight = shoulders?.y
        m.shoulderX = shoulders?.x
        m.elbowHeight = elbows?.y
        m.hipHeight = hips?.y
        m.hipX = hips?.x

        var angles: [Double] = []
        var arms: [CGFloat] = []
        for (s, e, w) in [(JointName.leftShoulder, JointName.leftElbow, JointName.leftWrist),
                          (.rightShoulder, .rightElbow, .rightWrist)] {
            guard let shoulder = j[s], let elbow = j[e] else { continue }
            arms.append(dist(shoulder, elbow))
            if let wrist = j[w] {
                if let a = AngleMath.angle(at: elbow, to: shoulder, and: wrist) { angles.append(a) }
                m.forearms.append(CGVector(dx: wrist.x - elbow.x, dy: wrist.y - elbow.y))
            }
        }
        if !angles.isEmpty { m.elbowAngle = angles.reduce(0, +) / Double(angles.count) }
        m.upperArmLength = arms.max()

        if let lw = j[.leftWrist], let rw = j[.rightWrist] { m.wristHeightDiff = abs(lw.y - rw.y) }
        return m
    }
}
