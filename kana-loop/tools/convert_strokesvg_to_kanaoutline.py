from __future__ import annotations

from pathlib import Path

from kana_outline_utils import (
    HIRAGANA_ORDER,
    ROMAJI_MAP,
    collect_stroke_paths,
    normalize_segment,
    parse_path_segments,
    save_json,
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


def build_stroke_definition(stroke_id: int, d_path: str, view_box) -> dict:
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


def build_kana_def(kana: str, svg_path: Path) -> dict:
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
        svg_path = svg_root / f"{kana}.svg"
        if not svg_path.exists():
            raise FileNotFoundError(f"Missing SVG for {kana}: {svg_path}")
        kana_defs.append(build_kana_def(kana, svg_path))
    save_json(output_path, kana_defs)


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[2]
    output_file = repo_root / "kana-loop" / "assets" / "data" / "kana_outline.json"
    convert(output_file)
    print(f"Wrote {output_file}")
