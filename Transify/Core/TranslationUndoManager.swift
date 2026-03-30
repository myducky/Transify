// Transify/Core/TranslationUndoManager.swift
import Foundation
import ApplicationServices

struct UndoEntry {
    let originalText: String
    let range: CFRange
    let element: AXUIElement
    let fullText: String
    let translatedText: String
}

class TranslationUndoManager {
    private var entry: UndoEntry?

    var canUndo: Bool { entry != nil }

    func record(originalText: String, range: CFRange, element: AXUIElement, fullText: String, translatedText: String = "") {
        entry = UndoEntry(originalText: originalText, range: range, element: element, fullText: fullText, translatedText: translatedText)
    }

    func consumeEntry() -> UndoEntry? {
        defer { entry = nil }
        return entry
    }

    func clear() { entry = nil }
}
