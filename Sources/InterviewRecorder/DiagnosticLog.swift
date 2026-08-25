import Foundation

enum DiagnosticLog {
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/InterviewRecorder/recorder.log")

    static func write(_ message: String) {
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: Date())) \(message)\n"
        NSLog("[InterviewRecorder] %@", message)

        let folder = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try Data(line.utf8).write(to: fileURL, options: .atomic)
            } else if let handle = try? FileHandle(forWritingTo: fileURL) {
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            }
        } catch {
            NSLog("[InterviewRecorder] Could not write diagnostic log: %@", error.localizedDescription)
        }
    }
}
