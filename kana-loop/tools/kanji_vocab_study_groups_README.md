# Kanji vocabulary optimized index and study groups

KanaLoop's kanji vocabulary data is stored in `kana-loop/assets/data/kanji_vocab_strokes.json`. The importer preserves the Anki note id, word, reading, meaning, sample sentence, tags, audio paths, and stroke data, but some Core 2000 exports do not import the `Optimized-Voc-Index` field. The two scripts in this folder handle that as a two-step build process.

## Goal

Generate study-able chronological groups of 10-20 vocabulary records where:

- words are considered in Core 2000 `Optimized-Voc-Index` order;
- multi-kanji words stay together as one vocabulary record;
- a sentence is considered group-safe when all of its kanji are either already learned in previous groups or assigned by words in the current group;
- collateral kanji in sample sentences are flagged unless they are already learned;
- generated groups are always chronological and are never randomized.

## Step 1: annotate vocabulary entries with `Optimized-Voc-Index`

Use `import_kanji_vocab_optimized_index.py` to copy optimized index values from the original Anki package or from a CSV export into KanaLoop's JSON entries.

### From an Anki package

```bash
python kana-loop/tools/import_kanji_vocab_optimized_index.py \
  --data kana-loop/assets/data/kanji_vocab_strokes.json \
  --apkg /path/to/Japanese_Core_2000.apkg \
  --output kana-loop/assets/data/kanji_vocab_strokes.json
```

### From a CSV export

```bash
python kana-loop/tools/import_kanji_vocab_optimized_index.py \
  --data kana-loop/assets/data/kanji_vocab_strokes.json \
  --csv /path/to/core2000_export.csv \
  --output kana-loop/assets/data/kanji_vocab_strokes.json
```

The CSV path is useful when Anki's package format is unavailable. The script matches entries by `note_id` when possible, then falls back to normalized `word + reading + meaning` matching.

### Custom field names

The script looks for common optimized-index field names, including `Optimized-Voc-Index`. If your source uses a different field/header name, pass it explicitly:

```bash
python kana-loop/tools/import_kanji_vocab_optimized_index.py \
  --data kana-loop/assets/data/kanji_vocab_strokes.json \
  --csv /path/to/core2000_export.csv \
  --index-field My-Optimized-Order-Field
```

By default, the script writes:

- top-level `optimized_vocab_index`;
- `study.optimized_vocab_index`;
- a `core2000_index_####` tag.

Use `--dry-run` to print match counts without writing files.

## Step 2: generate chronological study groups

After entries have optimized indexes, use `generate_kanji_vocab_study_groups.py`:

```bash
python kana-loop/tools/generate_kanji_vocab_study_groups.py \
  --data kana-loop/assets/data/kanji_vocab_strokes.json \
  --output kana-loop/assets/data/kanji_vocab_study_groups.json
```

The generated study-plan file contains group metadata, ordered record lists, entry ids, note ids, assigned kanji, learned kanji before each group, and sentence-safety diagnostics.

## Optional: write group metadata back onto entries

For runtime code that prefers tags or per-entry metadata, ask the generator to write an annotated copy of the vocabulary data:

```bash
python kana-loop/tools/generate_kanji_vocab_study_groups.py \
  --data kana-loop/assets/data/kanji_vocab_strokes.json \
  --output kana-loop/assets/data/kanji_vocab_study_groups.json \
  --annotated-output kana-loop/assets/data/kanji_vocab_strokes.grouped.json
```

This adds:

- `study.group_index`;
- `study.group_id`;
- `study.group_label`;
- `study.group_order`;
- `study.word_kanji`;
- `study.sentence_kanji`;
- `study.collateral_kanji`;
- `study.unlearned_sentence_kanji`;
- `study.sentence_ok_for_group`;
- a `study_group_###` tag.

Review the annotated output before replacing the main `kanji_vocab_strokes.json` file.

## Dependency behavior

For each vocabulary record, the grouping script computes:

```text
word_kanji       = kanji in the vocabulary word
sentence_kanji   = kanji in the Japanese sample sentence
collateral_kanji = sentence_kanji - word_kanji
```

A record is strictly placeable in a group when:

```text
sentence_kanji <= learned_kanji_from_previous_groups + assigned_kanji_in_current_group
```

If strict placement cannot fill the configured minimum group size, the script keeps chronological progress by adding the earliest blocked records and marking them with `unlearned_sentence_kanji`. These records should be treated as candidates for sentence replacement or delayed curriculum review.

## Group size options

Defaults are 10-20 vocabulary records per group:

```bash
python kana-loop/tools/generate_kanji_vocab_study_groups.py \
  --min-size 10 \
  --max-size 20
```

The final group may be smaller if there are not enough records left.

## Recommended validation workflow

```bash
python -m py_compile \
  kana-loop/tools/import_kanji_vocab_optimized_index.py \
  kana-loop/tools/generate_kanji_vocab_study_groups.py

python kana-loop/tools/import_kanji_vocab_optimized_index.py \
  --data kana-loop/assets/data/kanji_vocab_strokes.json \
  --apkg /path/to/Japanese_Core_2000.apkg \
  --dry-run

python kana-loop/tools/generate_kanji_vocab_study_groups.py \
  --data kana-loop/assets/data/kanji_vocab_strokes.json \
  --dry-run
```

After writing an annotated vocabulary file, run the existing vocabulary validator on the file you plan to ship:

```bash
python kana-loop/tools/validate_kanji_vocab_strokes.py \
  kana-loop/assets/data/kanji_vocab_strokes.json
```

