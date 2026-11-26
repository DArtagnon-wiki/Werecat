extends Node2D
class_name Werecat
## Layered werecat rig. All layers share an 800x800 canvas (see tools/gen_art.py).
## `front` holds the parts that must draw over the playfield (mantis arms,
## paws on the frame); add it to the scene after the field with the same
## transform as this node.
##
## Morph tiers (scary %):  0 cute | 1 darkening | 2 horns, ears, peeking arms
##                         3 glowing eyes, fangs, raised arms | 4 full beast

signal tier_changed(new_tier: int, old_tier: int)

const SP := "res://assets/sprites/"
const HC := Vector2(400, 380)
const SHOULDER := Vector2(590, 620)
const PERCH := Vector2(400, 700)      # canvas point that sits on the field's top edge
const ARM := {
	"arm_coxa": [Vector2(30, 40), Vector2(140, 40)],
	"arm_femur": [Vector2(30, 50), Vector2(290, 50)],
	"arm_tibia": [Vector2(24, 40), Vector2(236, 40)],
}
const SPIKE_SCALE := [0.0, 0.7, 0.82, 0.92, 1.0]
const HORN_SCALE := [0.0, 0.0, 0.6, 0.85, 1.0]

var morph := 0.0          # displayed morph, eases toward target
var target := 0.0
var tier := 0
var front: Node2D
var rig: Node2D
var front_rig: Node2D
var L := {}
var pivots := {}
var arm_sprites: Array = []   # two arrays (right, left) of 3 sprites
var arm_roots: Array = []
var t := 0.0
var blink_until := 0.0
var next_blink := 2.5
var strike_t := -1.0
var next_auto_strike := 4.0
var pop := 0.0
var spike_s := 0.0
var horn_s := 0.0
var arm_s := 0.0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	rig = Node2D.new()
	add_child(rig)
	front = Node2D.new()
	front_rig = Node2D.new()
	front.add_child(front_rig)

	_pivot_layer("wc_spikes", rig, HC)
	_layer("wc_body_cute", rig)
	_layer("wc_body_scary", rig)
	_layer("wc_ears_cute", rig)
	_layer("wc_ears_scary", rig)
	_pivot_layer("wc_horns", rig, Vector2(400, 232))
	_layer("wc_head_cute", rig)
	_layer("wc_head_scary", rig)
	_layer("wc_muzzle_cute", rig)
	_layer("wc_muzzle_scary", rig)
	_layer("wc_whiskers", rig)
	_layer("wc_eyes_cute", rig)
	_layer("wc_eyes_blink", rig)
	var glow := _layer("wc_eye_glow", rig)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	_layer("wc_eyes_scary", rig)
	_layer("wc_mouth_cute", rig)
	_layer("wc_mouth_scary", rig)
	_pivot_layer("wc_drool", rig, Vector2(444, 520))

	# mantis arms: right arm, and a mirrored copy for the left
	for side in 2:
		var holder := Node2D.new()
		if side == 1:
			holder.position = Vector2(800, 0)
			holder.scale = Vector2(-1, 1)
		front_rig.add_child(holder)
		var root := Node2D.new()
		holder.add_child(root)
		arm_roots.append(root)
		var segs: Array = []
		for n in ["arm_coxa", "arm_femur", "arm_tibia"]:
			var s := Sprite2D.new()
			s.texture = SpriteCrops.cropped(n, load(SP + n + ".png"))
			s.centered = false
			s.offset = -ARM[n][0]
			root.add_child(s)
			segs.append(s)
		arm_sprites.append(segs)
	_layer("wc_paws", front_rig)
	_layer("wc_paws_scary", front_rig)


func _layer(n: String, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteCrops.cropped(n, load(SP + n + ".png"))
	s.centered = false
	parent.add_child(s)
	L[n] = s
	return s


func _pivot_layer(n: String, parent: Node, p: Vector2) -> Sprite2D:
	var pv := Node2D.new()
	pv.position = p
	parent.add_child(pv)
	var s := _layer(n, pv)
	s.position = -p
	pivots[n] = pv
	return s


func set_target(v: float) -> void:
	target = clampf(v, 0.0, 1.0)


func snap(v: float) -> void:
	target = clampf(v, 0.0, 1.0)
	morph = target
	tier = tier_for(morph)
	spike_s = SPIKE_SCALE[tier]
	horn_s = HORN_SCALE[tier]


func strike() -> void:
	if tier >= 2:
		strike_t = 0.0


static func tier_for(m: float) -> int:
	return 0 if m < 0.2 else 1 if m < 0.4 else 2 if m < 0.6 else 3 if m < 0.8 else 4


func _ramp(v: float, a: float, b: float) -> float:
	return clampf((v - a) / (b - a), 0.0, 1.0)


func _process(delta: float) -> void:
	t += delta
	morph = move_toward(morph, target, delta * 0.5)
	var nt := tier_for(morph)
	if nt != tier:
		var old := tier
		tier = nt
		pop = 1.0
		tier_changed.emit(nt, old)
	pop = maxf(0.0, pop - delta * 3.0)

	var fur := _ramp(morph, 0.15, 0.65)
	L.wc_body_cute.modulate.a = 1.0 - fur
	L.wc_head_cute.modulate.a = 1.0 - fur
	L.wc_body_scary.modulate.a = fur
	L.wc_head_scary.modulate.a = fur
	# fully faded layers still cost GPU time unless hidden
	L.wc_body_cute.visible = fur < 0.999
	L.wc_head_cute.visible = fur < 0.999
	L.wc_body_scary.visible = fur > 0.001
	L.wc_head_scary.visible = fur > 0.001

	spike_s = move_toward(spike_s, SPIKE_SCALE[tier], delta * 1.5)
	horn_s = move_toward(horn_s, HORN_SCALE[tier], delta * 1.2)
	var spike_breathe := 1.0 + 0.03 * sin(t * 3.0) * float(tier >= 3)
	pivots.wc_spikes.scale = Vector2.ONE * spike_s * spike_breathe
	L.wc_spikes.visible = spike_s > 0.01
	pivots.wc_horns.scale = Vector2.ONE * horn_s
	L.wc_horns.visible = horn_s > 0.01

	var scary_face := tier >= 3
	L.wc_ears_cute.visible = tier < 2
	L.wc_ears_scary.visible = tier >= 2
	L.wc_muzzle_cute.visible = tier < 2
	L.wc_muzzle_scary.visible = tier >= 2
	L.wc_whiskers.visible = tier < 3
	L.wc_whiskers.modulate.a = 1.0 if tier < 2 else 0.55
	L.wc_mouth_cute.visible = not scary_face
	L.wc_mouth_scary.visible = scary_face
	L.wc_drool.visible = scary_face
	L.wc_eyes_scary.visible = scary_face
	L.wc_eye_glow.visible = scary_face
	L.wc_paws.visible = tier < 2
	L.wc_paws_scary.visible = tier >= 2

	# blink (cute eyes only)
	if t >= next_blink:
		blink_until = t + 0.13
		next_blink = t + rng.randf_range(2.2, 5.0)
	var blinking := t < blink_until
	L.wc_eyes_cute.visible = not scary_face and not blinking
	L.wc_eyes_blink.visible = not scary_face and blinking

	L.wc_eye_glow.modulate.a = (0.55 if tier == 3 else 0.8) + 0.2 * sin(t * 5.0)
	pivots.wc_drool.scale = Vector2(1.0, 1.0 + 0.3 * (0.5 + 0.5 * sin(t * 2.1)))

	# breathing + tier pop, pivoting at the perch point
	var sq := 1.0 + 0.012 * sin(t * 2.2) + 0.07 * pop * sin(pop * 12.0)
	var sx := 1.0 - 0.04 * pop * sin(pop * 12.0)
	var jit := Vector2.ZERO
	if tier == 4:
		jit = Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1, 1)) if rng.randf() < 0.3 else Vector2.ZERO
	rig.scale = Vector2(sx, sq)
	rig.position = PERCH - PERCH * rig.scale + jit
	front_rig.scale = rig.scale
	front_rig.position = rig.position

	_update_arms(delta)


func _update_arms(delta: float) -> void:
	var want := 0.0 if tier < 2 else (0.72 if tier == 2 else 1.0)
	arm_s = move_toward(arm_s, want, delta * 2.0)
	var show := arm_s > 0.01
	for r in arm_roots:
		r.visible = show
	if not show:
		return
	if tier == 4 and t >= next_auto_strike:
		strike()
		next_auto_strike = t + rng.randf_range(3.0, 6.0)
	var s := 0.0
	if strike_t >= 0.0:
		strike_t += delta
		if strike_t < 0.1:
			s = strike_t / 0.1
		elif strike_t < 0.22:
			s = 1.0
		elif strike_t < 0.5:
			s = 1.0 - (strike_t - 0.22) / 0.28
		else:
			strike_t = -1.0
	var twitch := sin(t * 7.0) * 2.0 + sin(t * 13.0) * 1.0
	var a1 := deg_to_rad(-50.0 + 30.0 * s + twitch * 0.3)
	var a2 := deg_to_rad(-70.0 + 80.0 * s + twitch)
	var a3 := deg_to_rad(155.0 - 75.0 * s - twitch * 1.5)
	for side in 2:
		var root: Node2D = arm_roots[side]
		root.scale = Vector2.ONE * arm_s
		root.position = SHOULDER * (1.0 - arm_s)
		var p := SHOULDER
		var segs: Array = arm_sprites[side]
		var names := ["arm_coxa", "arm_femur", "arm_tibia"]
		var angs := [a1, a2, a3]
		for k in 3:
			# sprites use plain canvas coords; root scales them about the shoulder
			var spr: Sprite2D = segs[k]
			spr.position = p
			spr.rotation = angs[k]
			var seg_len: float = (ARM[names[k]][1] - ARM[names[k]][0]).length()
			p += Vector2(cos(angs[k]), sin(angs[k])) * seg_len
