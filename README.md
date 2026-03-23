# ZeroWhisper

Free, local-only, push-to-talk speech-to-text for macOS. Zero cloud. Zero cost. Zero telemetry.

> Unlike SuperWhisper et al, this costs zero. Runs fully locally. No API keys needed.

## Features

- **Push-to-talk**: Hold Right Option to record, release to transcribe
- **Dictate mode**: Raw transcript via Parakeet STT (Right Option)
- **Polish mode**: Transcript cleaned up by Qwen LLM (Right Option + Shift)
- **100% local**: All processing on-device, nothing leaves your machine
- **Menubar app**: Lives in the menubar, no dock icon
- **Clipboard safe**: Transcript always stays on your clipboard

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon Mac (M1/M2/M3/M4)
- Xcode (for building)
- Python 3.10+ with pip

## Setup

```bash
git clone <repo-url> && cd zero-whisper
./Scripts/setup.sh
```

That's it. Installs Python dependencies, downloads ML models (~4GB), builds the app, and outputs `build/ZeroWhisper.app`.

Then:
```bash
open build/ZeroWhisper.app
```

Or copy to Applications:
```bash
cp -r build/ZeroWhisper.app /Applications/
```

On first launch, grant **Microphone** (prompted automatically) and **Accessibility** (System Settings > Privacy & Security > Accessibility > toggle ZeroWhisper on).

## Usage

| Action | Hotkey |
|--------|--------|
| Dictate (raw transcript) | Hold Right Option (⌥) |
| Polish (cleaned up text) | Hold Right Option (⌥) + Shift (⇧) |

1. Focus the app where you want text inserted
2. Hold the hotkey
3. Speak
4. Release — text is transcribed and pasted

Text is always on your clipboard. If the paste misses, just Cmd+V manually.

## Architecture

```
Swift app (menubar)          HTTP            Python server (localhost:8426)
┌──────────────────┐    POST /transcribe    ┌─────────────────────┐
│ HotkeyManager    │ ─────────────────────> │ Parakeet STT        │
│ AudioRecorder    │ <───────────────────── │ Qwen rewrite (opt)  │
│ PasteManager     │       JSON response    │ Models stay warm    │
└──────────────────┘                        └─────────────────────┘
```

## Troubleshooting

- **Hotkey not working**: Check Accessibility permission in System Settings
- **No audio**: Check Microphone permission
- **Slow first use**: Models are loading into memory. Subsequent uses are fast.
- **Helper not starting**: Run `./Scripts/setup.sh` to rebuild
