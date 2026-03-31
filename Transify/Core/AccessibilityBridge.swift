// Transify/Core/AccessibilityBridge.swift
import AppKit
import ApplicationServices

struct TextSelection {
    let text: String
    let isEditable: Bool
    let element: AXUIElement
    let range: CFRange
    let fullText: String
    var isClipboardFallback: Bool = false
}

class AccessibilityBridge {

    func readSelection() -> TextSelection? {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else { return nil }

        var selectedTextValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success,
              let selectedText = selectedTextValue as? String,
              !selectedText.isEmpty else { return nil }

        var rangeValue: AnyObject?
        var cfRange = CFRange(location: 0, length: 0)
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let rangeData = rangeValue {
            AXValueGetValue(rangeData as! AXValue, .cfRange, &cfRange)
        }

        var fullText = ""
        var isEditable = false
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success,
           settable.boolValue {
            isEditable = true
            var textValue: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue) == .success {
                fullText = (textValue as? String) ?? ""
            }
        }

        return TextSelection(text: selectedText, isEditable: isEditable, element: element, range: cfRange, fullText: fullText)
    }

    /// Fallback for apps that don't expose AX text (e.g. Electron-based apps like Feishu).
    /// Simulates Cmd+C, reads clipboard, and checks AX editability of the focused element.
    func readSelectionViaClipboard() async -> TextSelection? {
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        // Wait for clipboard to update
        try? await Task.sleep(nanoseconds: 200_000_000)

        guard pasteboard.changeCount != oldChangeCount,
              let text = pasteboard.string(forType: .string),
              !text.isEmpty else { return nil }

        // Check if the focused element is editable via AX (even if it doesn't expose text selection)
        let systemElement = AXUIElementCreateSystemWide()
        var focusedRaw: AnyObject?
        var isEditable = false
        var axElement = AXUIElementCreateSystemWide()
        if AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedRaw) == .success,
           let element = focusedRaw as! AXUIElement? {
            axElement = element
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success {
                isEditable = settable.boolValue
            }
        }

        return TextSelection(text: text, isEditable: isEditable,
                             element: axElement,
                             range: CFRange(location: 0, length: 0), fullText: "",
                             isClipboardFallback: true)
    }

    @discardableResult
    func replaceSelection(in selection: TextSelection, with newText: String) -> Bool {
        guard selection.isEditable else { return false }
        let nsRange = NSRange(location: selection.range.location, length: selection.range.length)
        guard let range = Range(nsRange, in: selection.fullText) else { return false }
        let newFullText = selection.fullText.replacingCharacters(in: range, with: newText) as CFString
        guard AXUIElementSetAttributeValue(selection.element, kAXValueAttribute as CFString, newFullText) == .success else { return false }
        let newLocation = selection.range.location + (newText as NSString).length
        var newRange = CFRange(location: newLocation, length: 0)
        if let rangeValue = AXValueCreate(.cfRange, &newRange) {
            AXUIElementSetAttributeValue(selection.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        }
        return true
    }

    static func hasPermission() -> Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
