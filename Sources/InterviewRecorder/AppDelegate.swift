import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = RecordingEngine()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let permissionsWindow = PermissionsWindowController()
    private var hotKey: GlobalHotKey?
    private var startedAt: Date?
    private var currentState: RecordingEngine.State = .idle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem.button?.image = NSImage(systemSymbolName: "cloud", accessibilityDescription: "Interview Recorder")
        statusItem.button?.image?.isTemplate = true
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self

        engine.onStateChange = { [weak self] state in
            self?.handleState(state)
        }

        hotKey = GlobalHotKey { [weak self] in self?.toggleRecording() }
        hotKey?.register()

        DiagnosticLog.write(
            "Installed-app authorization: screen=\(PermissionManager.hasScreenRecording ? "granted" : "missing") " +
            "microphone=\(PermissionManager.hasMicrophone ? "granted" : "missing")"
        )
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if currentState.isBusy {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Stop recording before quitting"
            alert.informativeText = "Use ⌥⌘R or choose Stop Recording so the video file can be finalized safely."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    @objc private func toggleRecording() {
        switch currentState {
        case .recording:
            Task { await engine.stop() }
        case .idle, .failed:
            startRecording()
        case .starting, .stopping:
            NSSound.beep()
        }
    }

    private func startRecording() {
        guard PermissionManager.hasScreenRecording, PermissionManager.hasMicrophone else {
            permissionsWindow.showWindow(nil)
            return
        }

        NSSound.beep()
        Task { await engine.start() }
    }

    private func handleState(_ state: RecordingEngine.State) {
        currentState = state
        switch state {
        case .idle:
            startedAt = nil
            setStatusIcon(recording: false)
            NSSound.beep()
        case .starting:
            setStatusIcon(recording: false)
            statusItem.button?.toolTip = "Starting recording…"
        case .recording:
            startedAt = Date()
            setStatusIcon(recording: true)
        case .stopping:
            statusItem.button?.toolTip = "Finalizing recording…"
        case let .failed(message):
            startedAt = nil
            setStatusIcon(recording: false)
            showError(message)
        }
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let weatherItem = NSMenuItem(title: "Weather Data", action: nil, keyEquivalent: "")
        weatherItem.isEnabled = false
        menu.addItem(weatherItem)

        let isRecording: Bool
        if case .recording = currentState {
            isRecording = true
        } else {
            isRecording = false
        }

        let startItem = NSMenuItem(title: "Start", action: #selector(startAction), keyEquivalent: "")
        startItem.target = self
        startItem.isEnabled = !currentState.isBusy
        menu.addItem(startItem)

        let stopItem = NSMenuItem(title: "Stop", action: #selector(stopAction), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = isRecording
        menu.addItem(stopItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func startAction() {
        if !currentState.isBusy {
            startRecording()
        }
    }

    @objc private func stopAction() {
        if case .recording = currentState {
            Task { await engine.stop() }
        }
    }

    private func setStatusIcon(recording: Bool) {
        let symbol = recording ? "cloud.bolt.fill" : "cloud"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: recording ? "Recording in progress" : "Interview Recorder")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.contentTintColor = recording ? .systemRed : nil
        statusItem.button?.toolTip = recording ? "Recording — ⌥⌘R to stop" : "Interview Recorder — ⌥⌘R to start"
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Interview Recorder"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
