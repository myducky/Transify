// TransifyTests/TranslationCoreTests.swift
import XCTest
import Security
@testable import Transify

class MockLLMClient: LLMClient {
    var translatedResult: String = "translated"
    var shouldThrow = false

    override func translate(text: String, to language: String, model: LLMModel, apiKey: String) async throws -> String {
        if shouldThrow { throw LLMError.invalidResponse }
        return translatedResult
    }
}

final class TranslationCoreTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clean up keychain entries to prevent test pollution
        for provider in ["google", "anthropic", "openai"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "transify-\(provider)"
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    func test_translate_returnsResult() async throws {
        let mock = MockLLMClient()
        mock.translatedResult = "你好"
        let store = SettingsStore(suiteName: "test-core-\(UUID().uuidString)")
        store.setApiKey("fake-key", for: .google)
        let core = TranslationCore(llmClient: mock, settings: store)
        let result = try await core.translate(text: "Hello")
        XCTAssertEqual(result, "你好")
    }

    func test_translate_throwsWhenNoApiKey() async {
        let mock = MockLLMClient()
        let store = SettingsStore(suiteName: "test-core-empty-\(UUID().uuidString)")
        let core = TranslationCore(llmClient: mock, settings: store)
        do {
            _ = try await core.translate(text: "Hello")
            XCTFail("Expected error")
        } catch LLMError.noApiKey {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
