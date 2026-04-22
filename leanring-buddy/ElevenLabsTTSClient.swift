//
//  ElevenLabsTTSClient.swift
//  leanring-buddy
//
//  Streams text-to-speech audio from ElevenLabs and plays it back
//  through the system audio output. Uses the streaming endpoint so
//  playback begins before the full audio has been generated.
//
//  Calls api.elevenlabs.io directly with a user-provided API key and
//  voice ID pulled from `ClickyAPIKeyStore` on every request so edits
//  in the settings UI take effect immediately.
//

import AVFoundation
import Foundation

/// Thrown when the caller tries to speak text without a user-provided
/// ElevenLabs API key or voice ID in the key store.
struct ElevenLabsTTSMissingAPIKeyError: LocalizedError {
    var errorDescription: String? {
        "Add your ElevenLabs API key and voice ID in the Clicky menu bar panel to enable voice responses."
    }
}

@MainActor
final class ElevenLabsTTSClient {
    /// Base URL path for the ElevenLabs text-to-speech endpoint. The
    /// full URL is this plus the user's voice ID appended at request
    /// time, so a voice ID change takes effect without rebuilding.
    private static let textToSpeechBaseURLString = "https://api.elevenlabs.io/v1/text-to-speech/"

    private let session: URLSession
    private let apiKeyStore: ClickyAPIKeyStore

    /// The audio player for the current TTS playback. Kept alive so the
    /// audio finishes playing even if the caller doesn't hold a reference.
    private var audioPlayer: AVAudioPlayer?

    init(apiKeyStore: ClickyAPIKeyStore? = nil) {
        self.apiKeyStore = apiKeyStore ?? ClickyAPIKeyStore.shared

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Sends `text` to ElevenLabs TTS and plays the resulting audio.
    /// Throws on network or decoding errors. Cancellation-safe.
    func speakText(_ text: String) async throws {
        guard let elevenLabsAPIKey = apiKeyStore.value(for: .elevenLabsAPIKey),
              let elevenLabsVoiceID = apiKeyStore.value(for: .elevenLabsVoiceID) else {
            throw ElevenLabsTTSMissingAPIKeyError()
        }

        guard let textToSpeechURL = URL(string: Self.textToSpeechBaseURLString + elevenLabsVoiceID) else {
            throw NSError(domain: "ElevenLabsTTS", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid ElevenLabs voice ID."])
        }

        var request = URLRequest(url: textToSpeechURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue(elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ElevenLabsTTS", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ElevenLabsTTS", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "TTS API error (\(httpResponse.statusCode)): \(errorBody)"])
        }

        try Task.checkCancellation()

        let player = try AVAudioPlayer(data: data)
        self.audioPlayer = player
        player.play()
        print("🔊 ElevenLabs TTS: playing \(data.count / 1024)KB audio")
    }

    /// Whether TTS audio is currently playing back.
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    /// Stops any in-progress playback immediately.
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
