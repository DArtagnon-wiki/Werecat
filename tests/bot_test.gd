extends SceneTree
## Bot playtest: tries to win every level by drawing straight claim strokes
## that push the meter toward the goal band, then holding it. It draws
## instantly (easier than a human in one way) but aims randomly (harder in
## another), so a level the bot can't beat in several attempts is suspect.
##   godot --headless --path . -s res://tests/bot_test.gd

const ATTEMPTS := 4
const MAX_STROKES := 220

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
		g.step_entities(dt)
		if g.state == "play":
			g.step_items(dt)
		if g.state == "play":
			g.step_goal(dt)


func random_cell_of(side: int) -> Variant:
	for tries in 400:
		var x := rng.randi_range(2, g.GW - 3)
		var y := rng.randi_range(2, g.GH - 3)
		if g.mask[y * g.GW + x] == side:
			return Vector2((x + 0.5) * g.CELL, (y + 0.5) * g.CELL)
	return null


func stroke(side: int, depth: float) -> void:
	## A U-shaped scoop: out `depth` px into enemy ground, across, and back.
	var p: Variant = random_cell_of(side)
	if p == null:
		return
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var across := dir.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
	var width := rng.randf_range(50.0, 140.0)
	g.begin_stroke(p)
	var q: Vector2 = p
	var was_active := false
	var path: Array = []
	# phase 1: go out until we've been in enemy ground for `depth` px
	var inside_len := 0.0
	for k in 220:
		q += dir * 6.0
		g.move_stroke(q)
		if not g.stroking:
			return  # closed (edge/stone/own ground)
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
	# phase 2: across
	for k in int(width / 6.0):
		q += across * 6.0
		g.move_stroke(q)
		if not g.stroking:
			return
	# phase 3: back the way we came until it closes
	for k in 260:
		q -= dir * 6.0
		g.move_stroke(q)
		if not g.stroking:
			return
	g.end_stroke()


func play_level(i: int) -> Array:
	g.open_intro(i)
	g.begin_play()
	var strokes := 0
	while g.state == "play" and strokes < MAX_STROKES:
		var s: float = g.scary_percent()
		var gmin: float = g.goal_min
		var gmax: float = g.goal_max
		if s >= gmin and s <= gmax:
			sim(0.5)
			continue
		var side: int = g.SCARY if s < gmin else g.CUTE
		var dist := (gmin - s) if s < gmin else (s - gmax)
		var depth := clampf(dist * 9.0, 30.0, 700.0)
		stroke(side, depth)
		strokes += 1
		sim(0.25)
	return [g.state == "won", strokes, g.lives, g.clock]


func run() -> void:
	rng.seed = 12345
	var failed: Array = []
	for i in g.levels.size():
		var lv: Dictionary = g.levels[i]
		var won := false
		var info := []
		for a in ATTEMPTS:
			info = play_level(i)
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
