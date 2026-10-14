import Foundation

struct Rep: Identifiable {
    let id = UUID()
    let index: Int
    let startFrame: Int
    let endFrame: Int
    let bottomFrame: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    var view: CameraView = .side
    var checks: [RuleCheck] = []

    var flags: [RuleFlag] { checks.compactMap(\.flag) }
    var evaluatedCount: Int { checks.filter(\.wasEvaluated).count }
    var failedCount: Int { flags.count }
    var isClean: Bool { flags.isEmpty }

    var score: Int? { SetAnalysis.percent(passed: evaluatedCount - failedCount, of: evaluatedCount) }
}
