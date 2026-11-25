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
	_apply()


func _music(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = load(path)
	s.loop = true
	p.stream = s
	add_child(p)
	return p


func set_morph(m: float) -> void:
	morph = clampf(m, 0.0, 1.0)
	_apply()


func set_enabled(on: bool) -> void:
	enabled = on
	_apply()


func _apply() -> void:
	if not music_cute:
		return
	# equal-power crossfade
	var c := cos(morph * PI / 2.0) * music_level
	var s := sin(morph * PI / 2.0) * music_level
	music_cute.volume_db = linear_to_db(maxf(c, 0.0001)) - 3.0
	music_scary.volume_db = linear_to_db(maxf(s, 0.0001)) - 3.0
	music_cute.stream_paused = not enabled
	music_scary.stream_paused = not enabled
	# keep the loops locked together if a browser hiccup drifts them apart
	if enabled and absf(music_cute.get_playback_position() - music_scary.get_playback_position()) > 0.08:
		music_scary.seek(music_cute.get_playback_position())


func play(n: String, vol_db := 0.0, pitch_var := 0.0) -> void:
	if not enabled or not streams.has(n):
		return
	var p: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	p.stream = streams[n]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
