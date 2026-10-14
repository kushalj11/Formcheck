import Foundation

enum CameraView: String, CaseIterable {
    case side, diagonal, front

    var displayName: String {
        switch self {
        case .side: return "Side view"
        case .diagonal: return "45° view"
        case .front: return "Front view"
        }
    }
}

struct Rule: Identifiable {
    let id: String
    let name: String
    let message: String
    let why: String
    let fix: String
    let citation: String
    let views: Set<CameraView>
    let joints: [JointName]
    let check: (Rep, TrackingResult) -> Verdict
}

enum Verdict {
    case pass(detail: String)
    case fail(frame: Int, detail: String)
    case unknown(String)
}

struct RuleFlag: Identifiable {
    var id: String { ruleID }
    let ruleID: String
    let message: String
    let why: String
    let citation: String
    let fix: String
    let detail: String
    let frameIndex: Int
    let joints: [JointName]
}

struct RuleCheck: Identifiable {
    enum Outcome {
        case passed(String)
        case failed(RuleFlag)
        case skipped(String)
    }

    let rule: Rule
    let outcome: Outcome
    var id: String { rule.id }

    var flag: RuleFlag? {
        if case .failed(let f) = outcome { return f }
        return nil
    }

    var wasEvaluated: Bool {
        if case .skipped = outcome { return false }
        return true
    }
}
