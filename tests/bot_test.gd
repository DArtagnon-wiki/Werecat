extends SceneTree
## Bot playtest: tries to win every level by drawing straight claim strokes
## that push the meter toward the goal band, then holding it. It draws
## instantly (easier than a human in one way) but aims randomly (harder in
## another), so a level the bot can't beat in several attempts is suspect.
##   godot --headless --path . -s res://tests/bot_test.gd

const ATTEMPTS := 6
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
	while g.state == "play" and strokes < MAX_STROKES:
		var pl := plan()
		if pl.is_empty():
			sim(0.5)
			continue
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
