extends Node

const AUDIO_KEYS := ["kanji", "word", "sentence_ja", "meaning_en"]
const KANJI_FALLBACK_KEYS := ["kanji", "word"]
const WORD_FALLBACK_KEYS := ["word", "kanji"]

var audio_player: AudioStreamPlayer
var stream_cache: Dictionary = {}
var placeholder_stream: AudioStream
var last_error := ""

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = AudioServer.get_bus_name(0)
	add_child(audio_player)
	placeholder_stream = _create_placeholder_stream()

func play_entry_kanji(entry: Dictionary) -> bool:
	return play_entry_audio(entry, KANJI_FALLBACK_KEYS)

func play_entry_word(entry: Dictionary) -> bool:
	return play_entry_audio(entry, WORD_FALLBACK_KEYS)

func play_entry_sentence_ja(entry: Dictionary) -> bool:
	return play_entry_audio(entry, ["sentence_ja"])

func play_entry_meaning_en(entry: Dictionary) -> bool:
	return play_entry_audio(entry, ["meaning_en"])

func play_entry_kanji_by_id(entry_id: String) -> bool:
	return play_entry_kanji(KanjiVocabData.get_entry_by_id(entry_id))

func play_entry_word_by_id(entry_id: String) -> bool:
	return play_entry_word(KanjiVocabData.get_entry_by_id(entry_id))

func play_entry_sentence_ja_by_id(entry_id: String) -> bool:
	return play_entry_sentence_ja(KanjiVocabData.get_entry_by_id(entry_id))

func play_entry_meaning_en_by_id(entry_id: String) -> bool:
	return play_entry_meaning_en(KanjiVocabData.get_entry_by_id(entry_id))

func play_entry_audio(entry: Dictionary, preferred_keys: Array) -> bool:
	var path := get_preferred_audio_path(entry, preferred_keys)
	if path == "":
		last_error = "No matching vocabulary audio path found."
		return false
	return play_audio_path(path)

func play_audio_path(path: String) -> bool:
	last_error = ""
	var stream := _get_stream(path)
	if stream == null:
		last_error = "Unable to load vocabulary audio stream: %s" % path
		return false
	audio_player.stream = stream
	audio_player.play()
	return true

func stop() -> void:
	if audio_player != null:
		audio_player.stop()

func is_playing() -> bool:
	return audio_player != null and audio_player.playing

func get_last_error() -> String:
	return last_error

func get_entry_audio_path(entry: Dictionary, key: String) -> String:
	if not AUDIO_KEYS.has(key):
		return ""
	var audio: Dictionary = entry.get("audio", {})
	return String(audio.get(key, "")).strip_edges()

func get_preferred_audio_path(entry: Dictionary, preferred_keys: Array) -> String:
	for key in preferred_keys:
		var path := get_entry_audio_path(entry, String(key))
		if path != "":
			return path
	return ""

func has_entry_audio(entry: Dictionary, key: String = "") -> bool:
	if key != "":
		return get_entry_audio_path(entry, key) != ""
	for audio_key in AUDIO_KEYS:
		if get_entry_audio_path(entry, audio_key) != "":
			return true
	return false

func _get_stream(path: String) -> AudioStream:
	if stream_cache.has(path):
		var cached_stream: AudioStream = stream_cache[path]
		return cached_stream
	var stream := _load_stream(path)
	stream_cache[path] = stream
	return stream

func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("Missing vocabulary audio file: %s" % path)
		return placeholder_stream
	var stream := ResourceLoader.load(path)
	if stream == null or not (stream is AudioStream):
		push_warning("Failed to load vocabulary audio file: %s" % path)
		return placeholder_stream
	return stream

func _create_placeholder_stream() -> AudioStream:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100
	stream.buffer_length = 0.1
	return stream
