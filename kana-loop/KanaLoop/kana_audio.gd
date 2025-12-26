extends Node

static var _instance: KanaAudio

const DEFAULT_VOICE := "Voice 1"
const VOICE_NAMES := ["Voice 1", "Voice 2"]
const KANA_LIST := [
	"あ", "い", "う", "え", "お",
	"か", "き", "く", "け", "こ",
	"さ", "し", "す", "せ", "そ",
]

var voice_catalog: Dictionary = {}
var audio_player: AudioStreamPlayer

func _enter_tree() -> void:
	_instance = self

func _exit_tree() -> void:
	if _instance == self:
		_instance = null

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = AudioServer.get_bus_name(0)
	add_child(audio_player)
	voice_catalog = _build_voice_catalogs()

func _build_voice_catalogs() -> Dictionary:
	var catalog: Dictionary = {}
	for voice in VOICE_NAMES:
		catalog[voice] = _build_kana_catalog()
	return catalog

func _build_kana_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for kana in KANA_LIST:
		catalog[kana] = _create_placeholder_stream()
	return catalog

func _create_placeholder_stream() -> AudioStream:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100
	stream.buffer_length = 0.1
	return stream

static func get_voice_names() -> Array[String]:
	return VOICE_NAMES.duplicate()

static func get_instance() -> KanaAudio:
	return _instance

static func play_kana_audio(kana: String, voice: String = "") -> void:
	if _instance == null:
		return
	_instance._play_kana_audio(kana, voice)

func _play_kana_audio(kana: String, voice: String = "") -> void:
	var voice_key := voice
	if voice_key == "":
		voice_key = KanaState.get_selected_voice()
	var catalog: Dictionary = voice_catalog.get(voice_key, {})
	var stream: AudioStream = catalog.get(kana)
	if stream == null:
		return
	audio_player.stream = stream
	audio_player.play()
