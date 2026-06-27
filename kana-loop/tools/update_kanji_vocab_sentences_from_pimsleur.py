from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
import zipfile
from pathlib import Path

from import_anki_kanji_vocab import (
    copy_audio,
    find_collection_file,
    load_media_index,
    read_notes,
    safe_filename,
    sound_refs,
    strip_markup,
)
from kana_outline_utils import save_json

KANA_KANJI_RE = re.compile(r"[ぁ-んァ-ヶ一-龯々〆〤ー]+")
SPACE_RE = re.compile(r"\s+")


def normalize_japanese(value: str) -> str:
    return SPACE_RE.sub("", value or "")


def is_matchable_word(value: str) -> bool:
    # Avoid matching punctuation, romaji-only strings, and single kana particles.
    return bool(value) and bool(KANA_KANJI_RE.search(value)) and len(normalize_japanese(value)) >= 2


def read_pimsleur_sentences(deck_paths: list[Path], front_field: str, back_field: str, temp_dir: Path) -> tuple[list[dict], dict[str, int]]:
    sentences: list[dict] = []
    stats = {"notes_seen": 0, "missing_front": 0, "missing_back": 0, "missing_audio": 0}
    for deck_index, deck_path in enumerate(deck_paths):
        deck_path = deck_path.resolve()
        extract_dir = temp_dir / deck_path.stem
        extract_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(deck_path) as archive:
            archive.extractall(extract_dir)
        media_index = load_media_index(extract_dir)
        for note_index, note in enumerate(read_notes(find_collection_file(extract_dir))):
            stats["notes_seen"] += 1
            raw_front = note.fields.get(front_field) or note.fields.get(front_field.lower())
            raw_back = note.fields.get(back_field) or note.fields.get(back_field.lower())
            front = strip_markup(raw_front or "")
            back = strip_markup(raw_back or "")
            audio_refs = sound_refs(raw_front or "")
            if not front:
                stats["missing_front"] += 1
                continue
            if not back:
                stats["missing_back"] += 1
                continue
            if not audio_refs:
                stats["missing_audio"] += 1
            sentences.append(
                {
                    "deck_index": deck_index,
                    "note_index": note_index,
                    "deck_path": deck_path,
                    "deck_name": note.deck_name,
                    "note_id": note.note_id,
                    "front": front,
                    "front_normalized": normalize_japanese(front),
                    "back": back,
                    "audio_ref": audio_refs[0] if audio_refs else "",
                    "media_index": media_index,
                    "extract_dir": extract_dir,
                }
            )
    return sentences, stats


def choose_sentence(word: str, candidates: list[dict]) -> dict | None:
    normalized_word = normalize_japanese(word)
    matches = [s for s in candidates if normalized_word in s["front_normalized"]]
    if not matches:
        return None
    return sorted(matches, key=lambda s: (s["deck_index"], s["note_index"], len(s["front_normalized"])))[0]


def pimsleur_deck_tag(sentence: dict) -> str:
    return f"pimsleur_deck:{sentence['deck_name']}"


def pimsleur_study_metadata(sentence: dict) -> dict:
    deck_index = int(sentence["deck_index"])
    note_index = int(sentence["note_index"])
    return {
        "deck_tag": pimsleur_deck_tag(sentence),
        "deck_index": deck_index,
        "deck_position": note_index + 1,
        "priority_key": f"{deck_index + 1:02d}-{note_index + 1:04d}",
    }


def apply_pimsleur_study_grouping(entry: dict, sentence: dict) -> bool:
    changed = False
    tags = entry.setdefault("tags", [])
    if not isinstance(tags, list):
        tags = []
        entry["tags"] = tags
        changed = True
    for tag in ("pimsleur", pimsleur_deck_tag(sentence)):
        if tag not in tags:
            tags.append(tag)
            changed = True
    tags.sort()

    study = entry.setdefault("study", {})
    if not isinstance(study, dict):
        study = {}
        entry["study"] = study
        changed = True
    metadata = pimsleur_study_metadata(sentence)
    if study.get("pimsleur") != metadata:
        study["pimsleur"] = metadata
        changed = True
    return changed


def res_path_to_file(asset_root: Path, value: str) -> Path | None:
    prefix = "res://"
    if not value.startswith(prefix):
        return None
    return asset_root / value[len(prefix):]


def remove_existing_pimsleur_audio(entry: dict, word: str, asset_root: Path, audio_output: Path, dry_run: bool) -> int:
    removed = 0
    audio = entry.get("audio")
    if not isinstance(audio, dict):
        audio = {}
    existing_audio = str(audio.get("sentence_ja", ""))
    existing_path = res_path_to_file(asset_root, existing_audio)
    paths: set[Path] = set()
    if existing_path and existing_path.name.startswith("pimsleur_"):
        paths.add(existing_path)
    sentence_dir = audio_output / "sentence_ja"
    paths.update(sentence_dir.glob(f"pimsleur_{safe_filename(word)}_*.mp3"))
    for path in paths:
        if path.exists():
            removed += 1
            if not dry_run:
                path.unlink()
    if existing_audio and "/pimsleur_" in existing_audio:
        removed += 1
        if not dry_run:
            audio.pop("sentence_ja", None)
    return removed


def update_entries(args: argparse.Namespace) -> int:
    input_path = args.input.resolve()
    output_path = args.output.resolve()
    asset_root = args.asset_root.resolve()
    audio_output = args.audio_output.resolve()
    entries = json.loads(input_path.read_text(encoding="utf-8"))
    if not isinstance(entries, list):
        raise ValueError(f"Expected {input_path} to contain a JSON array.")

    temp_context = tempfile.TemporaryDirectory(prefix="kanaloop_pimsleur_")
    temp_dir = Path(temp_context.name)
    pimsleur_sentences, scan_stats = read_pimsleur_sentences(args.deck, args.front_field, args.back_field, temp_dir)
    by_word: dict[str, dict | None] = {}
    updated = 0
    unchanged = 0
    no_match = 0
    unmatchable = 0
    audio_copied = 0
    audio_removed = 0

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        word = str(entry.get("word", ""))
        if not is_matchable_word(word):
            unmatchable += 1
            continue
        if word not in by_word:
            by_word[word] = choose_sentence(word, pimsleur_sentences)
        sentence = by_word[word]
        if sentence is None:
            no_match += 1
            continue

        sample = entry.setdefault("sample_sentence", {})
        if not isinstance(sample, dict):
            sample = {}
            entry["sample_sentence"] = sample
        audio = entry.setdefault("audio", {})
        if not isinstance(audio, dict):
            audio = {}
            entry["audio"] = audio

        sentence_audio = ""
        audio_removed += remove_existing_pimsleur_audio(entry, word, asset_root, audio_output, args.dry_run)
        if sentence["audio_ref"] and not args.dry_run:
            base_name = f"pimsleur_{word}_{hashlib.sha1(sentence['front'].encode('utf-8')).hexdigest()[:8]}"
            sentence_audio = copy_audio(
                sentence["audio_ref"],
                sentence["media_index"],
                sentence["extract_dir"],
                audio_output,
                asset_root,
                "sentence_ja",
                base_name,
            )

        changed = False
        if sample.get("ja") != sentence["front"]:
            sample["ja"] = sentence["front"]
            changed = True
        if sample.get("en") != sentence["back"]:
            sample["en"] = sentence["back"]
            changed = True
        if sentence_audio and audio.get("sentence_ja") != sentence_audio:
            audio["sentence_ja"] = sentence_audio
            audio_copied += 1
            changed = True
        entry["pimsleur_sentence_source"] = {
            "deck_path": str(sentence["deck_path"]),
            "deck_name": sentence["deck_name"],
            "note_id": sentence["note_id"],
            "deck_tag": pimsleur_deck_tag(sentence),
            "deck_index": sentence["deck_index"],
            "deck_position": sentence["note_index"] + 1,
            "matched_word": word,
        }
        if apply_pimsleur_study_grouping(entry, sentence):
            changed = True
        if changed:
            updated += 1
        else:
            unchanged += 1

    if args.dry_run:
        print(f"Dry run: would update {updated} entries in {output_path}.")
    else:
        save_json(output_path, entries)
        print(f"Updated {updated} entries in {output_path}.")
    print(f"Unchanged matched entries: {unchanged}")
    print(f"Entries with no Pimsleur sentence match: {no_match}")
    print(f"Unmatchable entries: {unmatchable}")
    print(f"Existing Pimsleur audio paths/files cleared: {audio_removed}")
    print(f"Sentence audio paths set/copied: {audio_copied}")
    print("Pimsleur note scan:")
    for key in sorted(scan_stats):
        print(f"- {key}: {scan_stats[key]}")
    temp_context.cleanup()
    return 0


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description="Update kanji vocabulary sample sentences/audio from Pimsleur Front/Back Anki decks.")
    parser.add_argument(
        "--deck",
        action="append",
        nargs="+",
        type=Path,
        required=True,
        help=(
            "Pimsleur .apkg file(s) to read in priority order. "
            "Pass all decks after one --deck, or repeat --deck; earlier arguments win ties."
        ),
    )
    parser.add_argument("--input", type=Path, default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json")
    parser.add_argument("--output", type=Path, default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json")
    parser.add_argument("--audio-output", type=Path, default=repo_root / "kana-loop" / "assets" / "audio" / "kanji_vocab")
    parser.add_argument("--asset-root", type=Path, default=repo_root / "kana-loop")
    parser.add_argument("--front-field", default="Front")
    parser.add_argument("--back-field", default="Back")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    args.deck = [deck_path for group in args.deck for deck_path in group]
    return args


if __name__ == "__main__":
    raise SystemExit(update_entries(parse_args()))
