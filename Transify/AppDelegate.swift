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
        checkAccessibilityPermission()
        eventMonitor.onHotkeyPressed = { [weak self] in self?.handleTranslationTrigger() }
        eventMonitor.onUndoPressed   = { [weak self] in self?.handleUndo() }
        eventMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor.stop()
    }

    // MARK: - Translation

    private func handleTranslationTrigger() {
        guard let selection = accessibilityBridge.readSelection() else { return }

        Task {
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
                        popupController.show(text: translated, near: mouseLocation)
                    }
                }
            } catch LLMError.noApiKey(let provider) {
                await MainActor.run { showNoApiKeyAlert(provider: provider) }
            } catch {
                print("Translation error: \(error.localizedDescription)")
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

    // MARK: - Permission

    private func checkAccessibilityPermission() {
        if !AccessibilityBridge.hasPermission() {
            AccessibilityBridge.requestPermission()
        }
    }

    private func showNoApiKeyAlert(provider: LLMProvider) {
        let alert = NSAlert()
        alert.messageText = "需要 API Key"
        alert.informativeText = "请在设置中填写 \(provider.displayName) 的 API Key。"
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
