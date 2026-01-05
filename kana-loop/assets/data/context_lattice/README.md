# Context lattice sentence data

This folder documents the sentence corpus used by the context lattice lesson. The loader currently reads from:

- `res://assets/data/sentence_corpus.json`

Use this README as the schema reference when adding new sentences to that file (or when splitting the corpus and updating the loader path).

## Sentence JSON schema

Each entry in the sentence corpus array is a dictionary with the following fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | ✅ | Unique sentence identifier. Prefer a stable slug like `<romaji>_<index>`, e.g. `mizu_1`. |
| `word_id` | string | ✅ | UUID of the dictionary entry this sentence belongs to (matches `id` in `assets/data/dictionary_3000_common_words.json`). |
| `jp` | string | ✅ | Japanese sentence with kanji. |
| `kana` | string | ✅ | Kana-only reading for the sentence. |
| `en` | string | ✅ | English gloss/translation. |
| `audio` | string or null | ✅ | Godot resource path to an audio file (e.g. `res://assets/audio/context_lattice/mizu_1.ogg`). Use `null` or an empty string for text-only prompts. |
| `difficulty` | number | ➖ | Optional difficulty hint (e.g. 1–5). Currently informational only. |

## File naming conventions

- **Corpus file**: keep the canonical file at `assets/data/sentence_corpus.json` unless you update `SENTENCE_CORPUS_PATH` in `KanaLoop/context_lattice.gd`.
- **Sentence IDs**: use lowercase, snake/romaji slugs with an index (e.g. `mizu_1`, `mizu_2`) so multiple sentences can live under one `word_id`.
- **Audio filenames**: match the sentence id (`mizu_1.ogg`) to keep assets discoverable.

## How the loader indexes by `word_id`

The loader (`_load_sentence_corpus` in `KanaLoop/context_lattice.gd`) parses the corpus into a dictionary keyed by `word_id`. Every sentence with the same `word_id` is appended to an array for that word, so multiple sentences become the selectable pool for that vocabulary item.

## Audio asset guidance

1. Place audio files under `assets/audio/context_lattice/` (or another folder of your choice).
2. Import the audio into Godot so it is available as a resource.
3. Reference the resource path in the `audio` field (e.g. `res://assets/audio/context_lattice/mizu_1.ogg`).

**When audio is missing:** if `audio` is empty/null, or the resource path does not exist, the lesson falls back to text-only prompts. The replay button will show an “Audio unavailable” message and no audio will play.

## Frequency ranking and scheduling priority

The context lattice lesson uses `frequency_rank` from `assets/data/dictionary_3000_common_words.json` to break ties when scheduling the next word. Lower `frequency_rank` values are treated as higher priority. If a word lacks a rank, it falls back to a large default (effectively lower priority). Frequency is evaluated after exposure-based sorting, so it mainly influences tie-breaking among otherwise eligible words.
