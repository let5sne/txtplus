import Foundation

/// Crash-recovery snapshots for dirty tabs.
///
/// Strategy: dirty tabs are written periodically to the autosave directory.
/// A clean quit (`applicationWillTerminate`) clears the whole directory, so any
/// files still present at launch mean the previous run crashed or was force-quit
/// — those get recovered. Foundation-only so it can be unit-tested in isolation.
enum Autosave {

    struct Record: Codable, Equatable {
        let id: UUID
        let name: String
        let urlPath: String?   // original file path, nil for never-saved tabs
        let content: String
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TxtPlus/autosave", isDirectory: true)
    }

    static func write(_ record: Record, in dir: URL = directory) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(record.id.uuidString).json")
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: file, options: .atomic)
    }

    static func remove(_ id: UUID, in dir: URL = directory) {
        let file = dir.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: file)
    }

    /// All snapshots currently on disk. Non-throwing: a corrupt file is skipped.
    static func scan(in dir: URL = directory) -> [Record] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Record.self, from: Data(contentsOf: $0)) }
    }

    static func clearAll(in dir: URL = directory) {
        try? FileManager.default.removeItem(at: dir)
    }
}
