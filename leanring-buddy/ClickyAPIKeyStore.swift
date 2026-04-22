//
//  ClickyAPIKeyStore.swift
//  leanring-buddy
//
//  User-provided API keys for Anthropic, AssemblyAI, and ElevenLabs.
//  Stored in the macOS Keychain so they persist across launches and are
//  never written to disk in plaintext. The app calls each provider's API
//  directly with the user's own key — there is no server-side proxy.
//

import Combine
import Foundation
import Security
import SwiftUI

/// A string identifier for each secret the app stores. Each identifier
/// maps 1:1 to a Keychain account name, so renaming one would orphan
/// the previous entry on existing installs.
enum ClickyAPIKeyIdentifier: String, CaseIterable {
    case anthropicAPIKey = "anthropic_api_key"
    case assemblyAIAPIKey = "assemblyai_api_key"
    case elevenLabsAPIKey = "elevenlabs_api_key"
    case elevenLabsVoiceID = "elevenlabs_voice_id"

    /// Human-readable label shown in the settings UI.
    var displayName: String {
        switch self {
        case .anthropicAPIKey:
            return "Anthropic API Key"
        case .assemblyAIAPIKey:
            return "AssemblyAI API Key"
        case .elevenLabsAPIKey:
            return "ElevenLabs API Key"
        case .elevenLabsVoiceID:
            return "ElevenLabs Voice ID"
        }
    }

    /// Where the user can go to obtain this value.
    var helpURL: URL? {
        switch self {
        case .anthropicAPIKey:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .assemblyAIAPIKey:
            return URL(string: "https://www.assemblyai.com/app/api-keys")
        case .elevenLabsAPIKey:
            return URL(string: "https://elevenlabs.io/app/settings/api-keys")
        case .elevenLabsVoiceID:
            return URL(string: "https://elevenlabs.io/app/voice-library")
        }
    }
}

/// Observable store for user-provided API keys. Reads once on init and
/// writes through to the Keychain on every change so the next launch
/// sees the same values.
@MainActor
final class ClickyAPIKeyStore: ObservableObject {
    /// Shared singleton — API clients and the settings UI both reach for
    /// the same instance so updates in the UI propagate to live clients.
    static let shared = ClickyAPIKeyStore()

    /// The Keychain service string used for every entry the app stores.
    /// Kept internal because tests and the store itself are the only
    /// callers that need to know about it.
    private static let keychainServiceName = "so.clicky.apikeys"

    @Published private(set) var anthropicAPIKey: String = ""
    @Published private(set) var assemblyAIAPIKey: String = ""
    @Published private(set) var elevenLabsAPIKey: String = ""
    @Published private(set) var elevenLabsVoiceID: String = ""

    private init() {
        self.anthropicAPIKey = Self.readFromKeychain(.anthropicAPIKey) ?? ""
        self.assemblyAIAPIKey = Self.readFromKeychain(.assemblyAIAPIKey) ?? ""
        self.elevenLabsAPIKey = Self.readFromKeychain(.elevenLabsAPIKey) ?? ""
        self.elevenLabsVoiceID = Self.readFromKeychain(.elevenLabsVoiceID) ?? ""
    }

    // MARK: - Public API

    /// Returns true when the minimum viable key (Anthropic) is present.
    /// Claude is the only key the app truly cannot operate without —
    /// ElevenLabs TTS and AssemblyAI STT are both optional (Apple Speech
    /// fallback exists for transcription, and TTS can be skipped).
    var hasAnthropicAPIKey: Bool {
        !anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAssemblyAIAPIKey: Bool {
        !assemblyAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasElevenLabsAPIKey: Bool {
        !elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !elevenLabsVoiceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns the current value (trimmed of whitespace) for `identifier`,
    /// or `nil` if it is unset. API clients should call this right before
    /// making a request so they always see the latest user-provided value.
    func value(for identifier: ClickyAPIKeyIdentifier) -> String? {
        let rawValue: String
        switch identifier {
        case .anthropicAPIKey:
            rawValue = anthropicAPIKey
        case .assemblyAIAPIKey:
            rawValue = assemblyAIAPIKey
        case .elevenLabsAPIKey:
            rawValue = elevenLabsAPIKey
        case .elevenLabsVoiceID:
            rawValue = elevenLabsVoiceID
        }
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    /// Persist a new value for `identifier`. Passing an empty string
    /// clears the entry from the Keychain entirely so the next launch
    /// sees an unset value rather than an empty string.
    func setValue(_ newValue: String, for identifier: ClickyAPIKeyIdentifier) {
        let trimmedNewValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch identifier {
        case .anthropicAPIKey:
            anthropicAPIKey = trimmedNewValue
        case .assemblyAIAPIKey:
            assemblyAIAPIKey = trimmedNewValue
        case .elevenLabsAPIKey:
            elevenLabsAPIKey = trimmedNewValue
        case .elevenLabsVoiceID:
            elevenLabsVoiceID = trimmedNewValue
        }

        if trimmedNewValue.isEmpty {
            Self.deleteFromKeychain(identifier)
        } else {
            Self.writeToKeychain(trimmedNewValue, for: identifier)
        }
    }

    // MARK: - Keychain

    /// Builds the query dictionary shared between read, write, and delete
    /// operations. `kSecClassGenericPassword` is the right class for
    /// opaque API tokens — they're not tied to a server or protocol.
    private static func baseKeychainQuery(for identifier: ClickyAPIKeyIdentifier) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: identifier.rawValue
        ]
    }

    private static func readFromKeychain(_ identifier: ClickyAPIKeyIdentifier) -> String? {
        var query = baseKeychainQuery(for: identifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var resultRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &resultRef)

        guard status == errSecSuccess,
              let data = resultRef as? Data,
              let storedValue = String(data: data, encoding: .utf8) else {
            return nil
        }

        return storedValue
    }

    private static func writeToKeychain(_ value: String, for identifier: ClickyAPIKeyIdentifier) {
        guard let valueData = value.data(using: .utf8) else { return }

        // Try update first; if no existing entry, fall through to add.
        let updateQuery = baseKeychainQuery(for: identifier)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: valueData
        ]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        // No existing entry — create one. kSecAttrAccessibleAfterFirstUnlock
        // is the right accessibility for background menu bar apps that
        // may be relaunched on login before the user unlocks again.
        var addQuery = baseKeychainQuery(for: identifier)
        addQuery[kSecValueData as String] = valueData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func deleteFromKeychain(_ identifier: ClickyAPIKeyIdentifier) {
        let query = baseKeychainQuery(for: identifier)
        _ = SecItemDelete(query as CFDictionary)
    }
}
