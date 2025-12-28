#!/usr/bin/env python3
import asyncio
import json
import logging
import os

import websockets
from vosk import KaldiRecognizer, Model


MODEL_PATH = "/models/vosk-model-small-ja-0.22"
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


async def main():
    async with websockets.serve(handle_connection, HOST, PORT):
        logging.info("Vosk server ready")
        logging.info("Listening on ws://%s:%s", HOST, PORT)
        logging.info("Model path: %s", MODEL_PATH)
        await asyncio.Future()


if __name__ == "__main__":
    if not os.path.isdir(MODEL_PATH):
        raise SystemExit(f"Model path not found: {MODEL_PATH}")
    MODEL = Model(MODEL_PATH)
    asyncio.run(main())
