import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct Recording: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let date: Date
    let bytes: Int64
    var name: String { url.deletingPathExtension().lastPathComponent }
    var family: LiftFamily {
        LiftFamily.allCases.first { name.hasPrefix($0.filePrefix + "_") } ?? .squat
    }
    var title: String { date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()) }
}

@Observable
final class RecordingStore {
    static let shared = RecordingStore()

    private(set) var recordings: [Recording] = []

    static var directory: URL {
        let dir = URL.documentsDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func newRecordingURL(family: LiftFamily = .squat, ext: String = "mov") -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return directory.appending(path: "\(family.filePrefix)_\(f.string(from: .now))_\(UUID().uuidString.prefix(4)).\(ext)")
    }

    @discardableResult
    func file(_ url: URL, as family: LiftFamily) -> Recording {
        let current = recording(for: url)
        guard current.family != family else { return current }
        let dest = Self.newRecordingURL(family: family, ext: url.pathExtension.isEmpty ? "mov" : url.pathExtension)
        guard (try? FileManager.default.moveItem(at: url, to: dest)) != nil else { return current }
        return recording(for: dest)
    }

    func reload() {
        let keys: [URLResourceKey] = [.creationDateKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: keys)) ?? []
        recordings = urls
            .filter { ["mov", "mp4", "m4v"].contains($0.pathExtension.lowercased()) }
            .map { url in
                let v = try? url.resourceValues(forKeys: Set(keys))
                return Recording(url: url, date: v?.creationDate ?? .distantPast, bytes: Int64(v?.fileSize ?? 0))
            }
            .sorted { $0.date > $1.date }
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.url)
        reload()
    }

    func recording(for url: URL) -> Recording {
        reload()
        return recordings.first { $0.url.lastPathComponent == url.lastPathComponent }
            ?? Recording(url: url, date: .now, bytes: 0)
    }
}

struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = RecordingStore.newRecordingURL(ext: ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return ImportedVideo(url: dest)
        }
    }
}
