// Transify/Core/LLMClient.swift
import Foundation

enum LLMError: Error, LocalizedError {
    case noApiKey(LLMProvider)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey(let p): return "No API key configured for \(p.displayName)"
        case .invalidResponse: return "Invalid response from LLM"
        case .apiError(let msg): return msg
        }
    }
}

class LLMClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(text: String, to language: String, model: LLMModel, apiKey: String) async throws -> String {
        let request = try buildRequest(model: model, apiKey: apiKey, text: text, targetLanguage: language)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.apiError(body)
        }
        return try parseResponse(data: data, model: model)
    }

    func buildRequest(model: LLMModel, apiKey: String, text: String, targetLanguage: String) throws -> URLRequest {
        let prompt = "You are a professional translator. Translate the following text to \(targetLanguage). Output ONLY the translated text, no explanations, no quotes.\n\nText: \(text)"
        switch model.provider {
        case .google:    return try buildGeminiRequest(model: model, apiKey: apiKey, prompt: prompt)
        case .openai:    return try buildOpenAIRequest(model: model, apiKey: apiKey, prompt: prompt)
        case .anthropic: return try buildAnthropicRequest(model: model, apiKey: apiKey, prompt: prompt)
        }
    }

    func parseResponse(data: Data, model: LLMModel) throws -> String {
        switch model.provider {
        case .google:    return try parseGeminiResponse(data: data)
        case .openai:    return try parseOpenAIResponse(data: data)
        case .anthropic: return try parseAnthropicResponse(data: data)
        }
    }

    private func buildGeminiRequest(model: LLMModel, apiKey: String, prompt: String) throws -> URLRequest {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["contents": [["parts": [["text": prompt]]]]])
        return req
    }

    private func buildOpenAIRequest(model: LLMModel, apiKey: String, prompt: String) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model.rawValue,
            "messages": [["role": "user", "content": prompt]]
        ])
        return req
    }

    private func buildAnthropicRequest(model: LLMModel, apiKey: String, prompt: String) throws -> URLRequest {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model.rawValue,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ])
        return req
    }

    private func parseGeminiResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { throw LLMError.invalidResponse }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseOpenAIResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else { throw LLMError.invalidResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseAnthropicResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else { throw LLMError.invalidResponse }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
