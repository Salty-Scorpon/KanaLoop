# Kana audio assets

Kana audio files are stored per voice and kana character under:

```
res://assets/audio/<voice>/<kana>.ogg
```

Where:
- `<voice>` matches the values in `KanaLoop/kana_audio.gd` (e.g., `Voice 1`, `Voice 2`).
- `<kana>` is the literal kana character (e.g., `あ`, `き`, `そ`).

When a file is missing or fails to load, the game falls back to a short placeholder
stream. Use the source MP3s in the repo root (`Vowels+k-row.mp3`, `S-row+T-row.mp3`)
to extract individual kana files and save them to the paths above.
