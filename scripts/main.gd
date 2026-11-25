extends Node2D
## Werecat prototype: one level of the core loop from the spec.
## Swipe to grow a wall from where your finger lands. The wall takes the
## color of the territory you started in. When it completes, every pocket
## with no bouncers inside flips to that color. Hit the target band and
## hold it for 3 seconds to win.

const COLS := 24
const ROWS := 36
const CELL := 26.0
const ORIGIN := Vector2(48, 250)
const WALL_SPEED := 14.0        # cells per second, per arm
const HOLD_TIME := 3.0

const CUTE := 0
const SCARY := 1

const COL_CUTE := Color(0.80, 0.70, 0.92)
const COL_CUTE_ALT := Color(0.85, 0.76, 0.95)
const COL_SCARY := Color(0.22, 0.03, 0.06)
const COL_SCARY_ALT := Color(0.26, 0.04, 0.08)
const COL_WALL_CUTE := Color(1.0, 0.72, 0.82)
const COL_WALL_SCARY := Color(0.05, 0.0, 0.02)

# Level definition (later: load from a levels resource)
var level := {
	"name": "1-3",
	"goal_min": 70.0,
	"goal_max": 80.0,
	"cute_bouncers": 1,
	"scary_bouncers": 1,
}

var cells: PackedInt32Array      # CUTE / SCARY
var solid: PackedByteArray       # 1 = completed wall
var bouncers: Array = []         # {pos: Vector2 (px, local to grid), vel: Vector2, type: int}
var wall = null                  # growing wall: {origin, axis, color, a, b} (a/b = arm lengths)
var lives := 3
var hold := 0.0
var state := "play"              # play / won / lost
var touch_start = null
var font: Font
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	font = ThemeDB.fallback_font
	reset_level()


func reset_level() -> void:
	cells = PackedInt32Array()
	solid = PackedByteArray()
	cells.resize(COLS * ROWS)
	solid.resize(COLS * ROWS)
	for y in ROWS:
		for x in COLS:
			cells[idx(x, y)] = CUTE if y < ROWS / 2 else SCARY
	bouncers.clear()
	for i in level.cute_bouncers:
		spawn_bouncer(CUTE)
	for i in level.scary_bouncers:
		spawn_bouncer(SCARY)
	wall = null
	lives = 3
	hold = 0.0
	state = "play"


func spawn_bouncer(type: int) -> void:
	var y0 := 2 if type == CUTE else ROWS / 2 + 2
	var y1 := ROWS / 2 - 3 if type == CUTE else ROWS - 3
	var p := Vector2(rng.randi_range(2, COLS - 3) + 0.5, rng.randi_range(y0, y1) + 0.5) * CELL
	var v := Vector2(1 if rng.randf() < 0.5 else -1, 1 if rng.randf() < 0.5 else -1) * 150.0
	bouncers.append({"pos": p, "vel": v, "type": type})


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
			if state != "play":
				reset_level()
				return
			touch_start = event.position
		else:
			touch_start = null
	elif event is InputEventScreenDrag and touch_start != null:
		var d: Vector2 = event.position - touch_start
		if d.length() > 24.0:
			try_start_wall(touch_start, absf(d.x) >= absf(d.y))
			touch_start = null


func try_start_wall(screen_pos: Vector2, horizontal: bool) -> void:
	if wall != null or state != "play":
		return
	var c := cell_of(screen_pos - ORIGIN)
	if not in_grid(c) or solid[idx(c.x, c.y)] == 1:
		return
	wall = {
		"origin": c,
		"axis": Vector2i(1, 0) if horizontal else Vector2i(0, 1),
		"color": cells[idx(c.x, c.y)],
		"a": 0.0, "b": 0.0, "a_done": false, "b_done": false,
	}


# ---------------------------------------------------------------- simulation

func _process(delta: float) -> void:
	if state == "play":
		step_bouncers(delta)
		step_wall(delta)
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
		# a bouncer touching a growing wall breaks it
		if wall != null and wall_cells().has(cell_of(p)):
			wall = null
			lives -= 1
			if lives <= 0:
				state = "lost"


func arm_cells(dir: int, length: float) -> Array:
	var out: Array = []
	var ax: Vector2i = wall.axis * dir
	for k in range(1, int(length) + 1):
		out.append(wall.origin + ax * k)
	return out


func wall_cells() -> Array:
	var out: Array = [wall.origin]
	out.append_array(arm_cells(-1, wall.a))
	out.append_array(arm_cells(1, wall.b))
	return out


func arm_can_grow(dir: int, length: float) -> bool:
	var nxt: Vector2i = wall.origin + wall.axis * dir * (int(length) + 1)
	return in_grid(nxt) and solid[idx(nxt.x, nxt.y)] == 0


func step_wall(delta: float) -> void:
	if wall == null:
		return
	for arm in [["a", "a_done", -1], ["b", "b_done", 1]]:
		if wall[arm[1]]:
			continue
		var grown: float = wall[arm[0]] + WALL_SPEED * delta
		while int(wall[arm[0]]) < int(grown):
			if not arm_can_grow(arm[2], wall[arm[0]]):
				wall[arm[1]] = true
				break
			wall[arm[0]] = float(int(wall[arm[0]]) + 1)
		if not wall[arm[1]]:
			wall[arm[0]] = grown
			if not arm_can_grow(arm[2], wall[arm[0]]):
				wall[arm[1]] = true
	if wall.a_done and wall.b_done:
		complete_wall()


func complete_wall() -> void:
	var color: int = wall.color
	var wc := wall_cells()
	for b in bouncers:
		if wc.has(cell_of(b.pos)):
			# a bouncer sits on the finished wall: counts as a hit
			wall = null
			lives -= 1
			if lives <= 0:
				state = "lost"
			return
	for c in wc:
		var i := idx(c.x, c.y)
		solid[i] = 1
		cells[i] = color
	wall = null
	flip_empty_pockets(color)


## Flood-fill every open pocket (bounded by solid walls). Pockets with no
## bouncer inside flip to the color of the wall that closed them.
func flip_empty_pockets(color: int) -> void:
	var seen := PackedByteArray()
	seen.resize(COLS * ROWS)
	var occupied := {}
	for b in bouncers:
		var c := cell_of(b.pos)
		occupied[idx(c.x, c.y)] = true
	for start in COLS * ROWS:
		if seen[start] == 1 or solid[start] == 1:
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
					if seen[j] == 0 and solid[j] == 0:
						seen[j] = 1
						stack.append(j)
		if not has_bouncer:
			for i in pocket:
				cells[i] = color


func step_goal(delta: float) -> void:
	var s := scary_percent()
	if s >= level.goal_min and s <= level.goal_max:
		hold += delta
		if hold >= HOLD_TIME:
			state = "won"
	else:
		hold = 0.0


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var s := scary_percent()
	var m := s / 100.0
	draw_hud(s)
	draw_werecat(Vector2(600, 120), m)
	# grid
	for y in ROWS:
		for x in COLS:
			var i := idx(x, y)
			var r := Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			var col: Color
			if solid[i] == 1:
				col = COL_WALL_CUTE if cells[i] == CUTE else COL_WALL_SCARY
			elif cells[i] == CUTE:
				col = COL_CUTE if (x + y) % 2 == 0 else COL_CUTE_ALT
			else:
				col = COL_SCARY if (x + y) % 2 == 0 else COL_SCARY_ALT
			draw_rect(r, col)
	draw_rect(Rect2(ORIGIN, Vector2(COLS, ROWS) * CELL), Color(1, 1, 1, 0.3), false, 2.0)
	# growing wall
	if wall != null:
		var wc := COL_WALL_CUTE if wall.color == CUTE else Color(0.6, 0.05, 0.1)
		for c in wall_cells():
			draw_rect(Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-2), wc)
	# bouncers
	for b in bouncers:
		var p: Vector2 = ORIGIN + b.pos
		if b.type == CUTE:
			draw_circle(p, CELL * 0.42, Color(1.0, 0.45, 0.65))
			draw_circle(p + Vector2(-3, -3), CELL * 0.12, Color(1, 1, 1, 0.8))
		else:
			draw_circle(p, CELL * 0.42, Color(0.05, 0.0, 0.0))
			draw_circle(p + Vector2(-4, -2), 2.5, Color(1, 0.2, 0.1))
			draw_circle(p + Vector2(4, -2), 2.5, Color(1, 0.2, 0.1))
	if state != "play":
		draw_rect(Rect2(Vector2.ZERO, Vector2(720, 1280)), Color(0, 0, 0, 0.55))
		var msg := "THE WERECAT IS PLEASED" if state == "won" else "THE WERECAT GOT YOU"
		draw_string(font, Vector2(0, 640), msg, HORIZONTAL_ALIGNMENT_CENTER, 720, 40, Color.WHITE)
		draw_string(font, Vector2(0, 700), "Tap to play again", HORIZONTAL_ALIGNMENT_CENTER, 720, 28, Color(1, 1, 1, 0.7))


func draw_hud(s: float) -> void:
	draw_string(font, Vector2(48, 70), "Level %s" % level.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_string(font, Vector2(48, 110), "Goal: Scary %d-%d%%" % [level.goal_min, level.goal_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.8, 0.85))
	draw_string(font, Vector2(48, 145), "Lives: %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.8))
	# meter
	var bar := Rect2(48, 175, 480, 30)
	draw_rect(bar, COL_CUTE)
	draw_rect(Rect2(bar.position + Vector2(bar.size.x * (1.0 - s / 100.0), 0), Vector2(bar.size.x * s / 100.0, bar.size.y)), Color(0.55, 0.03, 0.08))
	var g0: float = bar.position.x + bar.size.x * (1.0 - level.goal_max / 100.0)
	var g1: float = bar.position.x + bar.size.x * (1.0 - level.goal_min / 100.0)
	draw_rect(Rect2(g0, bar.position.y - 6, g1 - g0, bar.size.y + 12), Color(1, 0.9, 0.3), false, 3.0)
	draw_string(font, Vector2(bar.position.x, bar.end.y + 30), "%d%% scary" % roundi(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if hold > 0.0:
		draw_arc(Vector2(600, 120), 78, -PI / 2, -PI / 2 + TAU * hold / HOLD_TIME, 48, Color(1, 0.9, 0.3), 6.0)


## Simple procedural werecat head, morphing from cute (m=0) to scary (m=1).
func draw_werecat(c: Vector2, m: float) -> void:
	var fur := Color(0.84, 0.66, 0.47).lerp(Color(0.23, 0.16, 0.16), m)
	var dark := Color(0.63, 0.44, 0.28).lerp(Color(0.09, 0.05, 0.07), m)
	# ears
	var eh := 50.0 + 25.0 * m
	for sd in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(sd * 15, -35), c + Vector2(sd * 48, -eh), c + Vector2(sd * 50, -10)]), dark)
	# spikes
	if m > 0.2:
		var k := (m - 0.2) / 0.8
		for a in 14:
			var ang := TAU * a / 14.0
			var base := c + Vector2(cos(ang), sin(ang)) * 44.0
			var tip := c + Vector2(cos(ang), sin(ang)) * (44.0 + 22.0 * k)
			var pr := Vector2(-sin(ang), cos(ang)) * 7.0
			draw_colored_polygon(PackedVector2Array([base + pr, tip, base - pr]), dark)
	draw_circle(c, 48, fur)
	# horns
	if m > 0.45:
		var k2 := (m - 0.45) / 0.55
		for sd in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(sd * 10, -40), c + Vector2(sd * (30 + 14 * k2), -44 - 40 * k2), c + Vector2(sd * 26, -36)]), Color(0.12, 0.08, 0.08))
	# eyes
	for sd in [-1, 1]:
		var e := c + Vector2(sd * 18, -6)
		if m < 0.5:
			draw_circle(e, 11, Color(0.12, 0.08, 0.16))
			draw_circle(e + Vector2(-3, -4), 4, Color.WHITE)
		else:
			draw_circle(e, 13, Color(1, 0, 0, 0.35))
			draw_colored_polygon(PackedVector2Array([e + Vector2(-sd * 11, 0), e + Vector2(sd * 11, -7), e + Vector2(sd * 9, 6), e + Vector2(-sd * 9, 5)]), Color(1, 0.2, 0.1))
			draw_rect(Rect2(e + Vector2(-1.5, -6), Vector2(3, 11)), Color.BLACK)
	# snout and mouth
	draw_circle(c + Vector2(0, 18), 18, Color(0.95, 0.86, 0.75).lerp(Color(0.36, 0.24, 0.24), m))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 8), c + Vector2(6, 8), c + Vector2(0, 14)]), Color(0.95, 0.5, 0.6).lerp(Color.BLACK, m))
	if m >= 0.5:
		draw_rect(Rect2(c + Vector2(-12, 20), Vector2(24, 10 * m)), Color(0.25, 0, 0.03))
		for fx in [-9, -3, 3, 9]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(fx - 2.5, 20), c + Vector2(fx + 2.5, 20), c + Vector2(fx, 28)]), Color(0.98, 0.97, 0.9))
