extends Node
class_name GameAudio
## Music + SFX. Two music loops (same tempo, key and length) play in sync and
## crossfade with the werecat's morph value. SFX use a small voice pool.

const SFX := ["claim_cute", "claim_scary", "trail_cute", "trail_scary", "snap", "bomb", "capture",
	"tier_up", "tier_down", "win", "lose", "click", "charm", "spawn", "grow", "star1", "star2", "star3", "start"]

var music_cute: AudioStreamPlayer
var music_scary: AudioStreamPlayer
var voices: Array = []
var next_voice := 0
var streams := {}
var enabled := true
var morph := 0.0
var music_level := 1.0   # ducked during menus/results
var focused := true
var _js_visibility_cb   # keeps the JS callback alive


func _ready() -> void:
	music_cute = _music("res://assets/audio/music_cute.ogg")
	music_scary = _music("res://assets/audio/music_scary.ogg")
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		voices.append(p)
	for n in SFX:
		streams[n] = load("res://assets/audio/sfx_%s.ogg" % n)
	music_cute.play()
	music_scary.play()
	_apply_volumes()
	# Browsers keep Web Audio running in background tabs, and Godot's main
	# loop stops there, so react to the page being hidden directly from JS.
	if OS.has_feature("web"):
		_js_visibility_cb = JavaScriptBridge.create_callback(_on_js_visibility)
		var doc = JavaScriptBridge.get_interface("document")
		doc.addEventListener("visibilitychange", _js_visibility_cb)
		var win = JavaScriptBridge.get_interface("window")
		win.addEventListener("blur", _js_visibility_cb)
		win.addEventListener("focus", _js_visibility_cb)
		win.addEventListener("pagehide", _js_visibility_cb)


func _on_js_visibility(_args: Array) -> void:
	var hidden: bool = JavaScriptBridge.eval("document.hidden || !document.hasFocus()", true)
	set_focus(not hidden)
	focus_changed.emit(not hidden)


signal focus_changed(has_focus: bool)


## Silence everything while the page/app is in the background.
func set_focus(f: bool) -> void:
	if f == focused:
		return
	focused = f
	print("[audio] focus=%s" % f)
	AudioServer.set_bus_mute(0, not f)
	if not f:
		for v in voices:
			v.stop()
	_update_paused()


func _update_paused() -> void:
	if music_cute:
		music_cute.stream_paused = not (enabled and focused)
		music_scary.stream_paused = not (enabled and focused)


func _music(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = load(path)
	s.loop = true
	p.stream = s
	# Stream (decode as it plays) instead of the web default of fully decoded
	# samples: two 46 s loops as samples cost ~120 MB and crashed mobile tabs.
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(p)
	return p


func set_morph(m: float) -> void:
	m = clampf(m, 0.0, 1.0)
	if absf(m - morph) < 0.002:
		return
	morph = m
	_apply_volumes()


func set_enabled(on: bool) -> void:
	enabled = on
	_update_paused()
	_apply_volumes()


func set_music_level(v: float) -> void:
	if absf(v - music_level) < 0.001:
		return
	music_level = v
	_apply_volumes()


func _apply() -> void:
	_apply_volumes()


func _apply_volumes() -> void:
	if not music_cute:
		return
	# equal-power crossfade
	var c := cos(morph * PI / 2.0) * music_level
	var s := sin(morph * PI / 2.0) * music_level
	music_cute.volume_db = linear_to_db(maxf(c, 0.0001)) - 3.0
	music_scary.volume_db = linear_to_db(maxf(s, 0.0001)) - 3.0


var _sync_t := 0.0


func _process(delta: float) -> void:
	# keep the two loops locked together, checked rarely and only for big drift
	_sync_t += delta
	if _sync_t < 3.0 or not enabled or not music_cute.playing:
		return
	_sync_t = 0.0
	var a := music_cute.get_playback_position()
	var b := music_scary.get_playback_position()
	if absf(a - b) > 0.25 and absf(a - b) < 40.0:
		music_scary.seek(a)


func play(n: String, vol_db := 0.0, pitch_var := 0.0) -> void:
	if not enabled or not focused or not streams.has(n):
		return
	var p: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	p.stream = streams[n]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
