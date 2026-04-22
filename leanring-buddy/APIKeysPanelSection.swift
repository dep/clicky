//
//  APIKeysPanelSection.swift
//  leanring-buddy
//
//  Lets the user paste their own API keys for Anthropic, AssemblyAI,
//  and ElevenLabs. The section is always visible in the menu bar panel
//  so users can update keys without hunting through settings. Keys
//  live in the Keychain via `ClickyAPIKeyStore`.
//

import AppKit
import SwiftUI

struct APIKeysPanelSection: View {
    @ObservedObject var apiKeyStore: ClickyAPIKeyStore

    /// Controls whether the section is expanded. Collapsed by default
    /// once the minimum required key is present so the panel stays
    /// compact for the everyday "chat" state.
    @State private var isExpanded: Bool

    init(apiKeyStore: ClickyAPIKeyStore) {
        self.apiKeyStore = apiKeyStore
        // Auto-expand on first launch when no Anthropic key is present —
        // the user needs to see the fields to get started.
        _isExpanded = State(initialValue: !apiKeyStore.hasAnthropicAPIKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if isExpanded {
                keyFieldsStack
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Header (tap to expand/collapse)

    private var header: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 6) {
                Text("API KEYS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Colors.textTertiary)

                statusBadge

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    /// Shows "Missing" / "Ready" so users can tell at a glance whether
    /// they still need to paste a key without expanding the section.
    @ViewBuilder
    private var statusBadge: some View {
        if apiKeyStore.hasAnthropicAPIKey {
            HStack(spacing: 3) {
                Circle()
                    .fill(DS.Colors.success)
                    .frame(width: 5, height: 5)
                Text("Ready")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(DS.Colors.success)
            }
        } else {
            HStack(spacing: 3) {
                Circle()
                    .fill(DS.Colors.warning)
                    .frame(width: 5, height: 5)
                Text("Required")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(DS.Colors.warning)
            }
        }
    }

    // MARK: - Key Fields

    private var keyFieldsStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            APIKeyField(
                identifier: .anthropicAPIKey,
                subtitle: "Required — Claude chat",
                placeholder: "sk-ant-...",
                apiKeyStore: apiKeyStore
            )

            APIKeyField(
                identifier: .assemblyAIAPIKey,
                subtitle: "Optional — better voice transcription. Falls back to Apple Speech if empty.",
                placeholder: "AssemblyAI API key",
                apiKeyStore: apiKeyStore
            )

            APIKeyField(
                identifier: .elevenLabsAPIKey,
                subtitle: "Optional — voice replies. Text still streams if empty.",
                placeholder: "ElevenLabs API key",
                apiKeyStore: apiKeyStore
            )

            APIKeyField(
                identifier: .elevenLabsVoiceID,
                subtitle: "Voice ID from your ElevenLabs library. Only needed if voice replies are enabled.",
                placeholder: "e.g. 21m00Tcm4TlvDq8ikWAM",
                apiKeyStore: apiKeyStore,
                isSecure: false
            )

            Text("Keys live in your macOS Keychain. Nothing is sent anywhere except the provider you pasted the key for.")
                .font(.system(size: 10))
                .foregroundColor(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}

/// A single labeled field for entering one API key / voice ID. Supports
/// both secure (masked) and plain text modes so the voice ID can be
/// visible while actual secrets stay masked.
private struct APIKeyField: View {
    let identifier: ClickyAPIKeyIdentifier
    let subtitle: String
    let placeholder: String
    @ObservedObject var apiKeyStore: ClickyAPIKeyStore
    var isSecure: Bool = true

    /// Local editing state — only pushed to the key store on commit so
    /// we're not writing to the Keychain on every keystroke.
    @State private var inputValue: String = ""
    @State private var hasLoadedInitialValue: Bool = false
    @State private var isRevealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(identifier.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)

                if let helpURL = identifier.helpURL {
                    Button(action: {
                        NSWorkspace.shared.open(helpURL)
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .help("Open \(identifier.displayName) settings")
                }

                Spacer()

                // Allow users to toggle visibility on secure fields so
                // they can confirm what they pasted.
                if isSecure {
                    Button(action: {
                        isRevealed.toggle()
                    }) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .help(isRevealed ? "Hide" : "Reveal")
                }
            }

            inputField

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            if !hasLoadedInitialValue {
                inputValue = apiKeyStore.value(for: identifier) ?? ""
                hasLoadedInitialValue = true
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        Group {
            if isSecure && !isRevealed {
                SecureField(placeholder, text: $inputValue, onCommit: commitChange)
            } else {
                TextField(placeholder, text: $inputValue, onCommit: commitChange)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(DS.Colors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.small, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.small, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
        )
        // Commit on every change so users don't have to press Return —
        // pasting a key and tabbing away still persists it to the Keychain.
        .onChange(of: inputValue) { _, newInputValue in
            apiKeyStore.setValue(newInputValue, for: identifier)
        }
    }

    private func commitChange() {
        apiKeyStore.setValue(inputValue, for: identifier)
    }
}
