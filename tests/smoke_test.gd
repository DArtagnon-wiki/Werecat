extends SceneTree
## Headless smoke tests, run in CI:
##   godot --headless --path . -s res://tests/smoke_test.gd
## Field is 640x744 px. Cute is the top half, Scary the bottom half, with a
## wavy border around y = 372.

var failures := 0
var g


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		printerr("FAIL  ", msg)
		failures += 1


func fresh() -> void:
	g.start_level()
	for b in g.bouncers:
		b.node.queue_free()
	g.bouncers.clear()


func add_bouncer(type: int, pos: Vector2) -> void:
	var s := Sprite2D.new()
	g.bouncer_layer.add_child(s)
	g.bouncers.append({"pos": pos, "vel": Vector2.ZERO, "type": type, "node": s, "phase": 0.0})


func draw(points: Array) -> void:
	g.begin_stroke(points[0])
	draw_more(points)


func draw_more(points: Array) -> void:
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var n := maxi(1, int(a.distance_to(b) / 6.0))
		for k in range(1, n + 1):
			g.move_stroke(a.lerp(b, float(k) / n))


var started := false


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

	fresh()
	check(absf(g.scary_percent() - 50.0) < 3.0, "level starts about 50/50 (%.1f%%)" % g.scary_percent())

	# Cute line from the top half straight down to the bottom edge. The bat is
	# on the right, so the strip of Scary left of the line flips to Cute.
	fresh()
	add_bouncer(g.SCARY, Vector2(500, 600))
	var before: float = g.scary_percent()
	draw([Vector2(100, 200), Vector2(100, 760)])
	var after: float = g.scary_percent()
	check(after < before - 5.0 and after > 35.0, "line to the edge claims the bat-free side (%.1f%% -> %.1f%%)" % [before, after])
	check(g.lives == 3 and not g.stroke_active, "claim closes cleanly")

	# Lifting the finger before closing does nothing and costs nothing.
	fresh()
	before = g.scary_percent()
	draw([Vector2(300, 200), Vector2(300, 520)])
	check(g.stroke_active, "trail is open while drawing in the other territory")
	g.end_stroke()
	check(absf(g.scary_percent() - before) < 0.01 and g.lives == 3, "lifting early: no change, no penalty")

	# A bat touching an open trail snaps it.
	fresh()
	add_bouncer(g.SCARY, Vector2(300, 600))
	draw([Vector2(300, 200), Vector2(300, 540)])
	g.step_bouncers(1.0 / 60.0)
	check(g.lives == 3, "bat not yet touching the trail")
	draw_more([Vector2(300, 540), Vector2(300, 620)])
	g.step_bouncers(1.0 / 60.0)
	check(g.lives == 2 and not g.stroke_active, "bat touching the trail snaps it and costs a life")

	# Scary loop: up into Cute, across, and back down into Scary.
	fresh()
	add_bouncer(g.CUTE, Vector2(80, 80))
	before = g.scary_percent()
	draw([Vector2(320, 600), Vector2(320, 150), Vector2(440, 150), Vector2(440, 600)])
	after = g.scary_percent()
	check(after > before + 3.0, "closing a loop claims the enclosed pocket (%.1f%% -> %.1f%%)" % [before, after])

	# Strokes that never leave their own territory do nothing.
	fresh()
	before = g.scary_percent()
	draw([Vector2(100, 100), Vector2(500, 120)])
	g.end_stroke()
	check(absf(g.scary_percent() - before) < 0.01, "doodling inside your own territory changes nothing")

	g.start_endless()
	check(g.mode == "endless" and g.bouncers.size() == 2, "endless mode starts with 2 bouncers")
	for b in g.bouncers:
		b.node.queue_free()
	g.bouncers.clear()
	for i in 60 * 13:
		g.clock += 1.0 / 60.0
		g.step_endless(1.0 / 60.0)
	check(g.score > 0.0, "endless scores while inside the band")

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
