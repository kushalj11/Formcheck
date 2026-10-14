import AVFoundation
import Foundation

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    @Published private(set) var isRecording = false
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var recordingSeconds: Int = 0
    @Published private(set) var position: AVCaptureDevice.Position = .front
    var family: LiftFamily = .squat
    var onFinished: ((URL) -> Void)?
    var onPose: ((JointFrame, CGSize) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "formcheck.camera")
    private let frameQueue = DispatchQueue(label: "formcheck.camera.frames", qos: .userInitiated)
    private let visionQueue = DispatchQueue(label: "formcheck.camera.vision", qos: .userInitiated)
    private var configured = false
    private var currentInput: AVCaptureDeviceInput?
    private var timer: Timer?

    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var writerStarted = false
    private var wantsRecording = false
    private var visionBusy = false
    private var firstFrameTime: CMTime?

    func start() {
        Task {
            guard await requestAccess() else {
                await MainActor.run { self.errorMessage = "Camera access is turned off. Turn it on in Settings > Privacy & Security > Camera." }
                return
            }
            queue.async { [self] in
                if !configured { configure(position: .front) }
                if configured, !session.isRunning { session.startRunning() }
            }
        }
    }

    func flipCamera() {
        guard isReady, !isRecording else { return }
        let target: AVCaptureDevice.Position = position == .back ? .front : .back
        queue.async { [self] in
            guard configured else { return }
            configure(position: target)
        }
    }

    func stop() {
        frameQueue.async { [self] in
            if wantsRecording { finishWriting() }
        }
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func toggleRecording() {
        let ready = isReady
        frameQueue.async { [self] in
            if wantsRecording {
                finishWriting()
            } else if ready {
                wantsRecording = true
                writerStarted = false
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if wantsRecording { write(sampleBuffer) }
        trackPose(sampleBuffer)
    }

    private func write(_ sample: CMSampleBuffer) {
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        if writer == nil {
            guard let pixels = CMSampleBufferGetImageBuffer(sample) else { return }
            do {
                try startWriter(width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels))
            } catch {
                wantsRecording = false
                DispatchQueue.main.async { self.errorMessage = "Couldn't start recording: \(error.localizedDescription)" }
                return
            }
        }
        guard let writer, let writerInput else { return }
        if !writerStarted {
            guard writer.startWriting() else {
                failRecording(writer.error)
                return
            }
            writer.startSession(atSourceTime: time)
            writerStarted = true
            DispatchQueue.main.async { self.didStartRecording() }
        }
        if writerInput.isReadyForMoreMediaData {
            writerInput.append(sample)
        }
    }

    private func startWriter(width: Int, height: Int) throws {
        let url = RecordingStore.newRecordingURL(family: family)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw CocoaError(.fileWriteUnknown) }
        writer.add(input)
        self.writer = writer
        self.writerInput = input
    }

    private func finishWriting() {
        wantsRecording = false
        guard let writer, let writerInput, writerStarted else {
            resetWriter()
            DispatchQueue.main.async { self.didStopRecording() }
            return
        }
        resetWriter()
        writerInput.markAsFinished()
        let url = writer.outputURL
        writer.finishWriting {
            let ok = writer.status == .completed
            let error = writer.error
            DispatchQueue.main.async {
                self.didStopRecording()
                if ok {
                    self.onFinished?(url)
                } else {
                    self.errorMessage = error?.localizedDescription ?? "The recording couldn't be saved. Please try again."
                }
            }
        }
    }

    private func failRecording(_ error: Error?) {
        wantsRecording = false
        resetWriter()
        DispatchQueue.main.async {
            self.didStopRecording()
            self.errorMessage = error?.localizedDescription ?? "The recording couldn't be saved. Please try again."
        }
    }

    private func resetWriter() {
        writer = nil
        writerInput = nil
        writerStarted = false
    }

    private func trackPose(_ sample: CMSampleBuffer) {
        guard !visionBusy, onPose != nil, let pixels = CMSampleBufferGetImageBuffer(sample) else { return }
        visionBusy = true
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        if firstFrameTime == nil { firstFrameTime = time }
        let seconds = (time - (firstFrameTime ?? time)).seconds
        let size = CGSize(width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels))
        visionQueue.async { [self] in
            let frame = (try? PoseDetector.detect(sample: sample, orientation: .up, timestamp: seconds)) ?? .empty(at: seconds)
            frameQueue.async { self.visionBusy = false }
            DispatchQueue.main.async { self.onPose?(frame, size) }
        }
    }

    private func didStartRecording() {
        isRecording = true
        recordingSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingSeconds += 1
        }
    }

    private func didStopRecording() {
        timer?.invalidate()
        timer = nil
        isRecording = false
    }

    private func configure(position: AVCaptureDevice.Position) {
        guard let device = camera(at: position) else {
            DispatchQueue.main.async {
                self.errorMessage = "No camera is available on this device. Import a clip from Photos instead."
            }
            return
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        do {
            let input = try AVCaptureDeviceInput(device: device)

            if let currentInput {
                session.removeInput(currentInput)
            }
            guard session.canAddInput(input) else {
                if let currentInput { session.addInput(currentInput) }
                DispatchQueue.main.async { self.errorMessage = "Couldn't switch cameras." }
                return
            }
            session.addInput(input)
            currentInput = input

            if !configured {
                session.sessionPreset = .high
                videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
                guard session.canAddOutput(videoOutput) else {
                    DispatchQueue.main.async { self.errorMessage = "Couldn't start the camera." }
                    return
                }
                session.addOutput(videoOutput)
                configured = true
            }

            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = position == .front
                }
            }

            DispatchQueue.main.async {
                self.position = position
                self.isReady = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
    }

    private func camera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInDualWideCamera, .builtInTrueDepthCamera]
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: position)
            .devices.first
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}
