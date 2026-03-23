"""
Speech-to-text using parakeet-mlx (Apple Silicon optimized).
Falls back to a stub for testing if parakeet-mlx is not installed.

Loads WAV files with Python's built-in wave module — no ffmpeg required.
"""

import os
import sys
import wave

import numpy as np

# Flag to force stub mode for testing
_STUB_MODE = os.environ.get("ZEROWHISPER_STUB", "0") == "1"

# Cache the loaded model to avoid reloading on each call
_model_cache = {}

_MODEL_NAME = "mlx-community/parakeet-tdt-0.6b-v3"
_SAMPLE_RATE = 16000


def transcribe(wav_path: str) -> str:
    """Transcribe a WAV file to text.

    Args:
        wav_path: Path to a 16kHz mono 16-bit PCM WAV file.

    Returns:
        Transcribed text string.
    """
    if _STUB_MODE:
        return _stub_transcribe(wav_path)

    try:
        return _parakeet_transcribe(wav_path)
    except ImportError:
        print("[stt] parakeet-mlx not installed, using stub mode", file=sys.stderr)
        return _stub_transcribe(wav_path)


def _load_wav(wav_path: str) -> np.ndarray:
    """Load a 16-bit PCM WAV file into a float32 numpy array.

    Returns audio samples normalized to [-1, 1].
    """
    with wave.open(wav_path, "rb") as wf:
        n_channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        framerate = wf.getframerate()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)

    if sampwidth != 2:
        raise ValueError(f"Expected 16-bit PCM WAV, got sample width {sampwidth * 8}-bit")

    samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0

    # Convert stereo to mono if needed
    if n_channels > 1:
        samples = samples.reshape(-1, n_channels).mean(axis=1)

    # Resample if not 16kHz
    if framerate != _SAMPLE_RATE:
        duration = len(samples) / framerate
        target_len = int(duration * _SAMPLE_RATE)
        indices = np.linspace(0, len(samples) - 1, target_len)
        samples = np.interp(indices, np.arange(len(samples)), samples)

    return samples


def _parakeet_transcribe(wav_path: str) -> str:
    """Transcribe using parakeet-mlx, bypassing ffmpeg by loading WAV ourselves."""
    import mlx.core as mx
    from parakeet_mlx import from_pretrained
    from parakeet_mlx.audio import get_logmel

    if "model" not in _model_cache:
        print("[stt] Loading Parakeet model...", file=sys.stderr)
        _model_cache["model"] = from_pretrained(_MODEL_NAME)

    model = _model_cache["model"]

    # Load WAV with stdlib, convert to MLX array
    audio_np = _load_wav(wav_path)
    min_samples = _SAMPLE_RATE // 2  # 0.5s minimum
    if len(audio_np) < min_samples:
        return ""
    audio_mx = mx.array(audio_np)

    # Convert to mel spectrogram
    mel = get_logmel(audio_mx, model.preprocessor_config)

    # Run inference via generate() — bypasses ffmpeg-based transcribe()
    results = model.generate(mel)

    # generate() returns a list of AlignedResult
    if results and len(results) > 0:
        result = results[0]
        if hasattr(result, "text"):
            return result.text.strip()
        return str(result).strip()

    return ""


def _stub_transcribe(wav_path: str) -> str:
    """Return a stub transcript for testing without models."""
    file_size = os.path.getsize(wav_path)
    return f"[stub transcript from {os.path.basename(wav_path)}, {file_size} bytes]"
