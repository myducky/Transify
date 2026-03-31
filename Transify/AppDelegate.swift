// Transify/AppDelegate.swift
import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    private let accessibilityBridge = AccessibilityBridge()
    private let undoManager = TranslationUndoManager()
    private let popupController = TranslationPopupController()
    private lazy var translationCore = TranslationCore(settings: settingsStore)
    private lazy var eventMonitor = EventMonitor(
        keyCode: CGKeyCode(settingsStore.hotkeyKeyCode),
        modifiers: CGEventFlags(rawValue: UInt64(settingsStore.hotkeyModifiers))
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        eventMonitor.onHotkeyPressed = { [weak self] in self?.handleTranslationTrigger() }
        eventMonitor.onUndoPressed   = { [weak self] in self?.handleUndo() }
        startEventMonitorWhenReady()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor.stop()
    }

    // MARK: - Permission

    private func startEventMonitorWhenReady() {
        if AXIsProcessTrusted() {
            eventMonitor.start()
        } else {
            AccessibilityBridge.requestPermission()
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if AXIsProcessTrusted() {
                    print("✅ Accessibility granted, starting EventMonitor")
                    self.eventMonitor.start()
                    timer.invalidate()
                    NotificationCenter.default.post(name: .accessibilityStatusChanged, object: nil)
                }
            }
        }
    }

    // MARK: - Translation

    private func handleTranslationTrigger() {
        Task {
            var selection = accessibilityBridge.readSelection()
            if selection == nil {
                selection = await accessibilityBridge.readSelectionViaClipboard()
            }
            guard let selection else { return }

            do {
                let translated = try await translationCore.translate(text: selection.text)

                await MainActor.run {
                    if selection.isEditable {
                        undoManager.record(
                            originalText: selection.text,
                            range: selection.range,
                            element: selection.element,
                            fullText: selection.fullText,
                            translatedText: translated
                        )
                        accessibilityBridge.replaceSelection(in: selection, with: translated)
                        eventMonitor.pendingUndo = true
                        NotificationCenter.default.post(
                            name: .translationDidComplete,
                            object: nil,
                            userInfo: ["text": "已翻译"]
                        )
                    } else {
                        let mouseLocation = NSEvent.mouseLocation
                        let frontApp = NSWorkspace.shared.frontmostApplication
                        let onReplace: (() -> Void)? = selection.isClipboardFallback ? {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(translated, forType: .string)
                            self.popupController.dismiss()
                            frontApp?.activate(options: .activateIgnoringOtherApps)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                let src = CGEventSource(stateID: .hidSystemState)
                                let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
                                let vUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
                                vDown?.flags = .maskCommand
                                vUp?.flags   = .maskCommand
                                vDown?.post(tap: .cghidEventTap)
                                vUp?.post(tap: .cghidEventTap)
                            }
                        } : nil
                        popupController.show(text: translated, near: mouseLocation, onReplace: onReplace)
                    }
                }
            } catch LLMError.noApiKey(let provider) {
                await MainActor.run { showNoApiKeyAlert(provider: provider) }
            } catch {
                await MainActor.run {
                    let mouseLocation = NSEvent.mouseLocation
                    popupController.show(text: "翻译失败：\(error.localizedDescription)", near: mouseLocation)
                }
            }
        }
    }

    private func handleUndo() {
        guard let entry = undoManager.consumeEntry() else { return }
        AXUIElementSetAttributeValue(entry.element, kAXValueAttribute as CFString, entry.fullText as CFString)
        var cfRange = entry.range
        if let rangeValue = AXValueCreate(.cfRange, &cfRange) {
            AXUIElementSetAttributeValue(entry.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        }
    }

    private func showNoApiKeyAlert(provider: LLMProvider) {
        let alert = NSAlert()
        alert.messageText = "需要 API Key"
        alert.informativeText = "请在设置中填写 \(provider.displayName) 的 API Key。"
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsWindowManager.shared.open(settingsStore: settingsStore)
        }
    }
}

extension Notification.Name {
    static let accessibilityStatusChanged = Notification.Name("accessibilityStatusChanged")
}
