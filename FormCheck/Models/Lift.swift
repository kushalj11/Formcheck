import Foundation

enum LiftFamily: String, CaseIterable, Identifiable, Codable {
    case squat, bench

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squat: return "Squat"
        case .bench: return "Bench Press"
        }
    }

    var variants: [LiftType] { LiftType.allCases.filter { $0.family == self } }

    var filePrefix: String { rawValue }

    var filmingTip: String {
        switch self {
        case .squat:
            return "Film at a 45° angle to your front with your whole body in frame. From there every check can run on one clip."
        case .bench:
            return "Set the phone at bench height, 45° from your side toward your head, with your whole body and the bar in frame."
        }
    }
}

enum LiftType: String, CaseIterable, Identifiable, Codable {
    case barbellSquat
    case bodyweightSquat
    case benchPress

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbellSquat: return "Barbell Squat"
        case .bodyweightSquat: return "Bodyweight Squat"
        case .benchPress: return "Bench Press"
        }
    }

    var family: LiftFamily {
        switch self {
        case .barbellSquat, .bodyweightSquat: return .squat
        case .benchPress: return .bench
        }
    }

    var rules: [Rule] {
        switch self {
        case .barbellSquat:
            return [SquatRules.depth, SquatRules.lockout, SquatRules.backAngle, BarRules.barPath,
                    SquatRules.kneeCave, SquatRules.symmetry, BarRules.barLevel,
                    SquatRules.head, SquatRules.stance, SquatRules.pace]
        case .bodyweightSquat:
            return [SquatRules.depth, SquatRules.lockout, SquatRules.backAngle,
                    SquatRules.kneeCave, SquatRules.symmetry,
                    SquatRules.head, SquatRules.stance, SquatRules.pace]
        case .benchPress:
            return [BenchRules.touch, BenchRules.lockout, BenchRules.barOverShoulder,
                    BenchRules.forearms, BenchRules.barLevel, BenchRules.hips]
        }
    }
}
