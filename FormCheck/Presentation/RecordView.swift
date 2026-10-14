import SwiftUI

struct RecordView: View {
    @StateObject private var camera = CameraController()
    @StateObject private var live: LivePose
    @State private var finished: Recording?
    let family: LiftFamily
    var onClose: (() -> Void)?

    init(family: LiftFamily, onClose: (() -> Void)? = nil) {
        self.family = family
        self.onClose = onClose
        _live = StateObject(wrappedValue: LivePose(family: family))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
            PoseOverlay(frame: live.frame, videoSize: live.imageSize, contentMode: .fill)
                .ignoresSafeArea()

            if let message = camera.errorMessage {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }

            VStack {
                topCenter
                    .padding(.top, 8)

                Spacer()
                if live.frame?.hasPose == true {
                    cueCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                } else if camera.isReady, live.frame != nil {
                    Label("Step back until your whole body is in frame", systemImage: "figure.stand")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.bottom, 12)
                }
                controls
            }
            .animation(.snappy, value: live.cue)
        }
        .onAppear {
            camera.onFinished = { url in
                finished = RecordingStore.shared.recording(for: url)
            }
            camera.family = family
            camera.onPose = { frame, size in live.ingest(frame, size: size) }
            camera.start()
        }
        .onDisappear { camera.stop() }
        .fullScreenCover(item: $finished) { recording in
            NavigationStack {
                PlaybackView(recording: recording)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { finished = nil }
                        }
                    }
            }
        }
    }

    @ViewBuilder private var topCenter: some View {
        if camera.isRecording {
            Text(timeString(camera.recordingSeconds))
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.red, in: Capsule())
        } else if camera.isReady {
            VStack(spacing: 6) {
                Text(family.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("Film at 45° · whole body in frame")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var cueCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(live.phase.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Theme.accent)
            Text(live.cue)
                .font(.headline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var controls: some View {
        HStack {
            if let onClose {
                Button {
                    camera.stop()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .disabled(camera.isRecording)
                .opacity(camera.isRecording ? 0.4 : 1)
            } else {
                Color.clear.frame(width: 54, height: 54)
            }

            Spacer()
            Button {
                camera.toggleRecording()
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                    RoundedRectangle(cornerRadius: camera.isRecording ? 6 : 33)
                        .fill(.red)
                        .frame(width: camera.isRecording ? 34 : 66, height: camera.isRecording ? 34 : 66)
                }
            }
            .disabled(!camera.isReady)
            .opacity(camera.isReady ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.15), value: camera.isRecording)
            Spacer()

            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .disabled(!camera.isReady || camera.isRecording)
            .opacity(camera.isRecording ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
