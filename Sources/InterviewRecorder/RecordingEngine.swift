import AppKit
import AVFoundation
import CoreMedia
import ScreenCaptureKit

@available(macOS 15.0, *)
final class RecordingEngine: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
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
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var micWriterInput: AVAssetWriterInput?
    private var activeURL: URL?
    private var isWriterStarted = false
    private let writerQueue = DispatchQueue(label: "com.sachinkumar.InterviewRecorder.writerQueue")
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

            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1280,
                AVVideoHeightKey: 720,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 3_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoExpectedSourceFrameRateKey: 30,
                    AVVideoMaxKeyFrameIntervalKey: 30
                ]
            ]
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true

            let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            micInput.expectsMediaDataInRealTime = true

            if writer.canAdd(videoInput) { writer.add(videoInput) }
            if writer.canAdd(audioInput) { writer.add(audioInput) }
            if writer.canAdd(micInput) { writer.add(micInput) }

            self.assetWriter = writer
            self.videoWriterInput = videoInput
            self.audioWriterInput = audioInput
            self.micWriterInput = micInput
            self.isWriterStarted = false
            self.activeURL = outputURL

            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: writerQueue)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: writerQueue)
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: writerQueue)

            self.stream = stream
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
            self.stream = nil
            DiagnosticLog.write("SCStream stopCapture returned successfully")
            await finishWriter()
            state = .idle
        } catch {
            DiagnosticLog.write("Stop failed: \(error.localizedDescription)")
            cleanup(removeIncompleteFile: false)
            state = .failed("Could not stop cleanly: \(error.localizedDescription)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        writerQueue.async { [weak self] in
            guard let self, let writer = self.assetWriter else { return }

            if !self.isWriterStarted {
                guard outputType == .screen, sampleBuffer.imageBuffer != nil else { return }
                let pts = sampleBuffer.presentationTimeStamp
                guard pts.isValid && !pts.isIndefinite else { return }

                writer.startWriting()
                writer.startSession(atSourceTime: pts)
                self.isWriterStarted = true
                self.startWatchdog?.cancel()
                self.startWatchdog = nil

                DiagnosticLog.write("AVAssetWriter started session at source time \(pts.seconds)s")
                DispatchQueue.main.async { [weak self] in
                    if let url = self?.activeURL {
                        self?.state = .recording(url)
                    }
                }
            }

            guard self.isWriterStarted, writer.status == .writing else { return }

            switch outputType {
            case .screen:
                if let input = self.videoWriterInput, input.isReadyForMoreMediaData, sampleBuffer.imageBuffer != nil {
                    input.append(sampleBuffer)
                }
            case .audio:
                if let input = self.audioWriterInput, input.isReadyForMoreMediaData {
                    input.append(sampleBuffer)
                }
            case .microphone:
                if let input = self.micWriterInput, input.isReadyForMoreMediaData {
                    input.append(sampleBuffer)
                }
            @unknown default:
                break
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard state.isBusy else { return }
        DiagnosticLog.write("Capture stream stopped with error: \(error.localizedDescription)")
        cleanup(removeIncompleteFile: true)
        state = .failed("Screen capture stopped: \(error.localizedDescription)")
    }

    private func finishWriter() async {
        await withCheckedContinuation { continuation in
            writerQueue.async { [weak self] in
                guard let self, let writer = self.assetWriter else {
                    continuation.resume()
                    return
                }

                self.videoWriterInput?.markAsFinished()
                self.audioWriterInput?.markAsFinished()
                self.micWriterInput?.markAsFinished()

                if writer.status == .writing {
                    writer.finishWriting {
                        DiagnosticLog.write("AVAssetWriter finished writing")
                        self.assetWriter = nil
                        self.videoWriterInput = nil
                        self.audioWriterInput = nil
                        self.micWriterInput = nil
                        continuation.resume()
                    }
                } else {
                    DiagnosticLog.write("AVAssetWriter was not writing (status: \(writer.status.rawValue))")
                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                    self.micWriterInput = nil
                    continuation.resume()
                }
            }
        }
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
            self.state = .failed("The screen stream opened, but video samples were not received within five seconds. See ~/Library/Logs/InterviewRecorder/recorder.log for details.")
        }
    }

    private func preferredDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        let mainID = CGMainDisplayID()
        return displays.first(where: { $0.displayID == mainID }) ?? displays.first
    }

    private func makeOutputURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let folder = appSupport.appendingPathComponent("screensessions", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(RecordingHelpers.fileName())
    }

    private func cleanup(removeIncompleteFile: Bool) {
        startWatchdog?.cancel()
        startWatchdog = nil
        let url = activeURL
        stream = nil
        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        micWriterInput = nil
        isWriterStarted = false
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
