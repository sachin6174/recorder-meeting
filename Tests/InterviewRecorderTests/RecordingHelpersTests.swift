import CoreGraphics
import Foundation
import Testing
@testable import InterviewRecorder

struct RecordingHelpersTests {
    @Test func aspectFitsWideDisplayInside720pCanvas() {
        let rect = RecordingHelpers.aspectFit(source: CGSize(width: 2560, height: 1440))
        #expect(rect == CGRect(x: 0, y: 0, width: 1280, height: 720))
    }

    @Test func aspectFitsSixteenByTenWithSideBars() {
        let rect = RecordingHelpers.aspectFit(source: CGSize(width: 2560, height: 1600))
        #expect(rect == CGRect(x: 64, y: 0, width: 1152, height: 720))
    }

    @Test func elapsedTimeFormatting() {
        #expect(RecordingHelpers.elapsedText(seconds: 65) == "01:05")
        #expect(RecordingHelpers.elapsedText(seconds: 3_661) == "01:01:01")
    }

    @Test func stableFileName() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 0)
        #expect(RecordingHelpers.fileName(date: date, calendar: calendar) == "Interview-1970-01-01_00-00-00.mp4")
    }
}
