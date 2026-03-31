// TransifyTests/SettingsStoreTests.swift
import XCTest
@testable import Transify

final class SettingsStoreTests: XCTestCase {
    var store: SettingsStore!

    override func setUp() {
        super.setUp()
        store = SettingsStore(suiteName: "test-\(UUID().uuidString)")
    }

    func test_defaultModel_isGeminiFlash() {
        XCTAssertEqual(store.selectedModel, LLMModel.geminiFlash)
    }

    func test_defaultHotkey_isOptionT() {
        XCTAssertEqual(store.hotkeyKeyCode, 17)       // T key
        XCTAssertEqual(store.hotkeyModifiers, 524288) // CGEventFlags.maskAlternate (0x80000)
    }
}
