from __future__ import annotations

from pathlib import Path
import argparse
import json
import re
from typing import Any

KANJI_RE = re.compile(
    r"^[\u3400-\u4DBF\u4E00-\u9FFF\U00020000-\U0002A6DF\U0002A700-\U0002B73F\U0002B740-\U0002B81F\U0002B820-\U0002CEAF]$"
)
AUDIO_KEYS = {"kanji", "word", "sentence_ja", "meaning_en"}
REQUIRED_TEXT_FIELDS = ["id", "kanji", "word", "reading", "meaning"]
REQUIRED_RULE_KEYS = ["direction_enforced", "corridor_radius", "start_must_be_near", "end_must_be_near"]
SEGMENT_POINT_COUNTS = {"Line": 2, "Quad": 3, "Cubic": 4}


class ValidationReport:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warning(self, message: str) -> None:
        self.warnings.append(message)

    def print(self) -> None:
        if self.errors:
            print("Validation failed:")
            for error in self.errors:
                print(f"- {error}")
        if self.warnings:
            print("Validation warnings:")
            for warning in self.warnings:
                print(f"- {warning}")
        if not self.errors:
            print("Kanji vocabulary stroke validation passed.")


def load_entries(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("Expected kanji vocabulary stroke JSON to be a list of entries.")
    return data


def validate(path: Path, asset_root: Path, check_audio: bool = True) -> int:
    report = ValidationReport()
    if not path.exists():
        report.error(f"Kanji vocabulary stroke data not found: {path}")
        report.print()
        return 1

    try:
        entries = load_entries(path)
    except (json.JSONDecodeError, OSError, ValueError) as exc:
        report.error(str(exc))
        report.print()
        return 1

    seen_ids: set[str] = set()
    seen_contexts: set[tuple[str, str, str]] = set()
    for index, entry in enumerate(entries):
        validate_entry(entry, index, asset_root, check_audio, seen_ids, seen_contexts, report)

    if not entries:
        report.warning("Kanji vocabulary stroke data contains no entries.")
    report.print()
    return 1 if report.errors else 0


def validate_entry(
    entry: Any,
    index: int,
    asset_root: Path,
    check_audio: bool,
    seen_ids: set[str],
    seen_contexts: set[tuple[str, str, str]],
    report: ValidationReport,
) -> None:
    label = f"entry {index}"
    if not isinstance(entry, dict):
        report.error(f"{label} is not an object.")
        return

    for field in REQUIRED_TEXT_FIELDS:
        if not isinstance(entry.get(field), str) or not entry[field].strip():
            report.error(f"{label} missing non-empty string field: {field}")
    entry_id = str(entry.get("id", ""))
    if entry_id:
        if entry_id in seen_ids:
            report.error(f"{label} duplicate id: {entry_id}")
        seen_ids.add(entry_id)

    kanji = str(entry.get("kanji", ""))
    word = str(entry.get("word", ""))
    reading = str(entry.get("reading", ""))
    if kanji and not KANJI_RE.match(kanji):
        report.error(f"{label} kanji must be a single CJK ideograph: {kanji}")
    if kanji and word and kanji not in word:
        report.warning(f"{label} kanji {kanji} is not present in word {word}.")
    context = (kanji, word, reading)
    if all(context):
        if context in seen_contexts:
            report.error(f"{label} duplicate kanji/word/reading context: {kanji}/{word}/{reading}")
        seen_contexts.add(context)

    validate_sample_sentence(entry.get("sample_sentence"), label, report)
    validate_audio(entry.get("audio"), label, asset_root, check_audio, report)
    validate_tags(entry.get("tags"), label, report)
    validate_source(entry.get("source"), label, report)
    validate_strokes(entry, label, report)


def validate_sample_sentence(value: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(value, dict):
        report.error(f"{label} sample_sentence must be an object.")
        return
    for key in ("ja", "en"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            report.error(f"{label} sample_sentence.{key} must be a non-empty string.")


def validate_audio(value: Any, label: str, asset_root: Path, check_audio: bool, report: ValidationReport) -> None:
    if not isinstance(value, dict):
        report.error(f"{label} audio must be an object.")
        return
    unknown_keys = set(value.keys()) - AUDIO_KEYS
    for key in sorted(unknown_keys):
        report.warning(f"{label} audio has unknown key: {key}")
    if not value:
        report.warning(f"{label} has no audio paths.")
    for key, path_value in value.items():
        if not isinstance(path_value, str) or not path_value.strip():
            report.error(f"{label} audio.{key} must be a non-empty string when present.")
            continue
        if check_audio and not audio_path_exists(path_value, asset_root):
            report.error(f"{label} audio.{key} path does not exist: {path_value}")


def audio_path_exists(path_value: str, asset_root: Path) -> bool:
    if path_value.startswith("res://"):
        return (asset_root / path_value.removeprefix("res://")).exists()
    return Path(path_value).exists()


def validate_tags(value: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(value, list):
        report.error(f"{label} tags must be an array.")
        return
    for tag_index, tag in enumerate(value):
        if not isinstance(tag, str) or not tag.strip():
            report.error(f"{label} tags[{tag_index}] must be a non-empty string.")


def validate_source(value: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(value, dict):
        report.error(f"{label} source must be an object.")
        return
    if value.get("type") != "anki":
        report.error(f"{label} source.type must be 'anki'.")


def validate_strokes(entry: dict[str, Any], label: str, report: ValidationReport) -> None:
    stroke_count = entry.get("stroke_count")
    strokes = entry.get("strokes")
    missing_strokes = bool(entry.get("missing_strokes", False))
    if not isinstance(stroke_count, int) or stroke_count < 0:
        report.error(f"{label} stroke_count must be a non-negative integer.")
        return
    if not isinstance(strokes, list):
        report.error(f"{label} strokes must be an array.")
        return
    if missing_strokes:
        if stroke_count != 0 or strokes:
            report.error(f"{label} missing_strokes entries must have stroke_count 0 and no strokes.")
        return
    if stroke_count == 0 or not strokes:
        report.error(f"{label} must include strokes unless missing_strokes is true.")
        return
    if len(strokes) != stroke_count:
        report.error(f"{label} stroke_count {stroke_count} does not match strokes length {len(strokes)}.")
    for stroke_index, stroke in enumerate(strokes):
        validate_stroke(stroke, f"{label} stroke {stroke_index + 1}", report)


def validate_stroke(stroke: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(stroke, dict):
        report.error(f"{label} is not an object.")
        return
    if not isinstance(stroke.get("id"), int):
        report.error(f"{label} id must be an integer.")
    validate_point_hint(stroke.get("start_hint"), f"{label} start_hint", report)
    validate_point_hint(stroke.get("end_hint"), f"{label} end_hint", report)
    validate_path_hint(stroke.get("path_hint"), f"{label} path_hint", report)
    if not isinstance(stroke.get("arrow_hints"), list):
        report.error(f"{label} arrow_hints must be an array.")
    validate_rules(stroke.get("rules"), f"{label} rules", report)


def validate_point_hint(value: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(value, dict):
        report.error(f"{label} must be an object.")
        return
    for key in ("x", "y", "radius"):
        if not is_number(value.get(key)):
            report.error(f"{label}.{key} must be numeric.")
    if is_number(value.get("radius")) and float(value["radius"]) <= 0:
        report.error(f"{label}.radius must be greater than 0.")


def validate_path_hint(value: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(value, list) or not value:
        report.error(f"{label} must be a non-empty array.")
        return
    for segment_index, segment in enumerate(value):
        validate_segment(segment, f"{label}[{segment_index}]", report)


def validate_segment(segment: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(segment, dict):
        report.error(f"{label} must be an object.")
        return
    segment_type = segment.get("type")
    if segment_type not in SEGMENT_POINT_COUNTS:
        report.error(f"{label}.type must be one of {sorted(SEGMENT_POINT_COUNTS)}.")
        return
    points = segment.get("points")
    expected_count = SEGMENT_POINT_COUNTS[segment_type]
    if not isinstance(points, list) or len(points) != expected_count:
        report.error(f"{label}.points must contain {expected_count} points for {segment_type}.")
        return
    for point_index, point in enumerate(points):
        validate_point(point, f"{label}.points[{point_index}]", report)


def validate_point(value: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(value, dict):
        report.error(f"{label} must be an object.")
        return
    for key in ("x", "y"):
        if not is_number(value.get(key)):
            report.error(f"{label}.{key} must be numeric.")


def validate_rules(value: Any, label: str, report: ValidationReport) -> None:
    if not isinstance(value, dict):
        report.error(f"{label} must be an object.")
        return
    if not isinstance(value.get("direction_enforced"), bool):
        report.error(f"{label}.direction_enforced must be boolean.")
    for key in REQUIRED_RULE_KEYS[1:]:
        if not is_number(value.get(key)):
            report.error(f"{label}.{key} must be numeric.")


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description="Validate KanaLoop kanji vocabulary stroke JSON.")
    parser.add_argument(
        "path",
        nargs="?",
        type=Path,
        default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json",
        help="Kanji vocabulary stroke JSON path.",
    )
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=repo_root / "kana-loop",
        help="Godot asset root for resolving res:// audio paths.",
    )
    parser.add_argument(
        "--allow-missing-audio",
        action="store_true",
        help="Do not fail when an audio path points to a missing file.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    raise SystemExit(validate(args.path, args.asset_root, not args.allow_missing_audio))
