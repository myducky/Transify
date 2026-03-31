// Transify/UI/MenuBarView.swift
import SwiftUI
import ApplicationServices

struct MenuBarView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var statusMessage: String? = nil
    @State private var hasAccessibility = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Accessibility status
            HStack {
                Image(systemName: hasAccessibility ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(hasAccessibility ? .green : .orange)
                Text(hasAccessibility ? "辅助功能已授权" : "需要辅助功能权限")
                    .font(.system(size: 12))
                if !hasAccessibility {
                    Button("去授权") { openAccessibilitySettings() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if let msg = statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(msg).font(.system(size: 12))
                }
                .padding(.horizontal, 12)
            }

            Divider()
            Text("目标语言：\(currentLanguageName)")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 12)
            Text("模型：\(settings.selectedModel.displayName)")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 12)
            Divider()
            Button("设置...") {
                SettingsWindowManager.shared.open(settingsStore: settings)
            }.padding(.horizontal, 8)
            Button("退出") { NSApp.terminate(nil) }
                .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .frame(width: 220)
        .onReceive(NotificationCenter.default.publisher(for: .translationDidComplete)) { note in
            statusMessage = note.userInfo?["text"] as? String
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { statusMessage = nil }
        }
        .onAppear { hasAccessibility = AXIsProcessTrusted() }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityStatusChanged)) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
    }

    private var currentLanguageName: String {
        SettingsStore.availableLanguages.first { $0.code == settings.targetLanguage }?.name ?? settings.targetLanguage
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

extension Notification.Name {
    static let translationDidComplete = Notification.Name("translationDidComplete")
}

