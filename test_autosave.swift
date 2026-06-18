import Foundation

// ponytail: one runnable self-check for Autosave's write/scan/remove/clear cycle.
// Build: swiftc Sources/Autosave.swift test_autosave.swift -o /tmp/t && /tmp/t

@main
struct AutosaveTest {
    static func tmpDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("txtplus-test-\(UUID().uuidString)")
    }

    static func main() {
        let dir = tmpDir()
        defer { Autosave.clearAll(in: dir) }

        // empty → no records, no crash
        assert(Autosave.scan(in: dir).isEmpty, "fresh dir should be empty")

        let a = Autosave.Record(id: UUID(), name: "a.txt", urlPath: "/tmp/a.txt", content: "hello 世界")
        let b = Autosave.Record(id: UUID(), name: "Untitled", urlPath: nil, content: "draft")
        Autosave.write(a, in: dir)
        Autosave.write(b, in: dir)

        let scanned = Autosave.scan(in: dir).sorted { $0.name < $1.name }
        assert(scanned.count == 2, "expected 2, got \(scanned.count)")
        assert(scanned.contains(a), "record a round-trips (incl. CJK + path)")
        assert(scanned.contains(b), "record b round-trips (nil path)")

        // overwrite by id
        let a2 = Autosave.Record(id: a.id, name: "a.txt", urlPath: a.urlPath, content: "changed")
        Autosave.write(a2, in: dir)
        assert(Autosave.scan(in: dir).count == 2, "overwrite same id, still 2 files")
        assert(Autosave.scan(in: dir).contains(a2), "content updated")

        // remove one
        Autosave.remove(a.id, in: dir)
        let after = Autosave.scan(in: dir)
        assert(after.count == 1 && after[0] == b, "remove drops only a")

        // clearAll
        Autosave.clearAll(in: dir)
        assert(Autosave.scan(in: dir).isEmpty, "clearAll empties dir")

        print("ok")
    }
}

