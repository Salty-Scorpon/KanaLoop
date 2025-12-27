from __future__ import annotations

from pathlib import Path
import argparse
import json

from kana_outline_utils import (
    HIRAGANA_ORDER,
    ROMAJI_MAP,
    apply_yoon_transform,
    collect_stroke_paths,
    normalize_segment,
    parse_path_segments,
    save_json,
    split_yoon_kana,
    strokesvg_dir,
)

START_HINT_RADIUS = 0.05
END_HINT_RADIUS = 0.05
DEFAULT_RULES = {
    "direction_enforced": True,
    "corridor_radius": 0.05,
    "start_must_be_near": 0.08,
    "end_must_be_near": 0.08,
}


def build_stroke_definition(
    stroke_id: int,
    d_path: str | None,
    view_box,
    segments: list[dict] | None = None,
) -> dict:
    if segments is None:
        if d_path is None:
            raise ValueError(f"Stroke {stroke_id} missing path data.")
        segments = parse_path_segments(d_path)
    if not segments:
        raise ValueError(f"Stroke {stroke_id} contains no drawable segments.")
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


def build_kana_def(kana: str, svg_root: Path) -> dict:
    yoon_parts = split_yoon_kana(kana)
    if yoon_parts:
        base_kana, small_kana = yoon_parts
        base_path = svg_root / f"{base_kana}.svg"
        small_path = svg_root / f"{small_kana}.svg"
        base_paths, view_box = collect_stroke_paths(base_path)
        small_paths, _ = collect_stroke_paths(small_path)
        if not base_paths:
            raise ValueError(f"No stroke paths found in {base_path}.")
        if not small_paths:
            raise ValueError(f"No stroke paths found in {small_path}.")
        strokes = []
        for d_path in base_paths:
            strokes.append(build_stroke_definition(len(strokes) + 1, d_path, view_box))
        for d_path in small_paths:
            segments = parse_path_segments(d_path)
            if not segments:
                raise ValueError(f"Small kana stroke missing segments in {small_path}.")
            transformed_segments = apply_yoon_transform(segments, view_box, base_kana, small_kana)
            strokes.append(
                build_stroke_definition(
                    len(strokes) + 1,
                    None,
                    view_box,
                    segments=transformed_segments,
                )
            )
    else:
        svg_path = svg_root / f"{kana}.svg"
        stroke_paths, view_box = collect_stroke_paths(svg_path)
        if not stroke_paths:
            raise ValueError(f"No stroke paths found in {svg_path}.")
        strokes = [
            build_stroke_definition(stroke_index + 1, d_path, view_box)
            for stroke_index, d_path in enumerate(stroke_paths)
        ]
    return {
        "kana": kana,
        "romaji": ROMAJI_MAP[kana],
        "stroke_count": len(strokes),
        "strokes": strokes,
    }


def convert(output_path: Path) -> None:
    svg_root = strokesvg_dir()
    kana_defs = []
    for kana in HIRAGANA_ORDER:
        kana_defs.append(build_kana_def(kana, svg_root))
    save_json(output_path, kana_defs)


def update_single_kana(output_path: Path, kana: str) -> None:
    if kana not in ROMAJI_MAP:
        raise ValueError(f"Unsupported kana: {kana}")
    if not output_path.exists():
        raise FileNotFoundError(
            f"Missing {output_path}. Run the full converter once before updating a single kana."
        )
    svg_root = strokesvg_dir()
    kana_def = build_kana_def(kana, svg_root)
    existing = json.loads(output_path.read_text(encoding="utf-8"))
    if not isinstance(existing, list):
        raise ValueError(f"Expected {output_path} to contain a list of kana entries.")

    updated = False
    for index, entry in enumerate(existing):
        if entry.get("kana") == kana:
            existing[index] = kana_def
            updated = True
            break

    if not updated:
        raise ValueError(f"Could not find kana {kana} in {output_path}.")

    save_json(output_path, existing)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert StrokeSVG hiragana to kana outline JSON.")
    parser.add_argument(
        "--kana",
        help="Regenerate only a single kana entry (e.g., --kana お).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[2]
    output_file = repo_root / "kana-loop" / "assets" / "data" / "kana_outline.json"
    args = parse_args()
    if args.kana:
        update_single_kana(output_file, args.kana)
        print(f"Updated {args.kana} in {output_file}")
    else:
        convert(output_file)
        print(f"Wrote {output_file}")
