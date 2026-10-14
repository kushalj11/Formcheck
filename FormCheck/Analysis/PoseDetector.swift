import AVFoundation
import CoreImage
import ImageIO
import Vision

enum PoseDetectorError: LocalizedError {
    case noVideoTrack
    case readerFailed(String)
    case visionUnavailable

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "This file doesn't contain any video."
        case .readerFailed(let m): return "Couldn't read the video: \(m)"
        case .visionUnavailable: return "Pose detection isn't supported on this device. Open FormCheck on an iPhone to analyze this clip."
        }
    }
}

enum PoseDetector {
    static let minJointConfidence: Float = 0.1

    static func analyze(
        url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> TrackingResult {
        let task = Task.detached(priority: .userInitiated) {
            try await run(url: url, progress: progress)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func run(
        url: URL,
        progress: @Sendable (Double) -> Void
    ) async throws -> TrackingResult {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw PoseDetectorError.noVideoTrack
        }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let duration = try await asset.load(.duration).seconds
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))

        let primary = imageOrientation(for: transform)
        let fallback = mirrored(primary)

        var result = try await decode(asset: asset, track: track, orientation: primary, duration: duration, displaySize: displaySize, progress: progress)
        if result.summary.totalFrames > 0, result.summary.framesWithPose == 0, fallback != primary {
            result = try await decode(asset: asset, track: track, orientation: fallback, duration: duration, displaySize: displaySize, progress: progress)
        }
        if result.summary.totalFrames > 0, result.summary.framesFailed == result.summary.totalFrames {
            throw PoseDetectorError.visionUnavailable
        }
        return result
    }

    private static func decode(
        asset: AVURLAsset,
        track: AVAssetTrack,
        orientation: CGImagePropertyOrientation,
        duration: Double,
        displaySize: CGSize,
        progress: @Sendable (Double) -> Void
    ) async throws -> TrackingResult {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else {
            throw PoseDetectorError.readerFailed(reader.error?.localizedDescription ?? "unknown")
        }

        let started = Date()
        var frames: [JointFrame] = []
        var summary = TrackingSummary()
        var jointCounts: [JointName: Int] = [:]
        var confidenceSum: Float = 0
        var currentGap = 0

        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds

            var frame = JointFrame.empty(at: t)
            autoreleasepool {
                do {
                    frame = try detect(sample: sample, orientation: orientation, timestamp: t)
                } catch {
                    summary.framesFailed += 1
                    summary.lastErrorMessage = "\(error)"
                }
            }

            if frame.hasPose {
                summary.framesWithPose += 1
                confidenceSum += frame.confidence
                for name in frame.joints.keys { jointCounts[name, default: 0] += 1 }
                currentGap = 0
            } else {
                currentGap += 1
                summary.longestGapFrames = max(summary.longestGapFrames, currentGap)
            }
            frames.append(frame)

            if frames.count % 8 == 0, duration > 0 {
                progress(min(1, t / duration))
            }
        }

        if reader.status == .failed {
            throw PoseDetectorError.readerFailed(reader.error?.localizedDescription ?? "unknown")
        }

        summary.totalFrames = frames.count
        summary.meanConfidence = summary.framesWithPose == 0 ? 0 : confidenceSum / Float(summary.framesWithPose)
        for name in JointName.allCases {
            summary.perJointRate[name] = frames.isEmpty ? 0 : Double(jointCounts[name, default: 0]) / Double(frames.count)
        }
        summary.processingSeconds = Date().timeIntervalSince(started)
        progress(1)
        return TrackingResult(frames: frames, displaySize: displaySize, summary: summary)
    }

    private static func mirrored(_ o: CGImagePropertyOrientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .upMirrored
        case .down: return .downMirrored
        case .left: return .leftMirrored
        case .right: return .rightMirrored
        default: return o
        }
    }

    static func detect(
        sample: CMSampleBuffer,
        orientation: CGImagePropertyOrientation,
        timestamp: TimeInterval
    ) throws -> JointFrame {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sample, orientation: orientation, options: [:])
        try handler.perform([request])

        var best: (joints: [JointName: CGPoint], conf: [JointName: Float], extent: CGFloat)?
        for observation in request.results ?? [] {
            guard let points = try? observation.recognizedPoints(.all) else { continue }
            var joints: [JointName: CGPoint] = [:]
            var conf: [JointName: Float] = [:]
            for name in JointName.allCases {
                guard let p = points[name.visionName], p.confidence >= minJointConfidence else { continue }
                joints[name] = p.location
                conf[name] = p.confidence
            }
            guard !joints.isEmpty else { continue }
            let xs = joints.values.map(\.x), ys = joints.values.map(\.y)
            let extent = (xs.max()! - xs.min()!) * (ys.max()! - ys.min()!)
            if best == nil || extent > best!.extent { best = (joints, conf, extent) }
        }

        guard let best else { return .empty(at: timestamp) }
        let mean = best.conf.values.reduce(0, +) / Float(best.conf.count)
        return JointFrame(timestamp: timestamp, joints: best.joints, jointConfidences: best.conf, confidence: mean)
    }

    private static func imageOrientation(for t: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (t.a, t.b, t.c, t.d) {
        case (0, 1, -1, 0): return .right
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, -1): return .down
        default: return .up
        }
    }
}
