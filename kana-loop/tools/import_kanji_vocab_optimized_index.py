from __future__ import annotations

from pathlib import Path
import argparse
import csv
import json
import re
import sys
import tempfile
import zipfile
from typing import Any

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from import_anki_kanji_vocab import find_collection_file, read_notes, select_field, strip_markup

DEFAULT_INDEX_FIELDS = [
    "Optimized-Voc-Index",
    "Optimized Voc Index",
    "Optimized-Vocab-Index",
    "Optimized Vocabulary Index",
    "Vocabulary-Index",
    "Voc-Index",
]
DEFAULT_WORD_FIELDS = ["Expression", "Vocabulary-Kanji", "Word", "Vocabulary", "Japanese", "Kanji", "Term"]
DEFAULT_READING_FIELDS = ["Reading", "Vocabulary-Furigana", "Kana", "Pronunciation", "Hiragana", "Furigana"]
DEFAULT_MEANING_FIELDS = ["Meaning", "Vocabulary-English", "English", "Definition", "Gloss"]
INT_RE = re.compile(r"\d+")


def load_entries(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"Expected {path} to contain a JSON array.")
    entries: list[dict[str, Any]] = []
    for index, entry in enumerate(data):
        if not isinstance(entry, dict):
            raise ValueError(f"Entry {index} in {path} is not a JSON object.")
        entries.append(entry)
    return entries


def save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def parse_index(value: Any) -> int | None:
    text = strip_markup(str(value or ""))
    match = INT_RE.search(text)
    if not match:
        return None
    return int(match.group(0))


def normalize_text(value: Any) -> str:
    return strip_markup(str(value or "")).casefold()


def context_key(word: Any, reading: Any, meaning: Any) -> tuple[str, str, str]:
    return (normalize_text(word), normalize_text(reading), normalize_text(meaning))


def candidates_with_aliases(names: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for name in names:
        for candidate in (name, name.replace("-", " "), name.replace(" ", "-")):
            if candidate.casefold() in seen:
                continue
            seen.add(candidate.casefold())
            result.append(candidate)
    return result


def load_index_from_apkg(deck_path: Path, index_fields: list[str]) -> tuple[dict[int, int], dict[tuple[str, str, str], int]]:
    note_indexes: dict[int, int] = {}
    context_indexes: dict[tuple[str, str, str], int] = {}
    with tempfile.TemporaryDirectory(prefix="kanaloop_index_") as temp_dir_name:
        extract_dir = Path(temp_dir_name) / deck_path.stem
        extract_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(deck_path) as archive:
            archive.extractall(extract_dir)
        notes = read_notes(find_collection_file(extract_dir))
        for note in notes:
            index = parse_index(select_field(note.fields, index_fields))
            if index is None:
                continue
            note_indexes[note.note_id] = index
            word = select_field(note.fields, DEFAULT_WORD_FIELDS)
            reading = select_field(note.fields, DEFAULT_READING_FIELDS)
            meaning = select_field(note.fields, DEFAULT_MEANING_FIELDS)
            key = context_key(word, reading, meaning)
            if all(key):
                context_indexes.setdefault(key, index)
    return note_indexes, context_indexes


def row_value(row: dict[str, str], candidates: list[str]) -> str:
    lowered = {key.casefold(): value for key, value in row.items()}
    for candidate in candidates:
        if candidate in row and row[candidate]:
            return row[candidate]
        value = lowered.get(candidate.casefold())
        if value:
            return value
    return ""


def load_index_from_csv(csv_path: Path, index_fields: list[str], note_id_fields: list[str]) -> tuple[dict[int, int], dict[tuple[str, str, str], int]]:
    note_indexes: dict[int, int] = {}
    context_indexes: dict[tuple[str, str, str], int] = {}
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            index = parse_index(row_value(row, index_fields))
            if index is None:
                continue
            note_id = parse_index(row_value(row, note_id_fields))
            if note_id is not None:
                note_indexes[note_id] = index
            key = context_key(
                row_value(row, DEFAULT_WORD_FIELDS),
                row_value(row, DEFAULT_READING_FIELDS),
                row_value(row, DEFAULT_MEANING_FIELDS),
            )
            if all(key):
                context_indexes.setdefault(key, index)
    return note_indexes, context_indexes


def merge_indexes(target: dict[int, int] | dict[tuple[str, str, str], int], incoming: dict) -> None:
    for key, value in incoming.items():
        target.setdefault(key, value)


def annotate_entries(
    entries: list[dict[str, Any]],
    note_indexes: dict[int, int],
    context_indexes: dict[tuple[str, str, str], int],
    index_key: str,
    tag_prefix: str,
) -> tuple[int, int]:
    updated = 0
    missing = 0
    for entry in entries:
        note_id = entry.get("note_id")
        index = note_indexes.get(int(note_id)) if isinstance(note_id, int) or str(note_id).isdigit() else None
        if index is None:
            index = context_indexes.get(context_key(entry.get("word"), entry.get("reading"), entry.get("meaning")))
        if index is None:
            missing += 1
            continue
        entry[index_key] = index
        study = entry.get("study")
        if not isinstance(study, dict):
            study = {}
        study[index_key] = index
        study.setdefault("source_order", "core2000_optimized_vocab_index")
        entry["study"] = study
        tags = entry.get("tags")
        if not isinstance(tags, list):
            tags = []
        tag = f"{tag_prefix}{index:04d}"
        if tag not in tags:
            tags.append(tag)
            tags.sort(key=str)
        entry["tags"] = tags
        updated += 1
    return updated, missing


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Annotate KanaLoop kanji vocabulary entries with Core 2000 Optimized-Voc-Index values."
    )
    parser.add_argument("--data", type=Path, default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json")
    parser.add_argument("--output", type=Path, help="Output path. Defaults to overwriting --data unless --dry-run is set.")
    parser.add_argument("--apkg", action="append", type=Path, default=[], help="Anki .apkg source containing Optimized-Voc-Index. Repeatable.")
    parser.add_argument("--csv", action="append", type=Path, default=[], help="CSV export containing Optimized-Voc-Index. Repeatable.")
    parser.add_argument("--index-field", action="append", default=[], help="Additional field/header name for the optimized index.")
    parser.add_argument("--note-id-field", action="append", default=["note_id", "Note ID", "nid"], help="CSV field/header name for Anki note id.")
    parser.add_argument("--index-key", default="optimized_vocab_index", help="JSON key to write on each entry and under entry.study.")
    parser.add_argument("--tag-prefix", default="core2000_index_", help="Tag prefix to add for the optimized index.")
    parser.add_argument("--dry-run", action="store_true", help="Print counts without writing JSON.")
    return parser.parse_args()


def main(args: argparse.Namespace) -> int:
    entries = load_entries(args.data)
    index_fields = candidates_with_aliases(DEFAULT_INDEX_FIELDS + args.index_field)
    note_indexes: dict[int, int] = {}
    context_indexes: dict[tuple[str, str, str], int] = {}
    for apkg_path in args.apkg:
        note_map, context_map = load_index_from_apkg(apkg_path, index_fields)
        merge_indexes(note_indexes, note_map)
        merge_indexes(context_indexes, context_map)
    for csv_path in args.csv:
        note_map, context_map = load_index_from_csv(csv_path, index_fields, args.note_id_field)
        merge_indexes(note_indexes, note_map)
        merge_indexes(context_indexes, context_map)
    if not note_indexes and not context_indexes:
        print("No optimized vocabulary index values were found in the supplied sources.")
        return 1
    updated, missing = annotate_entries(entries, note_indexes, context_indexes, args.index_key, args.tag_prefix)
    print(f"Entries annotated: {updated}")
    print(f"Entries without an index match: {missing}")
    if args.dry_run:
        print("Dry run: no files written.")
        return 0
    output_path = args.output or args.data
    save_json(output_path, entries)
    print(f"Wrote annotated entries to {output_path}")
    return 0 if updated else 1


if __name__ == "__main__":
    raise SystemExit(main(parse_args()))
