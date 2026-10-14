import CoreGraphics
import Foundation

enum RuleEngine {
    static func evaluate(rep: Rep, in result: TrackingResult, lift: LiftType) -> [RuleCheck] {
        lift.rules.map { rule in
            guard rule.views.contains(rep.view) else {
                return RuleCheck(rule: rule, outcome: .skipped("Needs a 45° camera angle"))
            }
            switch rule.check(rep, result) {
            case .pass(let detail):
                return RuleCheck(rule: rule, outcome: .passed(detail))
            case .unknown(let reason):
                return RuleCheck(rule: rule, outcome: .skipped(reason))
            case .fail(let frame, let detail):
                return RuleCheck(rule: rule, outcome: .failed(RuleFlag(
                    ruleID: rule.id, message: rule.message, why: rule.why, citation: rule.citation,
                    fix: rule.fix, detail: detail, frameIndex: frame, joints: rule.joints
                )))
            }
        }
    }
}

enum RuleMath {
    static func window(around center: Int, radius: Int, in result: TrackingResult) -> ClosedRange<Int> {
        max(0, center - radius)...min(result.frames.count - 1, center + radius)
    }

    static func values<T>(_ range: ClosedRange<Int>, in result: TrackingResult, _ key: KeyPath<SquatMeasurements, T?>) -> [T] {
        range.compactMap { result.measurements(at: $0)[keyPath: key] }
    }

    static func standingFrames(rep: Rep, in result: TrackingResult) -> [Int] {
        let range = rep.startFrame...rep.endFrame
        let hips = range.map { (i: $0, h: result.measurements(at: $0).hipHeight) }
        let heights = hips.compactMap(\.h)
        guard let top = heights.max(), let low = heights.min(), top - low > 0.01 else { return [] }
        return hips.filter { ($0.h ?? -1) >= top - (top - low) * 0.15 }.map(\.i)
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    static func earlyAscentFrame(rep: Rep, in result: TrackingResult) -> Int? {
        guard rep.endFrame > rep.bottomFrame,
              let bottom = result.measurements(at: rep.bottomFrame).hipHeight,
              let top = values(rep.bottomFrame...rep.endFrame, in: result, \.hipHeight).max(),
              top - bottom > 0.01 else { return nil }
        let target = bottom + (top - bottom) / 3
        for i in rep.bottomFrame...rep.endFrame {
            if let h = result.measurements(at: i).hipHeight, h >= target { return i }
        }
        return nil
    }

    static func sagittalScale(_ view: CameraView) -> Double? {
        switch view {
        case .side: return 1
        case .diagonal: return cos(.pi / 4)
        case .front: return nil
        }
    }

    static func cameraView(rep: Rep, in result: TrackingResult) -> CameraView {
        let ratios = (rep.startFrame...rep.endFrame).compactMap { i -> Double? in
            let m = result.measurements(at: i)
            guard let w = m.shoulderWidth, let t = m.torsoLength, t > 0.01 else { return nil }
            return Double(w / t)
        }
        guard let ratio = median(ratios) else { return .side }
        if ratio < 0.3 { return .side }
        if ratio < 0.6 { return .diagonal }
        return .front
    }
}
