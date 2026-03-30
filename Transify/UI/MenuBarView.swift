// Transify/UI/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var statusMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let msg = statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(msg).font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            Divider()
            Text("目标语言：\(currentLanguageName)")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 12)
            Text("模型：\(settings.selectedModel.displayName)")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 12)
            Divider()
            Button("设置...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }.padding(.horizontal, 8)
            Button("退出") { NSApp.terminate(nil) }
                .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .frame(width: 200)
        .onReceive(NotificationCenter.default.publisher(for: .translationDidComplete)) { note in
            statusMessage = note.userInfo?["text"] as? String
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { statusMessage = nil }
        }
    }

    private var currentLanguageName: String {
        SettingsStore.availableLanguages.first { $0.code == settings.targetLanguage }?.name ?? settings.targetLanguage
    }
}

extension Notification.Name {
    static let translationDidComplete = Notification.Name("translationDidComplete")
}
