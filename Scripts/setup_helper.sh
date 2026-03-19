#!/bin/bash
# Setup script for LocalVoice Python helper.
# Creates a venv and installs dependencies.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HELPER_DIR="$PROJECT_DIR/Helper"
VENV_DIR="$HELPER_DIR/venv"

echo "=== LocalVoice Helper Setup ==="
echo "Helper dir: $HELPER_DIR"
echo "Venv dir:   $VENV_DIR"
echo ""

# Check Python version
PYTHON=$(command -v python3 || true)
if [ -z "$PYTHON" ]; then
    echo "ERROR: python3 not found. Install Python 3.10-3.12."
    exit 1
fi

PY_VERSION=$($PYTHON --version 2>&1)
echo "Using: $PY_VERSION"

# Create venv
if [ -d "$VENV_DIR" ]; then
    echo "Venv already exists. Updating..."
else
    echo "Creating virtual environment..."
    $PYTHON -m venv "$VENV_DIR"
fi

# Activate and install
source "$VENV_DIR/bin/activate"

echo ""
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r "$HELPER_DIR/requirements.txt"

echo ""
echo "=== Testing stub mode ==="

# Create a minimal test WAV for smoke testing
python3 -c "
import numpy as np
import soundfile as sf
# Generate 1 second of silence at 16kHz
samples = np.zeros(16000, dtype=np.float32)
sf.write('$HELPER_DIR/test.wav', samples, 16000)
print('Created test.wav')
"

# Test in stub mode
LOCALVOICE_STUB=1 python3 "$HELPER_DIR/voice_helper.py" --input "$HELPER_DIR/test.wav" --mode dictate
LOCALVOICE_STUB=1 python3 "$HELPER_DIR/voice_helper.py" --input "$HELPER_DIR/test.wav" --mode polish

echo ""
echo "=== Setup complete ==="
echo ""
echo "To test with real models, run:"
echo "  source $VENV_DIR/bin/activate"
echo "  python3 $HELPER_DIR/voice_helper.py --input /path/to/audio.wav --mode dictate"
echo ""
echo "First run will download models (~600MB for Parakeet, ~3GB for Qwen)."
