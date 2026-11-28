extends Node2D
## Werecat: Cute vs. Scary.
##
## Claim rules:
##   - The only walls are the field's border (and moonstone).
##   - Put your finger down in one territory and draw any shape into the other.
##   - The trail closes when it gets back to your side, the edge, or stone.
##     Bouncer-free pockets of the invaded side flip to your color. Pockets
##     smaller than CAPTURE_FRAC of the field trap their bouncers and flip too.
##   - Anything that touches an open trail snaps it: lose a life.
##     Lifting your finger early is free.
##
## Mechanics: bombs, moon charms, nests, thorn seeds, moonstone, carvers,
## wisps, stalkers, the boss, trapping. Level data lives in levels.gd.

const GW := 160
const GH := 186
const CELL := 4.0
const FIELD_POS := Vector2(40, 420)
const FIELD_SIZE := Vector2(640, 744)
const TRAIL_R := 2.2
const GROW_SPEED := 380.0        # px/s for each of the two growing ends
# Line curl: how sharply a drawn line may turn, in degrees per px of line.
# "true" = follows the finger exactly; "straight" = aim and push.
const CURL_ORDER := ["straight", "arc", "curly", "true"]
const CURL_RATE := {"arc": 0.35, "curly": 2.2}
const CURL_NAMES := {"straight": "straight", "arc": "gentle arcs", "curly": "curly", "true": "free"}
const CURL_AIM_DIST := 28.0      # finger must move this far before a limited line picks its heading
const CURL_GRACE := 40.0         # a limited line can't close on your own ground before this much enemy travel
const BOUNCER_SPEED := 170.0
const HOLD_TIME := 3.0
const WC_SCALE := 0.58
const CAPTURE_FRAC := 0.025
# bigger creatures can be trapped in bigger pockets
const CAPTURE_FRAC_BY_KIND := {"elite": 0.07, "boss": 0.04}
const BOMB_R := 22.0             # cells
const FREEZE_TIME := 4.0
const SEED_EVERY := 2.0
# Generators: item kind -> creature it hatches, seconds between hatches, and
# the cap on that creature (per side; wisps count both sides).
const SPAWNERS := {
	"nest": {"kind": "basic", "every": 6.5, "cap": 5},
	"den": {"kind": "stalker", "every": 9.0, "cap": 3},
	"burrow": {"kind": "carver", "every": 9.0, "cap": 3},
	"lantern": {"kind": "wisp", "every": 11.0, "cap": 2},
}
const ROOTED := ["nest", "den", "burrow", "lantern", "seed", "idol"]   # die when their ground flips
const SEED_MAX_R := 46.0

const CUTE := 0
const SCARY := 1
const STONE := 2

const ZONE_CONTROL := 0.6        # a zone belongs to a color at 60% of its ground
# Shrine effects. kind: wall (growth speed), curl (line curl), creature (speed)
const EFFECTS := {
	"swift": {"kind": "wall", "value": 1.7, "label": "Walls: fast", "icon": "zi_swift"},
	"slow": {"kind": "wall", "value": 0.55, "label": "Walls: slow", "icon": "zi_slow"},
	"straight": {"kind": "curl", "value": "straight", "label": "Lines: straight", "icon": "zi_straight"},
	"arc": {"kind": "curl", "value": "arc", "label": "Lines: gentle arcs", "icon": "zi_arc"},
	"curly": {"kind": "curl", "value": "curly", "label": "Lines: curly", "icon": "zi_curly"},
	"true": {"kind": "curl", "value": "true", "label": "Lines: free", "icon": "zi_true"},
	"haste": {"kind": "creature", "value": 1.4, "label": "Creatures: fast", "icon": "zi_haste"},
	"calm": {"kind": "creature", "value": 0.7, "label": "Creatures: calm", "icon": "zi_calm"},
}

const INK := Color("241226")
const PINK := Color("ffb3cb")
const GOLD := Color("ffd98a")
const SAVE_PATH := "user://werecat.cfg"

var levels: Array = Levels.all()
var level_idx := 0
var level: Dictionary = {}
var mode := "level"
var state := "title"
var mask := PackedByteArray()
var under := PackedByteArray()
var trail := PackedByteArray()
var trail_list := PackedInt32Array()
var tex_bytes := PackedByteArray()   # RG8 mask texture data, kept in sync by _set_cell
var scary_count := 0
var claimable := 1
var bouncers: Array = []
var items: Array = []
var zones: Array = []
var zone_layer: Node2D
var lbl_status: Label
var lbl_obj: Label
var level_page := 0
var page_rows: Array = []
var btn_page_prev: Button
var btn_page_next: Button
var lives := 3
var hold := 0.0
var goal_min := 0.0
var goal_max := 0.0
var clock := 0.0
var shake := 0.0
var freeze_t := 0.0
var mask_dirty := false
var upload_cool := 0.0
var rng := RandomNumberGenerator.new()

# endless
var band_target := 50.0
var score := 0.0
var next_shift := 0.0
var next_spawn := 0.0
var next_item := 0.0
var spawn_n := 0
var since_claim := 0.0          # seconds since the last finished wall (Endless anti-idle)
var lbl_idle: Label

# stroke
var stroking := false
var stroke_active := false
var stroke_origin := CUTE
var last_origin_pt := Vector2.ZERO
var stroke_points := PackedVector2Array()
# curl state (non-"true" modes): the line's tip chases the finger
var curl_mode := "true"
var tip := Vector2.ZERO
var tip_heading := 0.0
var tip_len := 0.0
var ray_anchor := Vector2.ZERO
var last_finger := Vector2.ZERO
var tip_aimed := false
var tip_enemy_len := 0.0
var leash: Line2D
# growth: after a path closes, the wall grows along it from both ends
var growing := false
var grow_pts := PackedVector2Array()
var grow_cum := PackedFloat32Array()
var grow_len := 0.0
var grow_a := 0.0
var grow_b := 0.0
var live := PackedByteArray()          # grown (vulnerable) cells
var live_list := PackedInt32Array()

# save data
var stars: Array = []
var best_endless := 0.0
var sound_on := true

# graphics quality. Tiers: 0 High (native resolution), 1 Medium (720-wide
# render, upscaled), 2 Lite (Medium + cheap shaders, fewer particles, one
# music stream). Setting "auto" starts at the last auto tier and steps down
# while the frame rate stays low.
const GFX_SETTINGS := ["auto", "high", "medium", "lite"]
const GFX_NAMES := ["High", "Medium", "Lite"]
const AUTO_WINDOW := 3.0         # seconds of frames per auto check
const AUTO_MIN_FPS := 40.0
const AUTO_SETTLE := 2.0         # ignore frames right after start / a switch
const DEBUG_OVERLAY := true      # debug release: perf readout on by default
var gfx_setting := "auto"
var gfx_auto_tier := 0
var gfx_tier := -1
var gfx_forced := ""             # ?gfx=... in the URL (not saved)
var particle_mult := 1.0
var shader_full := {}
var shader_lite := {}
var noise_tex: Texture2D
var wide_tex: ImageTexture
var btn_gfx_title: Button
var btn_gfx_pause: Button
var btn_stats: Button
var auto_t := 0.0
var auto_frames := 0
var auto_settle := AUTO_SETTLE
var auto_log: Array = []
var app_t := 0.0
# perf probes (ms, last measured)
var perf := {"game": 0.0, "mask": 0.0, "zones": 0.0, "fill": 0.0, "fill_worst": 0.0}
var perf_frames := PackedFloat32Array()
var perf_layer: CanvasLayer
var perf_panel: PanelContainer
var perf_label: Label
var perf_collapsed := true     # one-line pill; tap for details
var perf_hidden := false
var perf_t := 0.0
var perf_log_t := 0.0
var gpu_name := ""
var device_info := ""
var mask_serial := 0
var no_redraw := false
var zones_serial := -1

# nodes
var world: Node2D
var stage_off := Vector2.ZERO
var layers: Array = []
var bg: ColorRect
var werecat: Werecat
var field: ColorRect
var field_mat: ShaderMaterial
var frame: Node2D
var trail_line: Line2D
var grow_line_a: Line2D
var grow_line_b: Line2D
var front_a: Sprite2D
var front_b: Sprite2D
var item_layer: Node2D
var bouncer_layer: Node2D
var fx_layer: Node2D
var fx_back: Node2D
var audio: GameAudio
var hud: CanvasLayer
var lbl_title: Label
var lbl_goal_head: Label
var lbl_goal: Label
var hearts: Array = []
var meter: Node2D
var screens := {}
var lbl_over_title: Label
var lbl_over_sub: Label
var over_stars: Array = []
var btn_next: Button
var btn_sound_title: Button
var btn_sound_pause: Button
var intro_labels := {}
var intro_icon: TextureRect
var level_tiles: Array = []

var mask_img: Image
var mask_tex: ImageTexture
var prev_tex: ImageTexture
# Lite: half-resolution mask (the GPU filters it), no CPU upscaling
var lite_img: Image
var lite_mask_tex: ImageTexture
var lite_prev_tex: ImageTexture
# uploads rotate through these so we never rewrite a texture the GPU may
# still be drawing from (that stalls mobile GPUs)
var lite_ring: Array = []
var lite_ring_i := 0
var wide_ring: Array = []
var wide_ring_i := 0
var flip_t := 1.0
var menu_t := 0.0

var T := {}   # textures
var font_ui: FontVariation
var font_ui_bold: FontVariation
var font_title: FontVariation


func _ready() -> void:
	rng.randomize()
	for n in ["bouncer_puff", "bouncer_bat", "fx_sparkle", "fx_ember", "fx_glow", "ui_heart", "ui_heart_empty",
			"ent_bomb", "ent_charm", "ent_wisp", "ent_hunter", "ent_huggy", "ent_boss", "ent_nest_scary", "ent_nest_cute",
			"ent_seed_scary", "ent_seed_cute", "ent_grub_head", "ent_grub_seg", "ent_slug_head", "ent_slug_seg",
			"ui_star", "ui_star_empty", "ui_lock", "ui_pause", "ent_idol_cute", "ent_idol_scary", "ent_crown",
			"ent_den_scary", "ent_den_cute", "ent_burrow_scary", "ent_burrow_cute", "ent_lantern",
			"ui_zone_ring", "ui_reticle", "ui_lone_ring",
			"zi_hold", "zi_swift", "zi_slow", "zi_straight", "zi_arc", "zi_curly", "zi_true", "zi_haste", "zi_calm"]:
		T[n] = load("res://assets/sprites/%s.png" % n)
	font_ui = _font("res://assets/fonts/Fredoka.ttf", 500)
	font_ui_bold = _font("res://assets/fonts/Fredoka.ttf", 650)
	font_title = _font("res://assets/fonts/GrenzeGotisch.ttf", 800)
	mask.resize(GW * GH)
	under.resize(GW * GH)
	trail.resize(GW * GH)
	live.resize(GW * GH)
	stars.resize(levels.size())
	stars.fill(0)
	audio = GameAudio.new()
	add_child(audio)
	audio.focus_changed.connect(_on_focus_changed)
	_load_save()
	audio.set_enabled(sound_on)
	_build_scene()
	_load_layout(levels[0])
	get_viewport().size_changed.connect(_layout)
	_init_gfx()
	_build_perf_overlay()
	_layout()
	_show("title")


## Centers the 720x1280 design on any screen shape. The night sky stretches
## to fill the extra room; everything else stays centered.
func _layout() -> void:
	if gfx_tier >= 0:
		_apply_render_scale()
	var vis := get_viewport().get_visible_rect().size
	stage_off = Vector2(maxf(0.0, (vis.x - 720.0) / 2.0), maxf(0.0, (vis.y - 1280.0) / 2.0))
	for l in layers:
		l.offset = stage_off
	bg.position = -stage_off - Vector2(40, 40)
	bg.size = Vector2(720, 1280) + stage_off * 2.0 + Vector2(80, 80)
	var bm: ShaderMaterial = bg.material
	bm.set_shader_parameter("screen_size", bg.size)
	bm.set_shader_parameter("moon_center", Vector2(360, 236) + stage_off + Vector2(40, 40))
	bm.set_shader_parameter("ground_y", 1240.0 + stage_off.y)
	world.position = stage_off


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_on_focus_changed(false)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_on_focus_changed(true)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back()


## Android back button: step back through the screens instead of quitting
## mid-game; only the title screen closes the app.
func _go_back() -> void:
	match state:
		"play":
			_pause()
		"pause":
			_resume()
		"intro":
			_show("levels")
		"levels":
			_show("title")
		"title":
			get_tree().quit()
		_:
			_quit_to_levels()


## Going to the background mutes everything and pauses a level in progress.
func _on_focus_changed(has_focus: bool) -> void:
	if audio:
		audio.set_focus(has_focus)
	if not has_focus and state == "play":
		_pause()


# ================================================================ graphics quality

func _init_gfx() -> void:
	noise_tex = load("res://assets/textures/noise.png")
	shader_full = {"field": field_mat.shader, "bg": (bg.material as ShaderMaterial).shader}
	shader_lite = {"field": load("res://shaders/territory_lite.gdshader"),
		"bg": load("res://shaders/background_lite.gdshader")}
	var wimg := Image.create(GW / 7, GH / 7, false, Image.FORMAT_RG8)
	for k in 2:
		wide_ring.append(ImageTexture.create_from_image(wimg))
	wide_tex = wide_ring[0]
	lite_img = Image.create(GW / 2, GH / 2, false, Image.FORMAT_RG8)
	for k in 3:
		lite_ring.append(ImageTexture.create_from_image(lite_img))
	lite_mask_tex = lite_ring[0]
	lite_prev_tex = lite_ring[0]
	gpu_name = "%s · %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()]
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# the readout starts visible on the web debug build, hidden in the app
	# (Pause > Stats turns it on)
	var show_overlay := DEBUG_OVERLAY and OS.has_feature("web")
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("location.search", true))
		for part in q.trim_prefix("?").split("&", false):
			var kv := part.split("=")
			if kv[0] == "gfx" and kv.size() > 1 and kv[1] in GFX_SETTINGS:
				gfx_forced = kv[1]
			elif kv[0] == "debug":
				show_overlay = kv.size() < 2 or kv[1] != "0"
				perf_collapsed = kv.size() > 1 and kv[1] == "0"   # ?debug or ?debug=1: start expanded
			elif kv[0] == "play" and kv.size() > 1 and kv[1].is_valid_int():
				# diagnostics: ?play=25 jumps straight into night 25 (1-based)
				var li := clampi(int(kv[1]) - 1, 0, levels.size() - 1)
				(func() -> void:
					level_idx = li
					level = levels[li]
					begin_play()).call_deferred()
			elif kv[0] == "measure" and kv.size() > 1 and kv[1] == "0":
				RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
			elif kv[0] == "noredraw":
				no_redraw = true
			elif kv[0] == "hide" and kv.size() > 1:
				# diagnostics: ?hide=bg,field,cat,ui,fx hides layers to find GPU cost
				for h in kv[1].split(",", false):
					match h:
						"bg": bg.visible = false
						"field": field.visible = false
						"cat":
							werecat.visible = false
							werecat.front.visible = false
						"ui":
							for l in layers:
								l.visible = false
							hud.visible = false
						"fx":
							fx_layer.visible = false
							fx_back.visible = false
		device_info = str(JavaScriptBridge.eval(
			"'dpr ' + (window.devicePixelRatio || 1).toFixed(2) + ' · ' + (navigator.hardwareConcurrency || '?')"
			+ " + ' cores · ' + (navigator.deviceMemory ? navigator.deviceMemory + ' GB' : '? GB')", true))
	perf_hidden = not show_overlay
	_apply_gfx(_wanted_tier())


var _frame_sig := -1.0
var _sent_morph := -1.0
var _sent_freeze := -1.0
var _sent_hold := -1.0
var _meter_sig := ""


## The frame only depends on the morph and the meter on the split, the band
## and (inside the band) a pulse, so skip redraws when nothing changed.
func _redraw_if_changed() -> void:
	var fs := snappedf(werecat.morph, 0.01)
	if fs != _frame_sig:
		_frame_sig = fs
		frame.queue_redraw()
	if not meter.visible:
		return
	var s := scary_percent()
	var inside := s >= goal_min and s <= goal_max
	var ms := "%.1f|%s|%s|%d" % [s, goal_min, goal_max, int(clock * (20.0 if gfx_tier < 2 else 10.0)) if inside else -1]
	if ms != _meter_sig:
		_meter_sig = ms
		meter.queue_redraw()


## Runs f and keeps a smoothed time for it in perf[key] (ms).
func _timed(key: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	f.call()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	perf[key] = lerpf(float(perf.get(key, ms)), ms, 0.1)


func _gfx_choice() -> String:
	return gfx_forced if gfx_forced != "" else gfx_setting


func _wanted_tier() -> int:
	match _gfx_choice():
		"high":
			return 0
		"medium":
			return 1
		"lite":
			return 2
	return gfx_auto_tier


## Swaps a material's shader, carrying over every uniform value it had.
func _swap_shader(mat: ShaderMaterial, sh: Shader) -> void:
	if mat.shader == sh:
		return
	var vals := {}
	for u in mat.shader.get_shader_uniform_list():
		var v = mat.get_shader_parameter(u.name)
		if v != null:
			vals[u.name] = v
	mat.shader = sh
	for k in vals:
		mat.set_shader_parameter(k, vals[k])


func _apply_gfx(tier: int) -> void:
	if tier == gfx_tier:
		return
	gfx_tier = tier
	_apply_render_scale()
	var lite := tier == 2
	var bm: ShaderMaterial = bg.material
	_swap_shader(field_mat, shader_lite.field if lite else shader_full.field)
	_swap_shader(bm, shader_lite.bg if lite else shader_full.bg)
	if lite:
		field_mat.set_shader_parameter("noise_tex", noise_tex)
		field_mat.set_shader_parameter("wide_tex", wide_tex)
		bm.set_shader_parameter("noise_tex", noise_tex)
	field_mat.set_shader_parameter("mask_tex", lite_mask_tex if lite else mask_tex)
	field_mat.set_shader_parameter("prev_mask_tex", lite_prev_tex if lite else prev_tex)
	_upload_mask(false)      # refill the textures this tier reads
	flip_t = 1.0
	field_mat.set_shader_parameter("flip_progress", flip_t)
	particle_mult = 0.4 if lite else 1.0
	audio.set_single(lite)
	auto_settle = AUTO_SETTLE
	auto_t = 0.0
	auto_frames = 0
	_layout()
	_refresh_gfx_buttons()
	print("[gfx] tier=%s choice=%s build=%s" % [GFX_NAMES[tier], _gfx_choice(), BuildInfo.ID])


## High draws at the screen's native resolution. Medium and Lite draw at the
## 720-wide design resolution and upscale, but only when the screen is
## bigger than that (never upscale a small screen's rendering).
func _apply_render_scale() -> void:
	var root := get_tree().root
	var native := DisplayServer.window_get_size()
	var reduce := gfx_tier > 0 and native.x > 760
	var want := Window.CONTENT_SCALE_MODE_VIEWPORT if reduce else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if root.content_scale_mode != want:
		root.content_scale_mode = want


## Auto mode: step down while the frame rate stays under AUTO_MIN_FPS.
func _gfx_tick(delta: float) -> void:
	app_t += delta
	if _gfx_choice() != "auto" or gfx_tier >= 2:
		return
	if not audio.focused or delta > 0.5:
		auto_t = 0.0
		auto_frames = 0
		return
	if auto_settle > 0.0:
		auto_settle -= delta
		return
	auto_t += delta
	auto_frames += 1
	if auto_t < AUTO_WINDOW:
		return
	var fps := auto_frames / auto_t
	auto_t = 0.0
	auto_frames = 0
	if fps >= AUTO_MIN_FPS:
		return
	# very slow: skip straight to Lite
	var nt := 2 if fps < AUTO_MIN_FPS * 0.55 else gfx_tier + 1
	auto_log.append("%s -> %s at %ds (%.0f fps)" % [GFX_NAMES[gfx_tier], GFX_NAMES[nt], int(app_t), fps])
	print("[gfx] auto " + auto_log[-1])
	gfx_auto_tier = nt
	_save()
	_apply_gfx(nt)


func _toggle_stats() -> void:
	audio.play("click", -4.0)
	perf_hidden = not perf_hidden
	if perf_panel:
		perf_panel.visible = not perf_hidden
	perf_t = 1.0
	_refresh_gfx_buttons()


func _cycle_gfx() -> void:
	audio.play("click", -4.0)
	var i := GFX_SETTINGS.find(gfx_setting)
	gfx_setting = GFX_SETTINGS[(i + 1) % GFX_SETTINGS.size()]
	gfx_forced = ""
	if gfx_setting == "auto":
		gfx_auto_tier = 0        # re-detect from the top
		auto_log.append("Auto restarted at %ds" % int(app_t))
	_save()
	_apply_gfx(_wanted_tier())
	_refresh_gfx_buttons()


func _refresh_gfx_buttons() -> void:
	var names := {"auto": "Auto", "high": "High", "medium": "Medium", "lite": "Lite"}
	for b in [btn_gfx_title, btn_gfx_pause]:
		if b:
			b.text = "Graphics: " + names[_gfx_choice()]
	if btn_stats:
		btn_stats.text = "Stats: " + ("off" if perf_hidden else "on")


# ================================================================ perf overlay

func _particle_count() -> int:
	var n := 0
	for l in [fx_layer, fx_back]:
		for c in l.get_children():
			if c is CPUParticles2D and c.emitting:
				n += c.amount
	return n


func _build_perf_overlay() -> void:
	perf_layer = CanvasLayer.new()
	perf_layer.layer = 100
	add_child(perf_layer)
	perf_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.62)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(8)
	perf_panel.add_theme_stylebox_override("panel", st)
	perf_panel.position = Vector2(8, 8)
	perf_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	perf_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			perf_collapsed = not perf_collapsed
			perf_t = 1.0)
	perf_panel.visible = not perf_hidden
	perf_layer.add_child(perf_panel)
	perf_label = Label.new()
	perf_label.add_theme_font_override("font", font_ui)
	perf_label.add_theme_font_size_override("font_size", 17)
	perf_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	perf_panel.add_child(perf_label)
	perf_t = 1.0


func _perf_tick(delta: float) -> void:
	perf_frames.append(delta * 1000.0)
	if perf_frames.size() > 90:
		perf_frames.remove_at(0)
	perf_t += delta
	perf_log_t += delta
	if perf_t < 0.25 or not perf_panel:
		return
	perf_t = 0.0
	var avg := 0.0
	var worst := 0.0
	for f in perf_frames:
		avg += f
		worst = maxf(worst, f)
	avg /= maxf(1.0, perf_frames.size())
	var fps := 1000.0 / maxf(avg, 0.001)
	var vp := get_viewport().get_viewport_rid()
	var r_cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	var r_gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var wait := maxf(0.0, avg - proc - r_cpu)
	var screen := DisplayServer.window_get_size()
	var render: Vector2 = Vector2(screen)
	if get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		render = get_viewport().get_visible_rect().size
	if perf_log_t >= 5.0:
		perf_log_t = 0.0
		print("[perf2] grow=%.2f creatures=%.2f items=%.2f anim=%.2f hud=%.2f frame=%.2f meter=%.2f zones=%.2f cat=%.2f parts=%d" % [
			float(perf.get("growth", 0)), float(perf.get("creatures", 0)), float(perf.get("items", 0)), float(perf.get("anim", 0)), float(perf.get("hud", 0)),
			float(perf.get("d_frame", 0)), float(perf.get("d_meter", 0)), float(perf.get("d_zones", 0)), werecat.perf_ms, _particle_count()])
		print("[perf] fps=%.1f avg=%.1fms worst=%.0fms tier=%s game=%.2f mask=%.2f zones=%.2f fill=%.1f proc=%.2f render_cpu=%.2f wait=%.1f" % [
			fps, avg, worst, GFX_NAMES[gfx_tier], perf.game, perf.mask, perf.zones, perf.fill, proc, r_cpu, wait])
	if perf_hidden:
		return
	var vis_w := get_viewport().get_visible_rect().size.x
	if perf_collapsed:
		perf_label.text = "%.0f fps · %.0f ms · %s%s · v %s" % [fps, avg, GFX_NAMES[gfx_tier], " (auto)" if _gfx_choice() == "auto" else "", BuildInfo.ID.get_slice(" ", 0)]
		perf_panel.reset_size()
		perf_panel.position = Vector2((vis_w - perf_panel.size.x) / 2.0, 4)
		return
	var lines := PackedStringArray()
	lines.append("%.0f fps · avg %.1f ms · worst %.0f ms" % [fps, avg, worst])
	lines.append("script %.1f ms (game %.1f, mask %.1f, zones %.1f)" % [proc, perf.game, perf.mask, perf.zones])
	var pg := func(k: String) -> float: return float(perf.get(k, 0.0))
	lines.append("game: grow %.1f · creatures %.1f · items %.1f · anim %.1f · hud %.1f" % [pg.call("growth"), pg.call("creatures"), pg.call("items"), pg.call("anim"), pg.call("hud")])
	var ours: float = perf.game + pg.call("d_frame") + pg.call("d_meter") + pg.call("d_zones") + werecat.perf_ms
	lines.append("engine (not our scripts) %.1f ms" % maxf(0.0, proc - ours))
	lines.append("draw: frame %.1f · meter %.1f · zones %.1f · cat %.1f · particles %d" % [pg.call("d_frame"), pg.call("d_meter"), pg.call("d_zones"), werecat.perf_ms, _particle_count()])
	lines.append("draw cpu %.1f ms · gpu %s · wait %.1f ms" % [r_cpu, ("%.1f ms" % r_gpu) if r_gpu > 0.0 else "n/a", wait])
	if wait > avg * 0.5:
		lines.append("> mostly waiting on the GPU")
	lines.append("claim fill: last %.0f ms · worst %.0f ms" % [perf.fill, perf.fill_worst])
	lines.append("gfx %s (%s) · %dx%d of %dx%d" % [GFX_NAMES[gfx_tier], _gfx_choice(), int(render.x), int(render.y), screen.x, screen.y])
	lines.append(gpu_name)
	if device_info != "":
		lines.append(device_info)
	for e in auto_log.slice(-2):
		lines.append("auto: " + e)
	lines.append("build %s · tap to shrink" % BuildInfo.ID)
	perf_label.text = "\n".join(lines)
	perf_panel.reset_size()
	perf_panel.position = Vector2((vis_w - perf_panel.size.x) / 2.0, 4)


func _font(path: String, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv


# ================================================================ save

func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for i in levels.size():
		stars[i] = int(cf.get_value("stars", levels[i].id, 0))
	best_endless = float(cf.get_value("endless", "best", 0.0))
	sound_on = bool(cf.get_value("settings", "sound", true))
	gfx_setting = str(cf.get_value("settings", "gfx", "auto"))
	if not gfx_setting in GFX_SETTINGS:
		gfx_setting = "auto"
	gfx_auto_tier = clampi(int(cf.get_value("settings", "gfx_auto", 0)), 0, 2)


func _save() -> void:
	var cf := ConfigFile.new()
	for i in levels.size():
		cf.set_value("stars", levels[i].id, stars[i])
	cf.set_value("endless", "best", best_endless)
	cf.set_value("settings", "sound", sound_on)
	cf.set_value("settings", "gfx", gfx_setting)
	cf.set_value("settings", "gfx_auto", gfx_auto_tier)
	cf.save(SAVE_PATH)


func is_unlocked(i: int) -> bool:
	return i == 0 or stars[i - 1] > 0


# ================================================================ scene

func _build_scene() -> void:
	world = Node2D.new()
	add_child(world)

	bg = ColorRect.new()
	bg.position = Vector2(-40, -40)
	bg.size = Vector2(800, 1360)
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/background.gdshader")
	bm.set_shader_parameter("screen_size", bg.size)
	bm.set_shader_parameter("moon_center", Vector2(400, 276))
	bg.material = bm
	world.add_child(bg)

	fx_back = Node2D.new()
	world.add_child(fx_back)

	werecat = Werecat.new()
	var wc_pos := Vector2(360, FIELD_POS.y) - Werecat.PERCH * WC_SCALE
	werecat.position = wc_pos
	werecat.scale = Vector2.ONE * WC_SCALE
	werecat.tier_changed.connect(_on_tier_changed)
	world.add_child(werecat)

	var shadow := Node2D.new()
	shadow.draw.connect(func() -> void:
		for i in 6:
			var g := float(6 - i) * 5.0
			_rrect(shadow, Rect2(FIELD_POS - Vector2(g, g - 8), FIELD_SIZE + Vector2(g, g) * 2.0), 26.0 + g, Color(0, 0, 0, 0.08)))
	world.add_child(shadow)

	field = ColorRect.new()
	field.position = FIELD_POS
	field.size = FIELD_SIZE
	field_mat = ShaderMaterial.new()
	field_mat.shader = load("res://shaders/territory.gdshader")
	field_mat.set_shader_parameter("field_size", FIELD_SIZE)
	field.material = field_mat
	world.add_child(field)
	mask_img = Image.create(GW, GH, false, Image.FORMAT_RG8)
	mask_tex = ImageTexture.create_from_image(mask_img)
	prev_tex = ImageTexture.create_from_image(mask_img)
	field_mat.set_shader_parameter("mask_tex", mask_tex)
	field_mat.set_shader_parameter("prev_mask_tex", prev_tex)

	frame = Node2D.new()
	frame.draw.connect(func() -> void: _timed("d_frame", _draw_frame))
	world.add_child(frame)

	zone_layer = Node2D.new()
	zone_layer.draw.connect(func() -> void: _timed("d_zones", _draw_zones))
	world.add_child(zone_layer)

	item_layer = Node2D.new()
	world.add_child(item_layer)

	trail_line = _make_trail_line()
	world.add_child(trail_line)
	grow_line_a = _make_trail_line()
	grow_line_b = _make_trail_line()
	grow_line_a.material = trail_line.material
	grow_line_b.material = trail_line.material
	world.add_child(grow_line_a)
	world.add_child(grow_line_b)
	front_a = _make_front()
	front_b = _make_front()
	leash = Line2D.new()
	leash.width = 3.0
	leash.default_color = Color(1, 1, 1, 0.35)
	leash.antialiased = true
	leash.position = FIELD_POS
	world.add_child(leash)

	bouncer_layer = Node2D.new()
	world.add_child(bouncer_layer)

	world.add_child(werecat.front)
	werecat.front.position = wc_pos
	werecat.front.scale = werecat.scale

	fx_layer = Node2D.new()
	world.add_child(fx_layer)

	_build_hud()
	_build_title()
	_build_level_select()
	_build_intro()
	_build_pause()
	_build_over()


func _make_trail_line() -> Line2D:
	var l := Line2D.new()
	l.width = 36.0
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.antialiased = true
	l.position = FIELD_POS
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/trail.gdshader")
	l.material = mat
	return l


func _make_front() -> Sprite2D:
	var f := Sprite2D.new()
	f.texture = T.fx_sparkle
	f.visible = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	f.material = add
	world.add_child(f)
	return f


func _rrect(node: CanvasItem, r: Rect2, rad: float, col: Color, filled := true, w := 1.0) -> void:
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
		r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]
	var starts := [PI, -PI / 2, 0.0, PI / 2]
	for c in 4:
		for k in 9:
			var a: float = starts[c] + k * (PI / 2) / 8.0
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	if filled:
		node.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		node.draw_polyline(pts, col, w, true)


func _draw_frame() -> void:
	var m := werecat.morph
	var r := Rect2(FIELD_POS, FIELD_SIZE)
	_rrect(frame, r.grow(5), 27.0, INK, false, 8.0)
	var trim := PINK.lerp(Color("ff6a3a"), m)
	_rrect(frame, r.grow(1), 23.0, Color(trim, 0.85), false, 2.5)
	_rrect(frame, r.grow(10), 32.0, Color(trim, 0.35), false, 1.5)
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var pts := PackedVector2Array()
		for k in 4:
			var a := k * PI / 2 + PI / 4
			pts.append(c + Vector2(cos(a), sin(a)) * (13.0 if k % 2 == 0 else 7.0))
		frame.draw_colored_polygon(pts, INK)
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * 0.55)
		frame.draw_colored_polygon(inner, trim)


# ================================================================ UI

func _label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _centered(font: Font, size: int, col: Color, text: String, y: float, x := 0.0, w := 720.0) -> Label:
	var l := _label(font, size, col)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.position = Vector2(x, y)
	l.size = Vector2(w, size * 1.4)
	return l


func _panel_style(alpha := 0.88) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.03, 0.08, alpha)
	sb.border_color = Color(PINK, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(30)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	return sb


func _panel(r: Rect2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _button(text: String, cb: Callable, primary := true, w := 400.0, h := 92.0, fs := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.size = Vector2(w, h)
	b.add_theme_font_override("font", font_ui_bold)
	b.add_theme_font_size_override("font_size", fs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 8)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var base := Color("c23a6a") if primary else Color("3a1640")
		if st == "pressed":
			base = base.darkened(0.25)
		elif st == "hover":
			base = base.lightened(0.08)
		elif st == "disabled":
			base = Color("2a1a2e")
		sb.bg_color = base
		sb.border_color = INK
		sb.set_border_width_all(5)
		sb.border_width_bottom = 11 if st != "pressed" else 6
		sb.set_corner_radius_all(int(h / 2))
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 6)
		if st == "focus":
			sb.draw_center = false
			sb.border_color = Color(1, 1, 1, 0.0)
			sb.shadow_size = 0
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func() -> void:
		audio.play("click", -4.0)
		cb.call())
	return b


func _screen(n: String, layer := 10) -> Control:
	var cl := CanvasLayer.new()
	cl.layer = layer
	add_child(cl)
	layers.append(cl)
	var c := Control.new()
	c.size = Vector2(720, 1280)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(c)
	screens[n] = c
	c.visible = false
	return c


func _show(n: String) -> void:
	for k in screens:
		screens[k].visible = k == n
	hud.visible = n in ["play", "pause"] or (n == "over" and state != "title")
	var prev := state
	match n:
		"title":
			state = "title"
			menu_t = 0.0
		"levels":
			state = "levels"
			_refresh_level_select()
			# open on the page with the newest unlocked night
			var newest := 0
			for i in levels.size():
				if is_unlocked(i):
					newest = i
			_set_page(newest / 15)
		"intro":
			state = "intro"
		"pause":
			state = "paused"
		"play":
			state = "play"
	audio.set_music_level(1.0 if n == "play" else 0.75)
	audio.set_morph(werecat.morph)
	if prev == "paused" and n == "play":
		pass


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	layers.append(hud)
	var pause := TextureButton.new()
	pause.texture_normal = T.ui_pause
	pause.ignore_texture_size = true
	pause.stretch_mode = TextureButton.STRETCH_SCALE
	pause.size = Vector2(56, 56)
	pause.position = Vector2(22, 24)
	pause.pressed.connect(func() -> void:
		if state == "play":
			audio.play("click", -4.0)
			_pause())
	hud.add_child(pause)
	lbl_title = _label(font_ui_bold, 28, Color.WHITE)
	lbl_title.position = Vector2(90, 24)
	hud.add_child(lbl_title)
	for i in 3:
		var h := TextureRect.new()
		h.texture = T.ui_heart
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.size = Vector2(38, 38)
		h.position = Vector2(88 + i * 40, 64)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(h)
		hearts.append(h)
	lbl_goal_head = _label(font_ui_bold, 20, Color(1, 1, 1, 0.85))
	lbl_goal_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_goal_head.size = Vector2(260, 30)
	lbl_goal_head.position = Vector2(430, 28)
	hud.add_child(lbl_goal_head)
	lbl_goal = _label(font_title, 46, GOLD)
	lbl_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_goal.size = Vector2(300, 60)
	lbl_goal.position = Vector2(390, 50)
	hud.add_child(lbl_goal)
	lbl_status = _label(font_ui_bold, 22, Color("bfe8ff"))
	lbl_status.position = Vector2(24, 106)
	lbl_status.size = Vector2(340, 30)
	hud.add_child(lbl_status)
	lbl_obj = _label(font_ui_bold, 24, GOLD)
	lbl_obj.position = Vector2(24, 136)
	lbl_obj.size = Vector2(340, 32)
	hud.add_child(lbl_obj)
	lbl_idle = _label(font_ui_bold, 19, PINK)
	lbl_idle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_idle.size = Vector2(320, 28)
	lbl_idle.position = Vector2(370, 108)
	lbl_idle.text = "Keep claiming to score!"
	lbl_idle.visible = false
	hud.add_child(lbl_idle)
	meter = Node2D.new()
	meter.draw.connect(func() -> void: _timed("d_meter", _draw_meter))
	hud.add_child(meter)


func _build_title() -> void:
	var c := _screen("title")
	c.add_child(_panel(Rect2(FIELD_POS + Vector2(20, 40), FIELD_SIZE - Vector2(40, 80))))
	var title := _centered(font_title, 132, Color("ffe3ee"), "Werecat", 500)
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_constant_override("shadow_offset_y", 8)
	c.add_child(title)
	c.add_child(_centered(font_ui, 28, Color(1, 0.85, 0.9), "Cute or scary? You decide.", 668))
	var b1 := _button("Play", func() -> void: _show("levels"))
	b1.position = Vector2(160, 770)
	c.add_child(b1)
	var b2 := _button("Endless", start_endless, false)
	b2.position = Vector2(160, 885)
	c.add_child(b2)
	btn_sound_title = _button("", _toggle_sound, false, 260, 64, 26)
	btn_sound_title.position = Vector2(90, 1010)
	c.add_child(btn_sound_title)
	btn_gfx_title = _button("", _cycle_gfx, false, 260, 64, 26)
	btn_gfx_title.position = Vector2(370, 1010)
	c.add_child(btn_gfx_title)
	_refresh_sound_buttons()


func _build_level_select() -> void:
	var c := _screen("levels")
	c.add_child(_panel(Rect2(FIELD_POS + Vector2(12, 14), FIELD_SIZE - Vector2(24, 28))))
	c.add_child(_centered(font_title, 54, Color("ffe3ee"), "Choose a Night", 446))
	var back := _button("‹ Back", func() -> void: _show("title"), false, 150, 56, 24)
	back.position = Vector2(24, 28)
	c.add_child(back)
	var worlds := Levels.WORLDS.size()
	for w in worlds:
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(0, 530.0 + (w % 3) * 168.0)
		c.add_child(row)
		page_rows.append(row)
		var hdr := _label(font_title, 30, Color(PINK, 0.95))
		hdr.text = "%d · %s" % [w + 1, Levels.WORLDS[w]]
		hdr.position = Vector2(90, -4)
		row.add_child(hdr)
		for k in 5:
			var i := w * 5 + k
			if i >= levels.size():
				break
			var b := Button.new()
			b.position = Vector2(88 + k * 112, 38)
			b.size = Vector2(96, 96)
			b.add_theme_font_override("font", font_ui_bold)
			b.add_theme_font_size_override("font_size", 30)
			for cc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
				b.add_theme_color_override(cc, Color.WHITE)
			b.add_theme_color_override("font_outline_color", INK)
			b.add_theme_constant_override("outline_size", 7)
			b.pressed.connect(func() -> void:
				audio.play("click", -4.0)
				open_intro(i))
			row.add_child(b)
			var srow := HBoxContainer.new()
			srow.position = Vector2(8, 66)
			srow.add_theme_constant_override("separation", 1)
			srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(srow)
			var st_rects: Array = []
			for st in 3:
				var tr := TextureRect.new()
				tr.texture = T.ui_star_empty
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.custom_minimum_size = Vector2(26, 26)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				srow.add_child(tr)
				st_rects.append(tr)
			var lock := TextureRect.new()
			lock.texture = T.ui_lock
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.size = Vector2(46, 46)
			lock.position = Vector2(25, 22)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lock)
			level_tiles.append({"button": b, "stars": st_rects, "lock": lock})
	btn_page_prev = _button("‹", func() -> void: _set_page(level_page - 1), false, 90, 64, 34)
	btn_page_prev.position = Vector2(150, 1052)
	c.add_child(btn_page_prev)
	btn_page_next = _button("›", func() -> void: _set_page(level_page + 1), false, 90, 64, 34)
	btn_page_next.position = Vector2(480, 1052)
	c.add_child(btn_page_next)


func _page_count() -> int:
	return int(ceil(Levels.WORLDS.size() / 3.0))


func _set_page(p: int) -> void:
	level_page = clampi(p, 0, _page_count() - 1)
	for w in page_rows.size():
		page_rows[w].visible = w / 3 == level_page
	btn_page_prev.disabled = level_page == 0
	btn_page_next.disabled = level_page == _page_count() - 1


func _tile_style(col: Color, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.2) if pressed else col
	sb.border_color = INK
	sb.set_border_width_all(5)
	sb.border_width_bottom = 6 if pressed else 10
	sb.set_corner_radius_all(22)
	sb.content_margin_bottom = 26
	return sb


func _refresh_level_select() -> void:
	var total := 0
	for s in stars:
		total += s
	for i in level_tiles.size():
		var t: Dictionary = level_tiles[i]
		var b: Button = t.button
		var open := is_unlocked(i)
		b.disabled = not open
		b.text = levels[i].id if open else ""
		var col := Color("c23a6a") if stars[i] > 0 else Color("6a2a6e")
		if not open:
			col = Color("2a1a2e")
		for st in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, _tile_style(col))
		b.add_theme_stylebox_override("pressed", _tile_style(col, true))
		t.lock.visible = not open
		for s in 3:
			t.stars[s].texture = T.ui_star if s < stars[i] else T.ui_star_empty
			t.stars[s].visible = open


func _build_intro() -> void:
	var c := _screen("intro")
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.size = Vector2(720, 1280)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	c.add_child(_panel(Rect2(60, 520, 600, 600)))
	intro_labels.world = _centered(font_ui_bold, 22, PINK, "", 548)
	c.add_child(intro_labels.world)
	intro_labels.name = _centered(font_title, 62, Color("ffe3ee"), "", 578, 80, 560)
	c.add_child(intro_labels.name)
	intro_labels.goal = _centered(font_ui_bold, 32, GOLD, "", 668)
	c.add_child(intro_labels.goal)
	intro_icon = TextureRect.new()
	intro_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	intro_icon.size = Vector2(110, 110)
	intro_icon.position = Vector2(96, 748)
	intro_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(intro_icon)
	intro_labels.tip_head = _label(font_ui_bold, 28, Color.WHITE)
	intro_labels.tip_head.position = Vector2(222, 744)
	c.add_child(intro_labels.tip_head)
	var tip := _label(font_ui, 23, Color(1, 1, 1, 0.88))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.position = Vector2(222, 782)
	tip.size = Vector2(410, 120)
	tip.add_theme_constant_override("outline_size", 6)
	intro_labels.tip = tip
	c.add_child(tip)
	var go := _button("Go!", func() -> void: begin_play())
	go.position = Vector2(160, 940)
	c.add_child(go)
	var back := _button("‹ Levels", func() -> void: _show("levels"), false, 180, 56, 22)
	back.position = Vector2(270, 1040)
	c.add_child(back)


func _build_pause() -> void:
	var c := _screen("pause", 11)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = Vector2(720, 1280)
	c.add_child(dim)
	c.add_child(_panel(Rect2(100, 520, 520, 600)))
	c.add_child(_centered(font_title, 72, Color("ffe3ee"), "Paused", 540))
	var y := 660.0
	for spec in [["Resume", func() -> void: _resume(), true], ["Restart", func() -> void: begin_play(), false],
			["Levels", func() -> void: _quit_to_levels(), false]]:
		var b := _button(spec[0], spec[1], spec[2], 360, 84, 32)
		b.position = Vector2(180, y)
		c.add_child(b)
		y += 104.0
	btn_sound_pause = _button("", _toggle_sound, false, 232, 64, 24)
	btn_sound_pause.position = Vector2(124, y + 6)
	c.add_child(btn_sound_pause)
	btn_gfx_pause = _button("", _cycle_gfx, false, 232, 64, 24)
	btn_gfx_pause.position = Vector2(364, y + 6)
	c.add_child(btn_gfx_pause)
	btn_stats = _button("", _toggle_stats, false, 200, 44, 20)
	btn_stats.position = Vector2(260, y + 80)
	c.add_child(btn_stats)
	_refresh_sound_buttons()


func _build_over() -> void:
	var c := _screen("over", 11)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(720, 1280)
	c.add_child(dim)
	c.add_child(_panel(Rect2(70, 540, 580, 560)))
	lbl_over_title = _centered(font_title, 62, Color("ffe3ee"), "", 566, 90, 540)
	lbl_over_title.size.y = 170
	c.add_child(lbl_over_title)
	for s in 3:
		var tr := TextureRect.new()
		tr.texture = T.ui_star_empty
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(96, 96)
		tr.pivot_offset = Vector2(48, 48)
		tr.position = Vector2(206 + s * 106, 730 - (12 if s == 1 else 0))
		c.add_child(tr)
		over_stars.append(tr)
	lbl_over_sub = _centered(font_ui_bold, 28, GOLD, "", 846, 90, 540)
	c.add_child(lbl_over_sub)
	var retry := _button("Retry", func() -> void: _retry(), false, 250, 84, 32)
	retry.position = Vector2(100, 908)
	c.add_child(retry)
	btn_next = _button("Next", func() -> void: _next_level(), true, 250, 84, 32)
	btn_next.position = Vector2(370, 908)
	c.add_child(btn_next)
	var lv := _button("Levels", func() -> void: _quit_to_levels(), false, 200, 60, 24)
	lv.position = Vector2(260, 1016)
	c.add_child(lv)


func _toggle_sound() -> void:
	sound_on = not sound_on
	audio.set_enabled(sound_on)
	_refresh_sound_buttons()
	_save()


func _refresh_sound_buttons() -> void:
	for b in [btn_sound_title, btn_sound_pause]:
		if b:
			b.text = "Sound: On" if sound_on else "Sound: Off"


func _draw_meter() -> void:
	var s := scary_percent()
	var r := Rect2(78, 1200, 564, 34)
	_rrect(meter, r.grow(6), 21.0, INK)
	var split := r.position.x + r.size.x * (1.0 - s / 100.0)
	_grad_rect(Rect2(r.position, Vector2(split - r.position.x, r.size.y)), Color("ffd6ea"), Color("d9b8f5"))
	_grad_rect(Rect2(Vector2(split, r.position.y), Vector2(r.end.x - split, r.size.y)), Color("c0203a"), Color("4a0612"))
	meter.draw_rect(Rect2(r.position + Vector2(6, 3), Vector2(r.size.x - 12, 6)), Color(1, 1, 1, 0.18))
	var g0 := r.position.x + r.size.x * (1.0 - goal_max / 100.0)
	var g1 := r.position.x + r.size.x * (1.0 - goal_min / 100.0)
	var inside := s >= goal_min and s <= goal_max
	var gc := GOLD if not inside else Color(1, 1, 0.7)
	var pulse := (0.7 + 0.3 * sin(clock * 6.0)) if inside else 1.0
	meter.draw_rect(Rect2(g0, r.position.y - 9, maxf(g1 - g0, 3.0), r.size.y + 18), Color(gc, 0.18 * pulse))
	meter.draw_rect(Rect2(g0, r.position.y - 9, maxf(g1 - g0, 3.0), r.size.y + 18), Color(gc, pulse), false, 3.0)
	var nx := split
	meter.draw_colored_polygon(PackedVector2Array([Vector2(nx - 10, r.position.y - 18), Vector2(nx + 10, r.position.y - 18), Vector2(nx, r.position.y - 4)]), INK)
	meter.draw_colored_polygon(PackedVector2Array([Vector2(nx - 6, r.position.y - 16), Vector2(nx + 6, r.position.y - 16), Vector2(nx, r.position.y - 7)]), Color.WHITE)
	meter.draw_line(Vector2(nx, r.position.y), Vector2(nx, r.end.y), Color(1, 1, 1, 0.9), 2.0)
	meter.draw_texture_rect(T.bouncer_puff, Rect2(r.position.x - 52, r.position.y - 22, 74, 74), false)
	meter.draw_texture_rect(T.bouncer_bat, Rect2(r.end.x - 22, r.position.y - 24, 78, 78), false)
	var txt := "%d%% SCARY" % roundi(s)
	meter.draw_string_outline(font_ui_bold, Vector2(r.position.x, r.end.y - 8), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, 7, INK)
	meter.draw_string(font_ui_bold, Vector2(r.position.x, r.end.y - 8), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color.WHITE)


func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	if r.size.x <= 0.5:
		return
	meter.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func goal_text(a: float, b: float) -> Array:
	if b <= 50.0:
		return ["MAKE IT CUTE", "%d–%d%%" % [roundi(100 - b), roundi(100 - a)]]
	if a >= 50.0:
		return ["MAKE IT SCARY", "%d–%d%%" % [roundi(a), roundi(b)]]
	return ["KEEP THE BALANCE", "%d–%d%% scary" % [roundi(a), roundi(b)]]


# ================================================================ flow

func open_intro(i: int) -> void:
	level_idx = i
	level = levels[i]
	mode = "level"
	_load_layout(level)
	werecat.set_target(scary_percent() / 100.0)
	intro_labels.world.text = "NIGHT %s · %s" % [level.id, Levels.WORLDS[i / 5].to_upper()]
	intro_labels.name.text = level.name
	var gt := goal_text(level.goal[0], level.goal[1])
	intro_labels.goal.text = "%s  %s" % [gt[0].capitalize(), gt[1]]
	var tip: String = level.tip
	if tip == "":
		tip = "band" if i > 1 else "claim"
	var tdata: Array = Levels.TIPS[tip]
	intro_labels.tip_head.text = tdata[0]
	intro_labels.tip.text = tdata[1]
	intro_icon.texture = _tip_icon(tip)
	_show("intro")


func _tip_icon(tip: String) -> Texture2D:
	match tip:
		"bomb": return T.ent_bomb
		"charm": return T.ent_charm
		"grub": return T.ent_grub_head
		"slug": return T.ent_slug_head
		"seed": return T.ent_seed_scary
		"nest": return T.ent_nest_scary
		"gift": return T.ent_nest_cute
		"den": return T.ent_den_scary
		"huggy": return T.ent_den_cute
		"burrow": return T.ent_burrow_scary
		"candy": return T.ent_burrow_cute
		"lantern": return T.ent_lantern
		"pens", "pen2": return T.bouncer_bat
		"maze", "shores": return T.ui_lock
		"shepherd": return T.bouncer_puff
		"swarm": return T.ent_nest_scary
		"wisp": return T.ent_wisp
		"stalker": return T.ent_hunter
		"boss": return T.ent_boss
		"trap": return T.bouncer_puff
		"stone": return T.ui_lock
		"hold": return T.zi_hold
		"shrine": return T.zi_swift
		"curl": return T.zi_straight
		"arcs": return T.zi_arc
		"curse": return T.zi_slow
		"idol": return T.ent_idol_scary
		"idols": return T.ent_idol_cute
		"elite": return T.ent_crown
		"finale": return T.ui_star
		"remix": return T.zi_hold
		"lastidol": return T.ent_idol_scary
		"balance": return T.zi_arc
	return T.ui_star


func begin_play() -> void:
	mode = "level"
	lose_reason = ""
	_load_layout(level)
	_spawn_level_entities(level)
	_build_zones(level)
	level["_targets"] = targets_left()
	goal_min = level.goal[0]
	goal_max = level.goal[1]
	werecat.set_target(scary_percent() / 100.0)
	audio.play("start", -2.0)
	_show("play")


func start_endless() -> void:
	mode = "endless"
	level = {"id": "∞", "name": "Endless", "layout": ["split_h", 0.5], "goal": [42, 58], "par": 0, "bouncers": [], "items": [], "tip": ""}
	_load_layout(level)
	band_target = 50.0
	goal_min = 42.0
	goal_max = 58.0
	next_shift = 12.0
	next_spawn = ENDLESS_FIRST_GAP
	next_item = 15.0
	spawn_n = 0
	score = 0.0
	since_claim = 0.0
	_spawn_bouncer("basic", CUTE)
	_spawn_bouncer("basic", SCARY)
	werecat.set_target(scary_percent() / 100.0)
	audio.play("start", -2.0)
	_show("play")


func _pause() -> void:
	if stroking and not growing:
		_cancel_stroke()
	_show("pause")


func _resume() -> void:
	_show("play")


func _retry() -> void:
	if mode == "endless":
		start_endless()
	else:
		begin_play()


func _next_level() -> void:
	if level_idx + 1 < levels.size():
		open_intro(level_idx + 1)
	else:
		_show("levels")


func _quit_to_levels() -> void:
	_cancel_stroke()
	_clear_entities()
	_show("levels")


func _end(won: bool) -> void:
	state = "won" if won else "lost"
	_cancel_stroke()
	var earned := 0
	if mode == "endless":
		best_endless = maxf(best_endless, score)
		lbl_over_title.text = "The night ends"
		lbl_over_sub.text = "Score %d   ·   Best %d" % [roundi(score), roundi(best_endless)]
		btn_next.visible = false
		audio.play("lose", -2.0)
	elif won:
		earned = star_count(lives, clock, float(level.par))
		stars[level_idx] = maxi(stars[level_idx], earned)
		lbl_over_title.text = "The Werecat is pleased" if level_idx < levels.size() - 1 else "The spell is broken!"
		# say which stars were missed
		var missed: Array = []
		if lives < 3:
			missed.append("keep all 3 hearts")
		if clock > float(level.par):
			missed.append("finish within %ds (you took %ds)" % [int(level.par), int(ceil(clock))])
		lbl_over_sub.text = ("Night %s complete in %ds" % [level.id, int(ceil(clock))]) if missed.is_empty() \
			else ("For more stars: " + " and ".join(missed))
		btn_next.visible = level_idx + 1 < levels.size()
		audio.play("win", -1.0)
	else:
		lbl_over_title.text = "The Werecat is displeased"
		lbl_over_sub.text = (lose_reason + ". Try again?") if lose_reason != "" else "Out of lives. Try again?"
		btn_next.visible = false
		audio.play("lose", -2.0)
	_save()
	for s in 3:
		over_stars[s].visible = mode != "endless"
		over_stars[s].texture = T.ui_star_empty
		over_stars[s].scale = Vector2.ONE
	_show("over")
	state = "won" if won else "lost"
	# pop the stars in one by one
	for s in earned:
		var tr: TextureRect = over_stars[s]
		var tw := create_tween()
		tw.tween_interval(0.35 + s * 0.35)
		tw.tween_callback(func() -> void:
			tr.texture = T.ui_star
			tr.scale = Vector2.ONE * 1.5
			audio.play("star%d" % (s + 1), -3.0))
		tw.tween_property(tr, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ================================================================ grid

func _load_layout(lv: Dictionary) -> void:
	_clear_entities()
	_clear_zones()
	if trail_line:
		_clear_stroke()
	var built := Levels.build(lv, GW, GH)
	mask = built[0]
	under = built[1]
	trail.fill(0)
	trail_list.clear()
	_recount()
	lives = 3
	hold = 0.0
	clock = 0.0
	freeze_t = 0.0
	_rebuild_tex_bytes()
	_upload_mask(false)
	if lv.has("push"):
		lv["goal"] = push_goal(lv.push, scary_percent())


## A night's band from its push spec: `dir` +1 = make it Scarier, -1 = make it
## Cuter; the band's near edge is `dist` points from the starting split.
static func push_goal(push: Array, start: float) -> Array:
	var dir: int = push[0]
	var dist: float = push[1]
	var width: float = push[2] if push.size() > 2 else 10.0
	if dir > 0:
		var lo := minf(start + dist, 96.0)
		return [int(round(lo)), int(round(minf(lo + width, 100.0)))]
	var hi := maxf(start - dist, 4.0)
	return [int(round(maxf(hi - width, 0.0))), int(round(hi))]


func _recount() -> void:
	scary_count = 0
	claimable = 0
	for v in mask:
		if v != STONE:
			claimable += 1
			scary_count += v
	claimable = maxi(claimable, 1)


func in_field(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < FIELD_SIZE.x and p.y < FIELD_SIZE.y


func cell_index(p: Vector2) -> int:
	var x := clampi(int(p.x / CELL), 0, GW - 1)
	var y := clampi(int(p.y / CELL), 0, GH - 1)
	return y * GW + x


func type_at(p: Vector2) -> int:
	return mask[cell_index(p)]


func scary_percent() -> float:
	return 100.0 * scary_count / float(claimable)


func _set_cell(i: int, v: int) -> bool:
	var old := mask[i]
	if old == v or old == STONE:
		return false
	mask[i] = v
	tex_bytes[i * 2] = v * 255
	scary_count += v - old
	mask_dirty = true
	mask_serial += 1
	return true


func paint_disc(center: Vector2, r_cells: float, color: int) -> int:
	var cx := int(center.x / CELL)
	var cy := int(center.y / CELL)
	var r := int(ceil(r_cells))
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r_cells * r_cells:
				continue
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= GW or y >= GH:
				continue
			if _set_cell(y * GW + x, color):
				n += 1
	return n


func _disc_cells(center: Vector2, r_cells: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cx := int(center.x / CELL)
	var cy := int(center.y / CELL)
	var r := int(ceil(r_cells))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var y := cy + dy
			if dx * dx + dy * dy <= r_cells * r_cells and x >= 0 and y >= 0 and x < GW and y < GH:
				out.append(y * GW + x)
	return out


## Rebuilds the texture bytes from the mask (after a layout load). After
## that, _set_cell keeps them current so uploads need no per-cell loop.
func _rebuild_tex_bytes() -> void:
	tex_bytes.resize(GW * GH * 2)
	for i in GW * GH:
		var v := mask[i]
		if v == STONE:
			tex_bytes[i * 2] = under[i] * 255
			tex_bytes[i * 2 + 1] = 255
		else:
			tex_bytes[i * 2] = v * 255
			tex_bytes[i * 2 + 1] = 0
	mask_serial += 1


func _upload_mask(animate: bool, origin := Vector2(0.5, 0.5)) -> void:
	if tex_bytes.size() != GW * GH * 2:
		return
	var t0 := Time.get_ticks_usec()
	if gfx_tier == 2:
		_upload_mask_lite(animate)
	else:
		if animate:
			prev_tex.update(mask_img)
		var img := Image.create_from_data(GW, GH, false, Image.FORMAT_RG8, tex_bytes)
		img.resize(GW / 2, GH / 2, Image.INTERPOLATE_BILINEAR)
		img.resize(GW, GH, Image.INTERPOLATE_CUBIC)
		mask_img = img
		mask_tex.update(mask_img)
	mask_dirty = false
	perf.mask = (Time.get_ticks_usec() - t0) / 1000.0
	if animate:
		flip_t = 0.0
		field_mat.set_shader_parameter("flip_origin", origin)
	else:
		if gfx_tier != 2:
			prev_tex.update(mask_img)
		flip_t = 1.0
	field_mat.set_shader_parameter("flip_progress", flip_t)


## Lite upload: one half-size downscale (it doubles as the blur) and a tiny
## wide-blur copy for the seam halo. The shader's hardware filtering does the
## smoothing that the full path does with CPU upscales.
func _upload_mask_lite(animate: bool) -> void:
	var img := Image.create_from_data(GW, GH, false, Image.FORMAT_RG8, tex_bytes)
	img.resize(GW / 2, GH / 2, Image.INTERPOLATE_BILINEAR)
	lite_img = img
	var old: ImageTexture = lite_ring[lite_ring_i]
	lite_ring_i = (lite_ring_i + 1) % lite_ring.size()
	lite_mask_tex = lite_ring[lite_ring_i]
	lite_mask_tex.update(img)
	# while a claim animates, "prev" is simply the texture we just retired
	lite_prev_tex = old if animate else lite_mask_tex
	var w := img.duplicate() as Image
	w.resize(GW / 7, GH / 7, Image.INTERPOLATE_BILINEAR)
	wide_ring_i = (wide_ring_i + 1) % wide_ring.size()
	wide_tex = wide_ring[wide_ring_i]
	wide_tex.update(w)
	field_mat.set_shader_parameter("mask_tex", lite_mask_tex)
	field_mat.set_shader_parameter("prev_mask_tex", lite_prev_tex)
	field_mat.set_shader_parameter("wide_tex", wide_tex)


# ================================================================ input + strokes

func _input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if perf_panel and perf_panel.visible and perf_panel.get_global_rect().has_point(event.position):
				return
			var ep: Vector2 = event.position - stage_off
			if ep.distance_to(Vector2(360, 236)) < 110.0:
				audio.play("click", -4.0)
				_pause()
				return
			begin_stroke(ep - FIELD_POS)
		else:
			end_stroke()
	elif event is InputEventScreenDrag:
		move_stroke(event.position - stage_off - FIELD_POS)


func begin_stroke(p: Vector2) -> void:
	if state != "play" or growing or not in_field(p) or type_at(p) == STONE:
		return
	stroking = true
	stroke_active = false
	stroke_origin = type_at(p)
	last_origin_pt = p
	stroke_points.clear()


func move_stroke(p: Vector2) -> void:
	if not stroking:
		return
	var inside := in_field(p)
	var e := CELL * 1.5
	var near_edge := p.x < e or p.y < e or p.x > FIELD_SIZE.x - e or p.y > FIELD_SIZE.y - e
	if not stroke_active:
		if inside and type_at(p) == 1 - stroke_origin:
			stroke_active = true
			stroke_points = PackedVector2Array([last_origin_pt])
			trail_line.points = PackedVector2Array([last_origin_pt])
			trail_line.modulate.a = 0.45
			_style_trail()
			curl_mode = effective_curl()
			if curl_mode == "true":
				_extend_trail(p)
			else:
				tip = last_origin_pt
				ray_anchor = last_origin_pt
				tip_heading = (p - last_origin_pt).angle()
				tip_len = 0.0
				tip_enemy_len = 0.0
				tip_aimed = false
				last_finger = last_origin_pt
				_chase(p)
		elif inside and type_at(p) == stroke_origin:
			last_origin_pt = p
		return
	if curl_mode != "true":
		_chase(p)
		return
	var q := Vector2(clampf(p.x, 0.0, FIELD_SIZE.x - 0.01), clampf(p.y, 0.0, FIELD_SIZE.y - 0.01))
	if q.distance_to(stroke_points[stroke_points.size() - 1]) < 3.0 and inside and not near_edge:
		return
	_extend_trail(q)
	var t := type_at(q)
	if not inside or near_edge or t == stroke_origin or t == STONE:
		start_growth()


## Curl modes: the tip of the line follows the finger but can only turn so
## fast. Straight: the line is a ray from where it entered enemy ground; the
## finger pushes it forward. Returns after closing (growth starts).
func _chase(finger: Vector2) -> void:
	var step := 4.0
	# Aim from intent: wait until the finger is clearly past the anchor,
	# then take the heading from anchor to finger (not from the first,
	# shallow border crossing).
	if not tip_aimed:
		if finger.distance_to(ray_anchor) < CURL_AIM_DIST:
			leash.points = PackedVector2Array([tip, finger])
			return
		tip_aimed = true
		tip_heading = (finger - ray_anchor).angle()
		last_finger = ray_anchor
	if curl_mode == "straight":
		var dir := Vector2.from_angle(tip_heading)
		var want := maxf(tip_len, (finger - ray_anchor).dot(dir))
		while tip_len + step <= want:
			tip_len += step
			tip = ray_anchor + dir * tip_len
			if _tip_step():
				return
	else:
		var rate := deg_to_rad(float(CURL_RATE[curl_mode]))
		var budget := finger.distance_to(last_finger)
		while budget > 0.0:
			var to := finger - tip
			if to.length() < step:
				break
			var dh := wrapf(to.angle() - tip_heading, -PI, PI)
			tip_heading += clampf(dh, -rate * step, rate * step)
			tip += Vector2.from_angle(tip_heading) * step
			budget -= step
			if _tip_step():
				return
	last_finger = finger
	leash.points = PackedVector2Array([tip, finger])


## Lays the next bit of line at the tip; starts growth if the tip closed.
func _tip_step() -> bool:
	var q := Vector2(clampf(tip.x, 0.0, FIELD_SIZE.x - 0.01), clampf(tip.y, 0.0, FIELD_SIZE.y - 0.01))
	var e := CELL * 1.5
	var out := not in_field(tip) or tip.x < e or tip.y < e or tip.x > FIELD_SIZE.x - e or tip.y > FIELD_SIZE.y - e
	if q.distance_to(stroke_points[stroke_points.size() - 1]) >= 3.0 or out:
		_extend_trail(q)
	var t := type_at(q)
	if t == 1 - stroke_origin:
		tip_enemy_len += 4.0
	# grace: early wobbles back over your own ground don't close the line
	var closes_on_home := t == stroke_origin and tip_enemy_len >= CURL_GRACE
	if out or closes_on_home or t == STONE:
		leash.clear_points()
		start_growth()
		return true
	return false


## Lifting before the path closes just cancels the blueprint. Free.
func end_stroke() -> void:
	if stroking and stroke_active:
		_fade_line(trail_line, false)
	if not growing:
		_clear_stroke()
	else:
		stroking = false


func _cancel_stroke() -> void:
	if stroke_active or growing:
		_fade_line(trail_line, false)
		_fade_line(grow_line_a, false)
		_fade_line(grow_line_b, false)
	_clear_stroke()


func _clear_stroke() -> void:
	stroking = false
	stroke_active = false
	growing = false
	stroke_points.clear()
	for i in trail_list:
		trail[i] = 0
	trail_list.clear()
	for i in live_list:
		live[i] = 0
	live_list.clear()
	if trail_line:
		trail_line.clear_points()
		leash.clear_points()
		grow_line_a.clear_points()
		grow_line_b.clear_points()
		front_a.visible = false
		front_b.visible = false


## Drawing only lays down a blueprint (no risk, no triggers).
func _extend_trail(p: Vector2) -> void:
	var a := stroke_points[stroke_points.size() - 1]
	stroke_points.append(p)
	trail_line.add_point(p)
	var steps := maxi(1, int(a.distance_to(p) / (CELL * 0.5)))
	for k in steps + 1:
		_stamp(a.lerp(p, float(k) / steps), trail, trail_list)


func _stamp(p: Vector2, arr: PackedByteArray, list: PackedInt32Array) -> void:
	var cx := int(p.x / CELL)
	var cy := int(p.y / CELL)
	var r := int(ceil(TRAIL_R))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > TRAIL_R * TRAIL_R:
				continue
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= GW or y >= GH:
				continue
			var i := y * GW + x
			if arr[i] == 0:
				arr[i] = 1
				list.append(i)


func _style_trail() -> void:
	var mat: ShaderMaterial = trail_line.material
	if stroke_origin == CUTE:
		mat.set_shader_parameter("core_color", Color("fff4fa"))
		mat.set_shader_parameter("glow_color", Color("ff7ac0"))
	else:
		mat.set_shader_parameter("core_color", Color("2a0610"))
		mat.set_shader_parameter("glow_color", Color("ff5a2e"))
	mat.set_shader_parameter("danger", 0.0)


func _fade_line(src_line: Line2D, broken: bool) -> void:
	if src_line.get_point_count() < 2:
		return
	var l := _make_trail_line()
	l.points = src_line.points
	l.modulate.a = src_line.modulate.a
	var src: ShaderMaterial = src_line.material
	var mat: ShaderMaterial = l.material
	mat.set_shader_parameter("core_color", src.get_shader_parameter("core_color"))
	mat.set_shader_parameter("glow_color", src.get_shader_parameter("glow_color"))
	mat.set_shader_parameter("danger", 1.0 if broken else 0.0)
	world.add_child(l)
	world.move_child(l, trail_line.get_index())
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.45 if broken else 0.3)
	if broken:
		tw.parallel().tween_property(l, "width", 60.0, 0.45)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- growth

## The path closed: the wall now grows along it from both ends toward the
## middle. Grown sections are live; anything touching them snaps the wall.
func start_growth() -> void:
	stroking = false
	stroke_active = false
	growing = true
	grow_pts = stroke_points.duplicate()
	grow_cum = PackedFloat32Array([0.0])
	for i in range(1, grow_pts.size()):
		grow_cum.append(grow_cum[i - 1] + grow_pts[i].distance_to(grow_pts[i - 1]))
	grow_len = grow_cum[grow_cum.size() - 1]
	grow_a = 0.0
	grow_b = grow_len
	trail_line.modulate.a = 0.3
	var col := Color(1, 0.8, 0.95) if stroke_origin == CUTE else Color(1, 0.45, 0.15)
	for f in [front_a, front_b]:
		f.visible = true
		f.modulate = col
	audio.play("trail_cute" if stroke_origin == CUTE else "trail_scary", -4.0, 0.08)
	_update_growth_visuals()


func _point_at(d: float) -> Vector2:
	d = clampf(d, 0.0, grow_len)
	var lo := 0
	var hi := grow_cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if grow_cum[mid] <= d:
			lo = mid
		else:
			hi = mid
	var seg := grow_cum[hi] - grow_cum[lo]
	var t := 0.0 if seg <= 0.0001 else (d - grow_cum[lo]) / seg
	return grow_pts[lo].lerp(grow_pts[hi], t)


func _sub_points(d0: float, d1: float) -> PackedVector2Array:
	var out := PackedVector2Array([_point_at(d0)])
	for i in grow_pts.size():
		if grow_cum[i] > d0 and grow_cum[i] < d1:
			out.append(grow_pts[i])
	out.append(_point_at(d1))
	return out


func _grow_range(d0: float, d1: float) -> void:
	var d := d0
	while d <= d1:
		var p := _point_at(d)
		_stamp(p, live, live_list)
		for it in items:
			if it.alive and it.kind in ["bomb", "charm"] and it.pos.distance_to(p) < 26.0:
				if it.kind == "bomb" and not it.armed:
					_arm_bomb(it, stroke_origin)
				elif it.kind == "charm":
					_use_charm(it)
		d += 2.0
	_stamp(_point_at(d1), live, live_list)


func step_growth(delta: float) -> void:
	if not growing:
		return
	var adv := GROW_SPEED * wall_mult() * delta
	var na := grow_a + adv
	var nb := grow_b - adv
	if na >= nb:
		var mid := (grow_a + grow_b) / 2.0
		_grow_range(grow_a, mid)
		_grow_range(mid, grow_b)
		grow_a = mid
		grow_b = mid
		complete_growth(_point_at(mid))
		return
	_grow_range(grow_a, na)
	_grow_range(nb, grow_b)
	grow_a = na
	grow_b = nb
	_update_growth_visuals()


func _update_growth_visuals() -> void:
	grow_line_a.points = _sub_points(0.0, maxf(grow_a, 0.5))
	grow_line_b.points = _sub_points(minf(grow_b, grow_len - 0.5), grow_len)
	front_a.position = FIELD_POS + _point_at(grow_a)
	front_b.position = FIELD_POS + _point_at(grow_b)
	var pulse := 0.85 + 0.2 * sin(clock * 30.0)
	front_a.scale = Vector2.ONE * pulse
	front_b.scale = Vector2.ONE * pulse
	front_a.rotation = clock * 4.0
	front_b.rotation = -clock * 4.0


## The two ends met: claim.
func complete_growth(meet: Vector2) -> void:
	var bomb_before := _bomb_cells()
	for i in trail_list:
		_set_cell(i, stroke_origin)
	var flipped := _flip_empty_pockets(stroke_origin, trail_list)
	_upload_mask(true, meet / FIELD_SIZE)
	_fade_line(grow_line_a, false)
	_fade_line(grow_line_b, false)
	_burst(meet, T.fx_sparkle if stroke_origin == CUTE else T.fx_ember, 28, Color.WHITE)
	audio.play("claim_cute" if stroke_origin == CUTE else "claim_scary", -1.0, 0.04)
	if stroke_origin == SCARY:
		werecat.strike()
		shake = maxf(shake, 0.4)
	_clear_stroke()
	since_claim = 0.0
	_after_territory_change(bomb_before, stroke_origin)
	werecat.set_target(scary_percent() / 100.0)
	if flipped > 0 and mode == "endless":
		score += flipped * 0.02


func break_trail(at: Vector2 = Vector2(-1, -1)) -> void:
	if at.x < 0.0:
		at = _point_at(grow_a) if growing else FIELD_SIZE / 2.0
	_fade_line(grow_line_a, true)
	_fade_line(grow_line_b, true)
	_fade_line(trail_line, true)
	_clear_stroke()
	lives -= 1
	shake = 1.0
	audio.play("snap", 0.0, 0.05)
	_burst(at, T.fx_ember, 22, Color(1, 0.35, 0.15))
	if lives <= 0:
		_end(false)


func _bomb_cells() -> Dictionary:
	var d := {}
	for it in items:
		if it.alive and it.kind == "bomb" and not it.armed:
			d[it] = type_at(it.pos)
	return d


## After a claim or explosion: arm bombs whose ground flipped, and kill
## nests, seeds and carvers whose ground was taken.
func _after_territory_change(bomb_before: Dictionary, color: int) -> void:
	for it in bomb_before:
		if it.alive and not it.armed and type_at(it.pos) != bomb_before[it]:
			_arm_bomb(it, color)
	_check_deaths()


func _check_deaths() -> void:
	for it in items:
		if it.alive and it.kind in ROOTED and type_at(it.pos) == 1 - int(it.side):
			_kill_item(it)
	for b in bouncers.duplicate():
		if b.kind == "carver" and type_at(b.pos) == 1 - int(b.side):
			_capture(b)


## Splits the invaded territory into pockets. Only pockets that touch the
## new wall (or blast), i.e. `seeds`, can change: bouncer-free ones flip to
## `color`, tiny ones trap their bouncers and flip. Pockets elsewhere are
## left alone even if empty. Returns cells flipped.
func _flip_empty_pockets(color: int, seeds: PackedInt32Array) -> int:
	var t0 := Time.get_ticks_usec()
	var n := _flip_pockets_core(color, seeds)
	perf.fill = (Time.get_ticks_usec() - t0) / 1000.0
	perf.fill_worst = maxf(perf.fill_worst, perf.fill)
	return n


func _flip_pockets_core(color: int, seeds: PackedInt32Array) -> int:
	var invaded := 1 - color
	var n := GW * GH
	# label[i]: 0 = unvisited, -1 = part of a region too big to ever flip
	# (it holds a creature and outgrows every capture limit), >0 = pocket id
	var label := PackedInt32Array()
	label.resize(n)
	var occ_mark := PackedByteArray()
	occ_mark.resize(n)
	var occ := {}
	for bo in bouncers:
		if bo.side == invaded and bo.kind in ["basic", "stalker", "boss", "elite"]:
			var ci := cell_index(bo.pos)
			if ci < 0:
				continue
			occ_mark[ci] = 1
			if not occ.has(ci):
				occ[ci] = []
			occ[ci].append(bo)
	var max_frac := CAPTURE_FRAC
	for ci in occ:
		for bo in occ[ci]:
			max_frac = maxf(max_frac, float(CAPTURE_FRAC_BY_KIND.get(bo.kind, CAPTURE_FRAC)))
	var max_limit := int(claimable * max_frac) + 1
	var stack := PackedInt32Array()
	stack.resize(n)
	var visit := PackedInt32Array()
	visit.resize(n)
	# 1) from each creature: if its region outgrows every capture limit it can
	#    never flip, so mark what we saw as dead and stop early
	for ci in occ:
		if label[ci] != 0 or mask[ci] != invaded:
			continue
		var sp := 0
		var vc := 0
		stack[sp] = ci
		sp += 1
		label[ci] = 1
		var dead := false
		while sp > 0:
			sp -= 1
			var i := stack[sp]
			visit[vc] = i
			vc += 1
			if vc >= max_limit:
				dead = true
				break
			var x := i % GW
			if x > 0 and label[i - 1] == 0 and mask[i - 1] == invaded:
				label[i - 1] = 1
				stack[sp] = i - 1
				sp += 1
			if x < GW - 1 and label[i + 1] == 0 and mask[i + 1] == invaded:
				label[i + 1] = 1
				stack[sp] = i + 1
				sp += 1
			if i >= GW and label[i - GW] == 0 and mask[i - GW] == invaded:
				label[i - GW] = 1
				stack[sp] = i - GW
				sp += 1
			if i < n - GW and label[i + GW] == 0 and mask[i + GW] == invaded:
				label[i + GW] = 1
				stack[sp] = i + GW
				sp += 1
		if dead:
			for k in vc:
				label[visit[k]] = -1
			for k in sp:
				label[stack[k]] = -1
		else:
			for k in vc:
				label[visit[k]] = 0    # small pocket: the full pass decides
	# 2) pockets next to the new wall
	var next_id := 2
	var to_flip: Array = []
	for si in seeds:
		var sx := si % GW
		for start in [si, si - 1 if sx > 0 else -1, si + 1 if sx < GW - 1 else -1, si - GW, si + GW]:
			if start < 0 or start >= n or label[start] != 0 or mask[start] != invaded:
				continue
			var pid := next_id
			next_id += 1
			var pocket := PackedInt32Array()
			var inside: Array = []
			var dead := false
			var sp := 0
			stack[sp] = start
			sp += 1
			label[start] = pid
			while sp > 0:
				sp -= 1
				var i := stack[sp]
				pocket.append(i)
				if occ_mark[i] == 1:
					inside.append_array(occ[i])
				var x := i % GW
				var nb := i - 1
				if x > 0 and mask[nb] == invaded:
					if label[nb] == 0:
						label[nb] = pid
						stack[sp] = nb
						sp += 1
					elif label[nb] == -1:
						dead = true
						break
				nb = i + 1
				if x < GW - 1 and mask[nb] == invaded:
					if label[nb] == 0:
						label[nb] = pid
						stack[sp] = nb
						sp += 1
					elif label[nb] == -1:
						dead = true
						break
				nb = i - GW
				if nb >= 0 and mask[nb] == invaded:
					if label[nb] == 0:
						label[nb] = pid
						stack[sp] = nb
						sp += 1
					elif label[nb] == -1:
						dead = true
						break
				nb = i + GW
				if nb < n and mask[nb] == invaded:
					if label[nb] == 0:
						label[nb] = pid
						stack[sp] = nb
						sp += 1
					elif label[nb] == -1:
						dead = true
						break
			if dead:
				for i in pocket:
					label[i] = -1
				for k in sp:
					label[stack[k]] = -1
				continue
			var limit := int(claimable * CAPTURE_FRAC)
			for bb in inside:
				limit = maxi(limit, int(claimable * float(CAPTURE_FRAC_BY_KIND.get(bb.kind, CAPTURE_FRAC))))
			if inside.is_empty() or pocket.size() < limit:
				to_flip.append({"cells": pocket, "inside": inside})
	var flipped := 0
	# A color can never be wiped out: if these flips would take all of the
	# invaded color's ground, its largest pocket survives as a foothold (any
	# creatures in it can still be trapped).
	var remaining := scary_count if invaded == SCARY else claimable - scary_count
	var total_flip := 0
	for pk in to_flip:
		total_flip += pk.cells.size()
	var keep := -1
	if not to_flip.is_empty() and total_flip >= remaining:
		var biggest := 0
		for k in to_flip.size():
			if to_flip[k].cells.size() > biggest:
				biggest = to_flip[k].cells.size()
				keep = k
	for k in to_flip.size():
		var pk: Dictionary = to_flip[k]
		for bb in pk.inside:
			_capture(bb)
		if k == keep:
			continue
		for i in pk.cells:
			_set_cell(i, color)
		flipped += pk.cells.size()
	return flipped


func _threatens(b: Dictionary) -> bool:
	if not growing:
		return false
	match b.kind:
		"wisp", "carver":
			return true
	return b.side != stroke_origin


func _touches_trail(p: Vector2, radius: float) -> bool:
	var r := int(ceil(radius / CELL))
	var cx := int(p.x / CELL)
	var cy := int(p.y / CELL)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= GW or y >= GH:
				continue
			if live[y * GW + x] == 1 and Vector2(dx, dy).length() * CELL <= radius + CELL:
				return true
	return false


# ================================================================ entities

func _clear_entities() -> void:
	for b in bouncers:
		_free_bouncer_nodes(b)
	bouncers.clear()
	for it in items:
		if is_instance_valid(it.node):
			it.node.queue_free()
	items.clear()


func _free_bouncer_nodes(b: Dictionary) -> void:
	if is_instance_valid(b.node):
		b.node.queue_free()
	for s in b.get("segs", []):
		if is_instance_valid(s):
			s.queue_free()


func _spawn_level_entities(lv: Dictionary) -> void:
	for spec in lv.items:
		_spawn_item(spec.kind, spec.side, spec.at * FIELD_SIZE)
	for spec in lv.bouncers:
		var ats: Array = spec.get("at", [])
		for k in spec.count:
			if k < ats.size():
				var p: Vector2 = ats[k] * FIELD_SIZE
				paint_disc(p, 5.0, int(spec.side))
				_spawn_bouncer(spec.kind, spec.side, spec.speed, p)
			else:
				_spawn_bouncer(spec.kind, spec.side, spec.speed)


func _free_spot(side: int, radius: float, anywhere := false) -> Variant:
	var open := PackedInt32Array()
	for i in range(0, GW * GH, 3):
		var x := i % GW
		var y := i / GW
		if x < 7 or y < 7 or x > GW - 8 or y > GH - 8:
			continue
		var v := mask[i]
		if v == STONE or (not anywhere and v != side):
			continue
		var p := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
		var ok := true
		for a in 8:
			var q := p + Vector2(cos(a * PI / 4), sin(a * PI / 4)) * (radius + 6.0)
			var t := type_at(q) if in_field(q) else STONE
			if t == STONE or (not anywhere and t != side):
				ok = false
				break
		if ok:
			open.append(i)
	if open.is_empty():
		return null
	var i: int = open[rng.randi_range(0, open.size() - 1)]
	return Vector2((i % GW + 0.5) * CELL, (i / GW + 0.5) * CELL)


func _spawn_bouncer(kind: String, side: int, speed := 1.0, at: Variant = null) -> bool:
	var r := 15.0
	var tex: Texture2D = T.bouncer_puff if side == CUTE else T.bouncer_bat
	var sc := 0.6
	match kind:
		"stalker":
			tex = T.ent_huggy if side == CUTE else T.ent_hunter
			sc = 0.55 if side == CUTE else 0.62
			r = 17.0
		"wisp":
			tex = T.ent_wisp
			sc = 0.5
			r = 16.0
		"carver":
			tex = T.ent_slug_head if side == CUTE else T.ent_grub_head
			sc = 0.5
			r = 16.0
		"boss":
			tex = T.ent_boss
			sc = 0.72
			r = 30.0
		"elite":
			sc = 0.85 if side == CUTE else 1.05
			r = 21.0
	var anywhere := kind in ["wisp", "carver"]
	var p: Variant = at if at != null else _free_spot(side, r, anywhere)
	if p == null:
		return false
	var ang := rng.randf_range(0.35, 1.22) + PI / 2.0 * rng.randi_range(0, 3)
	if mode == "level":
		speed *= float(level.get("tempo", 1.0))   # per-night difficulty (tuned)
	var spd: float = BOUNCER_SPEED * speed * {"basic": 1.0, "stalker": 1.05, "wisp": 0.65, "carver": 0.62, "boss": 0.85, "elite": 0.75}[kind]
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * sc
	if kind == "elite":
		var cr := Sprite2D.new()
		cr.texture = T.ent_crown
		cr.position = Vector2(0, -38 if side == CUTE else -22)
		cr.scale = Vector2.ONE * (0.6 / sc)
		s.add_child(cr)
	if side == SCARY and kind in ["basic", "stalker", "boss", "elite"]:
		var glow := Sprite2D.new()
		glow.texture = T.fx_glow
		glow.scale = Vector2.ONE * (1.5 if kind != "boss" else 3.0)
		glow.modulate = Color(1, 0.25, 0.1, 0.5)
		glow.show_behind_parent = true
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		s.add_child(glow)
	bouncer_layer.add_child(s)
	var b := {"kind": kind, "side": side, "pos": p, "vel": Vector2(cos(ang), sin(ang)) * spd, "speed": spd,
		"r": r, "node": s, "phase": rng.randf() * TAU, "base_scale": sc}
	if kind == "carver":
		_add_glow(s, Color(1, 0.3, 0.1, 0.6) if side == SCARY else Color(1, 0.75, 0.9, 0.5), 1.0)
		var segs: Array = []
		for k in 5:
			var sg := Sprite2D.new()
			sg.texture = T.ent_slug_seg if side == CUTE else T.ent_grub_seg
			sg.scale = Vector2.ONE * (0.5 - k * 0.04)
			bouncer_layer.add_child(sg)
			bouncer_layer.move_child(sg, 0)
			segs.append(sg)
		b["segs"] = segs
		b["hist"] = PackedVector2Array([p])
	bouncers.append(b)
	return true


func _add_glow(parent: Sprite2D, col: Color, size: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = T.fx_glow
	glow.scale = Vector2.ONE * size / parent.scale.x
	glow.modulate = col
	glow.show_behind_parent = true
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	parent.add_child(glow)


func _spawn_item(kind: String, side: int, at: Vector2) -> void:
	var tex: Texture2D
	var sc := 0.56
	match kind:
		"bomb": tex = T.ent_bomb
		"charm": tex = T.ent_charm
		"nest":
			tex = T.ent_nest_cute if side == CUTE else T.ent_nest_scary
			sc = 0.62
		"den":
			tex = T.ent_den_cute if side == CUTE else T.ent_den_scary
			sc = 0.62
		"burrow":
			tex = T.ent_burrow_cute if side == CUTE else T.ent_burrow_scary
			sc = 0.6
		"lantern":
			tex = T.ent_lantern
			sc = 0.6
		"seed":
			tex = T.ent_seed_cute if side == CUTE else T.ent_seed_scary
			sc = 0.6
		"idol":
			tex = T.ent_idol_cute if side == CUTE else T.ent_idol_scary
			sc = 0.66
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * sc
	s.position = FIELD_POS + at
	var gcol: Color = {"bomb": Color(1, 0.7, 0.9, 0.55), "charm": Color(0.6, 0.85, 1, 0.6)}.get(kind,
		Color(1, 0.3, 0.1, 0.6) if side == SCARY else Color(1, 0.75, 0.9, 0.5))
	_add_glow(s, gcol, 1.25)
	item_layer.add_child(s)
	var it := {"kind": kind, "side": side, "pos": at, "node": s, "t": 0.0, "r": 6.0, "armed": false,
		"fuse": 0.0, "color": 0, "alive": true, "base_scale": sc, "phase": rng.randf() * TAU}
	items.append(it)
	# nests and seeds claim a little ground under themselves
	if kind in ROOTED:
		paint_disc(at, 7.0 if kind == "idol" else 6.0, side)
		_upload_mask(false)
		_recount()


func _kill_item(it: Dictionary) -> void:
	it.alive = false
	_burst(it.pos, T.fx_sparkle if it.side == SCARY else T.fx_ember, 24, Color.WHITE)
	audio.play("capture", -2.0)
	var n: Sprite2D = it.node
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


func _capture(b: Dictionary) -> void:
	if not bouncers.has(b):
		return
	bouncers.erase(b)
	audio.play("capture", -1.0, 0.1)
	_burst(b.pos, T.fx_sparkle if b.side == CUTE else T.fx_ember, 30, Color.WHITE)
	var n: Sprite2D = b.node
	var tw := create_tween()
	tw.tween_property(n, "scale", n.scale * 1.6, 0.08)
	tw.tween_property(n, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _free_bouncer_nodes(b))
	if mode == "endless":
		score += 50.0


func _arm_bomb(it: Dictionary, color: int) -> void:
	it.armed = true
	it.color = color
	it.fuse = 0.4


func _explode(it: Dictionary) -> void:
	it.alive = false
	var before := _bomb_cells()
	paint_disc(it.pos, BOMB_R, it.color)
	_flip_empty_pockets(it.color, _disc_cells(it.pos, BOMB_R + 1.0))
	_upload_mask(true, it.pos / FIELD_SIZE)
	audio.play("bomb", 0.0, 0.05)
	shake = 1.0
	_burst(it.pos, T.fx_ember, 46, Color(1, 0.9, 0.7))
	var p2 := _burst(it.pos, T.fx_sparkle if it.color == CUTE else T.fx_ember, 30, Color.WHITE)
	p2.initial_velocity_max = 520.0
	var n: Sprite2D = it.node
	n.queue_free()
	# shockwave flash
	var wave := Sprite2D.new()
	wave.texture = T.fx_glow
	wave.position = FIELD_POS + it.pos
	wave.modulate = Color(1, 0.75, 0.9, 0.95) if it.color == CUTE else Color(1, 0.35, 0.1, 0.95)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wave.material = add
	wave.scale = Vector2.ONE * 0.3
	fx_layer.add_child(wave)
	var tw := create_tween()
	tw.tween_property(wave, "scale", Vector2.ONE * BOMB_R * CELL * 2.6 / 128.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(wave, "modulate:a", 0.0, 0.45)
	tw.tween_callback(wave.queue_free)
	_after_territory_change(before, it.color)
	werecat.set_target(scary_percent() / 100.0)
	if it.color == SCARY:
		werecat.strike()


func _use_charm(it: Dictionary) -> void:
	it.alive = false
	freeze_t = FREEZE_TIME
	audio.play("charm", 0.0)
	_burst(it.pos, T.fx_sparkle, 36, Color(0.75, 0.9, 1.0))
	var n: Sprite2D = it.node
	var tw := create_tween()
	tw.tween_property(n, "scale", n.scale * 2.0, 0.25)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.25)
	tw.tween_callback(n.queue_free)


# ================================================================ simulation

func _process(delta: float) -> void:
	var t_frame := Time.get_ticks_usec()
	clock += delta if state == "play" else 0.0
	if flip_t < 1.0:
		flip_t = minf(1.0, flip_t + delta * 1.8)
		field_mat.set_shader_parameter("flip_progress", flip_t)
	upload_cool -= delta
	if mask_dirty and flip_t >= 1.0 and upload_cool <= 0.0:
		_upload_mask(false)
		upload_cool = 1.0 / 15.0
	var m := werecat.morph
	var bm: ShaderMaterial = bg.material
	if absf(m - _sent_morph) > 0.002:
		_sent_morph = m
		bm.set_shader_parameter("morph", m)
		field_mat.set_shader_parameter("morph", m)
		audio.set_morph(m)
	if state == "title":
		menu_t += delta
		var cyc := fmod(menu_t, 9.0)
		werecat.set_target(0.0 if cyc < 3.5 else 1.0 if cyc < 7.5 else 0.0)
	elif state == "levels":
		werecat.set_target(0.0)
	elif state == "play":
		if zones_serial != mask_serial and not zones.is_empty():
			var tz := Time.get_ticks_usec()
			_update_zones()
			perf.zones = (Time.get_ticks_usec() - tz) / 1000.0
		freeze_t = maxf(0.0, freeze_t - delta)
		_timed("growth", step_growth.bind(delta))
		if state == "play":
			_timed("creatures", step_entities.bind(delta))
		if state == "play":
			_timed("items", step_items.bind(delta))
		if state == "play":
			if mode == "endless":
				step_endless(delta)
			else:
				step_goal(delta)
		werecat.set_target(scary_percent() / 100.0)
	var fz := clampf(freeze_t, 0.0, 1.0)
	if fz != _sent_freeze:
		_sent_freeze = fz
		field_mat.set_shader_parameter("freeze", fz)
	var hv := hold / HOLD_TIME if mode == "level" and state == "play" else 0.0
	if hv != _sent_hold:
		_sent_hold = hv
		bm.set_shader_parameter("hold", hv)
	_timed("anim", _animate_entities)
	_update_zone_sprites()
	shake = maxf(0.0, shake - delta * 2.5)
	world.position = stage_off + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 10.0 * shake * shake
	_timed("hud", _update_hud)
	if not no_redraw:
		_redraw_if_changed()
	perf.game = (Time.get_ticks_usec() - t_frame) / 1000.0
	_gfx_tick(delta)
	_perf_tick(delta)


func step_entities(delta: float) -> void:
	delta *= creature_mult()
	if freeze_t > 0.0:
		# frozen bouncers still snap trails they sit on
		for b in bouncers:
			if _threatens(b) and _touches_trail(b.pos, b.r):
				break_trail(b.pos)
				return
		return
	for b in bouncers.duplicate():
		if not bouncers.has(b):
			continue
		match b.kind:
			"wisp":
				_move_free(b, delta, false)
			"carver":
				_move_carver(b, delta)
			_:
				_move_confined(b, delta)
		if _threatens(b) and _touches_trail(b.pos, b.r):
			break_trail(b.pos)
			return


func _move_confined(b: Dictionary, delta: float) -> void:
	var p: Vector2 = b.pos
	var v: Vector2 = b.vel
	var side: int = b.side
	if type_at(p) != side:
		p = _unstick(p, side)
	if b.kind in ["stalker", "boss"] and growing and side != stroke_origin:
		var fa := _point_at(grow_a)
		var fb := _point_at(grow_b)
		var head := fa if fa.distance_squared_to(p) < fb.distance_squared_to(p) else fb
		var want: Vector2 = (head - p).normalized() * b.speed * 1.15
		v = v.lerp(want, clampf(delta * 1.2, 0.0, 1.0))
		if v.length() > 1.0:
			v = v.normalized() * b.speed * 1.15
	elif v.length() > b.speed * 1.01:
		v = v.normalized() * maxf(b.speed, v.length() - 200.0 * delta)
	var r: float = b.r
	var nx := p + Vector2(v.x * delta, 0)
	if _blocked(side, nx + Vector2(signf(v.x) * r, 0)):
		v.x = -v.x
	else:
		p = nx
	var ny := p + Vector2(0, v.y * delta)
	if _blocked(side, ny + Vector2(0, signf(v.y) * r)):
		v.y = -v.y
	else:
		p = ny
	b.pos = p
	b.vel = v


func _blocked(side: int, probe: Vector2) -> bool:
	return not in_field(probe) or type_at(probe) != side


func _blocked_free(probe: Vector2) -> bool:
	return not in_field(probe) or type_at(probe) == STONE


func _move_free(b: Dictionary, delta: float, carve: bool) -> void:
	var p: Vector2 = b.pos
	var v: Vector2 = b.vel
	var r: float = b.r
	# gentle drifting wander
	v = v.rotated(sin(clock * 0.9 + b.phase) * 0.9 * delta)
	var nx := p + Vector2(v.x * delta, 0)
	if _blocked_free(nx + Vector2(signf(v.x) * r, 0)):
		v.x = -v.x
	else:
		p = nx
	var ny := p + Vector2(0, v.y * delta)
	if _blocked_free(ny + Vector2(0, signf(v.y) * r)):
		v.y = -v.y
	else:
		p = ny
	if type_at(p) == STONE:
		p = _unstick_free(p)
	b.pos = p
	b.vel = v


func _move_carver(b: Dictionary, delta: float) -> void:
	_move_free(b, delta, true)
	var changed := paint_disc(b.pos, 2.8, b.side)
	if changed > 0:
		_check_deaths()
	var hist: PackedVector2Array = b.hist
	if hist.size() == 0 or hist[hist.size() - 1].distance_to(b.pos) > 2.0:
		hist.append(b.pos)
		if hist.size() > 160:
			hist = hist.slice(hist.size() - 160)
	b.hist = hist


func _unstick(p: Vector2, side: int) -> Vector2:
	for r in range(1, 40):
		for a in 16:
			var q := p + Vector2(cos(a * TAU / 16.0), sin(a * TAU / 16.0)) * r * CELL
			if in_field(q) and type_at(q) == side:
				return q
	return p


func _unstick_free(p: Vector2) -> Vector2:
	for r in range(1, 40):
		for a in 16:
			var q := p + Vector2(cos(a * TAU / 16.0), sin(a * TAU / 16.0)) * r * CELL
			if in_field(q) and type_at(q) != STONE:
				return q
	return p


func step_items(delta: float) -> void:
	for it in items.duplicate():
		if not it.alive:
			continue
		it.t += delta
		match it.kind:
			"bomb":
				if it.armed:
					it.fuse -= delta
					if it.fuse <= 0.0:
						_explode(it)
						if state != "play":
							return
			"nest", "den", "burrow", "lantern":
				var sp: Dictionary = SPAWNERS[it.kind]
				if freeze_t <= 0.0 and it.t >= float(sp.every):
					it.t = 0.0
					var n := 0
					for b in bouncers:
						if b.kind == sp.kind and (b.side == it.side or sp.kind == "wisp"):
							n += 1
					if n < spawn_cap(sp, int(it.side)) and type_at(it.pos) == it.side:
						if _spawn_bouncer(sp.kind, it.side, 1.0, it.pos):
							audio.play("spawn", -4.0, 0.1)
							var nd: Sprite2D = it.node
							var tw := create_tween()
							tw.tween_property(nd, "scale", Vector2.ONE * it.base_scale * 1.25, 0.08)
							tw.tween_property(nd, "scale", Vector2.ONE * it.base_scale, 0.2)
			"seed":
				if freeze_t <= 0.0 and it.t >= SEED_EVERY:
					it.t = 0.0
					it.r = minf(it.r + 2.2, SEED_MAX_R)
					if paint_disc(it.pos, it.r, it.side) > 0:
						audio.play("grow", -10.0, 0.1)
						_check_deaths()
	items = items.filter(func(x: Dictionary) -> bool: return x.alive or is_instance_valid(x.node))


func _animate_entities() -> void:
	var frozen := freeze_t > 0.0
	for b in bouncers:
		var n: Sprite2D = b.node
		if not is_instance_valid(n):
			continue
		n.position = FIELD_POS + b.pos
		var ph: float = b.phase + clock
		var sc: float = b.base_scale
		match b.kind:
			"basic", "stalker", "elite":
				if b.side == CUTE:
					var sq := sin(ph * 7.0) * 0.05
					n.scale = Vector2(sc + sq, sc - sq)
					n.rotation = sin(ph * 2.0) * 0.12
				else:
					var s2 := sc * 1.4 if b.kind == "basic" else sc
					n.scale = Vector2(s2, s2 * (0.72 + 0.28 * absf(sin(ph * 14.0))))
					n.rotation = clampf(b.vel.x / BOUNCER_SPEED, -1, 1) * 0.25
			"boss":
				n.scale = Vector2(sc, sc * (0.85 + 0.15 * absf(sin(ph * 6.0))))
				n.rotation = clampf(b.vel.x / BOUNCER_SPEED, -1, 1) * 0.15
			"wisp":
				n.scale = Vector2(sc * (1.0 + 0.06 * sin(ph * 5.0)), sc * (1.0 + 0.08 * sin(ph * 5.0 + 1.0)))
				n.modulate.a = 0.75 + 0.25 * sin(ph * 2.0)
			"carver":
				n.rotation = b.vel.angle()
				n.flip_v = cos(n.rotation) < 0.0
				var hist: PackedVector2Array = b.hist
				var segs: Array = b.segs
				var need := 16.0
				var acc := 0.0
				var k := 0
				var j := hist.size() - 1
				while k < segs.size() and j > 0:
					acc += hist[j].distance_to(hist[j - 1])
					if acc >= need * (k + 1):
						segs[k].position = FIELD_POS + hist[j - 1]
						k += 1
					j -= 1
				while k < segs.size():
					segs[k].position = n.position
					k += 1
		n.modulate = Color(0.7, 0.85, 1.0, n.modulate.a) if frozen else Color(1, 1, 1, n.modulate.a)
	for it in items:
		if not it.alive:
			continue
		var n: Sprite2D = it.node
		var ph: float = it.phase + clock
		var sc: float = it.base_scale
		match it.kind:
			"bomb":
				if it.armed:
					var f := 1.0 + 0.25 * absf(sin(clock * 30.0))
					n.scale = Vector2.ONE * sc * f
					n.modulate = Color(1.6, 1.2, 1.0)
				else:
					n.scale = Vector2.ONE * sc * (1.0 + 0.04 * sin(ph * 3.0))
					n.rotation = sin(ph * 1.5) * 0.08
			"charm":
				n.position = FIELD_POS + it.pos + Vector2(0, sin(ph * 2.0) * 4.0)
				n.rotation = sin(ph * 1.2) * 0.15
			"seed":
				n.scale = Vector2.ONE * sc * (1.0 + 0.07 * sin(ph * 2.5))
			"nest", "den", "burrow":
				n.rotation = sin(ph * 1.7) * 0.05
			"lantern":
				n.position = FIELD_POS + it.pos + Vector2(0, sin(ph * 1.6) * 3.0)
				n.rotation = sin(ph * 1.1) * 0.12


func step_goal(delta: float) -> void:
	var why := impossible_reason()
	if why != "":
		lose_reason = why
		_end(false)
		return
	var s := scary_percent()
	if not objectives_done():
		hold = 0.0
		return
	if s >= goal_min - 0.0001 and s <= goal_max + 0.0001:
		hold += delta
		if hold >= HOLD_TIME:
			_end(true)
	else:
		hold = 0.0


func step_endless(delta: float) -> void:
	var center := (goal_min + goal_max) / 2.0
	center = move_toward(center, band_target, 6.0 * delta)
	goal_min = center - 8.0
	goal_max = center + 8.0
	if clock >= next_shift:
		next_shift += 12.0
		band_target = rng.randf_range(15.0, 85.0)
	if clock >= next_spawn:
		# No cap: creatures keep coming, faster and faster. Trap them to survive.
		spawn_n += 1
		next_spawn += maxf(ENDLESS_MIN_GAP, ENDLESS_FIRST_GAP - spawn_n * 0.6)
		_endless_spawn()
	if clock >= next_item:
		next_item += 18.0
		var at: Variant = _free_spot(0, 20.0, true)
		if at != null:
			_spawn_item(["bomb", "charm", "bomb", "seed"][rng.randi_range(0, 3)], rng.randi_range(0, 1), at)
	since_claim += delta
	var s := scary_percent()
	if s >= goal_min and s <= goal_max:
		score += 10.0 * delta * endless_rate()


# ================================================================ zones + objectives

## Removes the zones and their ring/icon sprites. Every reset goes through
## here, so sprites can't outlive their night.
func _clear_zones() -> void:
	for z in zones:
		for k in ["ring_node", "icon_node"]:
			if z.has(k) and is_instance_valid(z[k]):
				z[k].queue_free()
	zones.clear()
	_zone_sig = ""
	if zone_layer:
		zone_layer.queue_redraw()


func _build_zones(lv: Dictionary) -> void:
	_clear_zones()
	for spec in lv.get("zones", []):
		var c: Vector2 = spec.at * FIELD_SIZE
		var r: float = float(spec.r) * FIELD_SIZE.x
		var cells := PackedInt32Array()
		var rc := r / CELL
		var cx := int(c.x / CELL)
		var cy := int(c.y / CELL)
		for dy in range(-int(rc) - 1, int(rc) + 2):
			for dx in range(-int(rc) - 1, int(rc) + 2):
				var x := cx + dx
				var y := cy + dy
				if dx * dx + dy * dy <= rc * rc and x >= 0 and y >= 0 and x < GW and y < GH and mask[y * GW + x] != STONE:
					cells.append(y * GW + x)
		var z := {"kind": spec.kind, "side": int(spec.side), "effect": spec.get("effect", ""),
			"center": c, "r": r, "cells": cells, "frac": 0.0, "held": false}
		# animated parts are sprites (rotated/pulsed each frame); the rest is
		# drawn only when the zone's control changes
		var ring := Sprite2D.new()
		ring.texture = T.ui_zone_ring
		ring.position = FIELD_POS + c
		ring.scale = Vector2.ONE * (r / 100.0)
		ring.modulate = Color(1, 0.42, 0.74) if z.side == CUTE else Color(1, 0.42, 0.12)
		zone_layer.add_child(ring)
		var icon := Sprite2D.new()
		icon.texture = T.zi_hold if z.kind == "hold" else T[EFFECTS[z.effect].icon]
		icon.position = FIELD_POS + c
		zone_layer.add_child(icon)
		z["ring_node"] = ring
		z["icon_node"] = icon
		zones.append(z)
	_update_zones()


## frac = share of the zone's ground in the zone's color; held at 60%.
func _update_zones() -> void:
	zones_serial = mask_serial
	for z in zones:
		var n := 0
		for i in z.cells:
			if mask[i] == z.side:
				n += 1
		z.frac = float(n) / maxf(1.0, z.cells.size())
		z.held = z.frac >= ZONE_CONTROL


func _active_effects() -> Array:
	var out: Array = []
	for z in zones:
		if z.kind == "shrine" and z.held:
			out.append(z.effect)
	return out


func base_curl() -> String:
	return level.get("curl", "true")


## Curses (more restrictive than the level's curl) win over blessings.
func effective_curl() -> String:
	var base := base_curl()
	var bi := CURL_ORDER.find(base)
	var curse := 99
	var bless := -1
	for e in _active_effects():
		if EFFECTS[e].kind != "curl":
			continue
		var i := CURL_ORDER.find(EFFECTS[e].value)
		if i < bi:
			curse = mini(curse, i)
		elif i > bi:
			bless = maxi(bless, i)
	if curse != 99:
		return CURL_ORDER[curse]
	if bless != -1:
		return CURL_ORDER[bless]
	return base


func _mult(kind: String) -> float:
	var m := 1.0
	for e in _active_effects():
		if EFFECTS[e].kind == kind:
			m *= float(EFFECTS[e].value)
	return m


func wall_mult() -> float:
	return _mult("wall")


func creature_mult() -> float:
	return _mult("creature")


func targets_left() -> int:
	var n := 0
	for it in items:
		if it.alive and it.kind == "idol":
			n += 1
	for b in bouncers:
		if b.kind == "elite":
			n += 1
	return n


func holds_left() -> int:
	var n := 0
	for z in zones:
		if z.kind == "hold" and not z.held:
			n += 1
	return n


## Stars are independent: one for winning, one for keeping all 3 hearts,
## one for finishing within the night's target time (par).
static func star_count(lives_left: int, secs: float, par: float) -> int:
	return 1 + (1 if lives_left == 3 else 0) + (1 if secs <= par else 0)


func objectives_done() -> bool:
	return targets_left() == 0 and holds_left() == 0 and pens_left() == 0


func spawn_cap(sp: Dictionary, _side: int) -> int:
	return int(sp.cap)


func fuzzy_count() -> int:
	var n := 0
	for b in bouncers:
		if b.kind == "basic" and b.side == CUTE:
			n += 1
	return n


var lose_reason := ""


## A night that can no longer be won ends right away instead of stalling.
func impossible_reason() -> String:
	if mode != "level":
		return ""
	var need := int(level.get("pens", 0))
	if need > 0:
		var bats := 0
		for b in bouncers:
			if b.kind == "basic" and b.side == SCARY:
				bats += 1
		if bats < need and not _can_hatch("basic", SCARY):
			return "Not enough bats left to pen"
	return ""


func _can_hatch(kind: String, side: int) -> bool:
	for it in items:
		if it.alive and SPAWNERS.has(it.kind) and SPAWNERS[it.kind].kind == kind and int(it.side) == side:
			return true
	return false


var _pens_serial := -1
var _pens_bats := -1
var lone_bats: Array = []   # bats that are alone in their own pocket of Scary ground


## Bats (Scary basics) alone in their own connected pocket of Scary ground.
## Recomputed only when the ground or the number of bats changes.
func update_lone_bats() -> void:
	var bats: Array = []
	for b in bouncers:
		if b.kind == "basic" and b.side == SCARY:
			bats.append(b)
	if _pens_serial == mask_serial and _pens_bats == bats.size():
		return
	_pens_serial = mask_serial
	_pens_bats = bats.size()
	lone_bats.clear()
	var label := PackedInt32Array()
	label.resize(GW * GH)
	var next := 1
	var counts := {}
	var first := {}
	var stack := PackedInt32Array()
	for b in bats:
		var start := cell_index(b.pos)
		if start < 0 or mask[start] != SCARY:
			continue
		if label[start] == 0:
			label[start] = next
			stack.append(start)
			while not stack.is_empty():
				var i: int = stack[stack.size() - 1]
				stack.remove_at(stack.size() - 1)
				var x := i % GW
				if x > 0 and label[i - 1] == 0 and mask[i - 1] == SCARY:
					label[i - 1] = next
					stack.append(i - 1)
				if x < GW - 1 and label[i + 1] == 0 and mask[i + 1] == SCARY:
					label[i + 1] = next
					stack.append(i + 1)
				if i >= GW and label[i - GW] == 0 and mask[i - GW] == SCARY:
					label[i - GW] = next
					stack.append(i - GW)
				if i < GW * (GH - 1) and label[i + GW] == 0 and mask[i + GW] == SCARY:
					label[i + GW] = next
					stack.append(i + GW)
			next += 1
		var l := label[start]
		counts[l] = int(counts.get(l, 0)) + 1
		first[l] = b
	for l in counts:
		if counts[l] == 1:
			lone_bats.append(first[l])


func pens_left() -> int:
	if mode != "level" or int(level.get("pens", 0)) == 0:
		return 0
	update_lone_bats()
	return maxi(0, int(level.pens) - lone_bats.size())


func _draw_zones() -> void:
	for z in zones:
		var c: Vector2 = FIELD_POS + z.center
		var r: float = z.r
		var aligned := Color(1, 0.42, 0.74) if z.side == CUTE else Color(1, 0.42, 0.12)
		zone_layer.draw_circle(c, r, Color(aligned, 0.10))
		# control meter: arc fills with the zone's color, gold when held
		var arc_col := GOLD if z.held else aligned
		if z.frac > 0.005:
			zone_layer.draw_arc(c, r + 10.0, -PI / 2, -PI / 2 + TAU * z.frac, 40, INK, 9.0, true)
			zone_layer.draw_arc(c, r + 10.0, -PI / 2, -PI / 2 + TAU * z.frac, 40, arc_col, 5.0, true)
		var na := -PI / 2 + TAU * ZONE_CONTROL
		zone_layer.draw_line(c + Vector2.from_angle(na) * (r + 4), c + Vector2.from_angle(na) * (r + 16), INK, 4.0)
		_zone_badge(z, c, r)


var _zone_sig := ""
var _reticles: Array = []
var _lone_rings: Array = []


## Per frame: spin the zone rings, pulse held icons, move the target
## reticles and lone-bat rings, and redraw the static parts only on change.
func _update_zone_sprites() -> void:
	var sig := ""
	for z in zones:
		sig += "%d%s|" % [int(z.frac * 100.0), "h" if z.held else ""]
		if is_instance_valid(z.get("ring_node")):
			z.ring_node.rotation = clock * (0.25 if z.kind == "hold" else -0.25)
			var isz := 58.0 + (6.0 * sin(clock * 3.0) if z.held else 0.0)
			var it: Sprite2D = z.icon_node
			it.scale = Vector2.ONE * (isz / it.texture.get_width())
			it.modulate.a = 1.0 if z.held else 0.75
	if sig != _zone_sig:
		_zone_sig = sig
		zone_layer.queue_redraw()
	# reticles around must-destroy targets
	var targets: Array = []
	for it in items:
		if it.alive and it.kind == "idol":
			targets.append([FIELD_POS + it.pos, 40.0])
	for b in bouncers:
		if b.kind == "elite":
			targets.append([FIELD_POS + b.pos, 34.0])
	_place_pool(_reticles, T.ui_reticle, targets, true)
	var lone: Array = []
	if mode == "level" and int(level.get("pens", 0)) > 0 and state == "play":
		update_lone_bats()
		for b in lone_bats:
			lone.append([FIELD_POS + b.pos, 27.0])
	_place_pool(_lone_rings, T.ui_lone_ring, lone, false)


func _place_pool(pool: Array, tex: Texture2D, spots: Array, spin: bool) -> void:
	while pool.size() < spots.size():
		var sp := Sprite2D.new()
		sp.texture = tex
		zone_layer.add_child(sp)
		pool.append(sp)
	for k in pool.size():
		var sp: Sprite2D = pool[k]
		sp.visible = k < spots.size()
		if not sp.visible:
			continue
		sp.position = spots[k][0]
		if spin:
			var rr: float = float(spots[k][1]) + 4.0 * sin(clock * 5.0)
			sp.rotation = clock * 1.2
			sp.scale = Vector2.ONE * (rr / 40.0)


## Word label under (or over, near the bottom edge) each zone: which color
## it needs. Turns gold with a pulse once that color holds it.
func _zone_badge(z: Dictionary, c: Vector2, r: float) -> void:
	var cute: bool = z.side == CUTE
	var text := ("CUTE" if cute else "SCARY") if z.held else ("MAKE CUTE" if cute else "MAKE SCARY")
	if z.kind == "shrine":
		text = "CUTE" if cute else "SCARY"
	var fs := 22
	var w := font_ui_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26.0
	var h := 34.0
	var y := c.y + r + 18.0
	if y + h > FIELD_POS.y + FIELD_SIZE.y - 6.0:
		y = c.y - r - 18.0 - h
	var rect := Rect2(c.x - w / 2.0, y, w, h)
	var bgc := Color("ffd0e4") if cute else Color("3a0812")
	var fg := INK if cute else Color("ff8a4a")
	var edge := GOLD if z.held else (Color("ff6fae") if cute else Color("ff5a2e"))
	_rrect(zone_layer, rect.grow(3.0), h / 2.0 + 3.0, INK)
	_rrect(zone_layer, rect, h / 2.0, bgc)
	_rrect(zone_layer, rect, h / 2.0, edge, false, 3.0)
	zone_layer.draw_string(font_ui_bold, Vector2(rect.position.x, rect.position.y + h / 2.0 + fs * 0.36),
		text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, fg)


## Endless anti-idle: points only flow while you're actively claiming.
## Full rate for ACTIVE_FULL s after each finished wall, fading to zero
## over ACTIVE_FADE s. Letting the drifting band pass over you scores nothing.
const ACTIVE_FULL := 6.0
const ACTIVE_FADE := 4.0


func activity_factor() -> float:
	return clampf(1.0 - (since_claim - ACTIVE_FULL) / ACTIVE_FADE, 0.0, 1.0)


## The band is still drifting toward its next spot.
func band_moving() -> bool:
	return absf((goal_min + goal_max) / 2.0 - band_target) > 0.05


## Scoring rate: full while the band has settled (sitting in a still band is
## fair play); while it drifts, only recent claims count, so it can't wash
## over an idle player and hand out points.
func endless_rate() -> float:
	return 1.0 if not band_moving() else activity_factor()


const ENDLESS_FIRST_GAP := 20.0
const ENDLESS_MIN_GAP := 8.0
const ENDLESS_MAX_WISPS := 2   # wisps can't be trapped, so they never pile up


func endless_creature_count() -> int:
	return bouncers.size()


func _endless_spawn() -> void:
	var side := spawn_n % 2
	var wisps := 0
	for b in bouncers:
		if b.kind == "wisp":
			wisps += 1
	var pool := ["basic", "basic", "basic", "stalker", "carver"]
	if wisps < ENDLESS_MAX_WISPS and spawn_n >= 4:
		pool.append("wisp")
	var kind: String = "basic" if spawn_n <= 2 else pool[rng.randi_range(0, pool.size() - 1)]
	var spd := 1.0 + clock / 600.0
	# if that side has no room left, the creature appears on the other side
	if not _spawn_bouncer(kind, side, spd):
		_spawn_bouncer(kind, 1 - side, spd)


func _update_hud() -> void:
	if not hud.visible:
		return
	lbl_title.text = "ENDLESS" if mode == "endless" else "NIGHT %s" % level.id
	lbl_status.text = _status_text()
	lbl_obj.text = _objective_text()
	for i in 3:
		hearts[i].texture = T.ui_heart if i < lives else T.ui_heart_empty
	if mode == "endless":
		var n := endless_creature_count()
		lbl_goal_head.text = "SCORE · %d CREATURE%s" % [n, "" if n == 1 else "S"]
		var f := endless_rate()
		lbl_idle.visible = f < 1.0
		lbl_idle.modulate.a = 0.6 + 0.4 * absf(sin(clock * 4.0))
		lbl_goal.modulate = Color(1, 1, 1, 0.45 + 0.55 * f)
		lbl_goal.text = "%d" % roundi(score)
	else:
		var s_ := scary_percent()
		var in_band := s_ >= goal_min and s_ <= goal_max
		lbl_idle.visible = in_band and not objectives_done()
		lbl_idle.text = "Destroy the targets first!" if targets_left() > 0 else "Hold the marked ground!"
		lbl_idle.modulate.a = 0.6 + 0.4 * absf(sin(clock * 4.0))
		lbl_goal.modulate = Color.WHITE
		var gt := goal_text(goal_min, goal_max)
		lbl_goal_head.text = gt[0]
		lbl_goal.text = gt[1]


func _status_text() -> String:
	var parts: Array = []
	var curl := effective_curl()
	if curl != "true" or base_curl() != "true":
		parts.append("Lines: %s" % CURL_NAMES[curl])
	var wm := wall_mult()
	if wm > 1.01:
		parts.append("Walls: fast")
	elif wm < 0.99:
		parts.append("Walls: slow")
	var cm := creature_mult()
	if cm > 1.01:
		parts.append("Creatures: fast")
	elif cm < 0.99:
		parts.append("Creatures: calm")
	return " · ".join(parts)


func _objective_text() -> String:
	var parts: Array = []
	for side in [CUTE, SCARY]:
		var n := 0
		var held := 0
		for z in zones:
			if z.kind == "hold" and z.side == side:
				n += 1
				held += 1 if z.held else 0
		if n > 0:
			parts.append("%s ring%s %d/%d" % ["Cute" if side == CUTE else "Scary", "s" if n > 1 else "", held, n])
	if int(level.get("pens", 0)) > 0:
		update_lone_bats()
		parts.append("Lone bats %d/%d" % [mini(lone_bats.size(), int(level.pens)), int(level.pens)])
	var total_t := int(level.get("_targets", 0))
	if total_t > 0:
		parts.append("Targets %d/%d" % [total_t - targets_left(), total_t])
	return " · ".join(parts)


func _on_tier_changed(nt: int, old: int) -> void:
	if state != "play":
		return
	audio.play("tier_up" if nt > old else "tier_down", -3.0)
	var p := _burst(Vector2(360, 236) - FIELD_POS, T.fx_ember if nt > old else T.fx_sparkle, 48, Color.WHITE, fx_back)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 150.0
	p.emission_ring_inner_radius = 130.0
	p.direction = Vector2.ZERO
	shake = maxf(shake, 0.35 if nt > old else 0.15)


func _burst(field_pt: Vector2, tex: Texture2D, amount: int, tint: Color, parent: Node2D = null) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = FIELD_POS + field_pt
	p.texture = tex
	p.amount = maxi(1, int(round(amount * particle_mult)))
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 260) if tex == T.fx_sparkle else Vector2(0, -160)
	p.damping_min = 80.0
	p.damping_max = 140.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.9
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var g := Gradient.new()
	g.set_color(0, tint)
	g.set_color(1, Color(tint, 0.0))
	p.color_ramp = g
	(parent if parent else fx_layer).add_child(p)
	p.emitting = true
	if is_inside_tree():
		get_tree().create_timer(1.4).timeout.connect(p.queue_free)
	return p
