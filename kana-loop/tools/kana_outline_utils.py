from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

HIRAGANA_ORDER = [
    "あ", "い", "う", "え", "お",
    "か", "き", "く", "け", "こ",
    "さ", "し", "す", "せ", "そ",
    "た", "ち", "つ", "て", "と",
    "な", "に", "ぬ", "ね", "の",
    "は", "ひ", "ふ", "へ", "ほ",
    "ま", "み", "む", "め", "も",
    "や", "ゆ", "よ",
    "ら", "り", "る", "れ", "ろ",
    "わ", "を", "ん",
    "が", "ぎ", "ぐ", "げ", "ご",
    "ざ", "じ", "ず", "ぜ", "ぞ",
    "だ", "ぢ", "づ", "で", "ど",
    "ば", "び", "ぶ", "べ", "ぼ",
    "ぱ", "ぴ", "ぷ", "ぺ", "ぽ",
    "きゃ", "きゅ", "きょ",
    "ぎゃ", "ぎゅ", "ぎょ",
    "しゃ", "しゅ", "しょ",
    "じゃ", "じゅ", "じょ",
    "ちゃ", "ちゅ", "ちょ",
    "にゃ", "にゅ", "にょ",
    "ひゃ", "ひゅ", "ひょ",
    "びゃ", "びゅ", "びょ",
    "ぴゃ", "ぴゅ", "ぴょ",
    "みゃ", "みゅ", "みょ",
    "りゃ", "りゅ", "りょ",
    "ぁ", "ぃ", "ぅ", "ぇ", "ぉ",
    "ゃ", "ゅ", "ょ",
]

ROMAJI_MAP = {
    "あ": "a",
    "い": "i",
    "う": "u",
    "え": "e",
    "お": "o",
    "か": "ka",
    "き": "ki",
    "く": "ku",
    "け": "ke",
    "こ": "ko",
    "が": "ga",
    "ぎ": "gi",
    "ぐ": "gu",
    "げ": "ge",
    "ご": "go",
    "さ": "sa",
    "し": "shi",
    "す": "su",
    "せ": "se",
    "そ": "so",
    "ざ": "za",
    "じ": "ji",
    "ず": "zu",
    "ぜ": "ze",
    "ぞ": "zo",
    "た": "ta",
    "ち": "chi",
    "つ": "tsu",
    "て": "te",
    "と": "to",
    "だ": "da",
    "ぢ": "ji",
    "づ": "zu",
    "で": "de",
    "ど": "do",
    "な": "na",
    "に": "ni",
    "ぬ": "nu",
    "ね": "ne",
    "の": "no",
    "は": "ha",
    "ひ": "hi",
    "ふ": "fu",
    "へ": "he",
    "ほ": "ho",
    "ば": "ba",
    "び": "bi",
    "ぶ": "bu",
    "べ": "be",
    "ぼ": "bo",
    "ぱ": "pa",
    "ぴ": "pi",
    "ぷ": "pu",
    "ぺ": "pe",
    "ぽ": "po",
    "きゃ": "kya",
    "きゅ": "kyu",
    "きょ": "kyo",
    "ぎゃ": "gya",
    "ぎゅ": "gyu",
    "ぎょ": "gyo",
    "しゃ": "sha",
    "しゅ": "shu",
    "しょ": "sho",
    "じゃ": "ja",
    "じゅ": "ju",
    "じょ": "jo",
    "ちゃ": "cha",
    "ちゅ": "chu",
    "ちょ": "cho",
    "にゃ": "nya",
    "にゅ": "nyu",
    "にょ": "nyo",
    "ひゃ": "hya",
    "ひゅ": "hyu",
    "ひょ": "hyo",
    "びゃ": "bya",
    "びゅ": "byu",
    "びょ": "byo",
    "ぴゃ": "pya",
    "ぴゅ": "pyu",
    "ぴょ": "pyo",
    "みゃ": "mya",
    "みゅ": "myu",
    "みょ": "myo",
    "りゃ": "rya",
    "りゅ": "ryu",
    "りょ": "ryo",
    "ま": "ma",
    "み": "mi",
    "む": "mu",
    "め": "me",
    "も": "mo",
    "や": "ya",
    "ゆ": "yu",
    "よ": "yo",
    "ら": "ra",
    "り": "ri",
    "る": "ru",
    "れ": "re",
    "ろ": "ro",
    "わ": "wa",
    "を": "wo",
    "ん": "n",
    "ぁ": "xa",
    "ぃ": "xi",
    "ぅ": "xu",
    "ぇ": "xe",
    "ぉ": "xo",
    "ゃ": "xya",
    "ゅ": "xyu",
    "ょ": "xyo",
}


@dataclass
class ViewBox:
    min_x: float
    min_y: float
    width: float
    height: float


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def strokesvg_dir() -> Path:
    return repo_root() / "strokesvg" / "dist" / "hiragana"


def load_view_box(svg_root: ET.Element) -> ViewBox:
    view_box = svg_root.attrib.get("viewBox") or svg_root.attrib.get("viewbox")
    if view_box:
        parts = [float(value) for value in view_box.replace(",", " ").split()]
        if len(parts) == 4:
            return ViewBox(parts[0], parts[1], parts[2], parts[3])
    return ViewBox(0.0, 0.0, 1024.0, 1024.0)


def _local_name(tag: str) -> str:
    return tag.split("}", 1)[-1]


def _find_strokes_group(svg_root: ET.Element) -> ET.Element | None:
    for element in svg_root.iter():
        if _local_name(element.tag) == "g" and element.attrib.get("data-strokesvg") == "strokes":
            return element
    return None


def collect_stroke_paths(svg_path: Path) -> tuple[list[str], ViewBox]:
    tree = ET.parse(svg_path)
    root = tree.getroot()
    view_box = load_view_box(root)
    strokes_group = _find_strokes_group(root)
    if strokes_group is None:
        return [], view_box

    paths: list[str] = []

    def walk(node: ET.Element) -> None:
        for child in list(node):
            if _local_name(child.tag) == "path":
                d_attr = child.attrib.get("d")
                if d_attr:
                    paths.append(d_attr)
            if list(child):
                walk(child)

    walk(strokes_group)
    return paths, view_box


def tokenize_path(d: str) -> list[str]:
    token_re = re.compile(r"[MmLlHhVvCcSsQqTtZz]|-?(?:\d+\.\d+|\d+\.?|\.\d+)(?:[eE][-+]?\d+)?")
    return token_re.findall(d)


def parse_path_segments(d: str) -> list[dict]:
    tokens = tokenize_path(d)
    segments: list[dict] = []
    index = 0
    current = (0.0, 0.0)
    start = (0.0, 0.0)
    prev_cmd = None
    prev_control = None

    def read_numbers(count: int) -> list[float]:
        nonlocal index
        numbers = [float(tokens[index + i]) for i in range(count)]
        index += count
        return numbers

    def add_line(end: tuple[float, float]) -> None:
        nonlocal current
        segments.append({
            "type": "Line",
            "points": [
                {"x": current[0], "y": current[1]},
                {"x": end[0], "y": end[1]},
            ],
        })
        current = end

    def add_quad(control: tuple[float, float], end: tuple[float, float]) -> None:
        nonlocal current, prev_control
        segments.append({
            "type": "Quad",
            "points": [
                {"x": current[0], "y": current[1]},
                {"x": control[0], "y": control[1]},
                {"x": end[0], "y": end[1]},
            ],
        })
        current = end
        prev_control = control

    def add_cubic(control1: tuple[float, float], control2: tuple[float, float], end: tuple[float, float]) -> None:
        nonlocal current, prev_control
        segments.append({
            "type": "Cubic",
            "points": [
                {"x": current[0], "y": current[1]},
                {"x": control1[0], "y": control1[1]},
                {"x": control2[0], "y": control2[1]},
                {"x": end[0], "y": end[1]},
            ],
        })
        current = end
        prev_control = control2

    while index < len(tokens):
        token = tokens[index]
        if re.match(r"[MmLlHhVvCcSsQqTtZz]", token):
            index += 1
            cmd = token
        else:
            if prev_cmd is None:
                raise ValueError("Path data missing command.")
            cmd = prev_cmd

        is_relative = cmd.islower()
        cmd_upper = cmd.upper()

        if cmd_upper == "M":
            pairs = []
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                pairs.extend(read_numbers(2))
            for pair_index in range(0, len(pairs), 2):
                x = pairs[pair_index]
                y = pairs[pair_index + 1]
                if is_relative:
                    x += current[0]
                    y += current[1]
                if pair_index == 0:
                    current = (x, y)
                    start = current
                else:
                    add_line((x, y))
            prev_control = None
        elif cmd_upper == "L":
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                x, y = read_numbers(2)
                if is_relative:
                    x += current[0]
                    y += current[1]
                add_line((x, y))
            prev_control = None
        elif cmd_upper == "H":
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                x = read_numbers(1)[0]
                if is_relative:
                    x += current[0]
                add_line((x, current[1]))
            prev_control = None
        elif cmd_upper == "V":
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                y = read_numbers(1)[0]
                if is_relative:
                    y += current[1]
                add_line((current[0], y))
            prev_control = None
        elif cmd_upper == "C":
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                x1, y1, x2, y2, x, y = read_numbers(6)
                if is_relative:
                    x1 += current[0]
                    y1 += current[1]
                    x2 += current[0]
                    y2 += current[1]
                    x += current[0]
                    y += current[1]
                add_cubic((x1, y1), (x2, y2), (x, y))
            prev_control = (segments[-1]["points"][2]["x"], segments[-1]["points"][2]["y"]) if segments else None
        elif cmd_upper == "S":
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                x2, y2, x, y = read_numbers(4)
                if prev_cmd and prev_cmd.upper() in {"C", "S"} and prev_control is not None:
                    cx = current[0] * 2 - prev_control[0]
                    cy = current[1] * 2 - prev_control[1]
                else:
                    cx, cy = current
                if is_relative:
                    x2 += current[0]
                    y2 += current[1]
                    x += current[0]
                    y += current[1]
                add_cubic((cx, cy), (x2, y2), (x, y))
            prev_control = (segments[-1]["points"][2]["x"], segments[-1]["points"][2]["y"]) if segments else None
        elif cmd_upper == "Q":
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                x1, y1, x, y = read_numbers(4)
                if is_relative:
                    x1 += current[0]
                    y1 += current[1]
                    x += current[0]
                    y += current[1]
                add_quad((x1, y1), (x, y))
            prev_control = (segments[-1]["points"][1]["x"], segments[-1]["points"][1]["y"]) if segments else None
        elif cmd_upper == "T":
            while index < len(tokens) and not re.match(r"[MmLlHhVvCcSsQqTtZz]", tokens[index]):
                x, y = read_numbers(2)
                if prev_cmd and prev_cmd.upper() in {"Q", "T"} and prev_control is not None:
                    cx = current[0] * 2 - prev_control[0]
                    cy = current[1] * 2 - prev_control[1]
                else:
                    cx, cy = current
                if is_relative:
                    x += current[0]
                    y += current[1]
                add_quad((cx, cy), (x, y))
            prev_control = (segments[-1]["points"][1]["x"], segments[-1]["points"][1]["y"]) if segments else None
        elif cmd_upper == "Z":
            if current != start:
                add_line(start)
            prev_control = None
        else:
            raise ValueError(f"Unsupported path command: {cmd}")

        prev_cmd = cmd

    return segments


def normalize_point(point: dict, view_box: ViewBox) -> dict:
    return {
        "x": (point["x"] - view_box.min_x) / view_box.width,
        "y": (point["y"] - view_box.min_y) / view_box.height,
    }


def normalize_segment(segment: dict, view_box: ViewBox) -> dict:
    return {
        "type": segment["type"],
        "points": [normalize_point(point, view_box) for point in segment["points"]],
    }


def save_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
