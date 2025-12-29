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

static func grade_transcript(normalized_input: String, normalized_target: String) -> Dictionary:
	var distance := levenshtein_distance(normalized_input, normalized_target)
	var max_len := max(_string_length(normalized_input), _string_length(normalized_target))
	var score := 1.0
	if max_len > 0:
		score = 1.0 - (float(distance) / float(max_len))
	return {
		"normalized_input": normalized_input,
		"normalized_target": normalized_target,
		"distance": distance,
		"score": score,
		"is_correct": distance == 0,
	}

static func levenshtein_distance(left: String, right: String) -> int:
	var left_points := left.to_utf32()
	var right_points := right.to_utf32()
	var left_len := left_points.size()
	var right_len := right_points.size()

	if left_len == 0:
		return right_len
	if right_len == 0:
		return left_len

	var previous := []
	previous.resize(right_len + 1)
	for index in range(right_len + 1):
		previous[index] = index

	for left_index in range(1, left_len + 1):
		var current := []
		current.resize(right_len + 1)
		current[0] = left_index
		var left_codepoint := left_points[left_index - 1]
		for right_index in range(1, right_len + 1):
			var cost := 0 if left_codepoint == right_points[right_index - 1] else 1
			var deletion := previous[right_index] + 1
			var insertion := current[right_index - 1] + 1
			var substitution := previous[right_index - 1] + cost
			current[right_index] = min(deletion, insertion, substitution)
		previous = current

	return previous[right_len]

static func _string_length(text: String) -> int:
	return text.to_utf32().size()

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
