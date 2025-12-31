#!/usr/bin/env python3
import argparse
import json
import sqlite3
from pathlib import Path

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build search_index.sqlite from jmdict_with_freq.json",
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "jmdict_with_freq.json",
        help="Path to jmdict_with_freq.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "search_index.sqlite",
        help="Path to output SQLite database",
    )
    return parser.parse_args()


def normalize_gloss(gloss_value: object) -> str:
    if gloss_value is None:
        return ""
    if isinstance(gloss_value, list):
        return "; ".join(str(item) for item in gloss_value)
    return str(gloss_value)


def build_database(entries: list[dict], output_path: Path) -> None:
    if output_path.exists():
        output_path.unlink()

    connection = sqlite3.connect(output_path)
    try:
        cursor = connection.cursor()
        cursor.execute("PRAGMA journal_mode = WAL;")
        cursor.execute("PRAGMA synchronous = NORMAL;")
        cursor.execute("PRAGMA temp_store = MEMORY;")

        cursor.execute(
            """
            CREATE TABLE entries (
                id TEXT PRIMARY KEY,
                kana TEXT,
                kanji TEXT,
                romaji TEXT,
                gloss TEXT,
                frequency_rank INTEGER,
                jlpt TEXT
            );
            """
        )

        cursor.execute(
            """
            CREATE VIRTUAL TABLE entries_fts USING fts5(
                kana,
                kanji,
                romaji,
                gloss,
                content='entries',
                content_rowid='rowid'
            );
            """
        )

        rows = []
        for entry in entries:
            rows.append(
                (
                    entry.get("id"),
                    entry.get("kana"),
                    entry.get("kanji"),
                    entry.get("romaji"),
                    normalize_gloss(entry.get("gloss")),
                    entry.get("frequency_rank"),
                    entry.get("jlpt"),
                )
            )

        cursor.executemany(
            """
            INSERT INTO entries (
                id,
                kana,
                kanji,
                romaji,
                gloss,
                frequency_rank,
                jlpt
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            rows,
        )

        cursor.execute(
            """
            INSERT INTO entries_fts (
                rowid,
                kana,
                kanji,
                romaji,
                gloss
            )
            SELECT rowid, kana, kanji, romaji, gloss FROM entries;
            """
        )

        cursor.execute("CREATE INDEX entries_frequency_rank ON entries(frequency_rank);")
        cursor.execute("CREATE INDEX entries_jlpt ON entries(jlpt);")
        connection.commit()
    finally:
        connection.close()


def main() -> None:
    args = parse_args()
    input_path = args.input
    output_path = args.output

    with input_path.open("r", encoding="utf-8") as handle:
        entries = json.load(handle)

    build_database(entries, output_path)
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
