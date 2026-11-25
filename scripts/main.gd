extends Node2D
## Werecat prototype: the core loop from the spec.
##
## Wall rules:
##   - Walls only invade: a Cute wall grows into Scary territory and vice versa.
##   - Walls start at an anchor: the Cute/Scary border or a finished wall.
##     The wall takes the anchor's color. The outer frame is not an anchor.
##   - A wall grows one way, in the swipe direction, until it reaches the
##     frame, a finished wall, or territory of its own color.
##   - A bouncer touching a growing wall breaks it (lose a life).
##   - When the wall finishes, every pocket of the invaded territory with no
##     bouncer inside flips to the wall's color.
##
## Modes: "level" (hold the target band for 3 s) and "endless" (chase a
## drifting band for points).

const COLS := 24
const ROWS := 36
const CELL := 26.0
const ORIGIN := Vector2(48, 250)
const WALL_SPEED := 14.0        # cells per second
const HOLD_TIME := 3.0
const SNAP := 2                 # a touch this many cells from an anchor still counts

const CUTE := 0
const SCARY := 1

const ENDLESS_BAND := 16.0
const ENDLESS_SHIFT_EVERY := 12.0
const ENDLESS_SPAWN_EVERY := 30.0
const ENDLESS_MAX_BOUNCERS := 8

const COL_CUTE := Color(0.80, 0.70, 0.92)
const COL_CUTE_ALT := Color(0.85, 0.76, 0.95)
const COL_SCARY := Color(0.20, 0.03, 0.06)
const COL_SCARY_ALT := Color(0.24, 0.04, 0.08)
const COL_WALL_CUTE := Color(1.0, 0.72, 0.82)
const COL_WALL_SCARY := Color(0.05, 0.0, 0.02)
const COL_ICHOR := Color(0.55, 1.0, 0.35)

const LEVEL := {
	"name": "1-3",
	"goal_min": 70.0,
	"goal_max": 80.0,
	"cute_bouncers": 1,
	"scary_bouncers": 1,
}

var mode := "level"              # level / endless
var state := "menu"              # menu / play / won / lost
var cells: PackedInt32Array      # CUTE / SCARY
var solid: PackedByteArray       # 1 = finished wall
var bouncers: Array = []         # {pos: Vector2 (px, grid-local), vel: Vector2, type: int}
var wall = null                  # {start: Vector2i, dir: Vector2i, color: int, len: float}
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
var nope := 0.0                  # "nope" wobble timer for an invalid swipe
var touch_start = null
var font: Font
var rng := RandomNumberGenerator.new()

const BTN_LEVEL := Rect2(160, 640, 400, 90)
const BTN_ENDLESS := Rect2(160, 760, 400, 90)


func _ready() -> void:
	font = ThemeDB.fallback_font
	rng.randomize()
	reset_grid()


func reset_grid() -> void:
	cells = PackedInt32Array()
	solid = PackedByteArray()
	cells.resize(COLS * ROWS)
	solid.resize(COLS * ROWS)
	for y in ROWS:
		for x in COLS:
			cells[idx(x, y)] = CUTE if y < ROWS / 2 else SCARY
	bouncers.clear()
	wall = null
	lives = 3
	hold = 0.0
	clock = 0.0
	score = 0.0


func start_level() -> void:
	mode = "level"
	reset_grid()
	goal_min = LEVEL.goal_min
	goal_max = LEVEL.goal_max
	for i in LEVEL.cute_bouncers:
		spawn_bouncer(CUTE)
	for i in LEVEL.scary_bouncers:
		spawn_bouncer(SCARY)
	state = "play"


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
	state = "play"


## Spawns a bouncer on a random open cell of its own territory.
func spawn_bouncer(type: int) -> bool:
	var open: Array = []
	for i in COLS * ROWS:
		if cells[i] == type and solid[i] == 0:
			open.append(i)
	if open.is_empty():
		return false
	var i: int = open[rng.randi_range(0, open.size() - 1)]
	var p := (Vector2(i % COLS, i / COLS) + Vector2(0.5, 0.5)) * CELL
	var v := Vector2(1 if rng.randf() < 0.5 else -1, 1 if rng.randf() < 0.5 else -1) * 150.0
	bouncers.append({"pos": p, "vel": v, "type": type})
	return true


func idx(x: int, y: int) -> int:
	return y * COLS + x


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func scary_percent() -> float:
	var n := 0
	for v in cells:
		n += v
	return 100.0 * n / cells.size()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			match state:
				"menu":
					if BTN_LEVEL.has_point(event.position):
						start_level()
					elif BTN_ENDLESS.has_point(event.position):
						start_endless()
				"won", "lost":
					state = "menu"
				"play":
					touch_start = event.position
		else:
			touch_start = null
	elif event is InputEventScreenDrag and touch_start != null:
		var d: Vector2 = event.position - touch_start
		if d.length() > 24.0:
			var dir := Vector2i(signi(roundi(d.x)), 0) if absf(d.x) >= absf(d.y) else Vector2i(0, signi(roundi(d.y)))
			if not try_start_wall(touch_start, dir):
				nope = 0.3
			touch_start = null


## Finds an anchor near the touch and starts a wall growing in `dir`.
## Returns false if no legal wall can start there.
func try_start_wall(screen_pos: Vector2, dir: Vector2i) -> bool:
	if wall != null or state != "play":
		return false
	var c := cell_of(screen_pos - ORIGIN)
	# try the touch cell first, then cells further along/back the swipe line
	var offsets: Array = [0]
	for k in range(1, SNAP + 2):
		offsets.append_array([k, -k])
	for k in offsets:
		var s: Vector2i = c + dir * k
		var a: Vector2i = s - dir
		if not (in_grid(s) and in_grid(a)):
			continue
		var si := idx(s.x, s.y)
		var ai := idx(a.x, a.y)
		if solid[si] == 1:
			continue
		# anchor must be the other color: either a finished wall or the
		# territory across the border. Same color = can't invade own side.
		if cells[ai] != cells[si]:
			wall = {"start": s, "dir": dir, "color": cells[ai], "len": 1.0}
			return true
	return false


# ---------------------------------------------------------------- simulation

func _process(delta: float) -> void:
	nope = maxf(0.0, nope - delta)
	if state == "play":
		clock += delta
		step_bouncers(delta)
		step_wall(delta)
		if mode == "endless":
			step_endless(delta)
		else:
			step_goal(delta)
	queue_redraw()


func blocked_for(type: int, c: Vector2i) -> bool:
	if not in_grid(c):
		return true
	var i := idx(c.x, c.y)
	return solid[i] == 1 or cells[i] != type


func step_bouncers(delta: float) -> void:
	for b in bouncers:
		var p: Vector2 = b.pos
		var v: Vector2 = b.vel
		var nx := p + Vector2(v.x * delta, 0)
		if blocked_for(b.type, cell_of(nx)):
			v.x = -v.x
		else:
			p = nx
		var ny := p + Vector2(0, v.y * delta)
		if blocked_for(b.type, cell_of(ny)):
			v.y = -v.y
		else:
			p = ny
		b.pos = p
		b.vel = v
		if wall != null and wall_cells().has(cell_of(p)):
			break_wall()


func break_wall() -> void:
	wall = null
	lives -= 1
	if lives <= 0:
		state = "lost"
		best = maxf(best, score)


func wall_cells() -> Array:
	var out: Array = []
	for k in int(wall.len):
		out.append(wall.start + wall.dir * k)
	return out


func wall_can_grow() -> bool:
	var nxt: Vector2i = wall.start + wall.dir * int(wall.len)
	if not in_grid(nxt):
		return false
	var i := idx(nxt.x, nxt.y)
	return solid[i] == 0 and cells[i] != wall.color


func step_wall(delta: float) -> void:
	if wall == null:
		return
	var target: float = wall.len + WALL_SPEED * delta
	while int(wall.len) < int(target):
		if not wall_can_grow():
			complete_wall()
			return
		wall.len = float(int(wall.len) + 1)
	wall.len = target
	if not wall_can_grow():
		complete_wall()


func complete_wall() -> void:
	var color: int = wall.color
	var wc := wall_cells()
	for b in bouncers:
		if wc.has(cell_of(b.pos)):
			break_wall()
			return
	for c in wc:
		var i := idx(c.x, c.y)
		solid[i] = 1
		cells[i] = color
	wall = null
	flip_empty_pockets(color)


## Splits the invaded territory (the color opposite `color`) into pockets.
## Pockets with no bouncer inside flip to `color`.
func flip_empty_pockets(color: int) -> void:
	var invaded := 1 - color
	var seen := PackedByteArray()
	seen.resize(COLS * ROWS)
	var occupied := {}
	for b in bouncers:
		var c := cell_of(b.pos)
		occupied[idx(c.x, c.y)] = true
	for start in COLS * ROWS:
		if seen[start] == 1 or solid[start] == 1 or cells[start] != invaded:
			continue
		var pocket: Array = []
		var has_bouncer := false
		var stack: Array = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			pocket.append(i)
			if occupied.has(i):
				has_bouncer = true
			var x := i % COLS
			var y := i / COLS
			for n in [Vector2i(x + 1, y), Vector2i(x - 1, y), Vector2i(x, y + 1), Vector2i(x, y - 1)]:
				if in_grid(n):
					var j := idx(n.x, n.y)
					if seen[j] == 0 and solid[j] == 0 and cells[j] == invaded:
						seen[j] = 1
						stack.append(j)
		if not has_bouncer:
			for i in pocket:
				cells[i] = color


func step_goal(delta: float) -> void:
	var s := scary_percent()
	if s >= goal_min and s <= goal_max:
		hold += delta
		if hold >= HOLD_TIME:
			state = "won"
	else:
		hold = 0.0


func step_endless(delta: float) -> void:
	# band glides toward its target
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


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == "menu":
		draw_menu()
		return
	var s := scary_percent()
	draw_hud(s)
	draw_werecat(Vector2(600, 120), s / 100.0, clock)
	var shake := Vector2(sin(nope * 60.0) * 6.0 * nope / 0.3, 0)
	for y in ROWS:
		for x in COLS:
			var i := idx(x, y)
			var r := Rect2(ORIGIN + shake + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			var col: Color
			if solid[i] == 1:
				col = COL_WALL_CUTE if cells[i] == CUTE else COL_WALL_SCARY
			elif cells[i] == CUTE:
				col = COL_CUTE if (x + y) % 2 == 0 else COL_CUTE_ALT
			else:
				col = COL_SCARY if (x + y) % 2 == 0 else COL_SCARY_ALT
			draw_rect(r, col)
	draw_rect(Rect2(ORIGIN + shake, Vector2(COLS, ROWS) * CELL), Color(1, 1, 1, 0.3), false, 2.0)
	if wall != null:
		var wc := COL_WALL_CUTE if wall.color == CUTE else Color(0.6, 0.05, 0.1)
		for c in wall_cells():
			draw_rect(Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-2), wc)
	for b in bouncers:
		var p: Vector2 = ORIGIN + b.pos
		if b.type == CUTE:
			draw_circle(p, CELL * 0.42, Color(1.0, 0.45, 0.65))
			draw_circle(p + Vector2(-3, -3), CELL * 0.12, Color(1, 1, 1, 0.8))
		else:
			var flap := sin(clock * 18.0) * 5.0
			draw_circle(p, CELL * 0.6, Color(1, 0.1, 0.1, 0.22))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -flap), p + Vector2(-4, 3), p + Vector2(0, -3), p + Vector2(4, 3), p + Vector2(13, -flap), p + Vector2(0, 7)]), Color(0.02, 0.0, 0.0))
			draw_circle(p + Vector2(-2.5, 0), 1.8, Color(1, 0.2, 0.1))
			draw_circle(p + Vector2(2.5, 0), 1.8, Color(1, 0.2, 0.1))
	if state == "won" or state == "lost":
		draw_rect(Rect2(Vector2.ZERO, Vector2(720, 1280)), Color(0, 0, 0, 0.6))
		var msg: String
		if mode == "endless":
			msg = "SCORE %d" % roundi(score)
		else:
			msg = "THE WERECAT IS PLEASED" if state == "won" else "THE WERECAT IS DISPLEASED"
		draw_string(font, Vector2(0, 620), msg, HORIZONTAL_ALIGNMENT_CENTER, 720, 40, Color.WHITE)
		if mode == "endless":
			draw_string(font, Vector2(0, 670), "Best %d" % roundi(best), HORIZONTAL_ALIGNMENT_CENTER, 720, 28, Color(1, 0.9, 0.3))
		draw_string(font, Vector2(0, 730), "Tap to continue", HORIZONTAL_ALIGNMENT_CENTER, 720, 26, Color(1, 1, 1, 0.7))


func draw_menu() -> void:
	draw_werecat(Vector2(360, 330), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 900.0), Time.get_ticks_msec() / 1000.0, 2.2)
	draw_string(font, Vector2(0, 560), "WERECAT", HORIZONTAL_ALIGNMENT_CENTER, 720, 64, Color(1, 0.85, 0.9))
	for b in [[BTN_LEVEL, "Level 1-3"], [BTN_ENDLESS, "Endless"]]:
		var r: Rect2 = b[0]
		draw_rect(r, Color(0.25, 0.05, 0.1))
		draw_rect(r, Color(1, 0.7, 0.8), false, 3.0)
		draw_string(font, r.position + Vector2(0, 58), b[1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color.WHITE)
	draw_string(font, Vector2(0, 930), "Swipe from the border or a wall", HORIZONTAL_ALIGNMENT_CENTER, 720, 24, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(0, 965), "into the other territory.", HORIZONTAL_ALIGNMENT_CENTER, 720, 24, Color(1, 1, 1, 0.6))


func draw_hud(s: float) -> void:
	var title := "Endless" if mode == "endless" else "Level %s" % LEVEL.name
	draw_string(font, Vector2(48, 70), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	if mode == "endless":
		draw_string(font, Vector2(48, 110), "Score: %d" % roundi(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.3))
	else:
		draw_string(font, Vector2(48, 110), "Goal: Scary %d-%d%%" % [goal_min, goal_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.8, 0.85))
	draw_string(font, Vector2(48, 145), "Lives: %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.8))
	# meter: Cute on the left, Scary fills from the right
	var bar := Rect2(48, 175, 480, 30)
	draw_rect(bar, COL_CUTE)
	draw_rect(Rect2(bar.position + Vector2(bar.size.x * (1.0 - s / 100.0), 0), Vector2(bar.size.x * s / 100.0, bar.size.y)), Color(0.55, 0.03, 0.08))
	var g0: float = bar.position.x + bar.size.x * (1.0 - goal_max / 100.0)
	var g1: float = bar.position.x + bar.size.x * (1.0 - goal_min / 100.0)
	draw_rect(Rect2(g0, bar.position.y - 6, g1 - g0, bar.size.y + 12), Color(1, 0.9, 0.3), false, 3.0)
	draw_string(font, Vector2(bar.position.x, bar.end.y + 30), "%d%% scary" % roundi(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if mode == "level" and hold > 0.0:
		draw_arc(Vector2(600, 120), 78, -PI / 2, -PI / 2 + TAU * hold / HOLD_TIME, 48, Color(1, 0.9, 0.3), 6.0)


## Procedural werecat head, morphing from cute (m=0) to menacing (m=1).
## Tween-safe: menace comes from shape, eyes and motion. No blood.
func draw_werecat(c: Vector2, m: float, t: float, sc: float = 1.0) -> void:
	var fur := Color(0.84, 0.66, 0.47).lerp(Color(0.16, 0.11, 0.12), m)
	var dark := Color(0.63, 0.44, 0.28).lerp(Color(0.05, 0.02, 0.04), m)
	var eh := (50.0 + 30.0 * m) * sc
	for sd in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(sd * 15, -35) * sc, c + Vector2(sd * 48 * sc, -eh), c + Vector2(sd * 50, -10) * sc]), dark)
	if m > 0.2:
		var k := (m - 0.2) / 0.8
		for a in 16:
			var ang := TAU * a / 16.0
			var base := c + Vector2(cos(ang), sin(ang)) * 44.0 * sc
			var tip := c + Vector2(cos(ang), sin(ang)) * (44.0 + 26.0 * k) * sc
			var pr := Vector2(-sin(ang), cos(ang)) * 7.0 * sc
			draw_colored_polygon(PackedVector2Array([base + pr, tip, base - pr]), dark)
	draw_circle(c, 48 * sc, fur)
	if m > 0.45:
		var k2 := (m - 0.45) / 0.55
		for sd in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(sd * 10, -40) * sc, c + Vector2(sd * (30 + 14 * k2), -44 - 40 * k2) * sc, c + Vector2(sd * 26, -36) * sc]), Color(0.08, 0.05, 0.05))
	for sd in [-1, 1]:
		var e := c + Vector2(sd * 18, -6) * sc
		if m < 0.5:
			draw_circle(e, 11 * sc, Color(0.12, 0.08, 0.16))
			draw_circle(e + Vector2(-3, -4) * sc, 4 * sc, Color.WHITE)
		else:
			var pulse := 0.3 + 0.15 * sin(t * 6.0)
			draw_circle(e, 16 * sc, Color(1, 0, 0, pulse))
			draw_colored_polygon(PackedVector2Array([e + Vector2(-sd * 11, 0) * sc, e + Vector2(sd * 11, -7) * sc, e + Vector2(sd * 9, 6) * sc, e + Vector2(-sd * 9, 5) * sc]), Color(1, 0.2, 0.1))
			draw_rect(Rect2(e + Vector2(-1.5, -6) * sc, Vector2(3, 11) * sc), Color.BLACK)
	draw_circle(c + Vector2(0, 18) * sc, 18 * sc, Color(0.95, 0.86, 0.75).lerp(Color(0.3, 0.2, 0.2), m))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 8) * sc, c + Vector2(6, 8) * sc, c + Vector2(0, 14) * sc]), Color(0.95, 0.5, 0.6).lerp(Color.BLACK, m))
	if m >= 0.5:
		draw_rect(Rect2(c + Vector2(-12, 20) * sc, Vector2(24, 10 * m) * sc), Color(0.1, 0.0, 0.03))
		for fx in [-9, -3, 3, 9]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(fx - 2.5, 20) * sc, c + Vector2(fx + 2.5, 20) * sc, c + Vector2(fx, 28) * sc]), Color(0.98, 0.97, 0.9))
		# glowing green drool
		var dl := (6.0 + 8.0 * fmod(t, 1.0)) * sc
		draw_line(c + Vector2(8, 26) * sc, c + Vector2(8, 26) * sc + Vector2(0, dl), COL_ICHOR, 2.5 * sc)
