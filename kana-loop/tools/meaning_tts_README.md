# English Definition TTS Generator

`generate_meaning_tts.py` batch-generates local text-to-speech audio for the
English definitions in `assets/data/kanji_vocab_strokes.json`.

The generator reads each entry's `meaning` field, writes an audio file for the
spoken English definition, and adds the generated path to:

```json
"audio": {
  "meaning_en": "res://assets/audio/kanji_vocab/meaning_en/example.wav"
}
```

KanaLoop already recognizes the `meaning_en` audio key through
`KanaLoop/vocab_audio.gd`, so the generated paths are immediately usable by
game code that calls `VocabAudio.play_entry_meaning_en(entry)`.

## Local TTS engine choice

This tool uses **eSpeak NG** by default. It is local, fast, scriptable, and does
not require network access or API keys.

By default, the script writes `.wav` files because eSpeak NG can create WAV
output directly and Godot can import WAV assets. If you prefer `.mp3`, install
`ffmpeg` and run the script with `--format mp3`.

## Dependency setup

### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install espeak-ng
```

Optional MP3 support:

```bash
sudo apt-get install ffmpeg
```

### Fedora

```bash
sudo dnf install espeak-ng
```

Optional MP3 support:

```bash
sudo dnf install ffmpeg
```

### macOS

```bash
brew install espeak-ng
```

Optional MP3 support:

```bash
brew install ffmpeg
```

### Windows

Install eSpeak NG from the project releases or with a package manager such as
Chocolatey, then make sure `espeak-ng.exe` is available on `PATH`.

Optional MP3 support requires `ffmpeg.exe` on `PATH`.

## Recommended workflow

Run a read-only preview first:

```bash
python kana-loop/tools/generate_meaning_tts.py --dry-run
```

Generate WAV files and update the vocab JSON:

```bash
python kana-loop/tools/generate_meaning_tts.py
```

Generate MP3 files instead:

```bash
python kana-loop/tools/generate_meaning_tts.py --format mp3
```

Test a small batch before generating everything:

```bash
python kana-loop/tools/generate_meaning_tts.py --limit 10
```

After generation, open the Godot project so it can create `.import` metadata for
the new audio assets.

## Voice tuning

Useful eSpeak NG options are exposed as script flags:

```bash
python kana-loop/tools/generate_meaning_tts.py \
  --voice en-us \
  --speed 145 \
  --pitch 50 \
  --amplitude 160
```

Common voice choices include:

- `en-us`
- `en-gb`
- `en`

List installed voices with:

```bash
espeak-ng --voices=en
```

## Regeneration behavior

By default, the script skips entries that already have `audio.meaning_en`.

Use `--force` to rewrite JSON paths for entries that already have
`audio.meaning_en`:

```bash
python kana-loop/tools/generate_meaning_tts.py --force
```

Use `--force-audio` to overwrite existing destination audio files:

```bash
python kana-loop/tools/generate_meaning_tts.py --force --force-audio
```

## File reuse

The generator creates one audio file per unique English definition. For example,
if multiple entries have the meaning `one`, they will point to the same generated
audio file. This keeps the asset directory smaller and avoids duplicate TTS work.

Generated names include a short SHA-1 hash of the definition text, so file names
are deterministic and safe to regenerate.

## Validation

After generating audio, run:

```bash
python kana-loop/tools/validate_kanji_vocab_strokes.py
```

If the validator reports missing audio imports immediately after generation, open
the Godot project once so it can import the new audio files.
