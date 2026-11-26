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
		if s0 >= lv.goal[0] and s0 <= lv.goal[1]:
			printerr("  level %s starts inside its goal band (%.1f%%)" % [lv.id, s0])
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
	check(g.levels.size() == 20, "there are 20 levels")

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

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
