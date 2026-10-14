import AVFoundation
import PhotosUI
import SwiftUI

struct LibraryView: View {
    private let store = RecordingStore.shared
    @State private var pickerItem: PhotosPickerItem?
    @State private var importFamily: LiftFamily?
    @State private var importing = false
    @State private var importError: String?
    @State private var pendingDelete: Recording?

    var body: some View {
        NavigationStack {
            Group {
                if store.recordings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Library")
            .navigationDestination(for: Recording.self) { PlaybackView(recording: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if importing {
                        ProgressView()
                    } else {
                        importButton(label: Label("Import", systemImage: "plus"))
                    }
                }
            }
            .photosPicker(isPresented: Binding(get: { importFamily != nil && pickerItem == nil && !importing },
                                               set: { if !$0, pickerItem == nil { importFamily = nil } }),
                          selection: $pickerItem, matching: .videos)
            .onAppear { store.reload() }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                importing = true
                Task {
                    do {
                        if let video = try await item.loadTransferable(type: ImportedVideo.self) {
                            store.file(video.url, as: importFamily ?? .squat)
                        }
                    } catch {
                        importError = error.localizedDescription
                    }
                    importing = false
                    pickerItem = nil
                    importFamily = nil
                    store.reload()
                }
            }
            .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importError ?? "") }
            .confirmationDialog("Delete this recording?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete { withAnimation { store.delete(pendingDelete) } }
                }
            } message: { Text("This permanently removes the video from this device.") }
        }
    }

    private func importButton(label: some View) -> some View {
        Menu {
            ForEach(LiftFamily.allCases) { family in
                Button(family.displayName) { importFamily = family }
            }
        } label: { label }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    SectionLabel("\(store.recordings.count) recording\(store.recordings.count == 1 ? "" : "s")")
                    Spacer()
                }
                ForEach(store.recordings) { recording in
                    NavigationLink(value: recording) {
                        RecordingCard(recording: recording)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = recording }
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("No recordings yet").font(.title2.weight(.bold))
            Text("Record a set from a lift's page on Home, or import a clip from Photos. Film at a 45° angle with your whole body in frame.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            importButton(label:
                Label("Import from Photos", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            )
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecordingCard: View {
    let recording: Recording
    @State private var thumbnail: UIImage?
    @State private var duration: Double?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Rectangle().fill(Color(.tertiarySystemFill))
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                } else {
                    Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if let duration {
                    Text(String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title).font(.headline)
                Text(ByteCountFormatter.string(fromByteCount: recording.bytes, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(recording.family.displayName, systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .card(padding: 10)
        .contentShape(Rectangle())
        .task(id: recording.url) { await load() }
    }

    private func load() async {
        let asset = AVURLAsset(url: recording.url)
        duration = try? await asset.load(.duration).seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        if let (image, _) = try? await generator.image(at: CMTime(seconds: 0.3, preferredTimescale: 600)) {
            thumbnail = UIImage(cgImage: image)
        }
    }
}
