# Vosk Grammar Regression Checks

## Scope
These checks validate that the Vosk service honors grammar constraints and that final transcripts are correct for single kana, multi-kana, and a simple word ("かたな"). Use the harness below before Sprint 3 to capture quick expected vs. actual results.

## Test Harness
Use the existing WebSocket test client with grammar support.

### Microphone input
```bash
python speech/vosk_ws_test_client.py --grammar "あ" --validate
```

### Prerecorded audio (16kHz mono WAV)
```bash
python speech/vosk_ws_test_client.py --grammar "か,た,な,かたな" --audio-file path/to/katana.wav --validate
```

### Notes
- The harness sends a `set_grammar` message before streaming audio.
- `--validate` prints warnings if partial/final output contains tokens outside the grammar list.
- For prerecorded audio, ensure the WAV file is 16kHz mono 16-bit PCM.

## Reproducible Test Cases
| Case | Grammar | Audio Source | Expected Final Text |
| --- | --- | --- | --- |
| Single kana | `あ` | Mic or WAV of "あ" | `あ` |
| Multi-kana (set) | `か,き,く` | Mic or WAV of "か" (or one of the set) | One of: `か`, `き`, `く` |
| Word | `か,た,な,かたな` | Mic or WAV of "かたな" | `かたな` |

## Regression Log (Expected vs. Actual)
Fill this table after each run. Keep the most recent results at the top for quick comparison.

| Date | Case | Expected | Actual | Grammar-only Output? | Notes |
| --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | Single kana | `あ` |  |  |  |
| YYYY-MM-DD | Multi-kana (set) | `か` (or `き`/`く`) |  |  |  |
| YYYY-MM-DD | Word | `かたな` |  |  |  |
