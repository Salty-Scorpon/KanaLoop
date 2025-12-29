import argparse
import asyncio
import json
import wave

import sounddevice as sd
import websockets

WS_URL = "ws://localhost:2700"
SAMPLE_RATE = 16000
CHANNELS = 1
BLOCKSIZE = 8000  # 0.5s of audio per frame (16kHz * 0.5)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Send audio to the Vosk WebSocket service with optional grammar."
    )
    parser.add_argument("--ws-url", default=WS_URL, help="WebSocket URL.")
    parser.add_argument(
        "--grammar",
        default="",
        help="Comma-separated grammar list (e.g. あ,い,う).",
    )
    parser.add_argument(
        "--audio-file",
        default="",
        help="Optional WAV file (16kHz mono, 16-bit PCM).",
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate partial/final outputs against the grammar list.",
    )
    return parser.parse_args()


def parse_grammar(raw: str):
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


async def send_grammar(ws, grammar):
    if not grammar:
        return
    await ws.send(json.dumps({"type": "set_grammar", "grammar": grammar}))


async def stream_microphone(ws):
    with sd.RawInputStream(
        samplerate=SAMPLE_RATE,
        blocksize=BLOCKSIZE,
        dtype="int16",
        channels=CHANNELS,
    ) as stream:
        print("🎤 Speak into the mic. Ctrl+C to stop.")
        while True:
            data, _ = stream.read(BLOCKSIZE)
            await ws.send(bytes(data))


async def stream_wav_file(ws, audio_path):
    with wave.open(audio_path, "rb") as wav_file:
        if (
            wav_file.getframerate() != SAMPLE_RATE
            or wav_file.getnchannels() != CHANNELS
            or wav_file.getsampwidth() != 2
        ):
            raise ValueError(
                "Audio must be 16kHz mono 16-bit PCM WAV. "
                f"Got {wav_file.getframerate()}Hz, "
                f"{wav_file.getnchannels()}ch, "
                f"{wav_file.getsampwidth() * 8}-bit."
            )
        while True:
            data = wav_file.readframes(BLOCKSIZE)
            if not data:
                break
            await ws.send(data)


def is_text_in_grammar(text, grammar):
    if not grammar:
        return True
    return text in grammar


def token_outside_grammar(text, grammar):
    if not text or not grammar:
        return []
    tokens = text.split()
    return [token for token in tokens if token not in grammar]


async def receive_messages(ws, grammar, validate):
    async for message in ws:
        print("<<", message)
        if not validate:
            continue
        try:
            payload = json.loads(message)
        except json.JSONDecodeError:
            continue
        payload_type = payload.get("type")
        result = payload.get("result", {})
        text = result.get("text", "") if payload_type == "final" else result.get("partial", "")
        if payload_type in {"final", "partial"} and text:
            if not is_text_in_grammar(text, grammar):
                print(f"!! Output not in grammar: {text}")
            outside = token_outside_grammar(text, grammar)
            if outside:
                print(f"!! Tokens outside grammar: {outside}")


async def main():
    args = parse_args()
    grammar = parse_grammar(args.grammar)
    async with websockets.connect(args.ws_url, max_size=None) as ws:
        await send_grammar(ws, grammar)
        if args.audio_file:
            await asyncio.gather(
                stream_wav_file(ws, args.audio_file),
                receive_messages(ws, grammar, args.validate),
            )
        else:
            await asyncio.gather(
                stream_microphone(ws),
                receive_messages(ws, grammar, args.validate),
            )


if __name__ == "__main__":
    asyncio.run(main())
