from __future__ import annotations

from pathlib import Path
import json

from kana_outline_utils import (
    HIRAGANA_ORDER,
    collect_stroke_paths,
    split_yoon_kana,
    strokesvg_dir,
)


def load_kana_data(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("Expected kana outline JSON to be a list of KanaDef objects.")
    return data


def validate(kana_outline_path: Path) -> int:
    errors: list[str] = []
    kana_defs = load_kana_data(kana_outline_path)
    kana_lookup = {kana_def.get("kana"): kana_def for kana_def in kana_defs}

    for kana in HIRAGANA_ORDER:
        kana_def = kana_lookup.get(kana)
        if kana_def is None:
            errors.append(f"Missing kana definition: {kana}")
            continue
        strokes = kana_def.get("strokes")
        if not strokes:
            errors.append(f"Kana {kana} has no strokes.")
            continue
        for stroke in strokes:
            start_hint = stroke.get("start_hint")
            end_hint = stroke.get("end_hint")
            if not start_hint or not end_hint:
                errors.append(f"Kana {kana} stroke {stroke.get('id')} missing start/end hints.")
            if not stroke.get("path_hint"):
                errors.append(f"Kana {kana} stroke {stroke.get('id')} has empty path_hint.")

        yoon_parts = split_yoon_kana(kana)
        if yoon_parts:
            base_kana, small_kana = yoon_parts
            base_paths, _ = collect_stroke_paths(strokesvg_dir() / f"{base_kana}.svg")
            small_paths, _ = collect_stroke_paths(strokesvg_dir() / f"{small_kana}.svg")
            svg_stroke_count = len(base_paths) + len(small_paths)
        else:
            svg_path = strokesvg_dir() / f"{kana}.svg"
            stroke_paths, _ = collect_stroke_paths(svg_path)
            svg_stroke_count = len(stroke_paths)
        if kana_def.get("stroke_count") != svg_stroke_count:
            errors.append(
                f"Kana {kana} stroke_count ({kana_def.get('stroke_count')}) does not match SVG ({svg_stroke_count})."
            )
        if len(strokes) != svg_stroke_count:
            errors.append(
                f"Kana {kana} stroke list ({len(strokes)}) does not match SVG ({svg_stroke_count})."
            )

    if errors:
        print("Validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Kana outline validation passed.")
    return 0


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[2]
    outline_path = repo_root / "kana-loop" / "assets" / "data" / "kana_outline.json"
    raise SystemExit(validate(outline_path))
