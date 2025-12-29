import asyncio
import sounddevice as sd
import websockets

WS_URL = "ws://localhost:2700"
SAMPLE_RATE = 16000
CHANNELS = 1
BLOCKSIZE = 8000  # 0.5s of audio per frame (16kHz * 0.5)

async def send_audio(ws):
    with sd.RawInputStream(
        samplerate=SAMPLE_RATE,
        blocksize=BLOCKSIZE,
        dtype="int16",
        channels=CHANNELS
    ) as stream:
        print("🎤 Speak into the mic. Ctrl+C to stop.")
        while True:
            data, _ = stream.read(BLOCKSIZE)
            await ws.send(data.tobytes())

async def receive_messages(ws):
    async for message in ws:
        print("<<", message)

async def main():
    async with websockets.connect(WS_URL, max_size=None) as ws:
        await asyncio.gather(send_audio(ws), receive_messages(ws))

if __name__ == "__main__":
    asyncio.run(main())
