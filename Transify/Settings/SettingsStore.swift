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
    case qwenTurbo    = "qwen-turbo"
    case qwenPlus     = "qwen-plus"
    case qwenMax      = "qwen-max"

    var id: String { rawValue }

    var provider: LLMProvider {
        switch self {
        case .geminiFlash, .geminiPro:       return .google
        case .claudeHaiku, .claudeSonnet:    return .anthropic
        case .gpt4oMini, .gpt4o:             return .openai
        case .qwenTurbo, .qwenPlus, .qwenMax: return .bailian
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
        case .qwenTurbo:    return "百炼 Qwen Turbo"
        case .qwenPlus:     return "百炼 Qwen Plus"
        case .qwenMax:      return "百炼 Qwen Max"
        }
    }
}

enum LLMProvider: String {
    case google, anthropic, openai, bailian

    var displayName: String {
        switch self {
        case .google:    return "Google"
        case .anthropic: return "Anthropic"
        case .openai:    return "OpenAI"
        case .bailian:   return "百炼"
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
        let storedModifiers  = defaults.object(forKey: "hotkeyModifiers") == nil ? 524288 : defaults.integer(forKey: "hotkeyModifiers")
        self.hotkeyModifiers = storedModifiers == 2048 ? 524288 : storedModifiers
        self.launchAtLogin   = defaults.bool(forKey: "launchAtLogin")

        let modelRaw = defaults.string(forKey: "selectedModel") ?? LLMModel.geminiFlash.rawValue
        self.selectedModel = LLMModel(rawValue: modelRaw) ?? .geminiFlash
    }

    // MARK: - API Keys (UserDefaults, migrate to Keychain after proper code signing)

    func apiKey(for provider: LLMProvider) -> String? {
        let value = defaults.string(forKey: "apiKey-\(provider.rawValue)")
        return value?.isEmpty == false ? value : nil
    }

    func setApiKey(_ key: String, for provider: LLMProvider) {
        defaults.set(key, forKey: "apiKey-\(provider.rawValue)")
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
