from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import argparse
import json
import re
from typing import Any

KANJI_RE = re.compile(r"[\u3400-\u4DBF\u4E00-\u9FFF\U00020000-\U0002A6DF\U0002A700-\U0002B73F\U0002B740-\U0002B81F\U0002B820-\U0002CEAF]")


@dataclass
class VocabRecord:
    key: str
    note_id: int
    word: str
    reading: str
    meaning: str
    optimized_index: int
    entries: list[dict[str, Any]] = field(default_factory=list)
    entry_ids: list[str] = field(default_factory=list)
    word_kanji: set[str] = field(default_factory=set)
    sentence_kanji: set[str] = field(default_factory=set)

    @property
    def collateral_kanji(self) -> set[str]:
        return self.sentence_kanji - self.word_kanji


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


def kanji_set(value: Any) -> set[str]:
    return set(KANJI_RE.findall(str(value or "")))


def sortable_text(value: Any) -> str:
    return str(value or "").casefold()


def entry_index(entry: dict[str, Any], index_key: str) -> int | None:
    value = entry.get(index_key)
    if value is None and isinstance(entry.get("study"), dict):
        value = entry["study"].get(index_key)
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    return None


def record_key(entry: dict[str, Any], index: int) -> str:
    note_id = entry.get("note_id")
    if isinstance(note_id, int) or str(note_id).isdigit():
        return f"note:{int(note_id)}"
    return "context:%s|%s|%s|%d" % (
        sortable_text(entry.get("word")),
        sortable_text(entry.get("reading")),
        sortable_text(entry.get("meaning")),
        index,
    )


def build_records(entries: list[dict[str, Any]], index_key: str) -> tuple[list[VocabRecord], list[str]]:
    records_by_key: dict[str, VocabRecord] = {}
    missing: list[str] = []
    for position, entry in enumerate(entries):
        optimized_index = entry_index(entry, index_key)
        if optimized_index is None:
            missing.append(str(entry.get("id", f"entry:{position}")))
            continue
        key = record_key(entry, position)
        record = records_by_key.get(key)
        if record is None:
            note_id_value = entry.get("note_id")
            note_id = int(note_id_value) if isinstance(note_id_value, int) or str(note_id_value).isdigit() else 0
            sentence = entry.get("sample_sentence") if isinstance(entry.get("sample_sentence"), dict) else {}
            record = VocabRecord(
                key=key,
                note_id=note_id,
                word=str(entry.get("word", "")),
                reading=str(entry.get("reading", "")),
                meaning=str(entry.get("meaning", "")),
                optimized_index=optimized_index,
                word_kanji=kanji_set(entry.get("word")),
                sentence_kanji=kanji_set(sentence.get("ja", "")),
            )
            records_by_key[key] = record
        record.optimized_index = min(record.optimized_index, optimized_index)
        entry_id = str(entry.get("id", ""))
        if entry_id:
            record.entry_ids.append(entry_id)
        record.entries.append(entry)
        record.word_kanji |= kanji_set(entry.get("word"))
        sentence = entry.get("sample_sentence") if isinstance(entry.get("sample_sentence"), dict) else {}
        record.sentence_kanji |= kanji_set(sentence.get("ja", ""))
    records = sorted(records_by_key.values(), key=lambda record: (record.optimized_index, record.note_id, record.word, record.reading))
    return records, missing


def can_place(record: VocabRecord, learned_kanji: set[str], current_group_kanji: set[str]) -> bool:
    return record.sentence_kanji <= learned_kanji | current_group_kanji | record.word_kanji


def choose_group(pending: list[VocabRecord], learned_kanji: set[str], min_size: int, max_size: int) -> tuple[list[VocabRecord], list[VocabRecord]]:
    group: list[VocabRecord] = []
    group_kanji: set[str] = set()
    remaining: list[VocabRecord] = []

    for record in pending:
        if len(group) < max_size and can_place(record, learned_kanji, group_kanji):
            group.append(record)
            group_kanji |= record.word_kanji
        else:
            remaining.append(record)

    if len(group) >= min_size or not remaining:
        return group, remaining

    # If the strict pass cannot reach the target size, keep chronological progress by
    # adding the earliest blocked records and flagging their unlearned collateral kanji
    # in the generated report. This avoids infinite loops on real decks whose early
    # example sentences mention kanji that are learned much later.
    while len(group) < min_size and remaining:
        record = remaining.pop(0)
        group.append(record)
        group_kanji |= record.word_kanji
    return group, remaining


def build_groups(records: list[VocabRecord], min_size: int, max_size: int) -> list[list[VocabRecord]]:
    pending = records[:]
    learned_kanji: set[str] = set()
    groups: list[list[VocabRecord]] = []
    while pending:
        group, pending = choose_group(pending, learned_kanji, min_size, max_size)
        if not group:
            raise RuntimeError("Unable to place any vocabulary records into a study group.")
        groups.append(group)
        for record in group:
            learned_kanji |= record.word_kanji
    return groups


def group_payload(groups: list[list[VocabRecord]]) -> dict[str, Any]:
    learned_before: set[str] = set()
    payload_groups: list[dict[str, Any]] = []
    for group_number, group in enumerate(groups, start=1):
        assigned_kanji: set[str] = set()
        for record in group:
            assigned_kanji |= record.word_kanji
        allowed = learned_before | assigned_kanji
        records_payload: list[dict[str, Any]] = []
        blocked_count = 0
        for order, record in enumerate(group, start=1):
            unlearned = sorted(record.sentence_kanji - allowed)
            if unlearned:
                blocked_count += 1
            records_payload.append(
                {
                    "note_id": record.note_id,
                    "word": record.word,
                    "reading": record.reading,
                    "meaning": record.meaning,
                    "optimized_vocab_index": record.optimized_index,
                    "group_order": order,
                    "entry_ids": record.entry_ids,
                    "word_kanji": sorted(record.word_kanji),
                    "sentence_kanji": sorted(record.sentence_kanji),
                    "collateral_kanji": sorted(record.collateral_kanji),
                    "unlearned_sentence_kanji": unlearned,
                    "sentence_ok_for_group": not unlearned,
                }
            )
        payload_groups.append(
            {
                "id": f"core2000_group_{group_number:03d}",
                "index": group_number,
                "label": f"Core 2000 Group {group_number:03d}",
                "size": len(group),
                "assigned_kanji": sorted(assigned_kanji),
                "learned_kanji_before": sorted(learned_before),
                "blocked_sentence_count": blocked_count,
                "records": records_payload,
                "entry_ids": [entry_id for record in group for entry_id in record.entry_ids],
                "note_ids": [record.note_id for record in group if record.note_id],
            }
        )
        learned_before |= assigned_kanji
    return {
        "version": 1,
        "source": "Core 2000 Optimized-Voc-Index",
        "grouping_rules": {
            "chronological": True,
            "randomized": False,
            "sentence_kanji_must_be_in_previous_or_current_assigned_kanji": True,
        },
        "groups": payload_groups,
    }


def group_lookup(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    lookup: dict[str, dict[str, Any]] = {}
    for group in payload["groups"]:
        for record in group["records"]:
            for entry_id in record["entry_ids"]:
                lookup[entry_id] = {
                    "group_index": group["index"],
                    "group_id": group["id"],
                    "group_label": group["label"],
                    "group_order": record["group_order"],
                    "sentence_ok_for_group": record["sentence_ok_for_group"],
                    "word_kanji": record["word_kanji"],
                    "sentence_kanji": record["sentence_kanji"],
                    "collateral_kanji": record["collateral_kanji"],
                    "unlearned_sentence_kanji": record["unlearned_sentence_kanji"],
                }
    return lookup


def annotate_entries(entries: list[dict[str, Any]], payload: dict[str, Any], tag_prefix: str) -> int:
    lookup = group_lookup(payload)
    updated = 0
    for entry in entries:
        entry_id = str(entry.get("id", ""))
        group_data = lookup.get(entry_id)
        if group_data is None:
            continue
        study = entry.get("study")
        if not isinstance(study, dict):
            study = {}
        study.update(group_data)
        entry["study"] = study
        tags = entry.get("tags")
        if not isinstance(tags, list):
            tags = []
        tag = f"{tag_prefix}{int(group_data['group_index']):03d}"
        if tag not in tags:
            tags.append(tag)
            tags.sort(key=str)
        entry["tags"] = tags
        updated += 1
    return updated


def print_summary(payload: dict[str, Any], missing_indexes: list[str]) -> None:
    groups = payload["groups"]
    blocked = sum(int(group["blocked_sentence_count"]) for group in groups)
    print(f"Study groups generated: {len(groups)}")
    if groups:
        sizes = [int(group["size"]) for group in groups]
        print(f"Group size range: {min(sizes)}-{max(sizes)}")
    print(f"Records with sentence kanji outside the learned/current allowance: {blocked}")
    print(f"Entries missing optimized index and excluded: {len(missing_indexes)}")


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Generate chronological, dependency-aware kanji vocabulary study groups."
    )
    parser.add_argument("--data", type=Path, default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_strokes.json")
    parser.add_argument("--output", type=Path, default=repo_root / "kana-loop" / "assets" / "data" / "kanji_vocab_study_groups.json")
    parser.add_argument("--annotated-output", type=Path, help="Optional path for a copy of --data annotated with group study metadata and tags.")
    parser.add_argument("--index-key", default="optimized_vocab_index", help="Entry key containing the chronological Core 2000 index.")
    parser.add_argument("--min-size", type=int, default=10, help="Minimum vocabulary records per group, except the final group.")
    parser.add_argument("--max-size", type=int, default=20, help="Maximum vocabulary records per group.")
    parser.add_argument("--tag-prefix", default="study_group_", help="Tag prefix to add when --annotated-output is used.")
    parser.add_argument("--dry-run", action="store_true", help="Print a summary without writing files.")
    return parser.parse_args()


def main(args: argparse.Namespace) -> int:
    if args.min_size < 1 or args.max_size < args.min_size:
        raise ValueError("Expected 1 <= --min-size <= --max-size.")
    entries = load_entries(args.data)
    records, missing_indexes = build_records(entries, args.index_key)
    if not records:
        print(f"No records with {args.index_key!r} were found.")
        return 1
    groups = build_groups(records, args.min_size, args.max_size)
    payload = group_payload(groups)
    print_summary(payload, missing_indexes)
    if args.dry_run:
        print("Dry run: no files written.")
        return 0
    save_json(args.output, payload)
    print(f"Wrote study groups to {args.output}")
    if args.annotated_output:
        updated = annotate_entries(entries, payload, args.tag_prefix)
        save_json(args.annotated_output, entries)
        print(f"Wrote annotated entries to {args.annotated_output} ({updated} entries updated)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(parse_args()))
