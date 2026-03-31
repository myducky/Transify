// Transify/UI/TranslationPopup.swift
import SwiftUI
import AppKit

class TranslationPopupController {
    private var window: NSPanel?
    private var dismissTimer: Timer?
    private var clickMonitor: Any?

    func show(text: String, near point: NSPoint, onReplace: (() -> Void)? = nil) {
        dismiss()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        let view = PopupContentView(text: text, onDismiss: { self.dismiss() }, onReplace: onReplace)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        let height = min(hostingView.fittingSize.height, 400)
        panel.setContentSize(CGSize(width: 300, height: height))
        panel.contentView = hostingView

        var origin = point
        origin.y -= panel.frame.height + 8
        if let screen = NSScreen.main {
            origin.x = max(screen.visibleFrame.minX, min(origin.x, screen.visibleFrame.maxX - panel.frame.width))
            origin.y = max(screen.visibleFrame.minY, origin.y)
        }
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
        self.window = panel

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.dismiss()
        }
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        if let monitor = clickMonitor { NSEvent.removeMonitor(monitor) }
        clickMonitor = nil
        window?.close()
        window = nil
    }
}

private struct PopupContentView: View {
    let text: String
    let onDismiss: () -> Void
    let onReplace: (() -> Void)?
    @State private var copied = false
    @State private var replaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            HStack {
                Spacer()
                if let onReplace {
                    Button(replaced ? "已替换 ✓" : "替换") {
                        onReplace()
                        replaced = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(replaced ? .green : nil)
                }
                Button(copied ? "已复制 ✓" : "复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        )
    }
}
