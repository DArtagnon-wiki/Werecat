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
var single := false          # Lite: one loop at a time, played by the browser
var _active_scary := false
# Lite plays mono copies of the loops as Web Audio samples: the browser mixes
# them on its own thread, so slow game frames can't make the music stutter.
# We keep our own loop clock so a mood switch picks up in step.
# On the web the music is played by the browser's Web Audio (web/music.js):
# decoding and mixing happen off the game thread, so it never stutters.
var web_music := false
var _js_vol := Vector2(-1, -1)
var _full := []
var _lite := []
var _loop_t := 0.0
var _web_ready := false
var _loop_len := 45.714
var _js_visibility_cb   # keeps the JS callback alive


func _ready() -> void:
	music_cute = _music("res://assets/audio/music_cute.ogg")
	music_scary = _music("res://assets/audio/music_scary.ogg")
	_full = [music_cute.stream, music_scary.stream]
	web_music = OS.has_feature("web") and _init_web_music()
	_loop_len = music_cute.stream.get_length()
	_lite = _full       # outside the browser Lite just plays one normal loop
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		voices.append(p)
	for n in SFX:
		streams[n] = load("res://assets/audio/sfx_%s.ogg" % n)
	if not web_music:
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


func _init_web_music() -> bool:
	# music.js sits next to index.html; load it once
	JavaScriptBridge.eval("""
		if (!window.WCMusic && !window.__wcm_loading) {
			window.__wcm_loading = true;
			var s = document.createElement('script'); s.src = 'music.js'; document.head.appendChild(s);
		}""", true)
	return true


func _js(code: String) -> void:
	JavaScriptBridge.eval("if (window.WCMusic) { " + code + " }", true)


func _active() -> AudioStreamPlayer:
	return music_scary if _active_scary else music_cute


func _update_paused() -> void:
	if web_music:
		_js("WCMusic.setRunning(%s);" % ("true" if enabled and focused else "false"))
		return
	if music_cute:
		var run := enabled and focused
		if single:
			# samples can't be paused reliably, so stop/restart at our clock
			var a := _active()
			var other := music_cute if _active_scary else music_scary
			if other.playing:
				other.stop()
			if run and not a.playing:
				a.play(fmod(_loop_t, _loop_len))
			elif not run and a.playing:
				a.stop()
		else:
			music_cute.stream_paused = not run
			music_scary.stream_paused = not run


func set_single(on: bool) -> void:
	if on == single:
		return
	if web_music:
		single = on
		_js("WCMusic.setVariant('%s');" % ("lite" if on else "full"))
		return
	if not music_cute:
		single = on
		return
	var players := [music_cute, music_scary]
	if on:
		_loop_t = music_cute.get_playback_position() if music_cute.playing else _loop_t
		_active_scary = morph > 0.5
	for p in players:
		p.stop()
	single = on
	for k in 2:
		var p: AudioStreamPlayer = players[k]
		p.stream = _lite[k] if on else _full[k]
	if not on:
		var t := fmod(_loop_t, _loop_len)
		music_cute.play(t)
		music_scary.play(t)
	_apply_volumes()
	_update_paused()


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
	if web_music:
		# equal-power crossfade in the browser; only send real changes
		var v := Vector2(cos(morph * PI / 2.0), sin(morph * PI / 2.0)) * music_level
		if v.distance_to(_js_vol) > 0.01:
			_js_vol = v
			_js("WCMusic.setVol(%.3f, %.3f);" % [v.x, v.y])
		return
	if not music_cute:
		return
	if single:
		# one loop at a time; switch (in step) when the morph crosses over
		var want := morph > (0.45 if _active_scary else 0.55)
		if want != _active_scary:
			_active_scary = want
			_update_paused()
		var on_db := linear_to_db(maxf(music_level, 0.0001)) - 3.0
		music_cute.volume_db = -80.0 if _active_scary else on_db
		music_scary.volume_db = on_db if _active_scary else -80.0
		return
	# equal-power crossfade
	var c := cos(morph * PI / 2.0) * music_level
	var s := sin(morph * PI / 2.0) * music_level
	music_cute.volume_db = linear_to_db(maxf(c, 0.0001)) - 3.0
	music_scary.volume_db = linear_to_db(maxf(s, 0.0001)) - 3.0


var _sync_t := 0.0


func _process(delta: float) -> void:
	if web_music:
		# the script tag loads async: push the current state once it's there
		if not _web_ready and bool(JavaScriptBridge.eval("!!window.WCMusic", true)):
			_web_ready = true
			_js("WCMusic.setVariant('%s');" % ("lite" if single else "full"))
			_js_vol = Vector2(-1, -1)
			_apply_volumes()
			_update_paused()
		return
	if single and enabled and focused:
		_loop_t = fmod(_loop_t + delta, _loop_len)
	# keep the two loops locked together, checked rarely and only for big drift
	_sync_t += delta
	if _sync_t < 3.0 or single or not enabled or not music_cute.playing:
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
