// Transify/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var googleKey     = ""
    @State private var anthropicKey  = ""
    @State private var openaiKey     = ""
    @State private var showGoogleKey    = false
    @State private var showAnthropicKey = false
    @State private var showOpenAIKey    = false

    var body: some View {
        Form {
            Section("翻译设置") {
                Picker("目标语言", selection: $settings.targetLanguage) {
                    ForEach(SettingsStore.availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                Picker("翻译模型", selection: $settings.selectedModel) {
                    ForEach(LLMModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
            }
            Section("API Keys") {
                apiKeyField(label: "Google",    binding: $googleKey,    show: $showGoogleKey,    provider: .google)
                apiKeyField(label: "Anthropic", binding: $anthropicKey, show: $showAnthropicKey, provider: .anthropic)
                apiKeyField(label: "OpenAI",    binding: $openaiKey,    show: $showOpenAIKey,    provider: .openai)
            }
            Section("通用") {
                Toggle("开机自启", isOn: $settings.launchAtLogin)
                LabeledContent("翻译快捷键") {
                    Text("Option+T").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear { loadKeys() }
    }

    @ViewBuilder
    private func apiKeyField(label: String, binding: Binding<String>, show: Binding<Bool>, provider: LLMProvider) -> some View {
        HStack {
            Text(label).frame(width: 80, alignment: .leading)
            if show.wrappedValue {
                TextField("API Key", text: binding).textFieldStyle(.roundedBorder)
            } else {
                SecureField("API Key", text: binding).textFieldStyle(.roundedBorder)
            }
            Button(show.wrappedValue ? "隐藏" : "显示") { show.wrappedValue.toggle() }
                .buttonStyle(.borderless)
            Button("保存") { settings.setApiKey(binding.wrappedValue, for: provider) }
                .buttonStyle(.bordered)
                .disabled(binding.wrappedValue.isEmpty)
        }
    }

    private func loadKeys() {
        googleKey    = settings.apiKey(for: .google)    ?? ""
        anthropicKey = settings.apiKey(for: .anthropic) ?? ""
        openaiKey    = settings.apiKey(for: .openai)    ?? ""
    }
}
