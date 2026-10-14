import CoreGraphics
import Foundation

enum AngleMath {
    static func angle(at vertex: CGPoint, to a: CGPoint, and b: CGPoint) -> Double? {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)
        let m1 = (v1.dx * v1.dx + v1.dy * v1.dy).squareRoot()
        let m2 = (v2.dx * v2.dx + v2.dy * v2.dy).squareRoot()
        guard m1 > 0.0001, m2 > 0.0001 else { return nil }
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let cosTheta = max(-1, min(1, dot / (m1 * m2)))
        return acos(Double(cosTheta)) * 180 / Double.pi
    }
}
