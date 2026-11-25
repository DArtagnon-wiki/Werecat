extends Node2D
## Werecat: Cute vs. Scary.
##
## Claim rules:
##   - The only walls are the field's border.
##   - Put your finger down in one territory and draw (any shape) into the
##     other. A glowing trail follows your finger.
##   - The trail closes when your finger gets back to your own territory or
##     reaches the field's edge. Pockets of the invaded territory with no
##     bouncer inside flip to your color, and so does the trail itself.
##   - A bouncer that touches your trail while it's open snaps it: you lose
##     a life. Lifting your finger early just lets the trail fade, no penalty.
##
## Modes: "level" (hold the target band for 3 s) and "endless" (chase a
## drifting band for points).

const GW := 160
const GH := 186
const CELL := 4.0
const FIELD_POS := Vector2(40, 420)
const FIELD_SIZE := Vector2(640, 744)
const TRAIL_R := 2.2            # cells
const BOUNCER_R := 15.0         # px
const BOUNCER_SPEED := 170.0
const HOLD_TIME := 3.0
const WC_SCALE := 0.58

const CUTE := 0
const SCARY := 1

const ENDLESS_BAND := 16.0
const ENDLESS_SHIFT_EVERY := 12.0
const ENDLESS_SPAWN_EVERY := 30.0
const ENDLESS_MAX_BOUNCERS := 8

const LEVEL := {
	"name": "1-3",
	"goal_min": 70.0,
	"goal_max": 80.0,
	"cute_bouncers": 1,
	"scary_bouncers": 1,
}

const INK := Color("241226")
const PINK := Color("ffb3cb")
const GOLD := Color("ffd98a")

var mode := "level"
var state := "menu"
var mask := PackedByteArray()
var trail := PackedByteArray()
var trail_list := PackedInt32Array()
var scary_count := 0
var bouncers: Array = []
var lives := 3
var hold := 0.0
var goal_min := 0.0
var goal_max := 0.0
var band_target := 50.0
var score := 0.0
var best := 0.0
var clock := 0.0
var next_shift := 0.0
var next_spawn := 0.0
var spawn_type := CUTE
var shake := 0.0
var rng := RandomNumberGenerator.new()

# stroke state
var stroking := false
var stroke_active := false
var stroke_origin := CUTE
var last_origin_pt := Vector2.ZERO
var stroke_points := PackedVector2Array()

# nodes
var world: Node2D
var bg: ColorRect
var werecat: Werecat
var field: ColorRect
var field_mat: ShaderMaterial
var frame: Node2D
var trail_line: Line2D
var bouncer_layer: Node2D
var fx_layer: Node2D
var fx_back: Node2D
var tex_glow: Texture2D
var hud: CanvasLayer
var lbl_title: Label
var lbl_goal_head: Label
var lbl_goal: Label
var hearts: Array = []
var meter: Node2D
var menu: Control
var menu_layer: CanvasLayer
var overlay: Control
var lbl_over_title: Label
var lbl_over_sub: Label

var mask_img: Image
var mask_tex: ImageTexture
var prev_tex: ImageTexture
var flip_t := 1.0
var menu_t := 0.0

var tex_puff: Texture2D
var tex_bat: Texture2D
var tex_sparkle: Texture2D
var tex_ember: Texture2D
var tex_heart: Texture2D
var tex_heart_empty: Texture2D
var font_ui: FontVariation
var font_ui_bold: FontVariation
var font_title: FontVariation


func _ready() -> void:
	rng.randomize()
	tex_puff = load("res://assets/sprites/bouncer_puff.png")
	tex_bat = load("res://assets/sprites/bouncer_bat.png")
	tex_sparkle = load("res://assets/sprites/fx_sparkle.png")
	tex_ember = load("res://assets/sprites/fx_ember.png")
	tex_glow = load("res://assets/sprites/fx_glow.png")
	tex_heart = load("res://assets/sprites/ui_heart.png")
	tex_heart_empty = load("res://assets/sprites/ui_heart_empty.png")
	font_ui = _font("res://assets/fonts/Fredoka.ttf", 500)
	font_ui_bold = _font("res://assets/fonts/Fredoka.ttf", 650)
	font_title = _font("res://assets/fonts/GrenzeGotisch.ttf", 800)
	mask.resize(GW * GH)
	trail.resize(GW * GH)
	_build_scene()
	reset_grid()
	_show_menu()


func _font(path: String, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv


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
	mask_img = Image.create(GW, GH, false, Image.FORMAT_L8)
	mask_tex = ImageTexture.create_from_image(mask_img)
	prev_tex = ImageTexture.create_from_image(mask_img)
	field_mat.set_shader_parameter("mask_tex", mask_tex)
	field_mat.set_shader_parameter("prev_mask_tex", prev_tex)

	frame = Node2D.new()
	frame.draw.connect(_draw_frame)
	world.add_child(frame)

	trail_line = _make_trail_line()
	world.add_child(trail_line)

	bouncer_layer = Node2D.new()
	world.add_child(bouncer_layer)

	world.add_child(werecat.front)
	werecat.front.position = wc_pos
	werecat.front.scale = werecat.scale

	fx_layer = Node2D.new()
	world.add_child(fx_layer)

	_build_hud()
	_build_menu()
	_build_overlay()


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


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	lbl_title = _label(font_ui_bold, 30, Color.WHITE)
	lbl_title.position = Vector2(30, 26)
	hud.add_child(lbl_title)
	for i in 3:
		var h := TextureRect.new()
		h.texture = tex_heart
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.size = Vector2(40, 40)
		h.position = Vector2(26 + i * 42, 70)
		hud.add_child(h)
		hearts.append(h)
	lbl_goal_head = _label(font_ui_bold, 20, Color(1, 1, 1, 0.8))
	lbl_goal_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_goal_head.size = Vector2(240, 30)
	lbl_goal_head.position = Vector2(450, 30)
	hud.add_child(lbl_goal_head)
	lbl_goal = _label(font_title, 46, GOLD)
	lbl_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_goal.size = Vector2(300, 60)
	lbl_goal.position = Vector2(390, 52)
	hud.add_child(lbl_goal)
	meter = Node2D.new()
	meter.draw.connect(_draw_meter)
	hud.add_child(meter)


func _label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


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
	meter.draw_rect(Rect2(g0, r.position.y - 9, g1 - g0, r.size.y + 18), Color(gc, 0.18 * pulse))
	meter.draw_rect(Rect2(g0, r.position.y - 9, g1 - g0, r.size.y + 18), Color(gc, pulse), false, 3.0)
	var nx := split
	meter.draw_colored_polygon(PackedVector2Array([Vector2(nx - 10, r.position.y - 18), Vector2(nx + 10, r.position.y - 18), Vector2(nx, r.position.y - 4)]), INK)
	meter.draw_colored_polygon(PackedVector2Array([Vector2(nx - 6, r.position.y - 16), Vector2(nx + 6, r.position.y - 16), Vector2(nx, r.position.y - 7)]), Color.WHITE)
	meter.draw_line(Vector2(nx, r.position.y), Vector2(nx, r.end.y), Color(1, 1, 1, 0.9), 2.0)
	meter.draw_texture_rect(tex_puff, Rect2(r.position.x - 52, r.position.y - 22, 74, 74), false)
	meter.draw_texture_rect(tex_bat, Rect2(r.end.x - 22, r.position.y - 24, 78, 78), false)
	var txt := "%d%% SCARY" % roundi(s)
	meter.draw_string_outline(font_ui_bold, Vector2(r.position.x, r.end.y - 8), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, 7, INK)
	meter.draw_string(font_ui_bold, Vector2(r.position.x, r.end.y - 8), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color.WHITE)


func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	if r.size.x <= 0.5:
		return
	meter.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.03, 0.08, 0.86)
	sb.border_color = Color(PINK, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(30)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	return sb


func _button(text: String, cb: Callable, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 92)
	b.size = Vector2(400, 92)
	b.add_theme_font_override("font", font_ui_bold)
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 8)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		var base := Color("c23a6a") if primary else Color("3a1640")
		if st == "pressed":
			base = base.darkened(0.25)
		elif st == "hover":
			base = base.lightened(0.08)
		sb.bg_color = base
		sb.border_color = INK
		sb.set_border_width_all(5)
		sb.border_width_bottom = 11 if st != "pressed" else 6
		sb.set_corner_radius_all(46)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 6)
		if st == "focus":
			sb.draw_center = false
			sb.border_color = Color(1, 1, 1, 0.0)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b


func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	menu = Control.new()
	menu.size = Vector2(720, 1280)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(menu)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = FIELD_POS + Vector2(20, 40)
	panel.size = FIELD_SIZE - Vector2(40, 80)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(panel)
	var title := _label(font_title, 132, Color("ffe3ee"))
	title.text = "Werecat"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(720, 160)
	title.position = Vector2(0, 510)
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_constant_override("shadow_offset_y", 8)
	menu.add_child(title)
	var tag := _label(font_ui, 28, Color(1, 0.85, 0.9))
	tag.text = "Cute or scary? You decide."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(720, 40)
	tag.position = Vector2(0, 676)
	menu.add_child(tag)
	var b1 := _button("Play Level %s" % LEVEL.name, start_level)
	b1.position = Vector2(160, 790)
	menu.add_child(b1)
	var b2 := _button("Endless", start_endless, false)
	b2.position = Vector2(160, 910)
	menu.add_child(b2)
	var how := _label(font_ui, 23, Color(1, 1, 1, 0.8))
	how.text = "Draw from your side into the other side.\nClose the loop to claim it. Keep bats off your line!"
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD
	how.size = Vector2(560, 90)
	how.position = Vector2(80, 1040)
	how.add_theme_constant_override("outline_size", 6)
	menu.add_child(how)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Control.new()
	overlay.size = Vector2(720, 1280)
	overlay.visible = false
	layer.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(720, 1280)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(70, 600)
	panel.size = Vector2(580, 420)
	overlay.add_child(panel)
	lbl_over_title = _label(font_title, 64, Color("ffe3ee"))
	lbl_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_over_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_over_title.size = Vector2(540, 170)
	lbl_over_title.position = Vector2(90, 630)
	overlay.add_child(lbl_over_title)
	lbl_over_sub = _label(font_ui_bold, 30, GOLD)
	lbl_over_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_over_sub.size = Vector2(540, 50)
	lbl_over_sub.position = Vector2(90, 806)
	overlay.add_child(lbl_over_sub)
	var b := _button("Continue", _show_menu)
	b.position = Vector2(160, 890)
	overlay.add_child(b)


# ================================================================ game flow

func _show_menu() -> void:
	state = "menu"
	menu.visible = true
	overlay.visible = false
	hud.visible = false
	_clear_stroke()
	reset_grid()


func reset_grid() -> void:
	scary_count = 0
	for y in GH:
		for x in GW:
			var boundary := GH * 0.5 + 7.0 * sin(x * 0.07) + 3.5 * sin(x * 0.19 + 1.0)
			var v := SCARY if y >= boundary else CUTE
			mask[y * GW + x] = v
			scary_count += v
	trail.fill(0)
	trail_list.clear()
	for b in bouncers:
		b.node.queue_free()
	bouncers.clear()
	lives = 3
	hold = 0.0
	clock = 0.0
	score = 0.0
	_upload_mask(false)


func start_level() -> void:
	mode = "level"
	reset_grid()
	goal_min = LEVEL.goal_min
	goal_max = LEVEL.goal_max
	for i in LEVEL.cute_bouncers:
		spawn_bouncer(CUTE)
	for i in LEVEL.scary_bouncers:
		spawn_bouncer(SCARY)
	_enter_play()


func start_endless() -> void:
	mode = "endless"
	reset_grid()
	band_target = 50.0
	goal_min = band_target - ENDLESS_BAND / 2.0
	goal_max = band_target + ENDLESS_BAND / 2.0
	next_shift = ENDLESS_SHIFT_EVERY
	next_spawn = ENDLESS_SPAWN_EVERY
	spawn_type = CUTE
	spawn_bouncer(CUTE)
	spawn_bouncer(SCARY)
	_enter_play()


func _enter_play() -> void:
	state = "play"
	menu.visible = false
	overlay.visible = false
	hud.visible = true
	werecat.set_target(scary_percent() / 100.0)


func _end(won: bool) -> void:
	state = "won" if won else "lost"
	_clear_stroke()
	if mode == "endless":
		best = maxf(best, score)
		lbl_over_title.text = "The night ends"
		lbl_over_sub.text = "Score %d   ·   Best %d" % [roundi(score), roundi(best)]
	elif won:
		lbl_over_title.text = "The Werecat is pleased"
		lbl_over_sub.text = "Level %s complete" % LEVEL.name
	else:
		lbl_over_title.text = "The Werecat is displeased"
		lbl_over_sub.text = "Out of lives. Try again?"
	overlay.visible = true


func spawn_bouncer(type: int) -> bool:
	var open := PackedInt32Array()
	for i in GW * GH:
		if mask[i] != type:
			continue
		var x := i % GW
		var y := i / GW
		if x > 6 and y > 6 and x < GW - 7 and y < GH - 7 and (x + y) % 3 == 0:
			if _area_is(type, Vector2((x + 0.5) * CELL, (y + 0.5) * CELL), BOUNCER_R + 6.0):
				open.append(i)
	if open.is_empty():
		return false
	var i: int = open[rng.randi_range(0, open.size() - 1)]
	var p := Vector2((i % GW + 0.5) * CELL, (i / GW + 0.5) * CELL)
	var ang := rng.randf_range(0.35, 1.22) + PI / 2.0 * rng.randi_range(0, 3)
	var v := Vector2(cos(ang), sin(ang)) * BOUNCER_SPEED
	var s := Sprite2D.new()
	s.texture = tex_puff if type == CUTE else tex_bat
	s.scale = Vector2.ONE * 0.6
	if type == SCARY:
		var glow := Sprite2D.new()
		glow.texture = tex_glow
		glow.scale = Vector2.ONE * 1.5
		glow.modulate = Color(1, 0.25, 0.1, 0.5)
		glow.show_behind_parent = true
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		s.add_child(glow)
	bouncer_layer.add_child(s)
	bouncers.append({"pos": p, "vel": v, "type": type, "node": s, "phase": rng.randf() * TAU})
	return true


# ================================================================ grid helpers

func in_field(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < FIELD_SIZE.x and p.y < FIELD_SIZE.y


func cell_index(p: Vector2) -> int:
	var x := clampi(int(p.x / CELL), 0, GW - 1)
	var y := clampi(int(p.y / CELL), 0, GH - 1)
	return y * GW + x


func type_at(p: Vector2) -> int:
	return mask[cell_index(p)]


func _area_is(type: int, p: Vector2, r: float) -> bool:
	for a in 8:
		var q := p + Vector2(cos(a * PI / 4), sin(a * PI / 4)) * r
		if not in_field(q) or type_at(q) != type:
			return false
	return true


func scary_percent() -> float:
	return 100.0 * scary_count / float(GW * GH)


func _upload_mask(animate: bool, origin := Vector2(0.5, 0.5)) -> void:
	if animate:
		prev_tex.update(mask_img)
	var bytes := _blurred_mask()
	mask_img = Image.create_from_data(GW, GH, false, Image.FORMAT_L8, bytes)
	mask_tex.update(mask_img)
	if animate:
		flip_t = 0.0
		field_mat.set_shader_parameter("flip_origin", origin)
	else:
		prev_tex.update(mask_img)
		flip_t = 1.0
	field_mat.set_shader_parameter("flip_progress", flip_t)


## Smooths the binary mask so the shader's threshold traces organic curves
## instead of the cell grid. Uses native image resampling (fast on web):
## a 2x bilinear downsample then a cubic upsample is a cheap soft blur.
func _blurred_mask() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(GW * GH)
	for i in GW * GH:
		bytes[i] = mask[i] * 255
	var img := Image.create_from_data(GW, GH, false, Image.FORMAT_L8, bytes)
	img.resize(GW / 2, GH / 2, Image.INTERPOLATE_BILINEAR)
	img.resize(GW, GH, Image.INTERPOLATE_CUBIC)
	return img.get_data()


# ================================================================ input + strokes

func _input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			begin_stroke(event.position - FIELD_POS)
		else:
			end_stroke()
	elif event is InputEventScreenDrag:
		move_stroke(event.position - FIELD_POS)


func begin_stroke(p: Vector2) -> void:
	if state != "play" or not in_field(p):
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
		if inside and type_at(p) != stroke_origin:
			stroke_active = true
			stroke_points = PackedVector2Array([last_origin_pt])
			trail_line.points = PackedVector2Array([last_origin_pt])
			_style_trail()
			_extend_trail(p)
		elif inside:
			last_origin_pt = p
		return
	var q := Vector2(clampf(p.x, 0.0, FIELD_SIZE.x - 0.01), clampf(p.y, 0.0, FIELD_SIZE.y - 0.01))
	if q.distance_to(stroke_points[stroke_points.size() - 1]) < 3.0 and inside and not near_edge:
		return
	_extend_trail(q)
	if not stroking:
		return
	if not inside or near_edge or type_at(q) == stroke_origin:
		close_stroke(q)


func end_stroke() -> void:
	if stroking and stroke_active:
		_fade_trail(false)
	_clear_stroke()


func _clear_stroke() -> void:
	stroking = false
	stroke_active = false
	stroke_points.clear()
	for i in trail_list:
		trail[i] = 0
	trail_list.clear()
	if trail_line:
		trail_line.clear_points()


func _extend_trail(p: Vector2) -> void:
	var a := stroke_points[stroke_points.size() - 1]
	stroke_points.append(p)
	trail_line.add_point(p)
	var steps := maxi(1, int(a.distance_to(p) / (CELL * 0.5)))
	for k in steps + 1:
		_stamp(a.lerp(p, float(k) / steps))


func _stamp(p: Vector2) -> void:
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
			if trail[i] == 0:
				trail[i] = 1
				trail_list.append(i)


func _style_trail() -> void:
	var mat: ShaderMaterial = trail_line.material
	if stroke_origin == CUTE:
		mat.set_shader_parameter("core_color", Color("fff4fa"))
		mat.set_shader_parameter("glow_color", Color("ff7ac0"))
	else:
		mat.set_shader_parameter("core_color", Color("2a0610"))
		mat.set_shader_parameter("glow_color", Color("ff5a2e"))
	mat.set_shader_parameter("danger", 0.0)


func _fade_trail(broken: bool) -> void:
	if trail_line.get_point_count() < 2:
		return
	var l := _make_trail_line()
	l.points = trail_line.points
	var src: ShaderMaterial = trail_line.material
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


func break_trail() -> void:
	var at := stroke_points[stroke_points.size() - 1] if stroke_points.size() > 0 else FIELD_SIZE / 2.0
	_fade_trail(true)
	_clear_stroke()
	lives -= 1
	shake = 1.0
	_burst(at, tex_ember, 22, Color(1, 0.35, 0.15))
	if lives <= 0:
		_end(false)


func close_stroke(end_pt: Vector2) -> void:
	var invaded := 1 - stroke_origin
	for b in bouncers:
		if b.type == invaded and _touches_trail(b.pos):
			break_trail()
			return
	for i in trail_list:
		if mask[i] != stroke_origin:
			mask[i] = stroke_origin
			scary_count += 1 if stroke_origin == SCARY else -1
	_flip_empty_pockets(stroke_origin)
	_upload_mask(true, end_pt / FIELD_SIZE)
	_fade_trail(false)
	_burst(end_pt, tex_sparkle if stroke_origin == CUTE else tex_ember, 28, Color.WHITE)
	if stroke_origin == SCARY:
		werecat.strike()
		shake = maxf(shake, 0.4)
	werecat.set_target(scary_percent() / 100.0)
	_clear_stroke()


## Splits the invaded territory into pockets. Pockets with no bouncer of
## that territory inside flip to `color`. Returns cells flipped.
func _flip_empty_pockets(color: int) -> int:
	var invaded := 1 - color
	var seen := PackedByteArray()
	seen.resize(GW * GH)
	var occupied := {}
	for b in bouncers:
		if b.type == invaded:
			occupied[cell_index(b.pos)] = true
	var flipped := 0
	for start in GW * GH:
		if seen[start] == 1 or mask[start] != invaded:
			continue
		var pocket := PackedInt32Array()
		var has_bouncer := false
		var stack := PackedInt32Array([start])
		seen[start] = 1
		while stack.size() > 0:
			var i: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			pocket.append(i)
			if occupied.has(i):
				has_bouncer = true
			var x := i % GW
			if x > 0 and seen[i - 1] == 0 and mask[i - 1] == invaded:
				seen[i - 1] = 1
				stack.append(i - 1)
			if x < GW - 1 and seen[i + 1] == 0 and mask[i + 1] == invaded:
				seen[i + 1] = 1
				stack.append(i + 1)
			if i >= GW and seen[i - GW] == 0 and mask[i - GW] == invaded:
				seen[i - GW] = 1
				stack.append(i - GW)
			if i < GW * (GH - 1) and seen[i + GW] == 0 and mask[i + GW] == invaded:
				seen[i + GW] = 1
				stack.append(i + GW)
		if not has_bouncer:
			for i in pocket:
				mask[i] = color
			flipped += pocket.size()
			scary_count += pocket.size() if color == SCARY else -pocket.size()
	return flipped


func _touches_trail(p: Vector2) -> bool:
	var r := int(ceil(BOUNCER_R / CELL))
	var cx := int(p.x / CELL)
	var cy := int(p.y / CELL)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= GW or y >= GH:
				continue
			if trail[y * GW + x] == 1 and Vector2(dx, dy).length() * CELL <= BOUNCER_R + CELL:
				return true
	return false


# ================================================================ simulation

func _process(delta: float) -> void:
	clock += delta
	if flip_t < 1.0:
		flip_t = minf(1.0, flip_t + delta * 1.8)
		field_mat.set_shader_parameter("flip_progress", flip_t)
	var m := werecat.morph
	var bm: ShaderMaterial = bg.material
	bm.set_shader_parameter("morph", m)
	field_mat.set_shader_parameter("morph", m)
	if state == "menu":
		menu_t += delta
		var cyc := fmod(menu_t, 9.0)
		werecat.set_target(0.0 if cyc < 3.5 else 1.0 if cyc < 7.5 else 0.0)
	elif state == "play":
		step_bouncers(delta)
		if state == "play":
			if mode == "endless":
				step_endless(delta)
			else:
				step_goal(delta)
	bm.set_shader_parameter("hold", hold / HOLD_TIME if mode == "level" and state == "play" else 0.0)
	_animate_bouncers()
	shake = maxf(0.0, shake - delta * 2.5)
	world.position = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 10.0 * shake * shake
	_update_hud()
	frame.queue_redraw()
	meter.queue_redraw()


func step_bouncers(delta: float) -> void:
	for b in bouncers:
		var p: Vector2 = b.pos
		var v: Vector2 = b.vel
		var t: int = b.type
		if type_at(p) != t:
			p = _unstick(p, t)
		var nx := p + Vector2(v.x * delta, 0)
		if _blocked(t, nx + Vector2(signf(v.x) * BOUNCER_R, 0)):
			v.x = -v.x
		else:
			p = nx
		var ny := p + Vector2(0, v.y * delta)
		if _blocked(t, ny + Vector2(0, signf(v.y) * BOUNCER_R)):
			v.y = -v.y
		else:
			p = ny
		b.pos = p
		b.vel = v
		if stroke_active and t != stroke_origin and _touches_trail(p):
			break_trail()
			return


func _blocked(type: int, probe: Vector2) -> bool:
	return not in_field(probe) or type_at(probe) != type


func _unstick(p: Vector2, type: int) -> Vector2:
	for r in range(1, 40):
		for a in 16:
			var q := p + Vector2(cos(a * TAU / 16.0), sin(a * TAU / 16.0)) * r * CELL
			if in_field(q) and type_at(q) == type:
				return q
	return p


func _animate_bouncers() -> void:
	for b in bouncers:
		var n: Sprite2D = b.node
		n.position = FIELD_POS + b.pos
		var ph: float = b.phase + clock
		if b.type == CUTE:
			var sq := sin(ph * 7.0) * 0.05
			n.scale = Vector2(0.6 + sq, 0.6 - sq)
			n.rotation = sin(ph * 2.0) * 0.12
		else:
			n.scale = Vector2(0.85, 0.85 * (0.72 + 0.28 * absf(sin(ph * 14.0))))
			n.rotation = clampf(b.vel.x / BOUNCER_SPEED, -1, 1) * 0.25


func step_goal(delta: float) -> void:
	var s := scary_percent()
	if s >= goal_min and s <= goal_max:
		hold += delta
		if hold >= HOLD_TIME:
			_end(true)
	else:
		hold = 0.0


func step_endless(delta: float) -> void:
	var center := (goal_min + goal_max) / 2.0
	center = move_toward(center, band_target, 6.0 * delta)
	goal_min = center - ENDLESS_BAND / 2.0
	goal_max = center + ENDLESS_BAND / 2.0
	if clock >= next_shift:
		next_shift += ENDLESS_SHIFT_EVERY
		band_target = rng.randf_range(15.0, 85.0)
	if clock >= next_spawn:
		next_spawn += ENDLESS_SPAWN_EVERY
		if bouncers.size() < ENDLESS_MAX_BOUNCERS:
			spawn_bouncer(spawn_type)
			spawn_type = 1 - spawn_type
	var s := scary_percent()
	if s >= goal_min and s <= goal_max:
		score += 10.0 * delta


func _update_hud() -> void:
	if not hud.visible:
		return
	lbl_title.text = "ENDLESS" if mode == "endless" else "LEVEL %s" % LEVEL.name
	for i in 3:
		hearts[i].texture = tex_heart if i < lives else tex_heart_empty
	if mode == "endless":
		lbl_goal_head.text = "SCORE"
		lbl_goal.text = "%d" % roundi(score)
	else:
		lbl_goal_head.text = "MAKE IT SCARY"
		lbl_goal.text = "%d–%d%%" % [roundi(goal_min), roundi(goal_max)]


func _on_tier_changed(nt: int, old: int) -> void:
	if state != "play":
		return
	# a ring of embers/sparkles bursting out from behind the werecat
	var p := _burst(Vector2(360, 236) - FIELD_POS, tex_ember if nt > old else tex_sparkle, 48, Color.WHITE, fx_back)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 150.0
	p.emission_ring_inner_radius = 130.0
	p.direction = Vector2.ZERO
	shake = maxf(shake, 0.35 if nt > old else 0.15)


func _burst(field_pt: Vector2, tex: Texture2D, amount: int, tint: Color, parent: Node2D = null) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = FIELD_POS + field_pt
	p.texture = tex
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 260) if tex == tex_sparkle else Vector2(0, -160)
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
