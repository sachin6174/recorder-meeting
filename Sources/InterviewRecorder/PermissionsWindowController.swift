import AVFoundation
import AppKit

final class PermissionsWindowController: NSWindowController {
    private let screenStatus = NSTextField(labelWithString: "")
    private let microphoneStatus = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Interview Recorder Permissions"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        super.init(window: window)
        window.contentView = makeContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        refresh()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    private func makeContentView() -> NSView {
        let title = NSTextField(labelWithString: "Two permissions are required")
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let explanation = NSTextField(wrappingLabelWithString:
            "macOS protects screen and microphone access. Approve both system prompts, then reopen the app if macOS asks you to. The app cannot approve these privacy choices for you."
        )
        explanation.textColor = .secondaryLabelColor

        let screenRow = permissionRow(
            title: "Screen & System Audio Recording",
            status: screenStatus,
            requestTitle: "Request Access",
            requestAction: #selector(requestScreen),
            settingsAction: #selector(openScreenSettings)
        )

        let micRow = permissionRow(
            title: "Microphone",
            status: microphoneStatus,
            requestTitle: "Request Access",
            requestAction: #selector(requestMicrophone),
            settingsAction: #selector(openMicrophoneSettings)
        )

        let note = NSTextField(wrappingLabelWithString:
            "Recording is allowed only after every participant has explicitly agreed. The app displays a persistent recording indicator and plays a start/stop sound."
        )
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [title, explanation, screenRow, micRow, note])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -22)
        ])
        return content
    }

    private func permissionRow(
        title: String,
        status: NSTextField,
        requestTitle: String,
        requestAction: Selector,
        settingsAction: Selector
    ) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        status.font = .systemFont(ofSize: 12, weight: .semibold)

        let labels = NSStackView(views: [label, status])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3

        let request = NSButton(title: requestTitle, target: self, action: requestAction)
        let settings = NSButton(title: "Open Settings", target: self, action: settingsAction)
        let actions = NSStackView(views: [request, settings])
        actions.orientation = .horizontal
        actions.spacing = 8

        let row = NSStackView(views: [labels, NSView(), actions])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    func refresh() {
        screenStatus.stringValue = PermissionManager.hasScreenRecording ? "Granted" : "Not granted"
        screenStatus.textColor = PermissionManager.hasScreenRecording ? .systemGreen : .systemOrange

        switch PermissionManager.microphoneStatus {
        case .authorized:
            microphoneStatus.stringValue = "Granted"
            microphoneStatus.textColor = .systemGreen
        case .denied, .restricted:
            microphoneStatus.stringValue = "Denied — open System Settings"
            microphoneStatus.textColor = .systemRed
        case .notDetermined:
            microphoneStatus.stringValue = "Not requested"
            microphoneStatus.textColor = .systemOrange
        @unknown default:
            microphoneStatus.stringValue = "Unknown"
            microphoneStatus.textColor = .systemOrange
        }
    }

    @objc private func requestScreen() {
        _ = PermissionManager.requestScreenRecording()
        refresh()
    }

    @objc private func requestMicrophone() {
        PermissionManager.requestMicrophone { [weak self] _ in self?.refresh() }
    }

    @objc private func openScreenSettings() {
        PermissionManager.openScreenRecordingSettings()
    }

    @objc private func openMicrophoneSettings() {
        PermissionManager.openMicrophoneSettings()
    }
}
