import CoreGraphics
import Vision

enum JointName: String, CaseIterable, Codable, Hashable {
    case nose
    case leftEye, rightEye
    case leftEar, rightEar
    case neck
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case root
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle

    var visionName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .nose: return .nose
        case .leftEye: return .leftEye
        case .rightEye: return .rightEye
        case .leftEar: return .leftEar
        case .rightEar: return .rightEar
        case .neck: return .neck
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftElbow: return .leftElbow
        case .rightElbow: return .rightElbow
        case .leftWrist: return .leftWrist
        case .rightWrist: return .rightWrist
        case .root: return .root
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        }
    }

    var displayName: String {
        if self == .root { return "Hip center" }
        var words = ""
        for ch in rawValue {
            if ch.isUppercase { words += " " + ch.lowercased() } else { words.append(ch) }
        }
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    static let skeleton: [(JointName, JointName)] = [
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.leftEar, .leftShoulder), (.rightEar, .rightShoulder),
        (.neck, .nose), (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.nose, .leftEye), (.nose, .rightEye),
        (.root, .leftHip), (.root, .rightHip), (.neck, .root),
    ]
}

struct JointFrame {
    var timestamp: TimeInterval
    var joints: [JointName: CGPoint]
    var jointConfidences: [JointName: Float]
    var confidence: Float

    var hasPose: Bool { !joints.isEmpty }

    static func empty(at timestamp: TimeInterval) -> JointFrame {
        JointFrame(timestamp: timestamp, joints: [:], jointConfidences: [:], confidence: 0)
    }
}
