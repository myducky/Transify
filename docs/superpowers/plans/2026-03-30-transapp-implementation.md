# TransApp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS Menu Bar app that translates selected text in any app via hotkey, replacing editable input content and showing a popup for read-only text.

**Architecture:** CGEventTap monitors global hotkey (Option+T); AccessibilityBridge reads selected text and detects element type via AXUIElement; TranslationCore calls LLM API and routes result to either in-place replacement or floating popup.

**Tech Stack:** Swift 5.9+, SwiftUI (macOS 13+), CGEventTap, AXUIElement, URLSession, Keychain, xcodegen

---

## Task 1: Project Scaffolding

**Files:**
- Create: `project.yml`
- Create: `TransApp/Info.plist`
- Create: `TransApp/TransApp.entitlements`
- Create: `TransApp/TransAppApp.swift`
- Create: `TransApp/AppDelegate.swift`

- [ ] **Step 1: Install xcodegen**

```bash
brew install xcodegen
```

Expected: `xcodegen version x.x.x` after install.

- [ ] **Step 2: Create project.yml**

```yaml
name: TransApp
options:
  bundleIdPrefix: com.transapp
  deploymentTarget:
    macOS: "13.0"
settings:
  SWIFT_VERSION: "5.9"
targets:
  TransApp:
    type: application
    platform: macOS
    sources: [TransApp]
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.transapp.TransApp
      INFOPLIST_FILE: TransApp/Info.plist
      CODE_SIGN_ENTITLEMENTS: TransApp/TransApp.entitlements
      CODE_SIGN_IDENTITY: "-"
      CODE_SIGNING_REQUIRED: "NO"
  TransAppTests:
    type: bundle.unit-test
    platform: macOS
    sources: [TransAppTests]
    dependencies:
      - target: TransApp
```

- [ ] **Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TransApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.transapp.TransApp</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>TransApp needs accessibility access to read and replace text in other applications.</string>
</dict>
</plist>
```

- [ ] **Step 4: Create entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 5: Create TransAppApp.swift**

```swift
import SwiftUI

@main
struct TransAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("TransApp", systemImage: "translate") {
            MenuBarView()
                .environmentObject(appDelegate.settingsStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.settingsStore)
        }
    }
}
```

- [ ] **Step 6: Create AppDelegate.swift (stub)**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Will be wired up in Task 11
    }
}
```

- [ ] **Step 7: Create source directories and generate project**

```bash
mkdir -p TransApp/Core TransApp/Settings TransApp/UI TransAppTests
xcodegen generate
```

Expected: `TransApp.xcodeproj` created.

- [ ] **Step 8: Verify project builds**

Open in Xcode:
```bash
open TransApp.xcodeproj
```

Press `Cmd+B`. Expected: Build Succeeded (empty app, no logic yet).

- [ ] **Step 9: Commit**

```bash
git init
git add .
git commit -m "feat: initial project scaffold"
```

---

## Task 2: SettingsStore

**Files:**
- Create: `TransApp/Settings/SettingsStore.swift`
- Create: `TransAppTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// TransAppTests/SettingsStoreTests.swift
import XCTest
@testable import TransApp

final class SettingsStoreTests: XCTestCase {
    var store: SettingsStore!

    override func setUp() {
        super.setUp()
        // Use a separate suite to avoid polluting real UserDefaults
        store = SettingsStore(suiteName: "test-\(UUID().uuidString)")
    }

    func test_defaultTargetLanguage_isChinese() {
        XCTAssertEqual(store.targetLanguage, "zh")
    }

    func test_defaultModel_isGeminiFlash() {
        XCTAssertEqual(store.selectedModel, LLMModel.geminiFlash)
    }

    func test_defaultHotkey_isOptionT() {
        XCTAssertEqual(store.hotkeyKeyCode, 17)       // T
        XCTAssertEqual(store.hotkeyModifiers, 2048)   // Option
    }

    func test_persistTargetLanguage() {
        store.targetLanguage = "ja"
        let store2 = SettingsStore(suiteName: store.suiteName)
        XCTAssertEqual(store2.targetLanguage, "ja")
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: compile error — `SettingsStore` not defined.

- [ ] **Step 3: Create SettingsStore.swift**

```swift
// TransApp/Settings/SettingsStore.swift
import Foundation
import Combine

enum LLMModel: String, CaseIterable, Identifiable {
    case geminiFlash = "gemini-2.0-flash"
    case geminiPro   = "gemini-2.5-pro"
    case claudeHaiku = "claude-haiku-4-5"
    case claudeSonnet = "claude-sonnet-4-6"
    case gpt4oMini   = "gpt-4o-mini"
    case gpt4o       = "gpt-4o"

    var id: String { rawValue }

    var provider: LLMProvider {
        switch self {
        case .geminiFlash, .geminiPro: return .google
        case .claudeHaiku, .claudeSonnet: return .anthropic
        case .gpt4oMini, .gpt4o: return .openai
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

    init(suiteName: String = "com.transapp.settings") {
        self.suiteName = suiteName
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard

        self.targetLanguage  = defaults.string(forKey: "targetLanguage") ?? "zh"
        self.hotkeyKeyCode   = defaults.object(forKey: "hotkeyKeyCode")  == nil ? 17 : defaults.integer(forKey: "hotkeyKeyCode")
        self.hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") == nil ? 2048 : defaults.integer(forKey: "hotkeyModifiers")
        self.launchAtLogin   = defaults.bool(forKey: "launchAtLogin")

        let modelRaw = defaults.string(forKey: "selectedModel") ?? LLMModel.geminiFlash.rawValue
        self.selectedModel = LLMModel(rawValue: modelRaw) ?? .geminiFlash
    }

    // MARK: - Keychain

    func apiKey(for provider: LLMProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: "transapp-\(provider.rawValue)",
            kSecReturnData as String:  true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setApiKey(_ key: String, for provider: LLMProvider) {
        let account = "transapp-\(provider.rawValue)"
        let data = key.data(using: .utf8)!

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}

// Supported target languages
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
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: All SettingsStoreTests pass.

- [ ] **Step 5: Commit**

```bash
git add TransApp/Settings/SettingsStore.swift TransAppTests/SettingsStoreTests.swift
git commit -m "feat: add SettingsStore with UserDefaults and Keychain"
```

---

## Task 3: LLMClient

**Files:**
- Create: `TransApp/Core/LLMClient.swift`
- Create: `TransAppTests/LLMClientTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// TransAppTests/LLMClientTests.swift
import XCTest
@testable import TransApp

final class LLMClientTests: XCTestCase {

    func test_gemini_buildRequest() throws {
        let client = LLMClient(session: .shared)
        let req = try client.buildRequest(
            model: .geminiFlash,
            apiKey: "test-key",
            text: "Hello",
            targetLanguage: "zh"
        )
        XCTAssertTrue(req.url!.absoluteString.contains("gemini-2.0-flash"))
        XCTAssertTrue(req.url!.absoluteString.contains("test-key"))
        XCTAssertEqual(req.httpMethod, "POST")
        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        let contents = body["contents"] as! [[String: Any]]
        XCTAssertFalse(contents.isEmpty)
    }

    func test_openai_buildRequest() throws {
        let client = LLMClient(session: .shared)
        let req = try client.buildRequest(
            model: .gpt4oMini,
            apiKey: "test-key",
            text: "Hello",
            targetLanguage: "zh"
        )
        XCTAssertTrue(req.url!.absoluteString.contains("openai.com"))
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
    }

    func test_anthropic_buildRequest() throws {
        let client = LLMClient(session: .shared)
        let req = try client.buildRequest(
            model: .claudeHaiku,
            apiKey: "test-key",
            text: "Hello",
            targetLanguage: "zh"
        )
        XCTAssertTrue(req.url!.absoluteString.contains("anthropic.com"))
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "test-key")
    }

    func test_gemini_parseResponse() throws {
        let client = LLMClient(session: .shared)
        let json = """
        {
          "candidates": [{
            "content": { "parts": [{ "text": "你好" }] }
          }]
        }
        """.data(using: .utf8)!
        let result = try client.parseResponse(data: json, model: .geminiFlash)
        XCTAssertEqual(result, "你好")
    }

    func test_openai_parseResponse() throws {
        let client = LLMClient(session: .shared)
        let json = """
        {
          "choices": [{ "message": { "content": "你好" } }]
        }
        """.data(using: .utf8)!
        let result = try client.parseResponse(data: json, model: .gpt4oMini)
        XCTAssertEqual(result, "你好")
    }

    func test_anthropic_parseResponse() throws {
        let client = LLMClient(session: .shared)
        let json = """
        {
          "content": [{ "type": "text", "text": "你好" }]
        }
        """.data(using: .utf8)!
        let result = try client.parseResponse(data: json, model: .claudeHaiku)
        XCTAssertEqual(result, "你好")
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "error:|LLMClient"
```

Expected: compile error — `LLMClient` not defined.

- [ ] **Step 3: Create LLMClient.swift**

```swift
// TransApp/Core/LLMClient.swift
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

    // MARK: - Internal (internal for testing)

    func buildRequest(model: LLMModel, apiKey: String, text: String, targetLanguage: String) throws -> URLRequest {
        let prompt = buildPrompt(text: text, targetLanguage: targetLanguage)
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

    // MARK: - Private

    private func buildPrompt(text: String, targetLanguage: String) -> String {
        return "You are a professional translator. Translate the following text to \(targetLanguage). Output ONLY the translated text, no explanations, no quotes.\n\nText: \(text)"
    }

    private func buildGeminiRequest(model: LLMModel, apiKey: String, prompt: String) throws -> URLRequest {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func buildOpenAIRequest(model: LLMModel, apiKey: String, prompt: String) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model.rawValue,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func buildAnthropicRequest(model: LLMModel, apiKey: String, prompt: String) throws -> URLRequest {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func parseGeminiResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw LLMError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseOpenAIResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseAnthropicResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw LLMError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "LLMClientTests|passed|failed"
```

Expected: All 6 LLMClientTests pass.

- [ ] **Step 5: Commit**

```bash
git add TransApp/Core/LLMClient.swift TransAppTests/LLMClientTests.swift
git commit -m "feat: add LLMClient supporting Gemini, OpenAI, Anthropic"
```

---

## Task 4: AccessibilityBridge

**Files:**
- Create: `TransApp/Core/AccessibilityBridge.swift`

Note: AXUIElement requires runtime accessibility permission; unit tests are not practical here. Manual testing in Task 11.

- [ ] **Step 1: Create AccessibilityBridge.swift**

```swift
// TransApp/Core/AccessibilityBridge.swift
import AppKit
import ApplicationServices

struct TextSelection {
    let text: String
    let isEditable: Bool
    let element: AXUIElement
    let range: CFRange      // selection range in full text
    let fullText: String    // full text of element (only valid when isEditable)
}

class AccessibilityBridge {

    // Returns nil if no text is selected or permission not granted
    func readSelection() -> TextSelection? {
        let systemElement = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else { return nil }

        // Get selected text
        var selectedTextValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success,
              let selectedText = selectedTextValue as? String,
              !selectedText.isEmpty else { return nil }

        // Get selection range
        var rangeValue: AnyObject?
        var cfRange = CFRange(location: 0, length: 0)
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let rangeData = rangeValue {
            AXValueGetValue(rangeData as! AXValue, .cfRange, &cfRange)
        }

        // Check editability and get full text
        var fullText = ""
        var isEditable = false
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success,
           settable.boolValue {
            isEditable = true
            var textValue: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue) == .success {
                fullText = (textValue as? String) ?? ""
            }
        }

        return TextSelection(
            text: selectedText,
            isEditable: isEditable,
            element: element,
            range: cfRange,
            fullText: fullText
        )
    }

    // Replace selected text in an editable element
    // Returns true on success
    @discardableResult
    func replaceSelection(in selection: TextSelection, with newText: String) -> Bool {
        guard selection.isEditable else { return false }

        let nsRange = NSRange(location: selection.range.location, length: selection.range.length)
        guard let range = Range(nsRange, in: selection.fullText) else { return false }

        let newFullText = selection.fullText.replacingCharacters(in: range, with: newText) as CFString
        guard AXUIElementSetAttributeValue(selection.element, kAXValueAttribute as CFString, newFullText) == .success else {
            return false
        }

        // Move cursor to end of inserted text
        let newLocation = selection.range.location + (newText as NSString).length
        var newRange = CFRange(location: newLocation, length: 0)
        if let rangeValue = AXValueCreate(.cfRange, &newRange) {
            AXUIElementSetAttributeValue(selection.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        }

        return true
    }

    // Check if accessibility permission is granted
    static func hasPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    // Open System Settings to accessibility pane
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TransApp/Core/AccessibilityBridge.swift
git commit -m "feat: add AccessibilityBridge for AXUIElement read/write"
```

---

## Task 5: TranslationUndoManager

**Files:**
- Create: `TransApp/Core/TranslationUndoManager.swift`
- Create: `TransAppTests/TranslationUndoManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// TransAppTests/TranslationUndoManagerTests.swift
import XCTest
@testable import TransApp

final class TranslationUndoManagerTests: XCTestCase {

    func test_initialState_hasNoEntry() {
        let manager = TranslationUndoManager()
        XCTAssertFalse(manager.canUndo)
    }

    func test_afterRecord_canUndo() {
        let manager = TranslationUndoManager()
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        manager.record(originalText: "hello", range: CFRange(location: 0, length: 5), element: element, fullText: "hello world")
        XCTAssertTrue(manager.canUndo)
    }

    func test_afterConsume_cannotUndoAgain() {
        let manager = TranslationUndoManager()
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        manager.record(originalText: "hello", range: CFRange(location: 0, length: 5), element: element, fullText: "hello world")
        _ = manager.consumeEntry()
        XCTAssertFalse(manager.canUndo)
    }

    func test_consumeEntry_returnsRecordedValues() {
        let manager = TranslationUndoManager()
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        manager.record(originalText: "hello", range: CFRange(location: 2, length: 5), element: element, fullText: "xx hello yy")
        let entry = manager.consumeEntry()
        XCTAssertEqual(entry?.originalText, "hello")
        XCTAssertEqual(entry?.range.location, 2)
        XCTAssertEqual(entry?.fullText, "xx hello yy")
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "TranslationUndoManager|error:"
```

Expected: compile error.

- [ ] **Step 3: Create TranslationUndoManager.swift**

```swift
// TransApp/Core/TranslationUndoManager.swift
import Foundation
import ApplicationServices

struct UndoEntry {
    let originalText: String
    let range: CFRange
    let element: AXUIElement
    let fullText: String      // full text before replacement
    let translatedText: String // text that was inserted
}

class TranslationUndoManager {
    private var entry: UndoEntry?

    var canUndo: Bool { entry != nil }

    func record(originalText: String, range: CFRange, element: AXUIElement, fullText: String, translatedText: String = "") {
        entry = UndoEntry(
            originalText: originalText,
            range: range,
            element: element,
            fullText: fullText,
            translatedText: translatedText
        )
    }

    // Consume and return the stored entry (clears it)
    func consumeEntry() -> UndoEntry? {
        defer { entry = nil }
        return entry
    }

    func clear() {
        entry = nil
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "TranslationUndoManagerTests|passed|failed"
```

Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add TransApp/Core/TranslationUndoManager.swift TransAppTests/TranslationUndoManagerTests.swift
git commit -m "feat: add TranslationUndoManager"
```

---

## Task 6: TranslationCore

**Files:**
- Create: `TransApp/Core/TranslationCore.swift`
- Create: `TransAppTests/TranslationCoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// TransAppTests/TranslationCoreTests.swift
import XCTest
@testable import TransApp

// Mock LLMClient subclass for testing
class MockLLMClient: LLMClient {
    var translatedResult: String = "translated"
    var shouldThrow = false

    override func translate(text: String, to language: String, model: LLMModel, apiKey: String) async throws -> String {
        if shouldThrow { throw LLMError.invalidResponse }
        return translatedResult
    }
}

final class TranslationCoreTests: XCTestCase {

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
        // No API key set
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
```

- [ ] **Step 2: Run to confirm failure**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "TranslationCore|error:"
```

Expected: compile error.

- [ ] **Step 3: Create TranslationCore.swift**

```swift
// TransApp/Core/TranslationCore.swift
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
        return try await llmClient.translate(
            text: text,
            to: settings.targetLanguage,
            model: model,
            apiKey: apiKey
        )
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "TranslationCoreTests|passed|failed"
```

Expected: Both tests pass.

- [ ] **Step 5: Commit**

```bash
git add TransApp/Core/TranslationCore.swift TransAppTests/TranslationCoreTests.swift
git commit -m "feat: add TranslationCore"
```

---

## Task 7: EventMonitor

**Files:**
- Create: `TransApp/Core/EventMonitor.swift`

Note: CGEventTap requires an active run loop and accessibility permission; unit tests are not practical. Verified in Task 11.

- [ ] **Step 1: Create EventMonitor.swift**

```swift
// TransApp/Core/EventMonitor.swift
import AppKit
import ApplicationServices

class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotkeyPressed: (() -> Void)?
    var onUndoPressed: (() -> Void)?    // Cmd+Z after a translation

    private var hotkeyKeyCode: CGKeyCode
    private var hotkeyModifiers: CGEventFlags

    // Whether the last action was a translation (enables Cmd+Z intercept)
    var pendingUndo = false

    init(keyCode: CGKeyCode = 17, modifiers: CGEventFlags = .maskAlternate) {
        self.hotkeyKeyCode = keyCode
        self.hotkeyModifiers = modifiers
    }

    func updateHotkey(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        self.hotkeyKeyCode = keyCode
        self.hotkeyModifiers = modifiers
    }

    func start() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passRetained(self).toOpaque()
        )

        guard let tap = eventTap else {
            print("EventMonitor: Failed to create event tap — check Accessibility permission")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift])

        // Check translation hotkey
        if keyCode == hotkeyKeyCode && flags == hotkeyModifiers.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift]) {
            DispatchQueue.main.async { self.onHotkeyPressed?() }
            return nil  // consume the event
        }

        // Intercept Cmd+Z only if we have a pending undo
        if pendingUndo && keyCode == 6 && flags == .maskCommand {  // Z keycode = 6
            DispatchQueue.main.async { self.onUndoPressed?() }
            pendingUndo = false
            return nil  // consume the event
        }

        return Unmanaged.passRetained(event)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TransApp/Core/EventMonitor.swift
git commit -m "feat: add EventMonitor with CGEventTap"
```

---

## Task 8: TranslationPopup (read-only floating window)

**Files:**
- Create: `TransApp/UI/TranslationPopup.swift`

- [ ] **Step 1: Create TranslationPopup.swift**

```swift
// TransApp/UI/TranslationPopup.swift
import SwiftUI
import AppKit

class TranslationPopupController {
    private var window: NSPanel?
    private var dismissTimer: Timer?

    func show(text: String, near point: NSPoint) {
        dismiss()  // dismiss any existing popup

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        let view = PopupContentView(text: text) {
            self.dismiss()
        }
        panel.contentView = NSHostingView(rootView: view)
        panel.sizeToFit()

        // Position near mouse
        var origin = point
        origin.y -= panel.frame.height + 8
        // Clamp to screen
        if let screen = NSScreen.main {
            origin.x = max(screen.visibleFrame.minX, min(origin.x, screen.visibleFrame.maxX - panel.frame.width))
            origin.y = max(screen.visibleFrame.minY, origin.y)
        }
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
        self.window = panel

        // Auto-dismiss after 3 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        window?.close()
        window = nil
    }
}

private struct PopupContentView: View {
    let text: String
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: 13))
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button(copied ? "已复制 ✓" : "复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onTapGesture { onDismiss() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TransApp/UI/TranslationPopup.swift
git commit -m "feat: add TranslationPopup floating window"
```

---

## Task 9: SettingsView

**Files:**
- Create: `TransApp/Settings/SettingsView.swift`

- [ ] **Step 1: Create SettingsView.swift**

```swift
// TransApp/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var googleKey  = ""
    @State private var anthropicKey = ""
    @State private var openaiKey  = ""
    @State private var showGoogleKey = false
    @State private var showAnthropicKey = false
    @State private var showOpenAIKey = false

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
                    .onChange(of: settings.launchAtLogin) { _ in
                        updateLoginItem()
                    }
                LabeledContent("翻译快捷键") {
                    Text("Option+T")
                        .foregroundStyle(.secondary)
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
            Text(label)
                .frame(width: 80, alignment: .leading)
            if show.wrappedValue {
                TextField("API Key", text: binding)
                    .textFieldStyle(.roundedBorder)
            } else {
                SecureField("API Key", text: binding)
                    .textFieldStyle(.roundedBorder)
            }
            Button(show.wrappedValue ? "隐藏" : "显示") { show.wrappedValue.toggle() }
                .buttonStyle(.borderless)
            Button("保存") { settings.setApiKey(binding.wrappedValue, for: provider) }
                .buttonStyle(.bordered)
                .disabled(binding.wrappedValue.isEmpty)
        }
    }

    private func loadKeys() {
        googleKey     = settings.apiKey(for: .google)    ?? ""
        anthropicKey  = settings.apiKey(for: .anthropic) ?? ""
        openaiKey     = settings.apiKey(for: .openai)    ?? ""
    }

    private func updateLoginItem() {
        // SMAppService available macOS 13+
        // Minimal stub — full implementation requires a helper or SMLoginItemSetEnabled
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TransApp/Settings/SettingsView.swift
git commit -m "feat: add SettingsView"
```

---

## Task 10: MenuBarView

**Files:**
- Create: `TransApp/UI/MenuBarView.swift`

- [ ] **Step 1: Create MenuBarView.swift**

```swift
// TransApp/UI/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var statusMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let msg = statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            Divider()

            Text("目标语言：\(currentLanguageName)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            Text("模型：\(settings.selectedModel.displayName)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            Divider()

            Button("设置...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .padding(.horizontal, 8)

            Button("退出") { NSApp.terminate(nil) }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
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
```

- [ ] **Step 2: Commit**

```bash
git add TransApp/UI/MenuBarView.swift
git commit -m "feat: add MenuBarView"
```

---

## Task 11: Wire Up AppDelegate — Integration

**Files:**
- Modify: `TransApp/AppDelegate.swift`

- [ ] **Step 1: Update AppDelegate.swift with full integration**

```swift
// TransApp/AppDelegate.swift
import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    private let accessibilityBridge = AccessibilityBridge()
    private let undoManager = TranslationUndoManager()
    private let popupController = TranslationPopupController()
    private lazy var translationCore = TranslationCore(settings: settingsStore)
    private lazy var eventMonitor = EventMonitor(
        keyCode: CGKeyCode(settingsStore.hotkeyKeyCode),
        modifiers: CGEventFlags(rawValue: UInt64(settingsStore.hotkeyModifiers))
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermission()

        eventMonitor.onHotkeyPressed = { [weak self] in self?.handleTranslationTrigger() }
        eventMonitor.onUndoPressed   = { [weak self] in self?.handleUndo() }
        eventMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor.stop()
    }

    // MARK: - Translation

    private func handleTranslationTrigger() {
        guard let selection = accessibilityBridge.readSelection() else { return }

        Task {
            do {
                let translated = try await translationCore.translate(text: selection.text)

                await MainActor.run {
                    if selection.isEditable {
                        // Record undo state before replacing
                        undoManager.record(
                            originalText: selection.text,
                            range: selection.range,
                            element: selection.element,
                            fullText: selection.fullText,
                            translatedText: translated
                        )
                        accessibilityBridge.replaceSelection(in: selection, with: translated)
                        eventMonitor.pendingUndo = true
                        NotificationCenter.default.post(
                            name: .translationDidComplete,
                            object: nil,
                            userInfo: ["text": "已翻译"]
                        )
                    } else {
                        // Show popup for read-only text
                        let mouseLocation = NSEvent.mouseLocation
                        popupController.show(text: translated, near: mouseLocation)
                    }
                }
            } catch LLMError.noApiKey(let provider) {
                await MainActor.run {
                    showNoApiKeyAlert(provider: provider)
                }
            } catch {
                print("Translation error: \(error.localizedDescription)")
            }
        }
    }

    private func handleUndo() {
        guard let entry = undoManager.consumeEntry() else { return }
        // Restore the full original text directly — simplest and most reliable
        AXUIElementSetAttributeValue(entry.element, kAXValueAttribute as CFString, entry.fullText as CFString)
        // Restore selection to original range
        var cfRange = entry.range
        if let rangeValue = AXValueCreate(.cfRange, &cfRange) {
            AXUIElementSetAttributeValue(entry.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        }
    }

    // MARK: - Permission

    private func checkAccessibilityPermission() {
        if !AccessibilityBridge.hasPermission() {
            AccessibilityBridge.requestPermission()
        }
    }

    private func showNoApiKeyAlert(provider: LLMProvider) {
        let alert = NSAlert()
        alert.messageText = "需要 API Key"
        alert.informativeText = "请在设置中填写 \(provider.displayName) 的 API Key。"
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild build -scheme TransApp -destination 'platform=macOS' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`.

- [ ] **Step 3: Run the app manually and test**

In Xcode: press `Cmd+R` to run.

Test checklist:
1. App appears in Menu Bar as translate icon
2. First launch: macOS prompts for Accessibility permission — grant it in System Settings
3. Open Settings, enter your Gemini API key and save
4. Open any text editor (TextEdit), type "Hello world", select it
5. Press `Option+T` — text should be replaced with Chinese translation
6. Press `Cmd+Z` — original text should restore
7. Open a webpage, select some text (non-editable), press `Option+T` — popup should appear with translation and Copy button

- [ ] **Step 4: Commit**

```bash
git add TransApp/AppDelegate.swift
git commit -m "feat: wire up full translation flow in AppDelegate"
```

---

## Task 12: Run All Tests

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme TransApp -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests pass — LLMClientTests (6), TranslationCoreTests (2), TranslationUndoManagerTests (4), SettingsStoreTests (4).

- [ ] **Step 2: Final commit**

```bash
git add -A
git commit -m "chore: all tests passing, v1.0 complete"
```

---

## Build DMG for Distribution (Optional — after Xcode dev account setup)

When ready to distribute:

```bash
# 1. Archive in Xcode: Product → Archive → Distribute App → Developer ID
# 2. Create DMG
brew install create-dmg
create-dmg \
  --volname "TransApp" \
  --window-size 480 240 \
  --icon-size 100 \
  --icon "TransApp.app" 120 100 \
  --hide-extension "TransApp.app" \
  --app-drop-link 360 100 \
  "TransApp.dmg" \
  "path/to/exported/TransApp.app"
```
