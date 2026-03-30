# TransApp — Mac 翻译工具 设计文档

**日期：** 2026-03-30
**状态：** 已批准

---

## 概述

TransApp 是一款 macOS Menu Bar 应用，允许用户在任意应用的输入框或静态文字中选中文本，按快捷键后通过 LLM 自动翻译。针对可编辑输入框直接替换原文；针对只读文字在浮窗中展示译文并支持复制。

---

## 核心行为

### 触发流程

1. 用户在任意应用中选中文字（框选或三击选中）
2. 按快捷键（默认 `Option+T`，可自定义）
3. `AccessibilityBridge` 检测选中文本及元素类型
4. 调用 LLM API 翻译为目标语言
5. 根据元素类型分两种结果处理

### 结果处理

| 场景 | 处理方式 |
|------|----------|
| 可编辑输入框（NSTextField、NSTextView、浏览器地址栏等） | 用译文替换选中文本，支持 `Cmd+Z` 撤销 |
| 只读/静态文字（Label、网页正文、PDF 等） | 在选中文字附近弹出浮窗，显示译文 + 复制按钮，3 秒后自动消失 |

---

## 架构

```
┌──────────────────────────────────────────────────────┐
│                TransApp (Menu Bar App)                │
├───────────────┬──────────────────┬───────────────────┤
│ EventMonitor  │ TranslationCore  │  SettingsPanel    │
│               │                  │                   │
│ CGEventTap    │ LLMClient        │ 目标语言           │
│ 快捷键监听    │ 可配置模型/Key    │ 模型选择           │
│ 选中文本检测   │ Prompt 构建       │ 快捷键设置         │
├───────────────┴──────────────────┴───────────────────┤
│               AccessibilityBridge                     │
│      AXUIElement 读取选中文本 / 检测元素类型 / 写回     │
├──────────────────────────────────────────────────────┤
│               UndoManager                             │
│        记录替换前原文，支持 Cmd+Z 恢复原文              │
└──────────────────────────────────────────────────────┘
```

### 模块职责

- **EventMonitor**：通过 `CGEventTap` 全局监听键盘快捷键，触发翻译流程
- **AccessibilityBridge**：使用 `AXUIElement` API 读取当前焦点元素的选中文本、判断元素是否可编辑、写回译文
- **TranslationCore**：构建翻译 Prompt，调用 `LLMClient`，返回译文
- **LLMClient**：封装各 LLM 提供商 HTTP API 调用，支持按提供商切换
- **UndoManager**：替换前保存原文和光标范围，响应 `Cmd+Z` 恢复
- **SettingsPanel**：SwiftUI 设置面板，管理用户配置，API Key 存储于 macOS Keychain

---

## LLM 配置

### 默认模型

`gemini-2.0-flash`（Google Generative AI，免费额度高、响应速度快）

### 支持模型列表

| 提供商 | 模型 ID |
|--------|---------|
| Google（默认） | `gemini-2.0-flash`、`gemini-2.5-pro` |
| Anthropic | `claude-haiku-4-5`、`claude-sonnet-4-6` |
| OpenAI | `gpt-4o-mini`、`gpt-4o` |

### 翻译 Prompt

```
You are a professional translator.
Translate the following text to {targetLanguage}.
Output ONLY the translated text, no explanations, no quotes.

Text: {selectedText}
```

### API Key 存储

各提供商 API Key 单独存储于 macOS Keychain，Settings Panel 中按提供商分区填写。

### 首次使用处理

触发翻译时若当前所选模型的 API Key 未配置，自动弹出 Settings Panel 并高亮提示对应的 Key 输入框，翻译操作取消。

---

## Settings Panel

Menu Bar 图标点击后展示 SwiftUI 面板：

```
┌─────────────────────────────┐
│  TransApp 设置               │
├─────────────────────────────┤
│  翻译快捷键   [Option+T]  ▾  │
│  目标语言     [中文]       ▾  │
├─────────────────────────────┤
│  模型         [Gemini Flash]▾│
│                              │
│  Google API Key  [••••] ✎   │
│  Anthropic Key   [••••] ✎   │
│  OpenAI Key      [••••] ✎   │
├─────────────────────────────┤
│  开机自启      ●  开          │
│                    [退出]    │
└─────────────────────────────┘
```

**目标语言选项：** 中文、英文、日文、韩文、法文、德文、西班牙文

---

## 浮窗设计（只读场景）

- 出现位置：鼠标当前位置附近，避免超出屏幕边界
- 内容：译文文本 + "复制"按钮
- 交互：点击复制后按钮变为"已复制 ✓"；点击浮窗外部或 3 秒后自动关闭
- 实现：轻量 SwiftUI `NSPanel`（`NSFloatingWindowLevel`）

---

## 撤销机制

- 替换发生时，`UndoManager` 记录：原文内容、选中范围、目标 `AXUIElement`
- 优先依赖目标 App 原生 `Cmd+Z` 撤销（大多数 App 支持）
- 若原生撤销失效，`EventMonitor` 拦截 `Cmd+Z`，由 `UndoManager` 调用 `AXSetValue` 恢复原文并还原选中范围
- 仅支持最近一次翻译的撤销；撤销后清空记录

---

## 权限与分发

### 运行时权限

- **辅助功能权限（Accessibility）**：读写任意应用 UI 元素必须
- 首次启动时弹出引导，跳转至「系统设置 → 隐私与安全性 → 辅助功能」

### 分发方式

- 打包为 `.dmg` 直接分发（不上 App Store，避免沙盒限制 Accessibility 权限）
- 代码签名 + Apple Notarization（通过 macOS Gatekeeper 验证）

---

## 技术栈

- **语言：** Swift 5.9+
- **UI：** SwiftUI（Menu Bar Extra、Settings Panel、浮窗）
- **系统 API：** CGEventTap、AXUIElement、NSWorkspace、Keychain
- **网络：** URLSession（直接调用 LLM REST API，无第三方依赖）
- **最低系统版本：** macOS 13 Ventura

---

## 不在范围内（本版本）

- 翻译历史记录
- 多语言同时翻译
- 离线翻译模型
- iOS / iPadOS 支持
