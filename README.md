# Transify

Transify is a macOS menu bar app that translates selected text in any app with a global hotkey.

## Features

- Translate selected text from anywhere on macOS
- Replace text in editable fields directly
- Show a popup for read-only selections
- Undo the latest replacement
- Configure target language, model, and provider API keys

## Tech Stack

- Swift 5.9
- SwiftUI
- macOS Accessibility APIs
- URLSession
- xcodegen

## Project Structure

- `Transify/`: app source code
- `TransifyTests/`: unit tests
- `docs/`: product design and implementation notes
- `project.yml`: XcodeGen project definition

## Getting Started

1. Generate the Xcode project with `xcodegen generate`.
2. Open `Transify.xcodeproj` in Xcode.
3. Build and run the `Transify` scheme.
4. Grant Accessibility permission when prompted.
5. Add an API key for your selected model provider in Settings.

## Notes

- The app currently stores provider API keys in `UserDefaults`.
- `.gitignore` excludes local Xcode user files and local Codex/Claude settings.
