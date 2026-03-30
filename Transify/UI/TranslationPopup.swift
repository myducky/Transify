// Transify/UI/TranslationPopup.swift
import SwiftUI
import AppKit

class TranslationPopupController {
    private var window: NSPanel?
    private var dismissTimer: Timer?

    func show(text: String, near point: NSPoint) {
        dismiss()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        let view = PopupContentView(text: text) { self.dismiss() }
        let hostingView = NSHostingView(rootView: view)
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(fittingSize)
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

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        window?.close()
        window = nil
    }
}

private struct PopupContentView: View {
    let text: String
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: 13))
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Spacer()
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
        .frame(width: 280)
        .onTapGesture { onDismiss() }
    }
}
