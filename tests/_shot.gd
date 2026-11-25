extends SceneTree
var g
var f := 0
func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("/home/claude/shot/%s.png" % n)
func _process(_d: float) -> bool:
	f += 1
	match f:
		30: shot("g_menu_cute")
		31: g.menu_t = 4.0; g.werecat.snap(1.0)
		60: shot("g_menu_scary")
		61:
			g.start_level(); g.werecat.snap(0.5)
			g.bouncers[0].pos = Vector2(500, 120); g.bouncers[1].pos = Vector2(520, 600)
			g.begin_stroke(Vector2(120, 300))
			for k in 40:
				var t := k / 39.0
				g.move_stroke(Vector2(120 + 160 * sin(t * 2.5), 300 + t * 300))
		75: shot("g_play_stroke")
		76:
			for k in 30:
				g.move_stroke(Vector2(280 - k * 9, 600 + k * 6))
		82: shot("g_play_flip")
		120: shot("g_play_after")
		121:
			g.begin_stroke(Vector2(600, 600))
			for k in 60:
				g.move_stroke(Vector2(600 - k * 9, 600 - k * 8 + 40 * sin(k * 0.2)))
		200:
			g.werecat.snap(0.9)
		240: shot("g_play_scary"); return true
	return false
