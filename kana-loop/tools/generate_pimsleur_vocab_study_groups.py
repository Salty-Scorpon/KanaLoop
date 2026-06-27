from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import argparse
import json
from typing import Any


@dataclass
class PimsleurRecord:
    key: str
    priority_key: str
    deck_tag: str
    deck_index: int
    deck_position: int
    note_id: int
    word: str
    reading: str
    meaning: str
    entry_ids: list[str] = field(default_factory=list)


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


def pimsleur_metadata(entry: dict[str, Any]) -> dict[str, Any] | None:
    study = entry.get("study")
    if not isinstance(study, dict):
        return None
    pimsleur = study.get("pimsleur")
    if not isinstance(pimsleur, dict):
        return None
    priority_key = str(pimsleur.get("priority_key", "")).strip()
    if not priority_key:
        return None
    return pimsleur


def int_value(value: Any, default: int = 0) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.strip().lstrip("-").isdigit():
        return int(value)
    return default


def sortable_text(value: Any) -> str:
    return str(value or "").casefold()


def record_key(entry: dict[str, Any], index: int) -> str:
    source = entry.get("pimsleur_sentence_source")
    if isinstance(source, dict):
        source_note_id = source.get("note_id")
        if isinstance(source_note_id, int) or str(source_note_id).isdigit():
            return f"pimsleur_note:{int(source_note_id)}"
    note_id = entry.get("note_id")
    if isinstance(note_id, int) or str(note_id).isdigit():
        return f"note:{int(note_id)}"
    return "context:%s|%s|%s|%d" % (
        sortable_text(entry.get("word")),
        sortable_text(entry.get("reading")),
        sortable_text(entry.get("meaning")),
        index,
    )


def build_records(entries: list[dict[str, Any]]) -> tuple[list[PimsleurRecord], list[str]]:
    records_by_key: dict[str, PimsleurRecord] = {}
    missing_priority: list[str] = []
    for position, entry in enumerate(entries):
        metadata = pimsleur_metadata(entry)
        if metadata is None:
            if "pimsleur" in entry.get("tags", []) or entry.get("pimsleur_sentence_source"):
                missing_priority.append(str(entry.get("id", f"entry:{position}")))
            continue
        key = record_key(entry, position)
        priority_key = str(metadata["priority_key"])
        record = records_by_key.get(key)
        if record is None:
            note_id_value = entry.get("note_id")
            note_id = int(note_id_value) if isinstance(note_id_value, int) or str(note_id_value).isdigit() else 0
            record = PimsleurRecord(
                key=key,
                priority_key=priority_key,
                deck_tag=str(metadata.get("deck_tag", "")),
                deck_index=int_value(metadata.get("deck_index")),
                deck_position=int_value(metadata.get("deck_position")),
                note_id=note_id,
                word=str(entry.get("word", "")),
                reading=str(entry.get("reading", "")),
                meaning=str(entry.get("meaning", "")),
            )
            records_by_key[key] = record
        if priority_key < record.priority_key:
            record.priority_key = priority_key
        entry_id = str(entry.get("id", ""))
        if entry_id and entry_id not in record.entry_ids:
            record.entry_ids.append(entry_id)
    records = sorted(records_by_key.values(), key=lambda record: (record.priority_key, record.deck_index, record.deck_position, record.note_id, record.word, record.reading))
    return records, missing_priority


def build_groups(records: list[PimsleurRecord], group_size: int) -> list[list[PimsleurRecord]]:
    return [records[index : index + group_size] for index in range(0, len(records), group_size)]


def group_payload(groups: list[list[PimsleurRecord]], group_size: int) -> dict[str, Any]:
    payload_groups: list[dict[str, Any]] = []
    for group_number, group in enumerate(groups, start=1):
        records_payload: list[dict[str, Any]] = []
        for order, record in enumerate(group, start=1):
            records_payload.append(
                {
                    "note_id": record.note_id,
                    "word": record.word,
                    "reading": record.reading,
                    "meaning": record.meaning,
                    "priority_key": record.priority_key,
                    "deck_tag": record.deck_tag,
                    "deck_index": record.deck_index,
                    "deck_position": record.deck_position,
                    "group_order": order,
                    "entry_ids": record.entry_ids,
                }
            )
        payload_groups.append(
            {
                "id": f"pimsleur_group_{group_number:03d}",
                "index": group_number,
                "label": f"Pimsleur Group {group_number:03d}",
                "size": len(group),
                "group_size": group_size,
                "records": records_payload,
                "entry_ids": [entry_id for record in group for entry_id in record.entry_ids],
                "note_ids": [record.note_id for record in group if record.note_id],
            }
        )
    return {
        "version": 1,
        "source": "Pimsleur",
        "grouping_rules": {
            "pimsleur_only": True,
            "ordered_by": "study.pimsleur.priority_key",
            "group_size": group_size,
            "exclusive": False,
        },
        "groups": payload_groups,
    }


def print_summary(payload: dict[str, Any], missing_priority: list[str]) -> None:
    groups = payload["groups"]
    print(f"Pimsleur study groups generated: {len(groups)}")
    if groups:
        sizes = [int(group["size"]) for group in groups]
        print(f"Group size range: {min(sizes)}-{max(sizes)}")
    print(f"Pimsleur entries missing priority_key and excluded: {len(missing_priority)}")


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description="Generate Pimsleur-only kanji vocabulary study groups ordered by priority_key.")
    parser.add_argument("--data", type=Path, default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json")
    parser.add_argument("--output", type=Path, default=repo_root / "kana-loop" / "assets" / "data" / "pimsleur_vocab_study_groups.json")
    parser.add_argument("--group-size", type=int, default=20, help="Vocabulary records per Pimsleur group, except the final group.")
    parser.add_argument("--dry-run", action="store_true", help="Print a summary without writing files.")
    return parser.parse_args()


def main(args: argparse.Namespace) -> int:
    if args.group_size < 1:
        raise ValueError("Expected --group-size to be at least 1.")
    entries = load_entries(args.data)
    records, missing_priority = build_records(entries)
    if not records:
        print("No Pimsleur records with study.pimsleur.priority_key were found.")
        print_summary(group_payload([], args.group_size), missing_priority)
        return 1
    payload = group_payload(build_groups(records, args.group_size), args.group_size)
    print_summary(payload, missing_priority)
    if args.dry_run:
        print("Dry run: no files written.")
        return 0
    save_json(args.output, payload)
    print(f"Wrote Pimsleur study groups to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(parse_args()))
