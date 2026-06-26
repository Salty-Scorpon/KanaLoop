from __future__ import annotations

from pathlib import Path
from typing import Any
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile

SAFE_FILENAME_RE = re.compile(r"[^0-9A-Za-z._-]+")
DEFAULT_AUDIO_KEY = "meaning_en"
DEFAULT_TTS_ENGINE = "espeak-ng"
FALLBACK_TTS_ENGINE = "espeak"
SUPPORTED_FORMATS = ("wav", "mp3")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def default_data_path() -> Path:
    return repo_root() / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json"


def default_audio_output() -> Path:
    return repo_root() / "kana-loop" / "assets" / "audio" / "kanji_vocab" / DEFAULT_AUDIO_KEY


def default_asset_root() -> Path:
    return repo_root() / "kana-loop"


def load_entries(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"Expected {path} to contain a JSON array.")
    entries: list[dict[str, Any]] = []
    for index, entry in enumerate(data):
        if not isinstance(entry, dict):
            raise ValueError(f"Entry {index} is not a JSON object.")
        entries.append(entry)
    return entries


def save_entries(path: Path, entries: list[dict[str, Any]]) -> None:
    path.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def normalize_tts_text(value: Any) -> str:
    return " ".join(str(value or "").split()).strip()


def safe_filename(text: str, extension: str) -> str:
    stem = SAFE_FILENAME_RE.sub("_", text.lower()).strip("._-")
    stem = stem[:64].strip("._-") or "meaning"
    digest = hashlib.sha1(text.encode("utf-8")).hexdigest()[:10]
    return f"{stem}_{digest}.{extension}"


def res_path_for(asset_root: Path, path: Path) -> str:
    return "res://" + path.resolve().relative_to(asset_root.resolve()).as_posix()


def resolve_tts_engine(engine: str) -> str:
    resolved = shutil.which(engine)
    if resolved:
        return resolved
    if engine == DEFAULT_TTS_ENGINE:
        fallback = shutil.which(FALLBACK_TTS_ENGINE)
        if fallback:
            return fallback
    raise FileNotFoundError(
        f"Could not find local TTS engine '{engine}'. Install espeak-ng or pass --engine with another espeak-compatible binary."
    )


def require_ffmpeg() -> str:
    resolved = shutil.which("ffmpeg")
    if not resolved:
        raise FileNotFoundError("MP3 output requires ffmpeg. Install ffmpeg or use --format wav.")
    return resolved


def synthesize_wav(
    engine_path: str,
    text: str,
    output_path: Path,
    voice: str,
    speed: int,
    pitch: int,
    amplitude: int,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        engine_path,
        "-v",
        voice,
        "-s",
        str(speed),
        "-p",
        str(pitch),
        "-a",
        str(amplitude),
        "-w",
        str(output_path),
        text,
    ]
    subprocess.run(command, check=True)


def convert_wav_to_mp3(ffmpeg_path: str, wav_path: Path, mp3_path: Path, bitrate: str) -> None:
    mp3_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        ffmpeg_path,
        "-y",
        "-loglevel",
        "error",
        "-i",
        str(wav_path),
        "-codec:a",
        "libmp3lame",
        "-b:a",
        bitrate,
        str(mp3_path),
    ]
    subprocess.run(command, check=True)


def synthesize_audio(args: argparse.Namespace, text: str, output_path: Path, engine_path: str, ffmpeg_path: str = "") -> None:
    if args.format == "wav":
        synthesize_wav(engine_path, text, output_path, args.voice, args.speed, args.pitch, args.amplitude)
        return

    with tempfile.TemporaryDirectory(prefix="kanaloop_meaning_tts_") as temp_dir_name:
        temp_wav = Path(temp_dir_name) / "meaning.wav"
        synthesize_wav(engine_path, text, temp_wav, args.voice, args.speed, args.pitch, args.amplitude)
        convert_wav_to_mp3(ffmpeg_path, temp_wav, output_path, args.mp3_bitrate)


def should_skip_existing(entry: dict[str, Any], force: bool) -> bool:
    if force:
        return False
    audio = entry.get("audio", {})
    return isinstance(audio, dict) and bool(str(audio.get(DEFAULT_AUDIO_KEY, "")).strip())


def update_entries(args: argparse.Namespace) -> int:
    entries = load_entries(args.data)
    if not args.dry_run:
        args.audio_output.mkdir(parents=True, exist_ok=True)

    engine_path = "" if args.dry_run else resolve_tts_engine(args.engine)
    ffmpeg_path = require_ffmpeg() if not args.dry_run and args.format == "mp3" else ""

    generated = 0
    reused = 0
    skipped_existing = 0
    skipped_missing_meaning = 0
    seen_meanings: dict[str, str] = {}

    for entry in entries:
        if should_skip_existing(entry, args.force):
            skipped_existing += 1
            continue

        meaning = normalize_tts_text(entry.get("meaning", ""))
        if not meaning:
            skipped_missing_meaning += 1
            continue

        if meaning in seen_meanings:
            path = seen_meanings[meaning]
            reused += 1
        else:
            destination = args.audio_output / safe_filename(meaning, args.format)
            path = res_path_for(args.asset_root, destination)
            if destination.exists() and not args.force_audio:
                reused += 1
            else:
                generated += 1
                if not args.dry_run:
                    synthesize_audio(args, meaning, destination, engine_path, ffmpeg_path)
            seen_meanings[meaning] = path

        audio = entry.get("audio", {})
        if not isinstance(audio, dict):
            audio = {}
        audio[DEFAULT_AUDIO_KEY] = path
        entry["audio"] = audio

        if args.limit is not None and generated >= args.limit:
            break

    if not args.dry_run:
        save_entries(args.data, entries)

    print("Meaning TTS generation complete.")
    print(f"- Entries read: {len(entries)}")
    print(f"- Audio files generated: {generated}")
    print(f"- Existing/generated audio paths reused: {reused}")
    print(f"- Entries skipped with existing {DEFAULT_AUDIO_KEY}: {skipped_existing}")
    print(f"- Entries skipped with missing meaning: {skipped_missing_meaning}")
    if args.dry_run:
        print("- Dry run: no audio files or JSON updates were written.")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate local English TTS audio for kanji vocabulary definitions and wire it into kanji_vocab_strokes.json."
    )
    parser.add_argument("--data", type=Path, default=default_data_path(), help="Kanji vocabulary JSON file to update.")
    parser.add_argument(
        "--audio-output",
        type=Path,
        default=default_audio_output(),
        help="Directory where generated English definition audio files are written.",
    )
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=default_asset_root(),
        help="Godot asset root used to convert generated audio paths to res:// paths.",
    )
    parser.add_argument("--engine", default=DEFAULT_TTS_ENGINE, help="espeak-compatible local TTS binary.")
    parser.add_argument("--voice", default="en-us", help="espeak voice name, for example en-us, en-gb, or en.")
    parser.add_argument("--speed", type=int, default=150, help="Speech speed in words per minute.")
    parser.add_argument("--pitch", type=int, default=50, help="Voice pitch from 0 to 99.")
    parser.add_argument("--amplitude", type=int, default=160, help="Voice amplitude from 0 to 200.")
    parser.add_argument("--format", choices=SUPPORTED_FORMATS, default="wav", help="Generated audio format.")
    parser.add_argument("--mp3-bitrate", default="64k", help="MP3 bitrate when --format mp3 is used.")
    parser.add_argument("--force", action="store_true", help=f"Rewrite JSON paths even when {DEFAULT_AUDIO_KEY} already exists.")
    parser.add_argument("--force-audio", action="store_true", help="Regenerate audio files even when the destination file exists.")
    parser.add_argument("--dry-run", action="store_true", help="Report what would happen without writing audio files or JSON.")
    parser.add_argument("--limit", type=int, help="Generate at most this many new audio files, useful for test runs.")
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(update_entries(parse_args()))
