// Transify/Settings/SettingsStore.swift
import Foundation
import Combine

enum LLMModel: String, CaseIterable, Identifiable {
    case geminiFlash  = "gemini-2.0-flash"
    case geminiPro    = "gemini-2.5-pro"
    case claudeHaiku  = "claude-haiku-4-5"
    case claudeSonnet = "claude-sonnet-4-6"
    case gpt4oMini    = "gpt-4o-mini"
    case gpt4o        = "gpt-4o"

    var id: String { rawValue }

    var provider: LLMProvider {
        switch self {
        case .geminiFlash, .geminiPro:       return .google
        case .claudeHaiku, .claudeSonnet:    return .anthropic
        case .gpt4oMini, .gpt4o:             return .openai
        }
    }

    var displayName: String {
        switch self {
        case .geminiFlash:  return "Gemini 2.0 Flash"
        case .geminiPro:    return "Gemini 2.5 Pro"
        case .claudeHaiku:  return "Claude Haiku"
        case .claudeSonnet: return "Claude Sonnet"
        case .gpt4oMini:    return "GPT-4o Mini"
        case .gpt4o:        return "GPT-4o"
        }
    }
}

enum LLMProvider: String {
    case google, anthropic, openai

    var displayName: String {
        switch self {
        case .google:    return "Google"
        case .anthropic: return "Anthropic"
        case .openai:    return "OpenAI"
        }
    }
}

class SettingsStore: ObservableObject {
    let suiteName: String
    private let defaults: UserDefaults

    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: "targetLanguage") }
    }
    @Published var selectedModel: LLMModel {
        didSet { defaults.set(selectedModel.rawValue, forKey: "selectedModel") }
    }
    @Published var hotkeyKeyCode: Int {
        didSet { defaults.set(hotkeyKeyCode, forKey: "hotkeyKeyCode") }
    }
    @Published var hotkeyModifiers: Int {
        didSet { defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    init(suiteName: String = "com.transify.settings") {
        self.suiteName = suiteName
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard

        self.targetLanguage  = defaults.string(forKey: "targetLanguage") ?? "zh"
        self.hotkeyKeyCode   = defaults.object(forKey: "hotkeyKeyCode")   == nil ? 17   : defaults.integer(forKey: "hotkeyKeyCode")
        self.hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") == nil ? 2048 : defaults.integer(forKey: "hotkeyModifiers")
        self.launchAtLogin   = defaults.bool(forKey: "launchAtLogin")

        let modelRaw = defaults.string(forKey: "selectedModel") ?? LLMModel.geminiFlash.rawValue
        self.selectedModel = LLMModel(rawValue: modelRaw) ?? .geminiFlash
    }

    // MARK: - Keychain

    func apiKey(for provider: LLMProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: "transify-\(provider.rawValue)",
            kSecReturnData as String:  true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setApiKey(_ key: String, for provider: LLMProvider) {
        let account = "transify-\(provider.rawValue)"
        let data = key.data(using: .utf8)!

        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}

extension SettingsStore {
    static let availableLanguages: [(code: String, name: String)] = [
        ("zh", "中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español"),
    ]
}
