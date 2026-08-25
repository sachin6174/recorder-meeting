import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = RecordingEngine()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let permissionsWindow = PermissionsWindowController()
    private var hotKey: GlobalHotKey?
    private var startedAt: Date?
    private var lastSavedURL: URL?
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
            beginConsentFlow()
        case .starting, .stopping:
            NSSound.beep()
        }
    }

    private func beginConsentFlow() {
        guard PermissionManager.hasScreenRecording, PermissionManager.hasMicrophone else {
            permissionsWindow.showWindow(nil)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Confirm everyone has agreed"
        alert.informativeText = "Before recording, tell every interview participant that the screen, meeting audio, and microphone will be recorded, and obtain their explicit agreement. Recording without consent may violate law, company policy, or platform rules."
        alert.addButton(withTitle: "I Have Consent — Start Recording")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
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
            if let lastSavedURL {
                showSavedAlert(url: lastSavedURL)
                self.lastSavedURL = nil
            }
        case .starting:
            setStatusIcon(recording: false)
            statusItem.button?.toolTip = "Starting recording…"
        case let .recording(url):
            lastSavedURL = url
            startedAt = Date()
            setStatusIcon(recording: true)
        case .stopping:
            statusItem.button?.toolTip = "Finalizing recording…"
        case let .failed(message):
            startedAt = nil
            setStatusIcon(recording: false)
            lastSavedURL = nil
            showError(message)
        }
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let isRecording: Bool
        let commandTitle: String
        switch currentState {
        case .recording:
            isRecording = true
            commandTitle = "Stop Recording"
        case .starting:
            isRecording = false
            commandTitle = "Starting…"
        case .stopping:
            isRecording = true
            commandTitle = "Finalizing…"
        case .idle, .failed:
            isRecording = false
            commandTitle = "Start Recording"
        }

        let toggle = NSMenuItem(title: commandTitle, action: #selector(toggleRecording), keyEquivalent: "r")
        toggle.keyEquivalentModifierMask = [.command, .option]
        toggle.target = self
        switch currentState {
        case .starting, .stopping:
            toggle.isEnabled = false
        case .idle, .recording, .failed:
            toggle.isEnabled = true
        }
        menu.addItem(toggle)

        if isRecording, let startedAt {
            let elapsed = NSMenuItem(title: "Recording · \(RecordingHelpers.elapsedText(seconds: Date().timeIntervalSince(startedAt)))", action: nil, keyEquivalent: "")
            elapsed.isEnabled = false
            menu.addItem(elapsed)
        }

        menu.addItem(.separator())
        menu.addItem(item("Permissions…", #selector(showPermissions)))
        menu.addItem(item("Open Recordings Folder", #selector(openRecordings)))

        let login = item("Start at Login", #selector(toggleStartAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quality = NSMenuItem(title: "720p · 30 fps · H.264 · MP4", action: nil, keyEquivalent: "")
        quality.isEnabled = false
        menu.addItem(quality)
        let consent = NSMenuItem(title: "Record only with participant consent", action: nil, keyEquivalent: "")
        consent.isEnabled = false
        menu.addItem(consent)

        menu.addItem(.separator())
        menu.addItem(item("About Interview Recorder", #selector(showAbout)))
        menu.addItem(item("Quit", #selector(quit), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func setStatusIcon(recording: Bool) {
        let symbol = recording ? "cloud.bolt.fill" : "cloud"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: recording ? "Recording in progress" : "Interview Recorder")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.contentTintColor = recording ? .systemRed : nil
        statusItem.button?.toolTip = recording ? "Recording — ⌥⌘R to stop" : "Interview Recorder — ⌥⌘R to start"
    }

    @objc private func showPermissions() {
        permissionsWindow.showWindow(nil)
    }

    @objc private func openRecordings() {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        let folder = movies.appendingPathComponent("Interview Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    @objc private func toggleStartAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError("Could not change the login setting: \(error.localizedDescription)")
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Interview Recorder"
        alert.informativeText = "Consent-first 720p screen, system-audio, and microphone recording.\n\nShortcut: ⌥⌘R\nFiles: Movies/Interview Recordings"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showSavedAlert(url: URL) {
        let alert = NSAlert()
        alert.messageText = "Recording saved"
        alert.informativeText = url.path
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
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
