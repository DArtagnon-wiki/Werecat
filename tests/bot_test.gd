extends SceneTree
## Bot playtest: tries to win every level by drawing straight claim strokes
## that push the meter toward the goal band, then holding it. It draws
## instantly (easier than a human in one way) but aims randomly (harder in
## another), so a level the bot can't beat in several attempts is suspect.
##   godot --headless --path . -s res://tests/bot_test.gd

const ATTEMPTS := 12
const MAX_STROKES := 260

var g
var started := false
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	run()
	return false


func sim(seconds: float) -> void:
	var dt := 1.0 / 30.0
	for i in int(seconds * 30):
		if g.state != "play":
			return
		g.clock += dt
		g.freeze_t = maxf(0.0, g.freeze_t - dt)
		g._update_zones()
		g.step_growth(dt)
		if g.state != "play":
			return
		g.step_entities(dt)
		if g.state == "play":
			g.step_items(dt)
		if g.state == "play":
			g.step_goal(dt)


func random_cell_of(side: int, focus: Variant = null, radius := 170.0) -> Variant:
	for tries in 600:
		var x := rng.randi_range(2, g.GW - 3)
		var y := rng.randi_range(2, g.GH - 3)
		if focus != null:
			var f: Vector2 = focus
			var a := rng.randf() * TAU
			var r := rng.randf() * radius
			x = clampi(int((f.x + cos(a) * r) / g.CELL), 2, g.GW - 3)
			y = clampi(int((f.y + sin(a) * r) / g.CELL), 2, g.GH - 3)
		if g.mask[y * g.GW + x] == side:
			return Vector2((x + 0.5) * g.CELL, (y + 0.5) * g.CELL)
	return null if focus == null else random_cell_of(side)


func stroke(side: int, depth: float, focus: Variant = null) -> void:
	## A U-shaped scoop (or a straight line when curl is limited): out into
	## enemy ground, across, and back.
	var p: Variant = random_cell_of(side, focus)
	if p == null:
		return
	var dir := Vector2.from_angle(rng.randf() * TAU)
	if focus != null:
		dir = ((focus as Vector2) - (p as Vector2)).normalized().rotated(rng.randf_range(-0.5, 0.5))
		depth = maxf(depth, (p as Vector2).distance_to(focus) + 30.0)
	var curl: String = g.effective_curl()
	g.begin_stroke(p)
	var q: Vector2 = p
	if curl == "straight" or curl == "arc":
		# straight push until it closes
		for k in 400:
			q += dir * 6.0
			g.move_stroke(q)
			if not g.stroking:
				return
		g.end_stroke()
		return
	var across := dir.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
	var width := rng.randf_range(50.0, 140.0)
	var was_active := false
	var inside_len := 0.0
	for k in 220:
		q += dir * 6.0
		g.move_stroke(q)
		if not g.stroking:
			return
		if g.stroke_active:
			was_active = true
			inside_len += 6.0
			if inside_len >= depth:
				break
		elif k > 60:
			break
	if not was_active:
		g.end_stroke()
		return
	for k in int(width / 6.0):
		q += across * 6.0
		g.move_stroke(q)
		if not g.stroking:
			return
	for k in 260:
		q -= dir * 6.0
		g.move_stroke(q)
		if not g.stroking:
			return
	g.end_stroke()


func stroke_path(pts: Array) -> void:
	## Draw a polyline (first point must be on Cute ground for a Cute wall).
	g.begin_stroke(pts[0])
	if not g.stroking:
		return
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var n := maxi(1, int(a.distance_to(b) / 5.0))
		for k in range(1, n + 1):
			g.move_stroke(a.lerp(b, float(k) / n))
			if not g.stroking:
				return
	g.end_stroke()


func cell_at(p: Vector2) -> int:
	if p.x < 0 or p.y < 0 or p.x >= g.FIELD_SIZE.x or p.y >= g.FIELD_SIZE.y:
		return -1
	return g.mask[g.cell_index(p)]


## Bats grouped by connected pocket of Scary ground.
func bat_groups() -> Array:
	var label := {}
	var groups := {}
	var lab := PackedInt32Array()
	lab.resize(g.GW * g.GH)
	var next := 1
	for b in g.bouncers:
		if b.kind != "basic" or b.side != g.SCARY:
			continue
		var st: int = g.cell_index(b.pos)
		if g.mask[st] != g.SCARY:
			continue
		if lab[st] == 0:
			var stack := [st]
			lab[st] = next
			while stack.size() > 0:
				var i: int = stack.pop_back()
				var x: int = i % g.GW
				for j in [i - 1 if x > 0 else -1, i + 1 if x < g.GW - 1 else -1, i - g.GW, i + g.GW]:
					if j >= 0 and j < g.GW * g.GH and lab[j] == 0 and g.mask[j] == g.SCARY:
						lab[j] = next
						stack.append(j)
			next += 1
		var l := lab[st]
		if not groups.has(l):
			groups[l] = []
		groups[l].append(b)
	return groups.values()


## A Cute wall between two bats that share a pocket: along the perpendicular
## bisector until it leaves their Scary ground at both ends.
func pen_cut() -> Array:
	var crowded := bat_groups().filter(func(gr: Array) -> bool: return gr.size() >= 2)
	if crowded.is_empty():
		return []
	var gr: Array = crowded[rng.randi_range(0, crowded.size() - 1)]
	var a: Dictionary = gr[rng.randi_range(0, gr.size() - 1)]
	var b: Dictionary = gr[rng.randi_range(0, gr.size() - 1)]
	for t in 6:
		if a != b:
			break
		b = gr[rng.randi_range(0, gr.size() - 1)]
	if a == b:
		return []
	var m: Vector2 = (a.pos + b.pos) / 2.0
	var dir: Vector2 = (b.pos - a.pos).normalized().orthogonal().rotated(rng.randf_range(-0.35, 0.35))
	var ends: Array = []
	for sgn in [-1.0, 1.0]:
		var q := m
		for k in 300:
			q += dir * sgn * 4.0
			if cell_at(q) != g.SCARY:
				break
		ends.append(q)
	var e1: Vector2 = ends[0]
	var e2: Vector2 = ends[1]
	if cell_at(e2) == g.CUTE and cell_at(e1) != g.CUTE:
		var tmp := e1
		e1 = e2
		e2 = tmp
		dir = -dir
	var over: Vector2 = e2 + dir * 10.0
	if cell_at(e1) == g.CUTE:
		return [e1 - dir * 8.0, over]
	# no Cute at either end (stone or edge): come in from the nearest Cute ground
	var best: Variant = null
	var bd := 1e9
	for t in 400:
		var c: Variant = random_cell_of(g.CUTE, e1, 260.0)
		if c != null and (c as Vector2).distance_to(e1) < bd:
			bd = (c as Vector2).distance_to(e1)
			best = c
	if best == null:
		return []
	return [best, e1 + dir * 10.0, over]


## What to do next: targets first, then hold-zones, then the band.
func plan() -> Array:
	for it in g.items:
		if it.alive and it.kind == "idol":
			return [1 - int(it.side), 60.0, it.pos]
	for b in g.bouncers:
		if b.kind == "elite":
			# carve away its ground somewhere else; the pocket shrinks around it
			var away: Variant = random_cell_of(int(b.side))
			for t in 30:
				if away != null and (away as Vector2).distance_to(b.pos) > 220.0:
					break
				away = random_cell_of(int(b.side))
			return [1 - int(b.side), 80.0, away]
	for z in g.zones:
		if z.kind == "hold" and not z.held:
			return [int(z.side), 90.0, z.center]
	# shrines: break curses, grab blessings
	var bi: int = g.CURL_ORDER.find(g.base_curl())
	for z in g.zones:
		if z.kind != "shrine":
			continue
		var e: Dictionary = g.EFFECTS[z.effect]
		var good: bool = (e.kind == "wall" and float(e.value) > 1.0) or (e.kind == "creature" and float(e.value) < 1.0) \
			or (e.kind == "curl" and g.CURL_ORDER.find(e.value) > bi)
		if good and not z.held:
			return [int(z.side), 90.0, z.center]
		if not good and z.held:
			return [1 - int(z.side), 90.0, z.center]
	# generators: sometimes go close one (never the gift boxes on a fuzzies night)
	if rng.randf() < 0.45:
		for it in g.items:
			if not it.alive or not it.kind in ["nest", "den", "burrow", "lantern"]:
				continue
			if it.kind == "nest" and it.side == g.CUTE and int(g.level.get("fuzzies", 0)) > 0:
				continue
			if it.kind == "nest" and it.side == g.CUTE and g.goal_min > 50.0:
				pass
			elif it.kind == "nest" and it.side == g.CUTE:
				continue
			return [1 - int(it.side), 70.0, it.pos]
	if g.pens_left() > 0:
		var path := pen_cut()
		return ["path", path] if not path.is_empty() else ["wait"]
	if g.fuzzies_left() > 0:
		for it in g.items:
			if it.alive and it.kind == "nest" and it.side == g.CUTE and g.type_at(it.pos) == g.CUTE:
				return ["wait"]
	var s: float = g.scary_percent()
	if s >= g.goal_min and s <= g.goal_max:
		return []
	var side: int = g.SCARY if s < g.goal_min else g.CUTE
	var dist: float = (g.goal_min - s) if s < g.goal_min else (s - g.goal_max)
	return [side, clampf(dist * 9.0, 30.0, 700.0), null]


func finish_growth() -> void:
	var guard := 0
	while g.growing and g.state == "play" and guard < 300:
		sim(1.0 / 30.0 * 2.0)
		guard += 1


func play_level(i: int, attempt := 0) -> Array:
	g.rng.seed = 1000 * i + attempt   # deterministic spawns -> reproducible CI
	g.open_intro(i)
	g.begin_play()
	var strokes := 0
	while g.state == "play" and strokes < MAX_STROKES and g.clock < 900.0:
		var pl := plan()
		if pl.is_empty():
			sim(0.5)
			continue
		if pl[0] is String:
			if pl[0] == "wait":
				sim(1.0)
				strokes += 1      # counts toward the give-up limit
				continue
			stroke_path(pl[1])
		else:
			stroke(pl[0], pl[1], pl[2])
		finish_growth()
		strokes += 1
		sim(0.25)
	return [g.state == "won", strokes, g.lives, g.clock]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "range":
		# tuning mode: -- range <first> <last> <tries>
		for li in range(int(args[1]), int(args[2]) + 1):
			var n := int(args[3])
			var wins := 0
			var strokes: Array = []
			var times: Array = []
			for t in n:
				rng.seed = 900 + t
				var r := play_level(li, 300 + t)
				if r[0]:
					wins += 1
					strokes.append(r[1])
					times.append(r[3])
			strokes.sort()
			times.sort()
			var ms: int = strokes[strokes.size() / 2] if strokes.size() else -1
			var mt: float = times[times.size() / 2] if times.size() else -1.0
			print("STAT %s %-20s win %2d/%d  median strokes %3d  median sim time %5.1fs" % [g.levels[li].id, g.levels[li].name, wins, n, ms, mt])
		quit()
		return
	if args.size() >= 1:
		# stats mode: -- <level index> <tries>
		var li := int(args[0])
		var n := int(args[1]) if args.size() > 1 else 30
		var wins := 0
		for t in n:
			rng.seed = 777 + t
			if play_level(li, 100 + t)[0]:
				wins += 1
		print("level %s: bot won %d / %d" % [g.levels[li].id, wins, n])
		quit()
		return
	rng.seed = 12345
	var failed: Array = []
	for i in g.levels.size():
		var lv: Dictionary = g.levels[i]
		var won := false
		var info := []
		for a in ATTEMPTS:
			info = play_level(i, a)
			if info[0]:
				won = true
				break
		print("%s %-16s %s  strokes %3d  lives %d  time %5.1fs" % [lv.id, lv.name, "WON " if won else "FAIL", info[1], info[2], info[3]])
		if not won:
			failed.append(lv.id)
	g.stars.fill(0)
	g._save()
	print("bot could not beat: %s" % (", ".join(failed) if failed.size() > 0 else "none"))
	quit(1 if failed.size() > 0 else 0)
