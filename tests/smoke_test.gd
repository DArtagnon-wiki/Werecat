extends SceneTree
## Headless smoke test, run in CI:
##   godot --headless --path . -s res://tests/smoke_test.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		printerr("FAIL  ", msg)
		failures += 1


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.reset_level()

	check(absf(main.scary_percent() - 50.0) < 0.01, "level starts 50/50")

	# With no bouncers, a full-width Cute wall should flip every pocket to Cute.
	main.bouncers.clear()
	main.try_start_wall(main.ORIGIN + Vector2(5.5, 5.5) * main.CELL, true)
	check(main.wall != null, "swipe starts a wall")
	for i in 200:
		main.step_wall(1.0 / 60.0)
	check(main.wall == null, "wall completes")
	check(main.scary_percent() < 0.01, "empty pockets flip to the wall's color")

	# A bouncer in the wall's path breaks it and costs a life.
	main.reset_level()
	main.bouncers.clear()
	main.bouncers.append({"pos": Vector2(10.5, 25.5) * main.CELL, "vel": Vector2.ZERO, "type": main.SCARY})
	main.try_start_wall(main.ORIGIN + Vector2(3.5, 25.5) * main.CELL, true)
	for i in 120:
		main.step_wall(1.0 / 60.0)
		main.step_bouncers(1.0 / 60.0)
	check(main.lives == 2, "bouncer breaks a growing wall")

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
