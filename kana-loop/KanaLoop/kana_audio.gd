extends Node

static var _instance: KanaAudio

const DEFAULT_VOICE := "Voice 1"
# Expected audio layout: res://assets/audio/<voice>/<kana>.ogg
# Example: res://assets/audio/Voice 1/あ.ogg
const VOICE_NAMES := ["Voice 1", "Voice 2"]
const AUDIO_BASE_PATH := "res://assets/audio"
const KANA_LIST := [
	"あ", "い", "う", "え", "お",
	"か", "き", "く", "け", "こ",
	"さ", "し", "す", "せ", "そ",
]

var voice_catalog: Dictionary = {}
var audio_player: AudioStreamPlayer

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = AudioServer.get_bus_name(0)
	add_child(audio_player)
	voice_catalog = _build_voice_catalogs()

func _build_voice_catalogs() -> Dictionary:
	var catalog: Dictionary = {}
	for voice in VOICE_NAMES:
		catalog[voice] = _build_kana_catalog(voice)
	return catalog

func _build_kana_catalog(voice: String) -> Dictionary:
	var catalog: Dictionary = {}
	for kana in KANA_LIST:
		catalog[kana] = _load_kana_stream(kana, voice)
	return catalog

func _create_placeholder_stream() -> AudioStream:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100
	stream.buffer_length = 0.1
	return stream

func _load_kana_stream(kana: String, voice: String) -> AudioStream:
	var path := _get_kana_audio_path(kana, voice)
	if not ResourceLoader.exists(path):
		push_warning("Missing kana audio file: %s" % path)
		return _create_placeholder_stream()
	var stream := ResourceLoader.load(path)
	if stream == null or not (stream is AudioStream):
		push_warning("Failed to load kana audio file: %s" % path)
		return _create_placeholder_stream()
	return stream

func _get_kana_audio_path(kana: String, voice: String) -> String:
	return "%s/%s/%s.ogg" % [AUDIO_BASE_PATH, voice, kana]

func get_voice_names() -> Array[String]:
	var names: Array[String] = []
	for voice in VOICE_NAMES:
		names.append(voice)
	return names

func play_kana_audio(kana: String, voice: String = "") -> void:
	var voice_key := voice
	if voice_key == "":
		voice_key = KanaState.get_selected_voice()
	var catalog: Dictionary = voice_catalog.get(voice_key, {})
	var stream: AudioStream = catalog.get(kana)
	if stream == null:
		return
	audio_player.stream = stream
	audio_player.play()
