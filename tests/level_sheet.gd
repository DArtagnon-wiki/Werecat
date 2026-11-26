extends SceneTree
## Contact sheet of every level's starting layout (Cute pink, Scary dark red,
## stone grey, items as dots, zones as rings): build/levels.png
##   godot --headless --path . -s res://tests/level_sheet.gd

const GW := 160
const GH := 186
const COLS := 10


func _initialize() -> void:
	var lv_all: Array = Levels.all()
	var tw := GW
	var th := GH
	var rows := int(ceil(lv_all.size() / float(COLS)))
	var sheet := Image.create(COLS * (tw + 6), rows * (th + 6), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.06, 0.12))
	for n in lv_all.size():
		var lv: Dictionary = lv_all[n]
		var built: Array = Levels.build(lv, GW, GH)
		var m: PackedByteArray = built[0]
		var img := Image.create(GW, GH, false, Image.FORMAT_RGB8)
		for y in GH:
			for x in GW:
				var v := m[y * GW + x]
				img.set_pixel(x, y, Color(1, 0.8, 0.9) if v == 0 else Color(0.35, 0.05, 0.1) if v == 1 else Color(0.55, 0.52, 0.65))
		for it in lv.get("items", []):
			var p := Vector2i(int(it.at.x * GW), int(it.at.y * GH))
			var col := Color(0.2, 0.9, 1) if it.kind == "lantern" else Color(1, 0.85, 0.2) if it.kind in ["nest", "den", "burrow"] else Color(0.2, 1, 0.3)
			img.fill_rect(Rect2i(p - Vector2i(3, 3), Vector2i(7, 7)), col)
		for z in lv.get("zones", []):
			var c := Vector2(z.at.x * GW, z.at.y * GH)
			var r: float = z.r * GW
			for k in 64:
				var q := c + Vector2.from_angle(TAU * k / 64.0) * r
				if q.x >= 0 and q.y >= 0 and q.x < GW and q.y < GH:
					img.set_pixelv(Vector2i(q), Color(1, 0.4, 0.7) if z.side == 0 else Color(1, 0.5, 0.1))
		sheet.blit_rect(img, Rect2i(0, 0, GW, GH), Vector2i((n % COLS) * (tw + 6) + 3, (n / COLS) * (th + 6) + 3))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	sheet.save_png("res://build/levels.png")
	print("wrote build/levels.png (%d levels)" % lv_all.size())
	quit()
