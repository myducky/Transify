// TransifyTests/TranslationUndoManagerTests.swift
import XCTest
import ApplicationServices
@testable import Transify

final class TranslationUndoManagerTests: XCTestCase {

    func test_initialState_hasNoEntry() {
        let manager = TranslationUndoManager()
        XCTAssertFalse(manager.canUndo)
    }

    func test_afterRecord_canUndo() {
        let manager = TranslationUndoManager()
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        manager.record(originalText: "hello", range: CFRange(location: 0, length: 5), element: element, fullText: "hello world")
        XCTAssertTrue(manager.canUndo)
    }

    func test_afterConsume_cannotUndoAgain() {
        let manager = TranslationUndoManager()
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        manager.record(originalText: "hello", range: CFRange(location: 0, length: 5), element: element, fullText: "hello world")
        _ = manager.consumeEntry()
        XCTAssertFalse(manager.canUndo)
    }

    func test_consumeEntry_returnsRecordedValues() {
        let manager = TranslationUndoManager()
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        manager.record(originalText: "hello", range: CFRange(location: 2, length: 5), element: element, fullText: "xx hello yy")
        let entry = manager.consumeEntry()
        XCTAssertEqual(entry?.originalText, "hello")
        XCTAssertEqual(entry?.range.location, 2)
        XCTAssertEqual(entry?.fullText, "xx hello yy")
    }
}
