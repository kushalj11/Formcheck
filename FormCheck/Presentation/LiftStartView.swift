import PhotosUI
import SwiftUI

struct LiftStartView: View {
    let family: LiftFamily
    @AppStorage("defaultLift") private var defaultLift: LiftType = .barbellSquat
    @State private var recording = false

    private var lift: LiftType {
        family.variants.contains(defaultLift) ? defaultLift : family.variants[0]
    }
    @State private var pickerItem: PhotosPickerItem?
    @State private var importing = false
    @State private var importError: String?
    @State private var imported: Recording?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if family.variants.count > 1 {
                    Picker("Lift", selection: $defaultLift) {
                        ForEach(family.variants) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 12) {
                    Button {
                        recording = true
                    } label: {
                        Label("Record a Set", systemImage: "record.circle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        HStack {
                            if importing { ProgressView() }
                            Label("Import from Photos", systemImage: "photo.on.rectangle")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .disabled(importing)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("What's checked")
                    ForEach(lift.rules) { rule in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle").foregroundStyle(Theme.accent)
                            Text(rule.name).font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .card()

                Label(family.filmingTip, systemImage: "camera.viewfinder")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(family.displayName)
        .navigationDestination(item: $imported) { PlaybackView(recording: $0) }
        .fullScreenCover(isPresented: $recording) {
            RecordView(family: family, onClose: { recording = false })
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            importing = true
            Task {
                do {
                    if let video = try await item.loadTransferable(type: ImportedVideo.self) {
                        imported = RecordingStore.shared.file(video.url, as: family)
                    }
                } catch {
                    importError = error.localizedDescription
                }
                importing = false
                pickerItem = nil
            }
        }
        .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
    }
}
