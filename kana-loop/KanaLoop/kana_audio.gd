extends Node

static var _instance: KanaAudio

const DEFAULT_VOICE := "Voice 1"
# Expected audio layout: res://assets/audio/<voice>/<kana>.ogg
# Example: res://assets/audio/Voice 1/あ.ogg
const UI_SUCCESS_AUDIO_PATH := "res://assets/audio/ui/success.ogg"
const UI_FAILURE_AUDIO_PATH := "res://assets/audio/ui/failure.ogg"
const VOICE_NAMES := ["Voice 1", "Voice 2"]
const AUDIO_BASE_PATH := "res://assets/audio"
const KANA_LIST := [
	"あ", "い", "う", "え", "お",
	"か", "き", "く", "け", "こ",
	"さ", "し", "す", "せ", "そ",
	"た", "ち", "つ", "て", "と",
	"な", "に", "ぬ", "ね", "の",
	"は", "ひ", "ふ", "へ", "ほ",
	"ま", "み", "む", "め", "も",
	"や", "ゆ", "よ",
	"ら", "り", "る", "れ", "ろ",
	"わ", "を",
	"ん",
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
]

var voice_catalog: Dictionary = {}
var audio_player: AudioStreamPlayer
var ui_success_stream: AudioStream
var ui_failure_stream: AudioStream


func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = AudioServer.get_bus_name(0)
	add_child(audio_player)
	voice_catalog = _build_voice_catalogs()
	ui_success_stream = _load_ui_stream(UI_SUCCESS_AUDIO_PATH)
	ui_failure_stream = _load_ui_stream(UI_FAILURE_AUDIO_PATH)

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

func _load_ui_stream(path: String) -> AudioStream:
	# UI cues live at:
	# - res://assets/audio/ui/success.ogg
	# - res://assets/audio/ui/failure.ogg
	if not ResourceLoader.exists(path):
		push_warning("Missing UI audio file: %s" % path)
		return _create_placeholder_stream()
	var stream := ResourceLoader.load(path)
	if stream == null or not (stream is AudioStream):
		push_warning("Failed to load UI audio file: %s" % path)
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

func play_kana_audio_and_wait(kana: String, voice: String = "") -> void:
	var voice_key := voice
	if voice_key == "":
		voice_key = KanaState.get_selected_voice()
	var catalog: Dictionary = voice_catalog.get(voice_key, {})
	var stream: AudioStream = catalog.get(kana)
	if stream == null:
		return
	audio_player.stream = stream
	audio_player.play()
	await audio_player.finished

func play_success() -> void:
	audio_player.stream = ui_success_stream
	audio_player.play()

func play_failure() -> void:
	audio_player.stream = ui_failure_stream
	audio_player.play()
