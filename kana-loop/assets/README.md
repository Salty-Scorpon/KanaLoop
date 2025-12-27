# Assets

## Kana outline pipeline

The guided writing outline data is generated from the StrokeSVG hiragana set.

**Workflow**

1. Update or add SVGs in `strokesvg/dist/hiragana/`.
2. Run the converter:
   ```bash
   python3 kana-loop/tools/convert_strokesvg_to_kanaoutline.py
   ```
   This writes `kana-loop/assets/data/kana_outline.json`.
   - To regenerate a single kana entry in-place (for example, after editing `strokesvg/dist/hiragana/お.svg`):
     ```bash
     python3 kana-loop/tools/convert_strokesvg_to_kanaoutline.py --kana お
     ```
3. Validate the output:
   ```bash
   python3 kana-loop/tools/validate_kana_outline.py
   ```
4. The app reads the JSON file directly, so no code changes are required when SVGs change.

## Kana outline overrides

Guided writing supports per-kana overrides so you can fix a single kana without regenerating
the full outline file. Overrides are applied after `kana_outline.json` is loaded, and the
last override loaded for a kana replaces the generated entry.

**Load order (later wins)**

1. `assets/data/kana_outline.json` (generated data)
2. `assets/data/kana_outline_overrides.json` (optional)
3. `assets/data/overrides/*.json` (optional, loaded in directory listing order)

### Override formats

Use one of the following formats:

**Single file with multiple entries**

`assets/data/kana_outline_overrides.json` can contain:

* An array of full kana entries, matching the structure from `kana_outline.json`.
* A dictionary keyed by kana, where each value is a full kana entry (the `kana` field is
  injected automatically).

Example (array):

```json
[
  {
    "kana": "お",
    "strokes": [
      { "path_hint": [], "start_hint": {}, "end_hint": {}, "rules": {} }
    ]
  }
]
```

Example (dictionary keyed by kana):

```json
{
  "お": {
    "strokes": [
      { "path_hint": [], "start_hint": {}, "end_hint": {}, "rules": {} }
    ]
  }
}
```

**Per-kana file**

Place a file like `assets/data/overrides/お.json` with a single kana entry:

```json
{
  "kana": "お",
  "strokes": [
    { "path_hint": [], "start_hint": {}, "end_hint": {}, "rules": {} }
  ]
}
```

Whichever entry is loaded last for a given kana replaces the generated data, so you can
quickly fix a single kana by dropping an override file in `assets/data/overrides/`.
