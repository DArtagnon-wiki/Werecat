extends SceneTree
## Headless tests, run in CI:
##   godot --headless --path . -s res://tests/smoke_test.gd
## Field is 640x744 px. Test levels use split_h 0.5: Cute top, Scary bottom,
## wavy border near y = 372.

var failures := 0
var g
var started := false


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		printerr("FAIL  ", msg)
		failures += 1


func setup(extra := {}) -> void:
	var lv := {"id": "T", "name": "Test", "layout": ["split_h", 0.5], "goal": [95, 100], "par": 60,
		"bouncers": [], "items": [], "tip": ""}
	lv.merge(extra, true)
	g.level = lv
	g.begin_play()


func add_b(kind: String, side: int, pos: Vector2, vel := Vector2.ZERO) -> Dictionary:
	g._spawn_bouncer(kind, side, 1.0, pos)
	var b: Dictionary = g.bouncers[g.bouncers.size() - 1]
	b.vel = vel
	return b


func draw(points: Array, lift := false) -> void:
	g.begin_stroke(points[0])
	draw_more(points)
	if lift:
		g.end_stroke()


func draw_more(points: Array) -> void:
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var n := maxi(1, int(a.distance_to(b) / 6.0))
		for k in range(1, n + 1):
			g.move_stroke(a.lerp(b, float(k) / n))


func grow_out() -> void:
	## let a closed path's wall finish growing (bouncers keep moving)
	var dt := 1.0 / 60.0
	for i in 600:
		if not g.growing:
			return
		g.clock += dt
		g.step_growth(dt)
		g.step_entities(dt)


func sim(seconds: float, items := true) -> void:
	var dt := 1.0 / 60.0
	for i in int(seconds * 60):
		g.clock += dt
		g.freeze_t = maxf(0.0, g.freeze_t - dt)
		g._update_zones()
		g.step_growth(dt)
		g.step_entities(dt)
		if items:
			g.step_items(dt)


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	run()
	return false


func run() -> void:
	# ---------------------------------------------------------------- claims
	setup()
	check(absf(g.scary_percent() - 50.0) < 3.0, "test layout starts about 50/50 (%.1f%%)" % g.scary_percent())

	setup()
	add_b("basic", g.SCARY, Vector2(500, 600))
	var before: float = g.scary_percent()
	draw([Vector2(100, 200), Vector2(100, 760)])
	check(g.growing and absf(g.scary_percent() - before) < 0.01, "closing a path starts growth (nothing claimed yet)")
	grow_out()
	check(g.scary_percent() < before - 5.0 and g.lives == 3, "when the ends meet, the bat-free side is claimed")

	setup()
	before = g.scary_percent()
	draw([Vector2(300, 200), Vector2(300, 520)])
	check(g.stroke_active, "trail is open while drawing in the other territory")
	g.end_stroke()
	check(absf(g.scary_percent() - before) < 0.01 and g.lives == 3, "lifting early: no change, no penalty")

	setup()
	add_b("basic", g.SCARY, Vector2(300, 600))
	draw([Vector2(300, 200), Vector2(300, 640)])
	g.step_entities(1.0 / 60.0)
	check(g.lives == 3, "drawing a blueprint through a bat is safe")
	g.end_stroke()
	draw([Vector2(300, 200), Vector2(300, 760)])
	grow_out()
	check(g.lives == 2 and not g.growing, "a bat touching the growing wall snaps it")
	setup()
	add_b("basic", g.SCARY, Vector2(300, 600))
	g.begin_stroke(Vector2(100, 200))
	draw_more([Vector2(100, 200), Vector2(100, 760)])
	g.begin_stroke(Vector2(400, 200))
	check(not g.stroking, "you can't start a new path while a wall is growing")

	setup()
	add_b("basic", g.CUTE, Vector2(80, 80))
	before = g.scary_percent()
	draw([Vector2(320, 600), Vector2(320, 150), Vector2(440, 150), Vector2(440, 600)])
	grow_out()
	check(g.scary_percent() > before + 3.0, "closing a loop claims the enclosed pocket")

	# Only pockets touching the new wall change. On a checkerboard with no
	# bouncers, a small claim must not flip faraway empty squares.
	setup({"layout": ["checker", 3, 4]})
	var far_before: int = g.type_at(Vector2(600, 700))
	var far2_before: int = g.type_at(Vector2(40, 700))
	var start_type: int = g.type_at(Vector2(100, 90))
	# a scoop from the top-left square into its neighbour and back
	draw([Vector2(100, 90), Vector2(260, 90), Vector2(260, 150), Vector2(100, 150)])
	grow_out()
	check(g.type_at(Vector2(600, 700)) == far_before and g.type_at(Vector2(40, 700)) == far2_before,
		"empty pockets that don't touch the new wall are left alone")
	check(g.type_at(Vector2(240, 120)) == start_type, "the pocket the wall cut off does flip")

	# A color can never be wiped out: with no puffs, a line that splits the
	# Cute side would flip both halves; the bigger half survives instead.
	setup()
	draw([Vector2(200, 600), Vector2(200, -10)])
	grow_out()
	check(g.scary_percent() < 99.0 and g.scary_percent() > 55.0, "the last ground of a color survives as a foothold (%.1f%% Scary)" % g.scary_percent())

	# ---------------------------------------------------------------- trapping
	setup()
	var trapped := add_b("basic", g.CUTE, Vector2(40, 325))
	add_b("basic", g.CUTE, Vector2(450, 120))
	draw([Vector2(92, 500), Vector2(92, 282), Vector2(-10, 282)])
	grow_out()
	check(not g.bouncers.has(trapped) and g.bouncers.size() == 1, "a bouncer squeezed into a tiny pocket is trapped")
	check(g.type_at(Vector2(40, 325)) == g.SCARY, "the trapped pocket flips")

	# ---------------------------------------------------------------- bombs
	setup({"items": [{"kind": "bomb", "side": 0, "at": Vector2(300, 150) / g.FIELD_SIZE}]})
	add_b("basic", g.CUTE, Vector2(560, 60))
	before = g.scary_percent()
	draw([Vector2(300, 520), Vector2(300, -10)])
	grow_out()
	check(g.items[0].armed and g.items[0].color == g.SCARY, "a Scary wall growing through a bomb arms it Scary")
	sim(0.6)
	check(g.scary_percent() > before + 4.0, "bomb blast converts the area (%.1f%% -> %.1f%%)" % [before, g.scary_percent()])
	check(g.type_at(Vector2(300, 150)) == g.SCARY, "bomb's ground is now Scary")

	# ---------------------------------------------------------------- charms
	setup({"items": [{"kind": "charm", "side": 0, "at": Vector2(300, 500) / g.FIELD_SIZE}]})
	var bat := add_b("basic", g.SCARY, Vector2(500, 650), Vector2(150, 0))
	draw([Vector2(300, 200), Vector2(300, 760)])
	grow_out()
	check(g.freeze_t > 3.0, "a wall growing through a moon charm freezes bouncers")
	var p0: Vector2 = bat.pos
	g.step_entities(0.1)
	check(bat.pos == p0, "frozen bouncers don't move")

	# ---------------------------------------------------------------- nests
	setup({"items": [{"kind": "nest", "side": 1, "at": Vector2(320, 600) / g.FIELD_SIZE}]})
	var n0: int = g.bouncers.size()
	sim(7.0)
	check(g.bouncers.size() == n0 + 1, "a roost hatches a bat")
	g.paint_disc(Vector2(320, 600), 10, g.CUTE)
	g._check_deaths()
	check(not g.items[0].alive, "claiming a roost's ground destroys it")

	# ---------------------------------------------------------------- seeds
	setup({"items": [{"kind": "seed", "side": 1, "at": Vector2(320, 392) / g.FIELD_SIZE}]})
	before = g.scary_percent()
	sim(9.0)
	check(g.scary_percent() > before + 0.4, "thorn seeds spread their color (%.1f%% -> %.1f%%)" % [before, g.scary_percent()])
	g.paint_disc(Vector2(320, 392), 8, g.CUTE)
	g._check_deaths()
	check(not g.items[0].alive, "claiming a seed's ground pulls it out")

	# ---------------------------------------------------------------- stone
	setup({"stone": ["pillars", 5]})
	check(g.claimable < g.GW * g.GH, "moonstone isn't claimable")
	var sb := add_b("basic", g.SCARY, Vector2(320, 650), Vector2(150, 110))
	var ok := true
	for i in 600:
		g.step_entities(1.0 / 60.0)
		if g.type_at(sb.pos) == g.STONE:
			ok = false
	check(ok, "bouncers never enter stone")
	var stone_pt := Vector2(-1, -1)
	for y in range(100, 180):
		for x in range(10, 150):
			if g.mask[y * g.GW + x] == g.STONE and g.mask[(y - 8) * g.GW + x] == g.SCARY:
				stone_pt = Vector2(x * g.CELL + 2, y * g.CELL + 2)
				break
		if stone_pt.x >= 0:
			break
	if stone_pt.x >= 0:
		for b in g.bouncers.duplicate():
			g._capture(b)
		draw([Vector2(stone_pt.x, 200), stone_pt])
		check(g.growing, "a path can close on stone")
		grow_out()
		check(not g.growing and g.lives == 3, "and its wall completes")
	else:
		check(false, "found a stone cell for the stone test")

	# ---------------------------------------------------------------- carvers
	setup()
	var grub := add_b("carver", g.SCARY, Vector2(320, 150), Vector2(80, 60))
	before = g.scary_percent()
	sim(2.0, false)
	check(g.scary_percent() > before + 0.3, "a gloom grub tunnels Scary through Cute land")
	g.paint_disc(grub.pos, 6, g.CUTE)
	g._check_deaths()
	check(not g.bouncers.has(grub), "claiming the ground under a grub squashes it")

	# ---------------------------------------------------------------- wisps
	setup()
	var wisp := add_b("wisp", g.SCARY, Vector2(320, 300), Vector2(0, 100))
	sim(1.5, false)
	check(g.type_at(wisp.pos) == g.SCARY and wisp.pos.y > 372, "wisps drift across the border")
	wisp.pos = Vector2(600, 100)
	draw([Vector2(100, 100), Vector2(100, 760)])
	check(g.growing and g._threatens(wisp), "wisps threaten any growing wall")
	g._clear_stroke()

	# ---------------------------------------------------------------- stalkers
	setup()
	var hunter := add_b("stalker", g.SCARY, Vector2(560, 650), Vector2(170, 0))
	draw([Vector2(150, 200), Vector2(150, 760)])
	for i in 20:
		g.step_growth(1.0 / 60.0)
		g._move_confined(hunter, 1.0 / 60.0)
	var fa: Vector2 = g._point_at(g.grow_a)
	var fb: Vector2 = g._point_at(g.grow_b)
	var head: Vector2 = fa if fa.distance_to(hunter.pos) < fb.distance_to(hunter.pos) else fb
	check(hunter.vel.normalized().dot((head - hunter.pos).normalized()) > 0.5, "hunters steer toward a growing end")
	g._clear_stroke()

	# ---------------------------------------------------------------- line curl
	setup({"curl": "straight"})
	g.begin_stroke(Vector2(300, 200))
	var wig := []
	for k in 60:
		wig.append(Vector2(300 + 60 * sin(k * 0.4), 200 + k * 5))
	draw_more([Vector2(300, 200)] + wig)
	var pts: PackedVector2Array = g.stroke_points
	var a0: Vector2 = pts[0]
	var dirv: Vector2 = (pts[pts.size() - 1] - a0).normalized()
	var dev := 0.0
	for q in pts:
		dev = maxf(dev, absf((q - a0).cross(dirv)))
	check(pts.size() > 5 and dev < 4.0, "straight curl: a wiggly finger still makes a straight line (max deviation %.1f px)" % dev)
	g._clear_stroke()

	setup({"curl": "arc"})
	g.begin_stroke(Vector2(300, 300))
	draw_more([Vector2(300, 300), Vector2(300, 470), Vector2(560, 470)])   # hard 90° turn
	pts = g.stroke_points
	var max_turn := 0.0
	for k in range(2, pts.size()):
		var h0: float = (pts[k - 1] - pts[k - 2]).angle()
		var h1: float = (pts[k] - pts[k - 1]).angle()
		var seg: float = pts[k].distance_to(pts[k - 1])
		if seg > 2.0:
			max_turn = maxf(max_turn, absf(wrapf(h1 - h0, -PI, PI)) / seg)
	check(max_turn < deg_to_rad(0.35) * 1.6, "arc curl: the line can't turn sharper than the limit (%.2f deg/px)" % rad_to_deg(max_turn))
	g._clear_stroke()

	# limited-curl lines must not "bonk" (close instantly) when started near
	# the border with a natural thumb swoop
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3
	var bonks := 0
	for t in 60:
		setup({"curl": ["arc", "curly", "straight"][t % 3]})
		var sx := rng2.randf_range(80, 560)
		var st := Vector2(sx, 372 - rng2.randf_range(10, 50))
		var sd := 1.0 if rng2.randf() < 0.5 else -1.0
		var hh := rng2.randf_range(0.25, 1.3)
		var bend := rng2.randf_range(0.004, 0.012)
		g.begin_stroke(st)
		var pp := st
		for k in 120:
			hh = minf(hh + bend * 6.0, 1.45)
			pp += Vector2(cos(hh) * sd, sin(hh)) * 6.0
			g.move_stroke(pp)
			if not g.stroking:
				break
		var ln := 0.0
		var gp: PackedVector2Array = g.grow_pts if g.growing else g.stroke_points
		for k in range(1, gp.size()):
			ln += gp[k].distance_to(gp[k - 1])
		if g.growing and ln < 80.0:
			bonks += 1
		g._clear_stroke()
	check(bonks <= 3, "limited-curl lines started near the border rarely bonk (%d / 60)" % bonks)

	# ---------------------------------------------------------------- zones
	setup({"zones": [{"kind": "hold", "side": 1, "at": Vector2(0.5, 0.25), "r": 0.12}]})
	check(g.holds_left() == 1 and not g.objectives_done(), "an unheld hold-zone blocks the win")
	var s_now: float = g.scary_percent()
	g.goal_min = s_now - 50.0
	g.goal_max = s_now + 50.0
	for i in 200:
		g.step_goal(1.0 / 60.0)
	check(g.state == "play" and g.hold == 0.0, "being in the band isn't enough while objectives remain")
	g.paint_disc(Vector2(320, 186), 22, g.SCARY)
	g._update_zones()
	check(g.holds_left() == 0 and g.objectives_done(), "filling the zone with its color holds it")

	setup({"zones": [{"kind": "shrine", "side": 0, "at": Vector2(0.5, 0.75), "r": 0.12, "effect": "swift"},
		{"kind": "shrine", "side": 1, "at": Vector2(0.5, 0.25), "r": 0.12, "effect": "straight"},
		{"kind": "shrine", "side": 0, "at": Vector2(0.2, 0.75), "r": 0.1, "effect": "true"}]})
	check(is_equal_approx(g.wall_mult(), 1.0) and g.effective_curl() == "true", "unheld shrines do nothing")
	g.paint_disc(Vector2(320, 558), 22, g.CUTE)
	g.paint_disc(Vector2(320, 186), 22, g.SCARY)
	g.paint_disc(Vector2(128, 558), 18, g.CUTE)
	g._update_zones()
	check(is_equal_approx(g.wall_mult(), 1.7), "a held swift shrine speeds walls up")
	check(g.effective_curl() == "straight", "a curse shrine beats a blessing (curl straight)")

	# ---------------------------------------------------------------- targets
	setup({"items": [{"kind": "idol", "side": 1, "at": Vector2(0.5, 0.85)}]})
	check(g.targets_left() == 1 and not g.objectives_done(), "a living idol blocks the win")
	g.paint_disc(Vector2(320, 632), 12, g.CUTE)
	g._check_deaths()
	check(g.targets_left() == 0, "claiming an idol's ground destroys it")

	setup()
	var el := add_b("elite", g.CUTE, Vector2(40, 325))
	add_b("basic", g.CUTE, Vector2(450, 120))
	check(g.targets_left() == 1, "a crowned creature counts as a target")
	draw([Vector2(92, 500), Vector2(92, 282), Vector2(-10, 282)])
	grow_out()
	check(not g.bouncers.has(el) and g.targets_left() == 0, "trapping the crowned creature clears the target")

	# ---------------------------------------------------------------- generators + new win conditions
	for spec in [["den", g.SCARY, "stalker"], ["burrow", g.CUTE, "carver"], ["lantern", g.SCARY, "wisp"]]:
		setup({"items": [{"kind": spec[0], "side": spec[1], "at": Vector2(0.5, 0.2 if spec[1] == g.CUTE else 0.8)}]})
		sim(12.0)
		var hatched: int = g.bouncers.filter(func(b): return b.kind == spec[2]).size()
		check(hatched >= 1, "a %s hatches %ss (%d)" % [spec[0], spec[2], hatched])
	setup({"items": [{"kind": "den", "side": g.SCARY, "at": Vector2(0.5, 0.8)}]})
	g.paint_disc(Vector2(320, 595), 14, g.CUTE)
	g._check_deaths()
	check(not g.items[0].alive, "claiming a den's ground closes it")

	setup({"fuzzies": 3, "goal": [0, 100], "items": [{"kind": "nest", "side": g.CUTE, "at": Vector2(0.5, 0.2)}]})
	check(g.fuzzies_left() == 3 and not g.objectives_done(), "a fuzzies night needs its fuzzies")
	sim(22.0)
	check(g.fuzzy_count() >= 3 and g.fuzzies_left() == 0, "gift boxes hatch fuzzies past the goal (%d)" % g.fuzzy_count())

	setup({"fuzzies": 2, "goal": [0, 100]})
	g.step_goal(0.1)
	check(g.state == "lost" and g.lose_reason.begins_with("No fuzzies"), "a fuzzies night with no fuzzies and no gift box ends at once")

	setup({"pens": 2, "goal": [0, 100]})
	var b1 := add_b("basic", g.SCARY, Vector2(150, 600), Vector2.ZERO)
	var b2 := add_b("basic", g.SCARY, Vector2(490, 600), Vector2.ZERO)
	check(g.pens_left() == 2, "two bats sharing one pocket aren't lone")
	draw([Vector2(320, 300), Vector2(320, 740)])
	g.end_stroke()
	grow_out()
	check(g.bouncers.has(b1) and g.bouncers.has(b2) and g.pens_left() == 0, "a wall between them pens each bat alone")

	var mz: PackedByteArray = Levels.build({"layout": ["split_h", 0.5], "stone": ["maze", 4, 5, 7]}, g.GW, g.GH)[0]
	var mz2: PackedByteArray = Levels.build({"layout": ["split_h", 0.5], "stone": ["maze", 4, 5, 7]}, g.GW, g.GH)[0]
	var stones := 0
	for v in mz:
		stones += 1 if v == g.STONE else 0
	check(mz == mz2 and stones > 500, "mazes are deterministic and solid (%d stone cells)" % stones)

	# ---------------------------------------------------------------- all levels
	var lv_ok := true
	for i in g.levels.size():
		var lv: Dictionary = g.levels[i]
		g.open_intro(i)
		g.begin_play()
		var want := 0
		for spec in lv.bouncers:
			want += spec.count
		var s0: float = g.scary_percent()
		if g.bouncers.size() != want:
			printerr("  level %s: spawned %d of %d bouncers" % [lv.id, g.bouncers.size(), want])
			lv_ok = false
		if s0 >= lv.goal[0] and s0 <= lv.goal[1] and g.objectives_done():
			printerr("  level %s starts solved (%.1f%% in band, objectives done)" % [lv.id, s0])
			lv_ok = false
		var alive := 0
		for it in g.items:
			alive += 1 if it.alive else 0
		if alive != lv.items.size():
			printerr("  level %s: %d of %d items" % [lv.id, alive, lv.items.size()])
			lv_ok = false
		sim(6.0)
		for b in g.bouncers:
			if b.kind in ["basic", "stalker", "boss"] and g.type_at(b.pos) != b.side:
				g._move_confined(b, 1.0 / 60.0)
				if g.type_at(b.pos) != b.side:
					printerr("  level %s: %s stuck in wrong territory" % [lv.id, b.kind])
					lv_ok = false
		print("  level %s %-16s start %4.1f%%  goal %d-%d  bouncers %d" % [lv.id, lv.name, s0, lv.goal[0], lv.goal[1], want])
	check(lv_ok, "all %d levels load, spawn everything, don't start solved, and simulate cleanly" % g.levels.size())
	check(g.levels.size() == 100, "there are 100 levels")

	# ---------------------------------------------------------------- graphics tiers + perf paths
	setup()
	draw([Vector2(320, 100), Vector2(320, 560), Vector2(560, 560), Vector2(560, 100)])
	grow_out()
	var fresh := PackedByteArray(g.tex_bytes)
	g._rebuild_tex_bytes()
	check(fresh == g.tex_bytes, "incrementally kept mask bytes match a full rebuild after a claim")
	var tex_before = g.field_mat.get_shader_parameter("mask_tex")
	g._apply_gfx(2)
	check(g.field_mat.shader.resource_path.ends_with("territory_lite.gdshader"), "Lite swaps in the lite territory shader")
	check(g.field_mat.get_shader_parameter("mask_tex") == tex_before, "shader swap keeps the mask texture")
	check(g.field_mat.get_shader_parameter("noise_tex") != null and g.field_mat.get_shader_parameter("wide_tex") != null,
		"Lite gets its noise and wide-blur textures")
	var big := DisplayServer.window_get_size().x > 760
	check(g.get_tree().root.content_scale_mode == (Window.CONTENT_SCALE_MODE_VIEWPORT if big else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS),
		"Lite renders at design resolution on big screens, native on small ones")
	check(g.audio.single and g.particle_mult < 1.0, "Lite plays one music loop and fewer particles")
	var b0: float = g.scary_percent()
	draw([Vector2(80, 100), Vector2(80, 560), Vector2(200, 560), Vector2(200, 100)])
	grow_out()
	check(absf(g.scary_percent() - b0) > 3.0, "claims still work in Lite (%.1f%% -> %.1f%%)" % [b0, g.scary_percent()])
	g._apply_gfx(1)
	check(g.field_mat.shader.resource_path.ends_with("territory.gdshader") and not g.audio.single, "Medium uses the full shaders")
	g._apply_gfx(0)
	check(g.get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "High renders at native resolution")
	# auto: a slow stretch steps the tier down
	g.gfx_setting = "auto"
	g.gfx_forced = ""
	g.auto_settle = 0.0
	var saved_tier: int = g.gfx_auto_tier
	for i in 60:
		g._gfx_tick(0.1)       # 10 fps for 6 s
	check(g.gfx_tier == 2, "Auto drops a 10 fps device straight to Lite")
	g._apply_gfx(0)
	g.gfx_auto_tier = saved_tier
	g._save()

	# ---------------------------------------------------------------- save
	g.stars.fill(0)
	g.stars[0] = 3
	g.stars[1] = 1
	g._save()
	g.stars[0] = 0
	g.stars[1] = 0
	g._load_save()
	check(g.stars[0] == 3 and g.stars[1] == 1 and g.is_unlocked(2) and not g.is_unlocked(3), "progress saves, loads and unlocks levels")
	g.stars.fill(0)
	g._save()

	# ---------------------------------------------------------------- endless
	g.start_endless()
	check(g.mode == "endless" and g.bouncers.size() == 2, "endless mode starts with 2 bouncers")
	for b in g.bouncers.duplicate():
		g._capture(b)
	for i in 60 * 13:
		g.clock += 1.0 / 60.0
		g.step_endless(1.0 / 60.0)
	check(g.score > 0.0, "endless scores while inside the band")

	# Anti-idle: a drifting band can't hand points to an idle player...
	g.start_endless()
	for b in g.bouncers.duplicate():
		g._capture(b)
	g.next_spawn = 1e9
	g.next_item = 1e9
	g.next_shift = 1e9
	g.since_claim = 100.0
	var cur: float = g.scary_percent()
	g.goal_min = cur - 40.0
	g.goal_max = cur - 24.0
	g.band_target = cur + 40.0   # it will drift right through the current %
	var drift_gain := 0.0
	for i in 60 * 20:
		g.clock += 1.0 / 60.0
		var before_s: float = g.score
		g.step_endless(1.0 / 60.0)
		drift_gain += g.score - before_s
	check(drift_gain < 1.0, "an idle player gets nothing while the band drifts over them (%.1f pts)" % drift_gain)
	# ...but sitting idle inside a band that has settled scores normally
	cur = g.scary_percent()
	g.band_target = cur
	g.goal_min = cur - 8.0
	g.goal_max = cur + 8.0
	var still_start: float = g.score
	for i in 60 * 10:
		g.clock += 1.0 / 60.0
		g.step_endless(1.0 / 60.0)
	check(g.score - still_start > 95.0, "idling inside a settled band scores normally (%.0f pts in 10 s)" % (g.score - still_start))
	# claiming during a drift turns scoring on
	g.band_target = cur + 30.0
	draw([Vector2(100, 600), Vector2(100, -10)])
	grow_out()
	var claim_start: float = g.score
	for i in 60 * 2:
		g.clock += 1.0 / 60.0
		var s1: float = g.scary_percent()
		g.goal_min = s1 - 8.0
		g.goal_max = s1 + 8.0
		g.step_endless(1.0 / 60.0)
	check(g.score - claim_start > 15.0, "recent claims score even while the band drifts")

	# Endless keeps adding creatures without a cap (wisps capped at 2)
	g.start_endless()
	for i in 60 * 400:
		g.clock += 1.0 / 60.0
		g.step_endless(1.0 / 60.0)
	var wisps := 0
	for b in g.bouncers:
		wisps += 1 if b.kind == "wisp" else 0
	check(g.bouncers.size() > 20, "endless spawns past the old cap of 9 (%d after 400 s)" % g.bouncers.size())
	check(wisps <= 2, "endless never has more than 2 untrappable wisps")

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
