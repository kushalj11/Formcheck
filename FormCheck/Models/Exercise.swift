import Foundation

enum Exercise: String, CaseIterable, Identifiable {
    case squat, press, benchPress, deadlift, powerClean
    case deskErgonomics, sittingErgonomics

    var id: String { rawValue }

    enum Category { case lift, ergonomics }

    var category: Category {
        switch self {
        case .deskErgonomics, .sittingErgonomics: return .ergonomics
        default: return .lift
        }
    }

    static var lifts: [Exercise] { allCases.filter { $0.category == .lift } }
    static var ergonomics: [Exercise] { allCases.filter { $0.category == .ergonomics } }

    var isAvailable: Bool { family != nil }

    var family: LiftFamily? {
        switch self {
        case .squat: return .squat
        case .benchPress: return .bench
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .squat: return "Squat"
        case .press: return "Press"
        case .benchPress: return "Bench Press"
        case .deadlift: return "Deadlift"
        case .powerClean: return "Power Clean"
        case .deskErgonomics: return "Desk Ergonomics"
        case .sittingErgonomics: return "Sitting Ergonomics"
        }
    }

    var subtitle: String {
        switch self {
        case .squat: return "Depth, lockout, back angle, bar path"
        case .press: return "Overhead, standing"
        case .benchPress: return "Touch, lockout, bar path, forearms"
        case .deadlift: return "Conventional, from the floor"
        case .powerClean: return "Floor to front rack"
        case .deskErgonomics: return "Screen, keyboard and chair setup"
        case .sittingErgonomics: return "Posture while you sit"
        }
    }
}
