// TransifyTests/LLMClientTests.swift
import XCTest
@testable import Transify

final class LLMClientTests: XCTestCase {

    func test_gemini_buildRequest() throws {
        let client = LLMClient(session: .shared)
        let req = try client.buildRequest(model: .geminiFlash, apiKey: "test-key", text: "Hello", targetLanguage: "zh")
        XCTAssertTrue(req.url!.absoluteString.contains("gemini-2.0-flash"))
        XCTAssertTrue(req.url!.absoluteString.contains("test-key"))
        XCTAssertEqual(req.httpMethod, "POST")
        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        let contents = body["contents"] as! [[String: Any]]
        XCTAssertFalse(contents.isEmpty)
    }

    func test_openai_buildRequest() throws {
        let client = LLMClient(session: .shared)
        let req = try client.buildRequest(model: .gpt4oMini, apiKey: "test-key", text: "Hello", targetLanguage: "zh")
        XCTAssertTrue(req.url!.absoluteString.contains("openai.com"))
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
    }

    func test_anthropic_buildRequest() throws {
        let client = LLMClient(session: .shared)
        let req = try client.buildRequest(model: .claudeHaiku, apiKey: "test-key", text: "Hello", targetLanguage: "zh")
        XCTAssertTrue(req.url!.absoluteString.contains("anthropic.com"))
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "test-key")
    }

    func test_gemini_parseResponse() throws {
        let client = LLMClient(session: .shared)
        let json = """
        {"candidates":[{"content":{"parts":[{"text":"你好"}]}}]}
        """.data(using: .utf8)!
        let result = try client.parseResponse(data: json, model: .geminiFlash)
        XCTAssertEqual(result, "你好")
    }

    func test_openai_parseResponse() throws {
        let client = LLMClient(session: .shared)
        let json = """
        {"choices":[{"message":{"content":"你好"}}]}
        """.data(using: .utf8)!
        let result = try client.parseResponse(data: json, model: .gpt4oMini)
        XCTAssertEqual(result, "你好")
    }

    func test_anthropic_parseResponse() throws {
        let client = LLMClient(session: .shared)
        let json = """
        {"content":[{"type":"text","text":"你好"}]}
        """.data(using: .utf8)!
        let result = try client.parseResponse(data: json, model: .claudeHaiku)
        XCTAssertEqual(result, "你好")
    }
}
