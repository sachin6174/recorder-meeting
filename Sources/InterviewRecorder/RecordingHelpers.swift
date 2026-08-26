import CoreGraphics
import Foundation

enum RecordingHelpers {
    static let canvasSize = CGSize(width: 1280, height: 720)

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
