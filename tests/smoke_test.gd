extends SceneTree
## Headless smoke tests, run in CI:
##   godot --headless --path . -s res://tests/smoke_test.gd

var failures := 0
var main


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		printerr("FAIL  ", msg)
		failures += 1


func at(x: float, y: float) -> Vector2:
	return main.ORIGIN + Vector2(x, y) * main.CELL


func run_wall(frames: int = 240) -> void:
	for i in frames:
		main.step_bouncers(1.0 / 60.0)
		main.step_wall(1.0 / 60.0)


func fresh() -> void:
	main.start_level()
	main.bouncers.clear()


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

	fresh()
	check(absf(main.scary_percent() - 50.0) < 0.01, "level starts 50/50")

	# Rows 0-17 are Cute, 18-35 Scary. Touching just above the border and
	# swiping up anchors on Scary and grows a Scary wall into Cute.
	fresh()
	main.bouncers.append({"pos": Vector2(15.5, 5.5) * main.CELL, "vel": Vector2.ZERO, "type": main.CUTE})
	check(main.try_start_wall(at(5.5, 17.5), Vector2i(0, -1)), "swipe from border into Cute starts a wall")
	check(main.wall != null and main.wall.color == main.SCARY, "wall takes the anchor's color (Scary)")
	run_wall()
	check(main.wall == null and main.lives == 3, "wall completes")
	# left pocket (cols 0-4, 18 rows) + wall column (18 cells) flip to Scary
	check(absf(main.scary_percent() - 62.5) < 0.01, "only the empty pocket flips (62.5% Scary)")

	fresh()
	check(not main.try_start_wall(at(10.5, 5.5), Vector2i(1, 0)), "can't draw a wall inside its own territory")

	# Snap: touching 2 cells above the border still finds the anchor.
	fresh()
	check(main.try_start_wall(at(8.5, 20.5), Vector2i(0, -1)), "touch near the border snaps to it")

	# A new wall may anchor on a finished wall of the opposite color.
	fresh()
	main.bouncers.append({"pos": Vector2(15.5, 5.5) * main.CELL, "vel": Vector2.ZERO, "type": main.CUTE})
	main.try_start_wall(at(5.5, 17.5), Vector2i(0, -1))
	run_wall()
	check(main.try_start_wall(at(6.5, 3.5), Vector2i(1, 0)), "wall can anchor on a finished wall")

	# A Scary bouncer in the path breaks a Cute wall growing into Scary.
	fresh()
	main.bouncers.append({"pos": Vector2(10.5, 25.5) * main.CELL, "vel": Vector2.ZERO, "type": main.SCARY})
	check(main.try_start_wall(at(10.5, 17.5), Vector2i(0, 1)), "swipe from border into Scary starts a wall")
	run_wall()
	check(main.lives == 2, "bouncer breaks a growing wall")

	# Colored frame segments are anchors (bottom cols 8-15 are Cute) but
	# plain frame is not, and frame never counts toward the %.
	fresh()
	check(main.try_start_wall(at(10.5, 35.5), Vector2i(0, -1)), "Cute frame segment anchors a wall into Scary")
	fresh()
	check(not main.try_start_wall(at(2.5, 35.5), Vector2i(0, -1)), "plain frame is not an anchor")
	check(absf(main.scary_percent() - 50.0) < 0.01, "frame segments don't count toward the %")

	main.start_endless()
	check(main.mode == "endless" and main.bouncers.size() == 2, "endless mode starts with 2 bouncers")
	main.bouncers.clear()
	for i in 60 * 13:
		main.clock += 1.0 / 60.0
		main.step_endless(1.0 / 60.0)
	check(main.score > 0.0, "endless scores while inside the band")

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
