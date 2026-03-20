# LocalVoice

A local-only macOS menubar app for push-to-talk speech-to-text. Hold a key to speak, release to transcribe and paste.

## Features

- **Push-to-talk**: Hold Right Option to record, release to transcribe
- **Dictate mode**: Raw transcript via Parakeet STT (Right Option)
- **Polish mode**: Transcript cleaned up by Qwen LLM (Right Option + Shift)
- **Local only**: No cloud services, all processing on-device
- **Menubar app**: Lives in the menubar, no dock icon
- **Clipboard safe**: Transcript always stays on your clipboard

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon Mac (M1/M2/M3/M4)
- Xcode (for building the Swift app)
- Python 3.10+ (for the ML helper)

## Setup

### 1. Set up the Python helper

```bash
./Scripts/setup_helper.sh
```

This creates a Python venv in `Helper/venv/` and installs dependencies. Models download automatically on first use (~600MB for Parakeet, ~3GB for Qwen).

### 2. Build and run the app

Open `LocalVoice/Package.swift` in Xcode, select the LocalVoice scheme and My Mac, then Cmd+R.

The app appears as a mic icon in your menubar. It auto-starts the helper server in the background.

### 3. Grant permissions

- **Microphone**: Grant when prompted
- **Accessibility**: System Settings > Privacy & Security > Accessibility > toggle LocalVoice on

## Usage

| Action | Hotkey |
|--------|--------|
| Dictate (raw transcript) | Hold Right Option (⌥) |
| Polish (cleaned up text) | Hold Right Option (⌥) + Shift (⇧) |

1. Focus the app where you want text inserted
2. Hold the hotkey
3. Speak
4. Release — text is transcribed and pasted

The transcript is always on your clipboard. If the paste misses the target, just Cmd+V manually. You can also re-copy the last result from the menubar dropdown.

## Architecture

```
Swift app (menubar)          HTTP            Python server (localhost:8426)
┌──────────────────┐    POST /transcribe    ┌─────────────────────┐
│ HotkeyManager    │ ─────────────────────> │ Parakeet STT        │
│ AudioRecorder    │ <──────────────────── │ Qwen rewrite (opt)  │
│ PasteManager     │       JSON response    │ Models stay warm    │
└──────────────────┘                        └─────────────────────┘
```

The app records mic audio to a temp 16-bit PCM WAV, sends the path to the helper server, and pastes the result via clipboard + simulated Cmd+V.

## Troubleshooting

- **Hotkey not working**: Check Accessibility permission in System Settings
- **No audio**: Check Microphone permission in System Settings
- **Slow first use**: Models are downloading. Subsequent uses are fast.
- **Helper not starting**: Make sure you ran `./Scripts/setup_helper.sh` first
- **Stub mode**: Set `LOCALVOICE_STUB=1` env var to test without models
