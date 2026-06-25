from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import argparse
import hashlib
import html
import json
import re
import shutil
import sqlite3
import tempfile
import xml.etree.ElementTree as ET
import zipfile

from kana_outline_utils import (
    ViewBox,
    load_view_box,
    normalize_segment,
    parse_path_segments,
    save_json,
)

START_HINT_RADIUS = 0.05
END_HINT_RADIUS = 0.05
DEFAULT_RULES = {
    "direction_enforced": True,
    "corridor_radius": 0.05,
    "start_must_be_near": 0.08,
    "end_must_be_near": 0.08,
}
DEFAULT_FIELD_MAP = {
    "word": ["Expression", "Word", "Vocabulary", "Japanese", "Kanji", "Term"],
    "reading": ["Reading", "Kana", "Pronunciation", "Hiragana", "Furigana"],
    "meaning": ["Meaning", "English", "Definition", "Gloss"],
    "sentence_ja": ["Sentence", "Example", "Example Japanese", "Japanese Sentence"],
    "sentence_en": ["Sentence Meaning", "Example English", "English Sentence", "Translation"],
    "kanji_audio": ["Kanji Audio", "Character Audio"],
    "word_audio": ["Audio", "Word Audio", "Vocabulary Audio", "Expression Audio"],
    "sentence_audio": ["Sentence Audio", "Example Audio"],
    "meaning_audio": ["Meaning Audio", "English Audio", "Definition Audio"],
}
KANJI_RE = re.compile(r"[\u3400-\u4DBF\u4E00-\u9FFF\U00020000-\U0002A6DF\U0002A700-\U0002B73F\U0002B740-\U0002B81F\U0002B820-\U0002CEAF]")
SOUND_RE = re.compile(r"\[sound:([^\]]+)\]")
TAG_RE = re.compile(r"<[^>]+>")
SAFE_FILENAME_RE = re.compile(r"[^0-9A-Za-zぁ-んァ-ヶ一-龯々〆〤ー._-]+")


@dataclass(frozen=True)
class AnkiNote:
    note_id: int
    model_name: str
    deck_name: str
    fields: dict[str, str]
    tags: list[str]


@dataclass(frozen=True)
class MediaFile:
    source_name: str
    zip_member: str


def local_name(tag: str) -> str:
    return tag.split("}", 1)[-1]


def collect_kanjivg_stroke_paths(svg_path: Path) -> tuple[list[str], ViewBox]:
    tree = ET.parse(svg_path)
    root = tree.getroot()
    view_box = load_view_box(root)
    paths: list[tuple[int, str]] = []
    fallback_paths: list[str] = []
    for element in root.iter():
        if local_name(element.tag) != "path":
            continue
        d_attr = element.attrib.get("d")
        if not d_attr:
            continue
        path_id = element.attrib.get("id", "")
        match = re.search(r"-s(\d+)$", path_id)
        if match:
            paths.append((int(match.group(1)), d_attr))
        else:
            fallback_paths.append(d_attr)
    if paths:
        return [path for _, path in sorted(paths)], view_box
    return fallback_paths, view_box


def build_stroke_definition(stroke_id: int, d_path: str, view_box: ViewBox) -> dict:
    segments = parse_path_segments(d_path)
    if not segments:
        raise ValueError(f"Stroke {stroke_id} has no drawable path segments.")
    normalized_segments = [normalize_segment(segment, view_box) for segment in segments]
    start_point = normalized_segments[0]["points"][0]
    end_point = normalized_segments[-1]["points"][-1]
    return {
        "id": stroke_id,
        "start_hint": {"x": start_point["x"], "y": start_point["y"], "radius": START_HINT_RADIUS},
        "end_hint": {"x": end_point["x"], "y": end_point["y"], "radius": END_HINT_RADIUS},
        "path_hint": normalized_segments,
        "arrow_hints": [],
        "rules": DEFAULT_RULES,
    }


def kanji_svg_path(svg_root: Path, kanji: str) -> Path:
    return svg_root / f"{ord(kanji):05x}.svg"


def build_kanji_outline(kanji: str, svg_root: Path) -> dict:
    svg_path = kanji_svg_path(svg_root, kanji)
    if not svg_path.exists():
        return {
            "kanji": kanji,
            "stroke_count": 0,
            "strokes": [],
            "missing_strokes": True,
        }
    stroke_paths, view_box = collect_kanjivg_stroke_paths(svg_path)
    strokes = [
        build_stroke_definition(stroke_index + 1, d_path, view_box)
        for stroke_index, d_path in enumerate(stroke_paths)
    ]
    return {
        "kanji": kanji,
        "stroke_count": len(strokes),
        "strokes": strokes,
        "missing_strokes": len(strokes) == 0,
    }


def strip_markup(value: str) -> str:
    value = html.unescape(value or "")
    value = TAG_RE.sub("", value)
    value = SOUND_RE.sub("", value)
    return " ".join(value.replace("\xa0", " ").split()).strip()


def sound_refs(value: str) -> list[str]:
    return [html.unescape(match.group(1)).strip() for match in SOUND_RE.finditer(value or "")]


def load_field_map(config_path: Path | None) -> dict[str, list[str]]:
    field_map = {key: values[:] for key, values in DEFAULT_FIELD_MAP.items()}
    if config_path is None:
        return field_map
    data = json.loads(config_path.read_text(encoding="utf-8"))
    config_map = data.get("field_map", data)
    for key, values in config_map.items():
        if isinstance(values, str):
            field_map[key] = [values]
        elif isinstance(values, list):
            field_map[key] = [str(value) for value in values]
    return field_map


def select_field(fields: dict[str, str], candidates: list[str]) -> str:
    lowered = {name.lower(): value for name, value in fields.items()}
    for candidate in candidates:
        if candidate in fields and (strip_markup(fields[candidate]) or sound_refs(fields[candidate])):
            return fields[candidate]
        value = lowered.get(candidate.lower())
        if value is not None and (strip_markup(value) or sound_refs(value)):
            return value
    return ""


def parse_models(collection: sqlite3.Connection) -> dict[int, dict]:
    models_json = collection.execute("select models from col").fetchone()[0]
    models = json.loads(models_json)
    return {int(model_id): model for model_id, model in models.items()}


def parse_decks(collection: sqlite3.Connection) -> dict[int, str]:
    decks_json = collection.execute("select decks from col").fetchone()[0]
    decks = json.loads(decks_json)
    return {int(deck_id): deck.get("name", str(deck_id)) for deck_id, deck in decks.items()}


def note_deck_lookup(collection: sqlite3.Connection, decks: dict[int, str]) -> dict[int, str]:
    lookup: dict[int, str] = {}
    rows = collection.execute("select nid, did from cards order by id").fetchall()
    for note_id, deck_id in rows:
        lookup.setdefault(int(note_id), decks.get(int(deck_id), str(deck_id)))
    return lookup


def read_notes(collection_path: Path) -> list[AnkiNote]:
    connection = sqlite3.connect(collection_path)
    models = parse_models(connection)
    decks = parse_decks(connection)
    note_to_deck = note_deck_lookup(connection, decks)
    rows = connection.execute("select id, mid, flds, tags from notes order by id").fetchall()
    notes: list[AnkiNote] = []
    for note_id, model_id, raw_fields, raw_tags in rows:
        model = models.get(int(model_id), {})
        field_names = [field.get("name", f"Field {index + 1}") for index, field in enumerate(model.get("flds", []))]
        field_values = str(raw_fields).split("\x1f")
        fields = {
            field_name: field_values[index] if index < len(field_values) else ""
            for index, field_name in enumerate(field_names)
        }
        tags = [tag for tag in str(raw_tags).strip().split() if tag]
        notes.append(
            AnkiNote(
                note_id=int(note_id),
                model_name=model.get("name", str(model_id)),
                deck_name=note_to_deck.get(int(note_id), ""),
                fields=fields,
                tags=tags,
            )
        )
    connection.close()
    return notes


def find_collection_file(extract_dir: Path) -> Path:
    for name in ("collection.anki21b", "collection.anki21", "collection.anki2"):
        candidate = extract_dir / name
        if candidate.exists():
            return candidate
    raise FileNotFoundError("Could not find collection.anki2/collection.anki21 in the Anki package.")


def load_media_index(extract_dir: Path) -> dict[str, MediaFile]:
    media_path = extract_dir / "media"
    if not media_path.exists():
        return {}
    raw_media = json.loads(media_path.read_text(encoding="utf-8"))
    media: dict[str, MediaFile] = {}
    for zip_member, original_name in raw_media.items():
        media[str(original_name)] = MediaFile(source_name=str(original_name), zip_member=str(zip_member))
    return media


def safe_filename(value: str) -> str:
    cleaned = SAFE_FILENAME_RE.sub("_", strip_markup(value))
    cleaned = cleaned.strip("._-")
    return cleaned or hashlib.sha1(value.encode("utf-8")).hexdigest()[:12]


def res_path_for(asset_root: Path, path: Path) -> str:
    relative = path.relative_to(asset_root)
    return "res://" + relative.as_posix()


def copy_audio(
    sound_name: str,
    media_index: dict[str, MediaFile],
    extract_dir: Path,
    audio_output: Path,
    asset_root: Path,
    category: str,
    base_name: str,
) -> str:
    media_file = media_index.get(sound_name)
    if media_file is None:
        return ""
    source = extract_dir / media_file.zip_member
    if not source.exists():
        return ""
    extension = Path(media_file.source_name).suffix or source.suffix or ".mp3"
    digest = hashlib.sha1(media_file.source_name.encode("utf-8")).hexdigest()[:8]
    destination_dir = audio_output / category
    destination_dir.mkdir(parents=True, exist_ok=True)
    destination = destination_dir / f"{safe_filename(base_name)}_{digest}{extension}"
    shutil.copy2(source, destination)
    return res_path_for(asset_root, destination)


def extract_kanji(word: str) -> list[str]:
    seen: set[str] = set()
    kanji: list[str] = []
    for match in KANJI_RE.finditer(word):
        char = match.group(0)
        if char in seen:
            continue
        seen.add(char)
        kanji.append(char)
    return kanji


def entry_id(deck_path: Path, note: AnkiNote, kanji: str, word: str, reading: str) -> str:
    stable = f"{deck_path.name}:{note.note_id}:{kanji}:{word}:{reading}"
    digest = hashlib.sha1(stable.encode("utf-8")).hexdigest()[:12]
    return f"anki_{note.note_id}_{ord(kanji):05x}_{digest}"


def build_entries(
    deck_path: Path,
    notes: list[AnkiNote],
    field_map: dict[str, list[str]],
    media_index: dict[str, MediaFile],
    extract_dir: Path,
    audio_output: Path,
    asset_root: Path,
    svg_root: Path,
    deck_filter: set[str],
    tag_prefixes: list[str],
) -> tuple[list[dict], dict]:
    entries: list[dict] = []
    outline_cache: dict[str, dict] = {}
    skipped: dict[str, int] = {
        "deck_filtered": 0,
        "missing_word": 0,
        "missing_reading": 0,
        "missing_meaning": 0,
        "no_kanji": 0,
    }
    for note in notes:
        if deck_filter and note.deck_name not in deck_filter:
            skipped["deck_filtered"] += 1
            continue
        raw_word = select_field(note.fields, field_map["word"])
        raw_reading = select_field(note.fields, field_map["reading"])
        raw_meaning = select_field(note.fields, field_map["meaning"])
        word = strip_markup(raw_word)
        reading = strip_markup(raw_reading)
        meaning = strip_markup(raw_meaning)
        if not word:
            skipped["missing_word"] += 1
            continue
        if not reading:
            skipped["missing_reading"] += 1
            continue
        if not meaning:
            skipped["missing_meaning"] += 1
            continue
        kanji_chars = extract_kanji(word)
        if not kanji_chars:
            skipped["no_kanji"] += 1
            continue

        sentence_ja = strip_markup(select_field(note.fields, field_map["sentence_ja"]))
        sentence_en = strip_markup(select_field(note.fields, field_map["sentence_en"]))
        kanji_audio_refs = sound_refs(select_field(note.fields, field_map["kanji_audio"]))
        word_audio_refs = sound_refs(select_field(note.fields, field_map["word_audio"]))
        sentence_audio_refs = sound_refs(select_field(note.fields, field_map["sentence_audio"]))
        meaning_audio_refs = sound_refs(select_field(note.fields, field_map["meaning_audio"]))
        tags = sorted(set(note.tags + [f"deck:{note.deck_name}"] + tag_prefixes))
        audio_base_name = f"{word}_{reading}"
        word_audio = copy_audio(
            word_audio_refs[0], media_index, extract_dir, audio_output, asset_root, "word", audio_base_name
        ) if word_audio_refs else ""
        kanji_audio = copy_audio(
            kanji_audio_refs[0], media_index, extract_dir, audio_output, asset_root, "kanji", audio_base_name
        ) if kanji_audio_refs else ""
        sentence_audio = copy_audio(
            sentence_audio_refs[0], media_index, extract_dir, audio_output, asset_root, "sentence_ja", audio_base_name
        ) if sentence_audio_refs else ""
        meaning_audio = copy_audio(
            meaning_audio_refs[0], media_index, extract_dir, audio_output, asset_root, "meaning_en", meaning
        ) if meaning_audio_refs else ""

        for kanji in kanji_chars:
            if kanji not in outline_cache:
                outline_cache[kanji] = build_kanji_outline(kanji, svg_root)
            outline = outline_cache[kanji]
            audio = {}
            if kanji_audio:
                audio["kanji"] = kanji_audio
            if word_audio:
                audio["word"] = word_audio
                audio.setdefault("kanji", word_audio)
            if sentence_audio:
                audio["sentence_ja"] = sentence_audio
            if meaning_audio:
                audio["meaning_en"] = meaning_audio
            entries.append(
                {
                    "id": entry_id(deck_path, note, kanji, word, reading),
                    "kanji": kanji,
                    "word": word,
                    "reading": reading,
                    "pronunciation_key": safe_filename(reading),
                    "meaning": meaning,
                    "gloss": [part.strip() for part in re.split(r"[,;/]", meaning) if part.strip()],
                    "sample_sentence": {
                        "ja": sentence_ja,
                        "en": sentence_en,
                    },
                    "audio": audio,
                    "tags": tags,
                    "deck": note.deck_name,
                    "note_id": note.note_id,
                    "model": note.model_name,
                    "source": {
                        "type": "anki",
                        "deck_path": str(deck_path),
                        "note_id": note.note_id,
                        "model": note.model_name,
                    },
                    "missing_strokes": bool(outline.get("missing_strokes", False)),
                    "stroke_count": int(outline.get("stroke_count", 0)),
                    "strokes": outline.get("strokes", []),
                }
            )
    entries.sort(key=lambda entry: (entry["deck"], entry["note_id"], entry["word"], entry["kanji"], entry["reading"]))
    return entries, skipped


def import_deck(args: argparse.Namespace) -> int:
    asset_root = args.asset_root.resolve()
    audio_output = args.audio_output.resolve()
    svg_root = args.svg_root.resolve()
    field_map = load_field_map(args.config)
    deck_filter = set(args.deck_name or [])
    tag_prefixes = args.add_tag or []
    all_entries: list[dict] = []
    total_skipped: dict[str, int] = {}
    with tempfile.TemporaryDirectory(prefix="kanaloop_anki_") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        for deck_path in args.deck:
            deck_path = deck_path.resolve()
            deck_extract_dir = temp_dir / deck_path.stem
            deck_extract_dir.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(deck_path) as archive:
                archive.extractall(deck_extract_dir)
            collection_path = find_collection_file(deck_extract_dir)
            notes = read_notes(collection_path)
            media_index = load_media_index(deck_extract_dir)
            entries, skipped = build_entries(
                deck_path,
                notes,
                field_map,
                media_index,
                deck_extract_dir,
                audio_output,
                asset_root,
                svg_root,
                deck_filter,
                tag_prefixes,
            )
            all_entries.extend(entries)
            for key, value in skipped.items():
                total_skipped[key] = total_skipped.get(key, 0) + value
    seen_ids: set[str] = set()
    deduped_entries: list[dict] = []
    for entry in all_entries:
        if entry["id"] in seen_ids:
            continue
        seen_ids.add(entry["id"])
        deduped_entries.append(entry)
    save_json(args.output.resolve(), deduped_entries)
    print(f"Wrote {len(deduped_entries)} kanji vocabulary practice entries to {args.output}")
    if total_skipped:
        print("Skipped notes:")
        for key in sorted(total_skipped):
            print(f"- {key}: {total_skipped[key]}")
    return 0


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Import Anki .apkg decks into KanaLoop kanji guided-writing vocabulary JSON."
    )
    parser.add_argument("--deck", action="append", type=Path, required=True, help="Anki .apkg file to import. Repeat for multiple decks.")
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json",
        help="Output JSON path.",
    )
    parser.add_argument(
        "--audio-output",
        type=Path,
        default=repo_root / "kana-loop" / "assets" / "audio" / "kanji_vocab",
        help="Directory where imported Anki audio files are copied.",
    )
    parser.add_argument(
        "--svg-root",
        type=Path,
        default=repo_root / "kana-loop" / "assets" / "data" / "kanji",
        help="Directory containing KanjiVG-style SVG files named by five-digit lowercase codepoint.",
    )
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=repo_root / "kana-loop",
        help="Godot asset root used to convert copied audio paths to res:// paths.",
    )
    parser.add_argument("--config", type=Path, help="Optional JSON field-map config.")
    parser.add_argument("--deck-name", action="append", help="Only import notes whose first card belongs to this Anki deck name.")
    parser.add_argument("--add-tag", action="append", help="Extra tag to attach to every imported entry.")
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(import_deck(parse_args()))
