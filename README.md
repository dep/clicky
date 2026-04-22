# Hi, this is Clicky.
It's an AI teacher that lives as a buddy next to your cursor. It can see your screen, talk to you, and even point at stuff. Kinda like having a real teacher next to you.

---

## Fork: Bring Your Own API Keys

This is a fork of the original Clicky that removes the hosted proxy requirement — you bring your own API keys directly. No middleman, no subscription, no black box. Just drop your keys into the app's settings and go.

You'll need:
- An Anthropic API key (Claude)
- An ElevenLabs API key (TTS voice)
- An AssemblyAI API key (speech-to-text)

The Cloudflare Worker proxy is still included for anyone who wants it, but it's entirely optional. Viva la open source! 🎉

Download under releases: https://github.com/dep/clicky/releases/latest

---

Original README continues...

Download it [here](https://www.clicky.so/) for free.

Here's the [original tweet](https://x.com/FarzaTV/status/2041314633978659092) that kinda blew up for a demo for more context.

![Clicky — an ai buddy that lives on your mac](clicky-demo.gif)

This is the open-source version of Clicky for those that want to hack on it, build their own features, or just see how it works under the hood.

## Bring your own API keys

Clicky is 100% bring-your-own-key. When you open the app you paste your API keys straight into the menu bar panel and they get stored in the macOS Keychain. The app then calls each provider's API directly from your machine — there's no middle server, nothing to deploy, nothing routed through anyone else.

You need one required key and two optional keys:

| Key | Where to get it | What it does |
|---|---|---|
| **Anthropic** (required) | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) | Powers the Claude chat that sees your screen and talks back |
| **ElevenLabs** (optional) | [elevenlabs.io/app/settings/api-keys](https://elevenlabs.io/app/settings/api-keys) + a voice ID | Spoken voice replies. Without it, responses are text-only |
| **AssemblyAI** (optional) | [assemblyai.com/app/api-keys](https://www.assemblyai.com/app/api-keys) | High-quality streaming transcription. Without it, falls back to Apple's on-device Speech framework |

Usage is billed directly to each provider account — Clicky itself has no backend.

## Get started with Claude Code

The fastest way to get this running is with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Once you get Claude running, paste this:

```
Hi Claude.

Clone https://github.com/farzaa/clicky.git into my current directory.

Then read the CLAUDE.md. I want to get Clicky running locally on my Mac.

Help me open it in Xcode and build it. After it runs I'll paste my
Anthropic API key into the menu bar panel.
```

That's it. It'll clone the repo, read the docs, and walk you through the whole setup. Once you're running you can just keep talking to it — build features, fix bugs, whatever. Go crazy.

## Manual setup

If you want to do it yourself, here's the deal.

### Prerequisites

- macOS 14.2+ (for ScreenCaptureKit)
- Xcode 15+
- An [Anthropic API key](https://console.anthropic.com/settings/keys) (required)
- Optionally: an [ElevenLabs API key](https://elevenlabs.io/app/settings/api-keys) + voice ID, and/or an [AssemblyAI API key](https://www.assemblyai.com/app/api-keys)

### 1. Open in Xcode and run

```bash
open leanring-buddy.xcodeproj
```

In Xcode:
1. Select the `leanring-buddy` scheme (yes, the typo is intentional, long story)
2. Set your signing team under Signing & Capabilities
3. Hit **Cmd + R** to build and run

The app will appear in your menu bar (not the dock). Click the icon to open the panel.

### 2. Grant permissions + paste your keys

Grant the four permissions the panel asks for:

- **Microphone** — for push-to-talk voice capture
- **Accessibility** — for the global keyboard shortcut (Control + Option)
- **Screen Recording** — for taking screenshots when you use the hotkey
- **Screen Content** — for ScreenCaptureKit access

Then expand the **API Keys** section in the panel and paste at least your Anthropic key. That's enough to chat. If you want spoken replies, add your ElevenLabs key and voice ID. If you want higher-quality transcription, add your AssemblyAI key.

Once keys are in, hold **Control + Option** anywhere on your Mac to talk to Clicky.

## Architecture

If you want the full technical breakdown, read `CLAUDE.md`. But here's the short version:

**Menu bar app** (no dock icon) with two `NSPanel` windows — one for the control panel dropdown, one for the full-screen transparent cursor overlay. Push-to-talk streams audio over a websocket to AssemblyAI (or Apple Speech as a fallback), sends the transcript + screenshot to Claude via streaming SSE, and plays the response through ElevenLabs TTS (if configured). Claude can embed `[POINT:x,y:label:screenN]` tags in its responses to make the cursor fly to specific UI elements across multiple monitors. All three APIs are called directly from the app using user-provided keys stored in the macOS Keychain.

## Project structure

```
leanring-buddy/             # Swift source (yes, the typo stays)
  CompanionManager.swift       # Central state machine
  CompanionPanelView.swift     # Menu bar panel UI
  APIKeysPanelSection.swift    # BYO API key input UI
  ClickyAPIKeyStore.swift      # Keychain-backed key storage
  ClaudeAPI.swift              # Claude streaming client (direct)
  ElevenLabsTTSClient.swift    # Text-to-speech playback (direct)
  OverlayWindow.swift          # Blue cursor overlay
  AssemblyAI*.swift            # Real-time transcription (direct)
  BuddyDictation*.swift        # Push-to-talk pipeline
worker/                     # Legacy Cloudflare Worker proxy — unused by the app now
CLAUDE.md                   # Full architecture doc (agents read this)
```

The `worker/` directory is left in the repo for reference but is no longer used by the Swift app. You can safely ignore or delete it.

## Contributing

PRs welcome. If you're using Claude Code, it already knows the codebase — just tell it what you want to build and point it at `CLAUDE.md`.

Got feedback? DM me on X [@farzatv](https://x.com/farzatv).
