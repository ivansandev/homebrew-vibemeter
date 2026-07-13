import Foundation

struct SnapshotStore: Sendable {
    private var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appending(path: "VibeMeter", directoryHint: .isDirectory)
            .appending(path: "usage-snapshots.json")
    }

    func load() -> [ProviderID: ProviderSnapshot] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let values = try? JSONDecoder().decode([ProviderSnapshot].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: values.map { ($0.provider, $0) })
    }

    func save(_ snapshots: [ProviderSnapshot]) {
        guard let fileURL, let data = try? JSONEncoder().encode(snapshots) else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Cached usage is optional; provider refresh remains the source of truth.
        }
    }
}
