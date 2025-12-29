class_name GradingUtils
extends RefCounted

# Normalizes transcripts for grading by applying NFKC Unicode normalization when available,
# converting katakana to hiragana, and trimming punctuation/whitespace.
static func normalize_transcript(text: String) -> String:
	var normalized := text
	if ClassDB.class_has_method("String", "unicode_normalize"):
		normalized = normalized.unicode_normalize(String.NORMALIZATION_KC)

	normalized = _katakana_to_hiragana(normalized)
	return _trim_punctuation(normalized)

static func _katakana_to_hiragana(text: String) -> String:
	var codepoints := text.to_utf32()
	for index in codepoints.size():
		var codepoint := codepoints[index]
		if (codepoint >= 0x30A1 and codepoint <= 0x30F6) or (codepoint >= 0x30FD and codepoint <= 0x30FE):
			codepoint -= 0x60
		codepoints[index] = codepoint
	return String.from_utf32(codepoints)

static func _trim_punctuation(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return trimmed
	var start := 0
	var end := trimmed.length()
	while start < end and _is_trim_char(trimmed.substr(start, 1)):
		start += 1
	while end > start and _is_trim_char(trimmed.substr(end - 1, 1)):
		end -= 1
	return trimmed.substr(start, end - start)

static func _is_trim_char(character: String) -> bool:
	return character in {
		" ": true,
		"\t": true,
		"\n": true,
		"\r": true,
		"\u3000": true,
		",": true,
		".": true,
		"!": true,
		"?": true,
		":": true,
		";": true,
		"\"": true,
		"'": true,
		"(": true,
		")": true,
		"[": true,
		"]": true,
		"{": true,
		"}": true,
		"、": true,
		"。": true,
		"・": true,
		"！": true,
		"？": true,
		"：": true,
		"；": true,
		"，": true,
		"．": true,
		"「": true,
		"」": true,
		"『": true,
		"』": true,
		"（": true,
		"）": true,
		"［": true,
		"］": true,
		"｛": true,
		"｝": true,
		"“": true,
		"”": true,
		"‘": true,
		"’": true,
		"…": true,
		"〜": true,
		"～": true,
	}
