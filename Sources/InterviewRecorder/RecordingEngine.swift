import AppKit
import AVFoundation
import CoreMedia
import ScreenCaptureKit

@available(macOS 15.0, *)
final class RecordingEngine: NSObject, SCStreamDelegate, SCRecordingOutputDelegate {
    enum State: Equatable {
        case idle
        case starting
        case recording(URL)
        case stopping(URL)
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .starting, .recording, .stopping: true
            case .idle, .failed: false
            }
        }
    }

    private(set) var state: State = .idle {
        didSet { DispatchQueue.main.async { [weak self] in self?.onStateChange?(self?.state ?? .idle) } }
    }

    var onStateChange: ((State) -> Void)?
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var activeURL: URL?
    private var startWatchdog: Task<Void, Never>?

    func start() async {
        guard !state.isBusy else { return }
        DiagnosticLog.write("Start requested")
        state = .starting

        do {
            let outputURL = try makeOutputURL()
            DiagnosticLog.write("Output prepared: \(outputURL.path)")
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            DiagnosticLog.write("Shareable content loaded: \(content.displays.count) display(s)")
            guard let display = preferredDisplay(from: content.displays) else {
                throw RecorderError.noDisplay
            }

            let ownBundleID = Bundle.main.bundleIdentifier
            let excludedApps = content.applications.filter { $0.bundleIdentifier == ownBundleID }
            let filter = SCContentFilter(
                display: display,
                excludingApplications: excludedApps,
                exceptingWindows: []
            )

            let configuration = SCStreamConfiguration()
            configuration.width = 1_280
            configuration.height = 720
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.queueDepth = 6
            configuration.showsCursor = true
            configuration.showMouseClicks = true
            configuration.sourceRect = CGRect(x: 0, y: 0, width: display.width, height: display.height)
            configuration.destinationRect = RecordingHelpers.aspectFit(
                source: CGSize(width: display.width, height: display.height)
            )
            configuration.captureResolution = .nominal
            configuration.captureDynamicRange = .SDR

            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            configuration.channelCount = 2
            configuration.captureMicrophone = true

            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            let outputConfiguration = SCRecordingOutputConfiguration()
            outputConfiguration.outputURL = outputURL
            outputConfiguration.outputFileType = .mp4
            // H.264 is ScreenCaptureKit's documented recording-output path and is
            // hardware accelerated on supported Macs. At 720p it remains compact
            // while avoiding codec-negotiation failures seen with some HEVC setups.
            outputConfiguration.videoCodecType = .h264
            DiagnosticLog.write("Recording output configured: H.264 / MP4")

            let output = SCRecordingOutput(configuration: outputConfiguration, delegate: self)
            try stream.addRecordingOutput(output)

            self.stream = stream
            self.recordingOutput = output
            self.activeURL = outputURL
            try await stream.startCapture()
            DiagnosticLog.write("SCStream startCapture returned successfully")
            scheduleStartWatchdog()
        } catch {
            DiagnosticLog.write("Start failed: \(error.localizedDescription)")
            cleanup(removeIncompleteFile: true)
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard case let .recording(url) = state, let stream else { return }
        state = .stopping(url)

        do {
            DiagnosticLog.write("Stop requested")
            try await stream.stopCapture()
            DiagnosticLog.write("SCStream stopCapture returned successfully")
            // SCRecordingOutputDelegate changes the state after the movie is finalized.
        } catch {
            DiagnosticLog.write("Stop failed: \(error.localizedDescription)")
            cleanup(removeIncompleteFile: false)
            state = .failed("Could not stop cleanly: \(error.localizedDescription)")
        }
    }

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        guard let url = activeURL else { return }
        startWatchdog?.cancel()
        startWatchdog = nil
        DiagnosticLog.write("Recording output started")
        state = .recording(url)
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        DiagnosticLog.write("Recording output finished")
        cleanup(removeIncompleteFile: false)
        state = .idle
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        DiagnosticLog.write("Recording output failed: \(error.localizedDescription)")
        cleanup(removeIncompleteFile: true)
        state = .failed("Recording failed: \(error.localizedDescription)")
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard state.isBusy else { return }
        DiagnosticLog.write("Capture stream stopped with error: \(error.localizedDescription)")
        cleanup(removeIncompleteFile: true)
        state = .failed("Screen capture stopped: \(error.localizedDescription)")
    }

    private func scheduleStartWatchdog() {
        startWatchdog?.cancel()
        startWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, let self, case .starting = self.state else { return }
            DiagnosticLog.write("Recording output did not start within five seconds")
            if let stream = self.stream {
                try? await stream.stopCapture()
            }
            self.cleanup(removeIncompleteFile: true)
            self.state = .failed("The screen stream opened, but the movie writer did not start within five seconds. See ~/Library/Logs/InterviewRecorder/recorder.log for details.")
        }
    }

    private func preferredDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        let mainID = CGMainDisplayID()
        return displays.first(where: { $0.displayID == mainID }) ?? displays.first
    }

    private func makeOutputURL() throws -> URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        let folder = movies.appendingPathComponent("Interview Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(RecordingHelpers.fileName())
    }

    private func cleanup(removeIncompleteFile: Bool) {
        startWatchdog?.cancel()
        startWatchdog = nil
        let url = activeURL
        stream = nil
        recordingOutput = nil
        activeURL = nil
        if removeIncompleteFile, let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    enum RecorderError: LocalizedError {
        case noDisplay

        var errorDescription: String? {
            switch self {
            case .noDisplay: "No display is available to record."
            }
        }
    }
}
