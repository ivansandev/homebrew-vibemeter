import Foundation

struct CLILocator: Sendable {
    func find(_ name: String, overridePath: String?) -> URL? {
        let fileManager = FileManager.default
        if let overridePath, !overridePath.isEmpty,
           fileManager.isExecutableFile(atPath: overridePath) {
            return URL(fileURLWithPath: overridePath)
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        var candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(home)/.local/bin/\(name)",
            "/usr/bin/\(name)"
        ]

        let nvmRoot = "\(home)/.nvm/versions/node"
        if let versions = try? fileManager.contentsOfDirectory(atPath: nvmRoot) {
            candidates.append(contentsOf: versions.sorted().reversed().map { "\(nvmRoot)/\($0)/bin/\(name)" })
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/\(name)" })
        }

        return candidates.first(where: fileManager.isExecutableFile(atPath:)).map { URL(fileURLWithPath: $0) }
    }
}
