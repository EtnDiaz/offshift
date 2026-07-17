import Foundation
import OSLog

/// A deliberately narrow local diagnostic trail for companion lifecycle bugs.
/// Entries are fixed event codes only: no app names, source text, screen
/// content, Focus names, device credentials, or user-entered settings are
/// recorded. The file is for local debugging and is never read by MCP, the
/// Worker, ChatGPT, or any network integration.
enum OffshiftDiagnostics {
    static let subsystem = "com.tixo.offshift.companion"
    private static let logger = Logger(subsystem: subsystem, category: "diagnostics")
    private static let queue = DispatchQueue(label: "com.tixo.offshift.companion.diagnostics")
    private static let maximumBytes = 256 * 1024
    private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || Bundle.main.bundlePath.hasSuffix(".xctest")
        || Bundle.allBundles.contains { $0.bundlePath.hasSuffix(".xctest") }
        || ProcessInfo.processInfo.arguments.contains { $0.contains(".xctest") }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/Offshift/diagnostics.log")
    }

    static func record(_ event: String) {
        guard !isRunningTests else { return }
        logger.notice("\(event, privacy: .public)")
        queue.async {
            append(event)
        }
    }

    private static func append(_ event: String) {
        let fileManager = FileManager.default
        let directory = logURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if let attributes = try? fileManager.attributesOfItem(atPath: logURL.path),
               (attributes[.size] as? NSNumber)?.intValue ?? 0 > maximumBytes {
                try Data().write(to: logURL, options: .atomic)
            }
            let timestamp = Int(Date.now.timeIntervalSince1970)
            let line = "\(timestamp) \(event)\n"
            if !fileManager.fileExists(atPath: logURL.path) {
                try line.data(using: .utf8)?.write(to: logURL, options: .atomic)
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logURL.path)
            } else if let handle = try? FileHandle(forWritingTo: logURL) {
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            }
        } catch {
            logger.error("diagnostic_file_write_failed")
        }
    }
}
