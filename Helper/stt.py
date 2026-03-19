"""
Speech-to-text using parakeet-mlx (Apple Silicon optimized).
Falls back to a stub for testing if parakeet-mlx is not installed.
"""

import os

# Flag to force stub mode for testing
_STUB_MODE = os.environ.get("LOCALVOICE_STUB", "0") == "1"


def transcribe(wav_path: str) -> str:
    """Transcribe a WAV file to text.

    Args:
        wav_path: Path to a 16kHz mono WAV file.

    Returns:
        Transcribed text string.
    """
    if _STUB_MODE:
        return _stub_transcribe(wav_path)

    try:
        return _parakeet_transcribe(wav_path)
    except ImportError:
        print("[stt] parakeet-mlx not installed, using stub mode", file=__import__('sys').stderr)
        return _stub_transcribe(wav_path)


def _parakeet_transcribe(wav_path: str) -> str:
    """Transcribe using parakeet-mlx."""
    from parakeet_mlx import transcribe as pk_transcribe

    result = pk_transcribe(wav_path)

    # parakeet-mlx returns different types depending on version
    if isinstance(result, str):
        return result.strip()
    elif isinstance(result, dict):
        return result.get("text", "").strip()
    elif hasattr(result, "text"):
        return result.text.strip()
    else:
        return str(result).strip()


def _stub_transcribe(wav_path: str) -> str:
    """Return a stub transcript for testing without models."""
    file_size = os.path.getsize(wav_path)
    return f"[stub transcript from {os.path.basename(wav_path)}, {file_size} bytes]"
