#!/usr/bin/env python3
import asyncio
import json
import logging
import os
import sys
from pathlib import Path

import websockets
from vosk import KaldiRecognizer, Model


MODEL_NAME = "vosk-model-small-ja-0.22"
MODEL_ENV_VAR = "KANALOOP_MODEL_PATH"
DEFAULT_MODEL_ROOT = Path("/models")
HOST = "localhost"
PORT = 2700
SAMPLE_RATE = 16000


logging.basicConfig(level=logging.INFO, format="%(message)s")


async def handle_connection(websocket):
    recognizer = KaldiRecognizer(MODEL, SAMPLE_RATE)
    async for message in websocket:
        if isinstance(message, str):
            continue
        if recognizer.AcceptWaveform(message):
            result = json.loads(recognizer.Result())
            await websocket.send(json.dumps({"type": "final", "result": result}))
        else:
            result = json.loads(recognizer.PartialResult())
            await websocket.send(json.dumps({"type": "partial", "result": result}))


def resolve_model_path() -> Path:
    candidates = []
    env_value = os.environ.get(MODEL_ENV_VAR)
    if env_value:
        env_path = Path(env_value).expanduser()
        if env_path.name == MODEL_NAME:
            candidates.append(env_path)
        else:
            candidates.append(env_path / MODEL_NAME)

    candidates.append(DEFAULT_MODEL_ROOT / MODEL_NAME)

    bundle_root = getattr(sys, "_MEIPASS", None)
    if bundle_root:
        candidates.append(Path(bundle_root) / "models" / MODEL_NAME)

    executable_root = Path(sys.executable).resolve().parent
    candidates.append(executable_root / "models" / MODEL_NAME)
    candidates.append(executable_root.parent / "models" / MODEL_NAME)

    for candidate in candidates:
        if candidate.is_dir():
            return candidate
    raise SystemExit(
        "Model path not found. Checked:\n"
        + "\n".join(str(candidate) for candidate in candidates)
    )


async def main():
    async with websockets.serve(handle_connection, HOST, PORT):
        logging.info("Vosk server ready")
        logging.info("Listening on ws://%s:%s", HOST, PORT)
        logging.info("Model path: %s", MODEL_PATH)
        await asyncio.Future()


if __name__ == "__main__":
    MODEL_PATH = resolve_model_path()
    MODEL = Model(str(MODEL_PATH))
    asyncio.run(main())
