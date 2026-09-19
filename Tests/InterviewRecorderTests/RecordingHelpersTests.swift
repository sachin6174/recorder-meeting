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
        #expect(RecordingHelpers.fileName(date: date, calendar: calendar) == "screensession-1970-01-01_00-00-00.mp4")
    }

    @Test func compressionProfileTargetsSmallMeetingFiles() {
        let fiveMinutes = RecordingCompressionProfile.estimatedFileSizeMegabytes(seconds: 5 * 60)
        let oneHour = RecordingCompressionProfile.estimatedFileSizeMegabytes(seconds: 60 * 60)

        #expect(fiveMinutes < 25)
        #expect(oneHour < 275)
    }

    @Test func compressionProfileRetainsReadableMeetingResolution() {
        #expect(RecordingCompressionProfile.codecName == "HEVC/H.265")
        #expect(RecordingCompressionProfile.width == 1_280)
        #expect(RecordingCompressionProfile.height == 720)
        #expect(RecordingCompressionProfile.framesPerSecond == 15)
        #expect(RecordingCompressionProfile.audioChannelCount == 1)
    }
}
