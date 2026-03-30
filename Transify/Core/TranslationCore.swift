// Transify/Core/TranslationCore.swift
import Foundation

class TranslationCore {
    private let llmClient: LLMClient
    private let settings: SettingsStore

    init(llmClient: LLMClient = LLMClient(), settings: SettingsStore) {
        self.llmClient = llmClient
        self.settings = settings
    }

    func translate(text: String) async throws -> String {
        let model = settings.selectedModel
        guard let apiKey = settings.apiKey(for: model.provider), !apiKey.isEmpty else {
            throw LLMError.noApiKey(model.provider)
        }
        return try await llmClient.translate(text: text, to: settings.targetLanguage, model: model, apiKey: apiKey)
    }
}
