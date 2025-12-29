# Lesson Schema

This directory contains lesson definitions. Each lesson file should follow the
schema below to ensure consistent loading, display, and grading.

## Required fields

```yaml
id: "lesson-unique-id" # required string
title: "Lesson title"   # required string
items:                 # required array
  - kana: "あ"           # required string
```

## Item fields

Each entry in `items` must include at least:

- `kana` (string, required): the canonical source string used for **grammar
  parsing (S2.T5)** and **display (S4)**. Always treat `items[].kana` as the
  source of truth for these stages.

The item objects are intentionally extensible so new fields can be added without
breaking existing content. For example, for **S5 grading** you may later add:

```yaml
items:
  - kana: "あ"
    accepted: ["あ", "ぁ"] # optional list for grading/validation in S5
```

## Notes

- Keep lesson `id` values stable so progress and analytics can be keyed
  reliably.
- Additional fields (e.g., `description`, `tags`, `audio`, `notes`) are allowed
  as long as the required fields above are present.
