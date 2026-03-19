# LocalVoice

A local-only macOS menubar app for push-to-talk speech-to-text. Hold a key to speak, release to transcribe and paste.

## Features

- **Push-to-talk**: Hold Right Option to record, release to transcribe
- **Dictate mode**: Raw transcript via Parakeet STT (Right Option)
- **Polish mode**: Transcript cleaned up by Qwen LLM (Right Option + Shift)
- **Local only**: No cloud services, all processing on-device
- **Menubar app**: Lives in the menubar, no dock icon

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon Mac (M1/M2/M3/M4) recommended for MLX acceleration
- Xcode (for building the Swift app)
- Python 3.10–3.12 (for the ML helper)

## Setup

### 1. Build the Swift app

Open `LocalVoice/LocalVoice.xcodeproj` in Xcode, then Build & Run (Cmd+R).

The app will appear in your menubar.

### 2. Set up the Python helper

```bash
./Scripts/setup_helper.sh
```

This creates a Python virtual environment in `Helper/venv/` and installs dependencies.

First run with real models will download:
- ~600MB for Parakeet STT model
- ~3GB for Qwen 2.5 1.5B rewrite model

### 3. Grant permissions

On first use, the app will need:
- **Microphone access**: Grant when prompted, or via System Settings > Privacy > Microphone
- **Accessibility access**: Required for the global hotkey and paste simulation. Grant via System Settings > Privacy > Accessibility

## Usage

| Action | Hotkey |
|--------|--------|
| Dictate (raw transcript) | Hold Right Option (⌥) |
| Polish (cleaned up text) | Hold Right Option (⌥) + Shift (⇧) |

1. Focus the app where you want text inserted (TextEdit, Notes, browser, etc.)
2. Hold the hotkey
3. Speak
4. Release — text is transcribed and pasted

## Architecture

```
LocalVoice/          Swift/SwiftUI menubar app
  ├── AppState       State machine coordinator
  ├── AudioRecorder  AVAudioEngine → 16kHz mono WAV
  ├── HotkeyManager  NSEvent global monitor for Right Option
  ├── HelperClient   Invokes Python helper, parses JSON
  ├── PasteManager   Clipboard + CGEvent Cmd+V
  └── MenuBarView    Menubar UI

Helper/              Python ML helper
  ├── voice_helper   CLI entry point
  ├── stt            Parakeet-MLX transcription
  └── rewrite        Qwen rewriting via mlx-lm
```

## Troubleshooting

- **Hotkey not working**: Check Accessibility permission in System Settings
- **No audio**: Check Microphone permission in System Settings
- **Helper not found**: Check the helper path in Settings > General
- **Slow first run**: Models are downloading (~4GB total). Subsequent runs are fast.
- **Stub mode**: Set `LOCALVOICE_STUB=1` env var to test without models
