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
3. Validate the output:
   ```bash
   python3 kana-loop/tools/validate_kana_outline.py
   ```
4. The app reads the JSON file directly, so no code changes are required when SVGs change.
