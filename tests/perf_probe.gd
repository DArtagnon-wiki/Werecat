extends SceneTree
## CPU cost probe (headless, so no GPU): average per-frame process time on the
## title screen and in a few busy levels.
##   godot --headless --path . -s res://tests/perf_probe.gd

var g
var frame := 0
var phase := 0
var acc := 0.0
var n := 0
var phases := [["title", -1], ["1-1", 0], ["5-5", 24], ["6-5", 29]]


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 30:
		return false
	acc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	n += 1
	if n < 240:
		return false
	print("PROBE %-6s process %.2f ms/frame  (game %.2f)  nodes %d" % [phases[phase][0], acc / n, g.perf.game,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	acc = 0.0
	n = 0
	phase += 1
	frame = 0
	if phase >= phases.size():
		return true
	g.level_idx = phases[phase][1]
	g.level = g.levels[g.level_idx]
	g.begin_play()
	return false
