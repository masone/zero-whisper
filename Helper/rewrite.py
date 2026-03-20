"""
Text rewriting/polishing using a local Qwen model via mlx-lm.
Falls back to a stub for testing if mlx-lm is not installed.
"""

import os
import sys

_STUB_MODE = os.environ.get("ZEROWHISPER_STUB", "0") == "1"

# Model to use — Qwen2.5-1.5B-Instruct is small and fast on Apple Silicon
_MODEL_NAME = "Qwen/Qwen2.5-1.5B-Instruct"

# Cache the loaded model to avoid reloading on subsequent calls
_model_cache = {}

SYSTEM_PROMPT = (
    "Clean up this dictated text for readability. "
    "Preserve meaning exactly. Do not add facts. "
    "Keep the original language. Return only the final text."
)


def polish(text: str) -> str:
    """Polish/rewrite dictated text for readability.

    Args:
        text: Raw transcript from STT.

    Returns:
        Cleaned up text.
    """
    if _STUB_MODE:
        return _stub_polish(text)

    try:
        return _mlx_polish(text)
    except ImportError:
        print("[rewrite] mlx-lm not installed, using stub mode", file=sys.stderr)
        return _stub_polish(text)


def _mlx_polish(text: str) -> str:
    """Polish using mlx-lm with a local Qwen model."""
    from mlx_lm import load, generate

    if "model" not in _model_cache:
        model, tokenizer = load(_MODEL_NAME)
        _model_cache["model"] = model
        _model_cache["tokenizer"] = tokenizer
    else:
        model = _model_cache["model"]
        tokenizer = _model_cache["tokenizer"]

    # Build chat messages
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": text},
    ]

    prompt = tokenizer.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=True
    )

    response = generate(
        model,
        tokenizer,
        prompt=prompt,
        max_tokens=len(text.split()) * 3 + 50,  # reasonable limit
    )

    return response.strip()


def _stub_polish(text: str) -> str:
    """Return a stub polished version for testing."""
    # Simple stub: capitalize first letter of each sentence, add period if missing
    sentences = text.split(". ")
    polished = ". ".join(s.strip().capitalize() for s in sentences if s.strip())
    if polished and not polished.endswith("."):
        polished += "."
    return f"[polished] {polished}"
