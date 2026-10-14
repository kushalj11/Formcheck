import AVFoundation
import SwiftUI

struct PoseOverlay: View {
    let frame: JointFrame?
    let videoSize: CGSize
    var highlight: Set<JointName> = []
    var contentMode: ContentMode = .fit

    var body: some View {
        Canvas { ctx, size in
            guard let frame, frame.hasPose else { return }
            let rect = contentMode == .fit
                ? AVMakeRect(aspectRatio: videoSize, insideRect: CGRect(origin: .zero, size: size))
                : Self.fillRect(videoSize, in: size)
            func point(_ p: CGPoint) -> CGPoint {
                CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + (1 - p.y) * rect.height)
            }

            for (a, b) in JointName.skeleton {
                guard let pa = frame.joints[a], let pb = frame.joints[b] else { continue }
                var path = Path()
                path.move(to: point(pa))
                path.addLine(to: point(pb))
                let flagged = highlight.contains(a) && highlight.contains(b)
                ctx.stroke(path, with: .color(flagged ? .red : .white.opacity(0.6)), lineWidth: flagged ? 4 : 2)
            }
            for (name, p) in frame.joints {
                let c = point(p)
                let flagged = highlight.contains(name)
                let r: CGFloat = flagged ? 8 : 6
                let dot = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.fill(dot, with: .color(flagged ? .red : Self.color(for: frame.jointConfidences[name] ?? 0)))
                ctx.stroke(dot, with: .color(flagged ? .white : .black.opacity(0.7)), lineWidth: flagged ? 2 : 1)
            }
        }
        .allowsHitTesting(false)
    }

    static func fillRect(_ video: CGSize, in size: CGSize) -> CGRect {
        guard video.width > 0, video.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = max(size.width / video.width, size.height / video.height)
        let w = video.width * scale, h = video.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    static func color(for confidence: Float) -> Color {
        switch confidence {
        case 0.7...: return .green
        case 0.4...: return .yellow
        default: return .red
        }
    }
}
