# Dictionary Search Index Builder

This tool builds a SQLite search index with FTS tables from `jmdict_with_freq.json`.

## Usage

From the repository root:

```sh
python3 kana-loop/tools/dictionary/build_search_index.py \
  --input kana-loop/jmdict_with_freq.json \
  --output kana-loop/search_index.sqlite
```

The script creates:

- `entries` table with kana, kanji, romaji, gloss, frequency_rank, and jlpt columns
- `entries_fts` FTS5 table for full-text search across kana, kanji, romaji, and gloss

You can override the paths with `--input` and `--output`. If the output file exists it will be replaced.
