import AppKit

final class RecordingIndicatorController {
    private let panel: NSPanel
    private let timeLabel: NSTextField

    init() {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 18
        background.layer?.masksToBounds = true

        let dot = NSTextField(labelWithString: "●")
        dot.textColor = .systemRed
        dot.font = .systemFont(ofSize: 21, weight: .bold)
        dot.setContentHuggingPriority(.required, for: .horizontal)

        let recordingLabel = NSTextField(labelWithString: "RECORDING")
        recordingLabel.textColor = .white
        recordingLabel.font = .systemFont(ofSize: 12, weight: .bold)

        timeLabel = NSTextField(labelWithString: "00:00")
        timeLabel.textColor = .white
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        let stack = NSStackView(views: [dot, recordingLabel, timeLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 13),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -13),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -8)
        ])

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 190, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = background
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    func update(seconds: TimeInterval) {
        timeLabel.stringValue = RecordingHelpers.elapsedText(seconds: seconds)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.maxX - size.width - 18,
            y: frame.maxY - size.height - 18
        ))
    }
}
