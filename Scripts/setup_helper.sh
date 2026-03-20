#!/bin/bash
# Setup script for ZeroWhisper Python helper.
# Creates a venv and installs dependencies.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HELPER_DIR="$PROJECT_DIR/Helper"
VENV_DIR="$HELPER_DIR/venv"

echo "=== ZeroWhisper Helper Setup ==="

# Check Python version
PYTHON=$(command -v python3 || true)
if [ -z "$PYTHON" ]; then
    echo "ERROR: python3 not found. Install Python 3.10+."
    exit 1
fi

echo "Using: $($PYTHON --version 2>&1)"

# Create venv
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    $PYTHON -m venv "$VENV_DIR"
fi

# Install dependencies
source "$VENV_DIR/bin/activate"
pip install --upgrade pip -q
pip install -r "$HELPER_DIR/requirements.txt"

echo ""
echo "Done. Models will download automatically on first use."
echo "Run the app from Xcode — the helper server starts automatically."
