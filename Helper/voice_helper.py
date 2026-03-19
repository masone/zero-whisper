#!/usr/bin/env python3
"""
LocalVoice helper CLI.
Accepts a WAV file and returns a JSON transcript via stdout.

Usage:
    python3 voice_helper.py --input /path/to/audio.wav --mode dictate
    python3 voice_helper.py --input /path/to/audio.wav --mode polish
"""

import argparse
import json
import sys
import os


def main():
    parser = argparse.ArgumentParser(description="LocalVoice speech helper")
    parser.add_argument("--input", required=True, help="Path to WAV file")
    parser.add_argument("--mode", choices=["dictate", "polish"], default="dictate",
                        help="Mode: dictate (STT only) or polish (STT + rewrite)")
    args = parser.parse_args()

    # Validate input file
    if not os.path.exists(args.input):
        output_error(f"Input file not found: {args.input}")
        return

    try:
        # Step 1: Transcribe
        from stt import transcribe
        transcript = transcribe(args.input)

        if not transcript or not transcript.strip():
            output_error("Transcription returned empty result")
            return

        # Step 2: Optionally polish
        if args.mode == "polish":
            from rewrite import polish
            output_text = polish(transcript)
            output_result(mode="polish", transcript=transcript, output_text=output_text)
        else:
            output_result(mode="dictate", transcript=transcript, output_text=transcript)

    except ImportError as e:
        output_error(f"Missing dependency: {e}. Run setup_helper.sh to install.")
    except Exception as e:
        output_error(str(e))


def output_result(mode: str, transcript: str, output_text: str):
    result = {
        "ok": True,
        "mode": mode,
        "transcript": transcript,
        "output_text": output_text,
    }
    print(json.dumps(result))


def output_error(message: str):
    result = {
        "ok": False,
        "error": message,
    }
    print(json.dumps(result))
    sys.exit(1)


if __name__ == "__main__":
    main()
