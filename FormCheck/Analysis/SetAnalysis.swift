import Foundation

struct SetAnalysis {
    let lift: LiftType
    let reps: [Rep]

    var checksRun: Int { reps.reduce(0) { $0 + $1.evaluatedCount } }
    var checksFailed: Int { reps.reduce(0) { $0 + $1.failedCount } }

    var score: Int? { Self.percent(passed: checksRun - checksFailed, of: checksRun) }

    static func percent(passed: Int, of total: Int) -> Int? {
        guard total > 0 else { return nil }
        return Int((Double(passed) / Double(total) * 100).rounded())
    }

    static func run(on result: TrackingResult, lift: LiftType) -> SetAnalysis {
        var reps = RepSegmenter.segment(result, family: lift.family)
        for i in reps.indices {
            reps[i].view = RuleMath.cameraView(rep: reps[i], in: result)
            reps[i].checks = RuleEngine.evaluate(rep: reps[i], in: result, lift: lift)
        }
        return SetAnalysis(lift: lift, reps: reps)
    }
}
