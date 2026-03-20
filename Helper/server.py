#!/usr/bin/env python3
"""
ZeroWhisper helper — persistent HTTP server.
Keeps Parakeet (and optionally Qwen) models warm in memory.

Usage:
    python3 server.py [--port 8426] [--preload]

The server exposes:
    POST /transcribe  { "input": "/path/to.wav", "mode": "dictate"|"polish" }
    GET  /health
"""

import argparse
import json
import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

# Add parent dir so stt/rewrite imports work
sys.path.insert(0, os.path.dirname(__file__))

DEFAULT_PORT = 8426


class HelperHandler(BaseHTTPRequestHandler):
    """Handle transcription requests."""

    def do_GET(self):
        if self.path == "/health":
            self._json_response({"ok": True, "status": "ready"})
        else:
            self._json_response({"ok": False, "error": "not found"}, code=404)

    def do_POST(self):
        if self.path != "/transcribe":
            self._json_response({"ok": False, "error": "not found"}, code=404)
            return

        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length > 0 else {}
        except (json.JSONDecodeError, ValueError):
            self._json_response({"ok": False, "error": "invalid JSON body"}, code=400)
            return

        wav_path = body.get("input", "")
        mode = body.get("mode", "dictate")

        if not wav_path:
            self._json_response({"ok": False, "error": "missing 'input' field"}, code=400)
            return

        if not os.path.exists(wav_path):
            self._json_response({"ok": False, "error": f"file not found: {wav_path}"}, code=400)
            return

        try:
            from stt import transcribe
            transcript = transcribe(wav_path)

            if not transcript or not transcript.strip():
                self._json_response({"ok": False, "error": "transcription returned empty"}, code=500)
                return

            if mode == "polish":
                from rewrite import polish
                output_text = polish(transcript)
                self._json_response({
                    "ok": True,
                    "mode": "polish",
                    "transcript": transcript,
                    "output_text": output_text,
                })
            else:
                self._json_response({
                    "ok": True,
                    "mode": "dictate",
                    "transcript": transcript,
                    "output_text": transcript,
                })

        except Exception as e:
            self._json_response({"ok": False, "error": str(e)}, code=500)

    def _json_response(self, data, code=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Log to stderr so it doesn't pollute JSON output
        print(f"[helper] {args[0]}", file=sys.stderr)


def preload_models():
    """Pre-load Parakeet model so first request is fast."""
    print("[helper] Pre-loading Parakeet model...", file=sys.stderr)
    try:
        from stt import _model_cache, _STUB_MODE, _MODEL_NAME
        if not _STUB_MODE:
            from parakeet_mlx import from_pretrained
            if "model" not in _model_cache:
                _model_cache["model"] = from_pretrained(_MODEL_NAME)
                print("[helper] Parakeet model loaded.", file=sys.stderr)
    except ImportError:
        print("[helper] parakeet-mlx not available, will use stub.", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="ZeroWhisper helper server")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--preload", action="store_true",
                        help="Pre-load models on startup")
    args = parser.parse_args()

    if args.preload:
        preload_models()

    server = HTTPServer(("127.0.0.1", args.port), HelperHandler)
    print(f"[helper] Listening on http://127.0.0.1:{args.port}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[helper] Shutting down.", file=sys.stderr)
        server.shutdown()


if __name__ == "__main__":
    main()
