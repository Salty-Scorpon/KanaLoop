from __future__ import annotations

import argparse
import json
import tempfile
import zipfile
from pathlib import Path

from import_anki_kanji_vocab import find_collection_file, read_notes, strip_markup
from kana_outline_utils import save_json


def expression_by_note_id(deck_paths: list[Path], expression_field: str, deck_filter: set[str]) -> tuple[dict[int, str], dict[str, int]]:
    expressions: dict[int, str] = {}
    stats = {
        "notes_seen": 0,
        "deck_filtered": 0,
        "missing_expression_field": 0,
        "empty_expression": 0,
        "conflicting_note_id": 0,
    }
    with tempfile.TemporaryDirectory(prefix="kanaloop_anki_expression_") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        for deck_path in deck_paths:
            deck_path = deck_path.resolve()
            deck_extract_dir = temp_dir / deck_path.stem
            deck_extract_dir.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(deck_path) as archive:
                archive.extractall(deck_extract_dir)
            notes = read_notes(find_collection_file(deck_extract_dir))
            for note in notes:
                stats["notes_seen"] += 1
                if deck_filter and note.deck_name not in deck_filter:
                    stats["deck_filtered"] += 1
                    continue
                raw_expression = note.fields.get(expression_field)
                if raw_expression is None:
                    lowered = {name.lower(): value for name, value in note.fields.items()}
                    raw_expression = lowered.get(expression_field.lower())
                if raw_expression is None:
                    stats["missing_expression_field"] += 1
                    continue
                expression = strip_markup(raw_expression)
                if not expression:
                    stats["empty_expression"] += 1
                    continue
                previous = expressions.get(note.note_id)
                if previous is not None and previous != expression:
                    stats["conflicting_note_id"] += 1
                    continue
                expressions[note.note_id] = expression
    return expressions, stats


def update_sentences(args: argparse.Namespace) -> int:
    input_path = args.input.resolve()
    output_path = args.output.resolve()
    expressions, stats = expression_by_note_id(args.deck, args.expression_field, set(args.deck_name or []))
    entries = json.loads(input_path.read_text(encoding="utf-8"))
    if not isinstance(entries, list):
        raise ValueError(f"Expected {input_path} to contain a JSON array.")

    updated = 0
    unchanged = 0
    missing_note_id = 0
    no_expression_match = 0
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        note_id = entry.get("note_id")
        if note_id is None:
            note_id = entry.get("source", {}).get("note_id") if isinstance(entry.get("source"), dict) else None
        if note_id is None:
            missing_note_id += 1
            continue
        expression = expressions.get(int(note_id))
        if expression is None:
            no_expression_match += 1
            continue
        sample_sentence = entry.setdefault("sample_sentence", {})
        if not isinstance(sample_sentence, dict):
            sample_sentence = {}
            entry["sample_sentence"] = sample_sentence
        if sample_sentence.get("ja") == expression:
            unchanged += 1
            continue
        sample_sentence["ja"] = expression
        updated += 1

    if args.dry_run:
        print(f"Dry run: would update {updated} entries in {output_path}.")
    else:
        save_json(output_path, entries)
        print(f"Updated {updated} entries in {output_path}.")
    print(f"Unchanged entries: {unchanged}")
    print(f"Entries missing note_id: {missing_note_id}")
    print(f"Entries without matching expression: {no_expression_match}")
    print("Anki note scan:")
    for key in sorted(stats):
        print(f"- {key}: {stats[key]}")
    return 0


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description=(
            "Update kanji_vocab_strokes.json sample_sentence.ja values from the "
            "Expression field in one or more Anki .apkg decks."
        )
    )
    parser.add_argument("--deck", action="append", type=Path, required=True, help="Anki .apkg file to read. Repeat for multiple decks.")
    parser.add_argument(
        "--input",
        type=Path,
        default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json",
        help="Existing kanji vocabulary JSON to update.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json",
        help="Destination JSON path. Defaults to updating the input file in place.",
    )
    parser.add_argument("--expression-field", default="Expression", help="Anki field name to copy into sample_sentence.ja.")
    parser.add_argument("--deck-name", action="append", help="Only read notes whose first card belongs to this Anki deck name.")
    parser.add_argument("--dry-run", action="store_true", help="Report the number of changed entries without writing JSON.")
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(update_sentences(parse_args()))
