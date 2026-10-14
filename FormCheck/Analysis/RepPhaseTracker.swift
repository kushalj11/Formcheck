import CoreGraphics
import Foundation

enum RepPhase: Equatable {
    case setup, descent, bottom, ascent, lockout

    var title: String {
        switch self {
        case .setup: return "Setup"
        case .descent: return "On the way down"
        case .bottom: return "Bottom"
        case .ascent: return "On the way up"
        case .lockout: return "Top"
        }
    }

    func cues(for family: LiftFamily) -> [String] {
        switch family {
        case .squat: return squatCues
        case .bench: return benchCues
        }
    }

    private var benchCues: [String] {
        switch self {
        case .setup:
            return ["Eyes under the bar, feet flat on the floor",
                    "Squeeze the shoulder blades together and keep the chest up",
                    "Wrists straight, bar over the heel of the hand",
                    "Big breath and hold it before each rep"]
        case .descent:
            return ["Lower the bar to the lower chest, elbows slightly in"]
        case .bottom:
            return ["Touch the chest, forearms vertical"]
        case .ascent:
            return ["Press back toward your face, over the shoulders"]
        case .lockout:
            return ["Lock the elbows with the bar over the shoulders"]
        }
    }

    private var squatCues: [String] {
        switch self {
        case .setup:
            return ["Heels about shoulder width apart, toes out about 30°",
                    "Big breath, brace your abs and hold it",
                    "Eyes on a spot on the floor a few feet ahead"]
        case .descent:
            return ["Knees out over the toes, hips back"]
        case .bottom:
            return ["Hip crease just below the top of the knee"]
        case .ascent:
            return ["Drive your hips straight up, chest rising with them"]
        case .lockout:
            return ["Stand tall: hips and knees fully straight"]
        }
    }
}

struct RepPhaseTracker {
    let family: LiftFamily

    static let standingDepth: CGFloat = 0.15
    static let bottomDepth: CGFloat = 0.6
    static let movingSpeed: CGFloat = 0.25
    static let lockoutHold: TimeInterval = 1.5

    private(set) var phase: RepPhase = .setup
    private var recentHeights: [(time: TimeInterval, height: CGFloat)] = []
    private var bodyLength: CGFloat = 0
    private var lockoutUntil: TimeInterval = 0

    init(family: LiftFamily) { self.family = family }

    private func reading(_ frame: JointFrame, aspect: CGFloat) -> (height: CGFloat?, length: CGFloat?) {
        switch family {
        case .squat:
            let m = SquatMeasurements.from(frame, aspect: aspect)
            return (m.hipHeight, m.thighLength)
        case .bench:
            let m = BenchMeasurements.from(frame, aspect: aspect)
            return (m.barHeight, m.upperArmLength)
        }
    }

    mutating func update(_ frame: JointFrame, aspect: CGFloat) -> RepPhase {
        let r = reading(frame, aspect: aspect)
        guard let height = r.height else { return phase }
        let t = frame.timestamp
        if let length = r.length { bodyLength = max(bodyLength, length) }
        recentHeights.append((t, height))
        recentHeights.removeAll { t - $0.time > 4 }
        guard bodyLength > 0.01, let standing = recentHeights.map(\.height).max() else { return phase }

        let depth = (standing - height) / bodyLength
        let speed = velocity(over: 0.25) / bodyLength

        if depth < Self.standingDepth {
            if phase == .ascent { lockoutUntil = t + Self.lockoutHold }
            phase = t < lockoutUntil ? .lockout : .setup
        } else if speed < -Self.movingSpeed {
            phase = depth > Self.bottomDepth ? .bottom : .descent
        } else if speed > Self.movingSpeed {
            phase = .ascent
        } else if depth > Self.bottomDepth {
            phase = .bottom
        }
        return phase
    }

    private func velocity(over window: TimeInterval) -> CGFloat {
        guard let last = recentHeights.last,
              let first = recentHeights.first(where: { last.time - $0.time <= window }),
              last.time - first.time > 0.05 else { return 0 }
        return (last.height - first.height) / CGFloat(last.time - first.time)
    }
}
