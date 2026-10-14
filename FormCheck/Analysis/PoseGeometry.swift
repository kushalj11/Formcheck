import CoreGraphics
import Foundation

enum PoseGeometry {
    static let minRuleConfidence: Float = 0.3

    static func ruleJoints(_ frame: JointFrame, aspect: CGFloat) -> [JointName: CGPoint] {
        var j: [JointName: CGPoint] = [:]
        for (name, p) in frame.joints where (frame.jointConfidences[name] ?? 0) >= minRuleConfidence {
            j[name] = CGPoint(x: p.x * aspect, y: p.y)
        }
        return j
    }

    static func midpoint(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        switch (a, b) {
        case let (x?, y?): return CGPoint(x: (x.x + y.x) / 2, y: (x.y + y.y) / 2)
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
