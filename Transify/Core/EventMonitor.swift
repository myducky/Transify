// Transify/Core/EventMonitor.swift
import AppKit
import ApplicationServices

class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotkeyPressed: (() -> Void)?
    var onUndoPressed: (() -> Void)?

    private var hotkeyKeyCode: CGKeyCode
    private var hotkeyModifiers: CGEventFlags

    var pendingUndo = false

    init(keyCode: CGKeyCode = 17, modifiers: CGEventFlags = .maskAlternate) {
        self.hotkeyKeyCode = keyCode
        self.hotkeyModifiers = modifiers
    }

    func updateHotkey(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        self.hotkeyKeyCode = keyCode
        self.hotkeyModifiers = modifiers
    }

    func start() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passRetained(self).toOpaque()
        )
        guard let tap = eventTap else {
            print("EventMonitor: Failed to create event tap — check Accessibility permission")
            return
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift])

        if keyCode == hotkeyKeyCode && flags == hotkeyModifiers.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift]) {
            DispatchQueue.main.async { self.onHotkeyPressed?() }
            return nil
        }
        if pendingUndo && keyCode == 6 && flags == .maskCommand {
            DispatchQueue.main.async { self.onUndoPressed?() }
            pendingUndo = false
            return nil
        }
        return Unmanaged.passRetained(event)
    }
}
