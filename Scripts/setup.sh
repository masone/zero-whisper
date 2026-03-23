#!/bin/bash
# ZeroWhisper — full setup & build
# Run this once after cloning. Builds the app and installs Python dependencies.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HELPER_DIR="$PROJECT_DIR/Helper"
VENV_DIR="$HELPER_DIR/venv"
SWIFT_DIR="$PROJECT_DIR/ZeroWhisper"
BUILD_DIR="/tmp/zerowhisper-build"
APP_DIR="$PROJECT_DIR/build/ZeroWhisper.app"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║         ZeroWhisper Setup            ║"
echo "  ║  Zero cloud. Zero cost. Zero keys.   ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# --- Check requirements ---

# Python
PYTHON=$(command -v python3 || true)
if [ -z "$PYTHON" ]; then
    echo "ERROR: python3 not found. Install Python 3.10+."
    exit 1
fi
echo "Python:  $($PYTHON --version 2>&1)"

# Swift
if ! command -v swift &>/dev/null; then
    echo "ERROR: swift not found. Install Xcode or Command Line Tools."
    exit 1
fi
echo "Swift:   $(swift --version 2>&1 | head -1)"

# --- Python helper ---

echo ""
echo "=== Setting up Python helper ==="

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    $PYTHON -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
"$VENV_DIR/bin/python" -m pip install --upgrade pip -q
"$VENV_DIR/bin/python" -m pip install -r "$HELPER_DIR/requirements.txt"
echo "Python dependencies installed."

# --- Download ML models ---

echo ""
echo "=== Downloading ML models (first time only) ==="

"$VENV_DIR/bin/python" -c "
from parakeet_mlx import from_pretrained
print('Downloading Parakeet STT model...')
from_pretrained('mlx-community/parakeet-tdt-0.6b-v3')
print('Parakeet model ready.')
"

"$VENV_DIR/bin/python" -c "
from mlx_lm import load
print('Downloading Qwen rewrite model...')
load('Qwen/Qwen2.5-1.5B-Instruct')
print('Qwen model ready.')
"

# --- Build Swift app ---

echo ""
echo "=== Building ZeroWhisper.app ==="

cd "$SWIFT_DIR"
swift build --build-path "$BUILD_DIR" -c release 2>&1 | tail -5

# Create .app bundle
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/arm64-apple-macosx/release/ZeroWhisper" "$APP_DIR/Contents/MacOS/"
cp "$SWIFT_DIR/ZeroWhisper/Info.plist" "$APP_DIR/Contents/"
cp "$SWIFT_DIR/ZeroWhisper/AppIcon.icns" "$APP_DIR/Contents/Resources/" 2>/dev/null || true

echo "Built: $APP_DIR"

# --- Done ---

echo ""
echo "=== Setup complete ==="
echo ""
echo "To run:"
echo "  open $APP_DIR"
echo ""
echo "Or copy to Applications:"
echo "  cp -r $APP_DIR /Applications/"
echo ""
echo "First launch will:"
echo "  - Ask for Microphone permission"
echo "  - Prompt for Accessibility permission (must enable manually)"
echo ""
echo "Hold Right Option (⌥) to dictate. Add Shift for polish mode."
