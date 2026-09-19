import CoreGraphics
import Foundation

/// A size-first profile tuned for meeting and interview screen recordings.
///
/// The bit-rate budget is deliberately centralized so a future resolution or
/// codec change cannot accidentally return the recorder to 100 MB/5-minute
/// files without failing the size-budget tests.
enum RecordingCompressionProfile {
    static let codecName = "HEVC/H.265"
    static let width = 1_280
    static let height = 720
    static let framesPerSecond = 15

    // Screen content changes much less than camera video. HEVC can preserve
    // readable 720p meeting content at this rate while remaining very small.
    static let videoBitRate = 500_000

    // System sound and microphone remain separate mono tracks. These rates are
    // intended for speech; music fidelity is not the goal of this recorder.
    static let systemAudioBitRate = 40_000
    static let microphoneAudioBitRate = 32_000
    static let audioSampleRate = 32_000
    static let audioChannelCount = 1

    static let keyFrameIntervalSeconds = 10
    static let estimatedContainerOverhead = 1.02

    static var totalBitRate: Int {
        videoBitRate + systemAudioBitRate + microphoneAudioBitRate
    }

    static func estimatedFileSizeBytes(seconds: TimeInterval) -> Int64 {
        guard seconds > 0 else { return 0 }
        let mediaBytes = (Double(totalBitRate) * seconds) / 8
        return Int64(ceil(mediaBytes * estimatedContainerOverhead))
    }

    static func estimatedFileSizeMegabytes(seconds: TimeInterval) -> Double {
        Double(estimatedFileSizeBytes(seconds: seconds)) / 1_000_000
    }
}

enum RecordingHelpers {
    static let canvasSize = CGSize(
        width: RecordingCompressionProfile.width,
        height: RecordingCompressionProfile.height
    )

    static func aspectFit(source: CGSize, inside canvas: CGSize = canvasSize) -> CGRect {
        guard source.width > 0, source.height > 0, canvas.width > 0, canvas.height > 0 else {
            return CGRect(origin: .zero, size: canvas)
        }

        let scale = min(canvas.width / source.width, canvas.height / source.height)
        let width = floor(source.width * scale / 2) * 2
        let height = floor(source.height * scale / 2) * 2
        return CGRect(
            x: floor((canvas.width - width) / 2),
            y: floor((canvas.height - height) / 2),
            width: width,
            height: height
        )
    }

    static func fileName(date: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "screensession-\(formatter.string(from: date)).mp4"
    }

    static func elapsedText(seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds))
        let hours = whole / 3_600
        let minutes = (whole % 3_600) / 60
        let seconds = whole % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
