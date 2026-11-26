class_name Levels
## Level data and starting-layout generators.
##
## Goals are always in Scary % (0-100). The HUD shows "Make it CUTE" with the
## mirrored numbers when the band sits below 50.
##
## Bouncer entry: {kind, side, count, speed}. kind = basic | stalker | wisp |
## carver | boss. side = 0 Cute, 1 Scary.
## Item entry: {kind, side, at: Vector2(u, v)} with u, v in 0..1 of the field.
## kind = bomb | charm | nest | seed.

const CUTE := 0
const SCARY := 1
const STONE := 2

const WORLDS := ["Moonrise", "Moonstone", "Creeping Dark", "Hallowed Ground", "Blood Moon", "The Hunt"]

const TIPS := {
	"claim": ["Claim ground", "Drag from the Scary side into the Cute side and back. Then the wall grows from both ends. If a bouncer touches it before the ends meet, it snaps!"],
	"band": ["Hit the gold band", "Keep the meter inside the gold band for 3 seconds. Going too far counts as missing."],
	"trap": ["Trap them", "Squeeze a bouncer into a tiny pocket and it's captured. Its pocket flips too."],
	"bomb": ["Bombs", "Grow a wall through a bomb. Boom: everything nearby turns your color."],
	"stone": ["Moonstone", "Stone belongs to nobody. Bouncers bounce off it, and your trail can end on it like the edge."],
	"charm": ["Moon charms", "Grow a wall through a charm to freeze every bouncer for 4 seconds."],
	"grub": ["Gloom grubs", "Grubs tunnel through Cute land, turning it Scary. Claim the ground under one to squash it."],
	"slug": ["Sugar slugs", "Slugs paint sweet trails through Scary land. Claim the ground under one to stop it."],
	"seed": ["Thorn seeds", "Seeds keep spreading their color. Claim the ground they sit on to pull them out."],
	"nest": ["Bat roosts", "Roosts hatch a new bat every few seconds until you claim the ground under them."],
	"wisp": ["Wisps", "Wisps drift through every territory, and they snap any trail they touch."],
	"stalker": ["Hunters", "Hunter bats chase the growing ends of your wall. Keep walls short, or bait them away."],
	"boss": ["The Night Mother", "She hunts your growing walls, and her roost keeps hatching bats. Trap her to break the spell."],
	"balance": ["Small steps", "Going past the band counts as missing. Get close with big claims, then finish with small ones."],
	"finale": ["World finale", "Everything from this world, all at once. Take it one claim at a time."],
	"remix": ["The Hunt", "No new tricks tonight, just old ones in new company. Read the field before you draw."],
	"lastidol": ["The Last Idol", "Two idols, a crowned bat, a cursed shrine and ground to hold. Break the curse first."],
	"hold": ["Hold the ground", "A flagged ring must be held to win. Its label says which color: fill it 60% with that color, and keep it that way."],
	"shrine": ["Shrines", "While its color holds a shrine, it changes the rules. Take this one for Cute and your walls grow fast."],
	"curl": ["Straight lines", "Tonight your lines only go straight: aim, then push. Take the quill shrine for Cute to free them."],
	"arcs": ["Gentle arcs", "Your line turns slowly tonight and trails your finger like a leash. Plan wide curves."],
	"curse": ["Curses", "Shrines held by Scary curse you: slow walls, fast creatures. Take them back to lift the curse."],
	"idol": ["The bone idol", "The idol must fall before you can win. Claim the ground under it for Cute, even though tonight you want Scary."],
	"idols": ["Sugar idols", "Both idols must fall. Claim the Cute ground they stand on, then make the night Cute again."],
	"elite": ["The crowned bat", "The crowned bat must be trapped before you can win. Squeeze it into a tiny pocket."],
}

static func _b(kind: String, side: int, count := 1, speed := 1.0) -> Dictionary:
	return {"kind": kind, "side": side, "count": count, "speed": speed}


static func _i(kind: String, side: int, u: float, v: float) -> Dictionary:
	return {"kind": kind, "side": side, "at": Vector2(u, v)}


## Zone: kind "hold" (must be held by `side` to win) or "shrine" (its effect
## is active while `side` holds it). r is a fraction of the field's width.
static func _z(kind: String, side: int, u: float, v: float, r: float, effect := "") -> Dictionary:
	return {"kind": kind, "side": side, "at": Vector2(u, v), "r": r, "effect": effect}


static func all() -> Array:
	return [
		# ================================================ World 1: Moonrise - learn the claim
		{"id": "1-1", "name": "First Claim", "layout": ["split_h", 0.55], "goal": [60, 80], "par": 40,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [], "tip": "claim"},
		{"id": "1-2", "name": "Sweet Revenge", "layout": ["split_h", 0.45], "goal": [20, 40], "par": 45,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [], "tip": "band"},
		{"id": "1-3", "name": "Steady Paws", "layout": ["split_v", 0.7], "goal": [45, 55], "par": 50,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [], "tip": "balance"},
		{"id": "1-4", "name": "Trapped!", "layout": ["island", 0.27, SCARY], "goal": [70, 85], "par": 60,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY)], "items": [], "tip": "trap"},
		{"id": "1-5", "name": "Balancing Act", "layout": ["checker", 3, 4], "goal": [37, 41], "par": 70,
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY, 3)], "items": [], "tip": "finale"},
		# ================================================ World 2: Moonstone - tools that help
		{"id": "2-1", "name": "Boom", "layout": ["split_v", 0.5], "goal": [75, 90], "par": 50,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("bomb", 0, 0.22, 0.25), _i("bomb", 0, 0.3, 0.55), _i("bomb", 0, 0.2, 0.82)], "tip": "bomb"},
		{"id": "2-2", "name": "Moonstones", "layout": ["split_h", 0.5], "stone": ["pillars", 5], "goal": [14, 32], "par": 60,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [], "tip": "stone"},
		{"id": "2-3", "name": "Frozen Stiff", "layout": ["split_h", 0.4], "goal": [25, 40], "par": 60,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2, 1.25)],
		 "items": [_i("charm", 0, 0.25, 0.65), _i("charm", 0, 0.75, 0.8)], "tip": "charm"},
		{"id": "2-4", "name": "Hold the Altar", "layout": ["split_h", 0.5], "goal": [56, 68], "par": 60,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [],
		 "zones": [_z("hold", SCARY, 0.5, 0.26, 0.14)], "tip": "hold"},
		{"id": "2-5", "name": "Rubble", "layout": ["island", 0.3, CUTE], "stone": ["cross"], "goal": [42, 48], "par": 80,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY, 3)],
		 "items": [_i("bomb", 0, 0.2, 0.2), _i("bomb", 0, 0.8, 0.2), _i("bomb", 0, 0.2, 0.8), _i("charm", 0, 0.8, 0.8)],
		 "zones": [_z("hold", CUTE, 0.16, 0.86, 0.1)], "tip": "finale"},
		# ================================================ World 3: Creeping Dark - threats that grow
		{"id": "3-1", "name": "Thorns", "layout": ["split_v", 0.55], "goal": [6, 18], "par": 70,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("seed", SCARY, 0.66, 0.3), _i("seed", SCARY, 0.68, 0.75)], "tip": "seed"},
		{"id": "3-2", "name": "The Roost", "layout": ["corners", 0.32], "goal": [6, 16], "par": 75,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("nest", SCARY, 0.12, 0.1), _i("nest", SCARY, 0.88, 0.9)], "tip": "nest"},
		{"id": "3-3", "name": "Gloom Grub", "layout": ["split_h", 0.6], "goal": [10, 22], "par": 75,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY), _b("carver", SCARY)], "items": [], "tip": "grub"},
		{"id": "3-4", "name": "Sugar Slug", "layout": ["split_h", 0.4], "goal": [75, 90], "par": 75,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY), _b("carver", CUTE)],
		 "items": [_i("seed", CUTE, 0.3, 0.3)], "tip": "slug"},
		{"id": "3-5", "name": "Overgrowth", "layout": ["checker", 2, 3], "goal": [75, 81], "par": 100,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY), _b("carver", CUTE), _b("carver", SCARY)],
		 "items": [_i("seed", CUTE, 0.25, 0.17), _i("seed", SCARY, 0.75, 0.17), _i("nest", SCARY, 0.25, 0.5), _i("seed", CUTE, 0.75, 0.5), _i("seed", CUTE, 0.25, 0.83)], "tip": "finale"},
		# ================================================ World 4: Hallowed Ground - rules that change
		{"id": "4-1", "name": "Swift Shrine", "layout": ["split_v", 0.5], "goal": [65, 80], "par": 60,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [],
		 "zones": [_z("shrine", CUTE, 0.24, 0.5, 0.12, "swift")], "tip": "shrine"},
		{"id": "4-2", "name": "Straight and Narrow", "layout": ["split_h", 0.45], "curl": "straight", "goal": [20, 35], "par": 75,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [],
		 "zones": [_z("shrine", CUTE, 0.5, 0.74, 0.13, "true")], "tip": "curl"},
		{"id": "4-3", "name": "Gentle Arcs", "layout": ["corners", 0.32], "curl": "arc", "goal": [10, 20], "par": 85,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [],
		 "zones": [_z("hold", CUTE, 0.13, 0.11, 0.1), _z("hold", CUTE, 0.87, 0.89, 0.1)], "tip": "arcs"},
		{"id": "4-4", "name": "Cursed Ground", "layout": ["checker", 2, 3], "goal": [60, 70], "par": 95,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [],
		 "zones": [_z("shrine", SCARY, 0.75, 0.167, 0.12, "slow"), _z("shrine", SCARY, 0.25, 0.5, 0.12, "haste"),
			_z("hold", SCARY, 0.75, 0.5, 0.12)], "tip": "curse"},
		{"id": "4-5", "name": "Rings", "layout": ["rings", 4], "stone": ["ring", 0.42], "goal": [76, 86], "par": 100,
		 "bouncers": [_b("basic", SCARY, 2), _b("stalker", CUTE), _b("basic", CUTE)],
		 "items": [_i("charm", 0, 0.15, 0.12), _i("charm", 0, 0.85, 0.88)],
		 "zones": [_z("shrine", CUTE, 0.5, 0.5, 0.1, "calm"), _z("shrine", SCARY, 0.86, 0.12, 0.09, "arc")], "tip": "finale"},
		# ================================================ World 5: Blood Moon - hunters of the night
		{"id": "5-1", "name": "Bone Idol", "layout": ["split_h", 0.5], "goal": [65, 80], "par": 85,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("idol", SCARY, 0.5, 0.86)], "tip": "idol"},
		{"id": "5-2", "name": "Crowned Bat", "layout": ["split_h", 0.5], "goal": [20, 35], "par": 95,
		 "bouncers": [_b("basic", CUTE), _b("elite", SCARY)], "items": [], "tip": "elite"},
		{"id": "5-3", "name": "Will-o'-Wisps", "layout": ["split_h", 0.5], "goal": [70, 85], "par": 70,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY), _b("wisp", SCARY, 2)], "items": [], "tip": "wisp"},
		{"id": "5-4", "name": "Hunters", "layout": ["split_h", 0.5], "goal": [15, 30], "par": 80,
		 "bouncers": [_b("basic", CUTE), _b("stalker", SCARY, 2)], "items": [_i("charm", 0, 0.5, 0.25)], "tip": "stalker"},
		{"id": "5-5", "name": "Night Mother", "layout": ["island", 0.36, SCARY], "stone": ["pillars", 3], "goal": [0, 15], "par": 140,
		 "bouncers": [_b("boss", SCARY, 1, 0.75), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.5, 0.36), _i("charm", 0, 0.12, 0.1), _i("charm", 0, 0.88, 0.9), _i("bomb", 0, 0.1, 0.9)], "tip": "boss"},
		# ================================================ World 6: The Hunt - mastery
		{"id": "6-1", "name": "Witching Hour", "layout": ["stripes", 5], "goal": [64, 72], "par": 120,
		 "bouncers": [_b("basic", CUTE), _b("stalker", CUTE), _b("stalker", SCARY), _b("wisp", SCARY)],
		 "items": [_i("seed", SCARY, 0.2, 0.75), _i("bomb", 0, 0.8, 0.2)],
		 "zones": [_z("shrine", CUTE, 0.8, 0.8, 0.1, "swift"), _z("hold", SCARY, 0.2, 0.2, 0.1)], "tip": "remix"},
		{"id": "6-2", "name": "Spiral", "layout": ["spiral"], "goal": [84, 92], "par": 110,
		 "bouncers": [_b("basic", CUTE), _b("stalker", CUTE, 2), _b("basic", SCARY)],
		 "items": [_i("nest", CUTE, 0.5, 0.5), _i("bomb", 0, 0.2, 0.2), _i("bomb", 0, 0.8, 0.3), _i("bomb", 0, 0.3, 0.85)], "tip": "remix"},
		{"id": "6-3", "name": "Sugar Idols", "layout": ["split_h", 0.5], "curl": "curly", "goal": [15, 30], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("idol", CUTE, 0.18, 0.12), _i("idol", CUTE, 0.82, 0.16)], "tip": "idols"},
		{"id": "6-4", "name": "Curled Hunt", "layout": ["split_v", 0.5], "curl": "curly", "goal": [38, 46], "par": 110,
		 "bouncers": [_b("elite", CUTE), _b("basic", SCARY)],
		 "items": [_i("idol", SCARY, 0.86, 0.5)], "tip": "remix"},
		{"id": "6-5", "name": "The Last Idol", "layout": ["rings", 4], "goal": [75, 90], "par": 160,
		 "bouncers": [_b("basic", CUTE), _b("elite", SCARY), _b("basic", SCARY)],
		 "items": [_i("idol", SCARY, 0.5, 0.5), _i("idol", CUTE, 0.14, 0.13)],
		 "zones": [_z("hold", CUTE, 0.84, 0.86, 0.1), _z("shrine", SCARY, 0.16, 0.84, 0.1, "straight")], "tip": "lastidol"},
	]


static func count() -> int:
	return all().size()


# ------------------------------------------------------------------ layouts

## Returns a mask (values CUTE/SCARY/STONE) of gw x gh cells, plus `under`
## (territory beneath stone) in the second array.
static func build(level: Dictionary, gw: int, gh: int) -> Array:
	var mask := PackedByteArray()
	mask.resize(gw * gh)
	var lay: Array = level.layout
	var asp := float(gw) / float(gh)
	for y in gh:
		for x in gw:
			var u := (x + 0.5) / gw
			var v := (y + 0.5) / gh
			mask[y * gw + x] = _layout_at(lay, u, v, asp)
	var under := mask.duplicate()
	if level.has("stone"):
		var st: Array = level.stone
		for y in gh:
			for x in gw:
				if _stone_at(st, (x + 0.5) / gw, (y + 0.5) / gh, asp):
					mask[y * gw + x] = STONE
	return [mask, under]


static func _wave(t: float, a: float) -> float:
	return a * (sin(t * 11.0) * 0.6 + sin(t * 27.0 + 1.0) * 0.3)


static func _layout_at(lay: Array, u: float, v: float, asp: float) -> int:
	match lay[0]:
		"split_h":
			return CUTE if v < float(lay[1]) + _wave(u, 0.035) else SCARY
		"split_v":
			return CUTE if u < float(lay[1]) + _wave(v, 0.03) else SCARY
		"island":
			var d := Vector2((u - 0.5) * asp, v - 0.5).length()
			var ang := atan2(v - 0.5, u - 0.5)
			var r: float = float(lay[1]) * (1.0 + 0.08 * sin(ang * 5.0) + 0.04 * sin(ang * 9.0 + 1.0))
			return int(lay[2]) if d < r else 1 - int(lay[2])
		"checker":
			var cx := int(floor((u + _wave(v, 0.012)) * float(lay[1])))
			var cy := int(floor((v + _wave(u, 0.012)) * float(lay[2])))
			return posmod(cx + cy, 2)
		"stripes":
			var s: float = (u + v * 0.8 + _wave(u - v, 0.02)) * float(lay[1]) * 0.6
			return posmod(int(floor(s)), 2)
		"corners":
			var near: float = min(min(Vector2(u * asp, v).length(), Vector2((1 - u) * asp, 1 - v).length()),
				min(Vector2((1 - u) * asp, v).length(), Vector2(u * asp, 1 - v).length()))
			return SCARY if near < float(lay[1]) + _wave(u + v, 0.02) else CUTE
		"rings":
			var d2 := Vector2((u - 0.5) * asp, v - 0.5).length()
			return posmod(int(floor(d2 * float(lay[1]) * 2.2 + _wave(atan2(v - 0.5, u - 0.5), 0.05))), 2)
		"spiral":
			var p := Vector2((u - 0.5) * asp, v - 0.5)
			var a := atan2(p.y, p.x)
			var k := fposmod(p.length() * 9.0 - a / TAU * 2.0, 2.0)
			return CUTE if k < 1.0 else SCARY
	return CUTE


static func _stone_at(st: Array, u: float, v: float, asp: float) -> bool:
	match st[0]:
		"pillars":
			var n: int = st[1]
			for i in n:
				var c := Vector2(0.15 + 0.7 * fmod(i * 0.618 + 0.1, 1.0), 0.15 + 0.7 * (float(i) + 0.5) / n)
				var d := Vector2((u - c.x) * asp, v - c.y).length()
				if d < 0.045 + 0.008 * sin(i * 3.0):
					return true
		"cross":
			var w := 0.035
			if absf(u - 0.5) < w and absf(v - 0.5) < 0.3:
				return true
			if absf(v - 0.5) < w * asp and absf(u - 0.5) < 0.3:
				return true
		"ring":
			var d2 := Vector2((u - 0.5) * asp, v - 0.5).length()
			var ang := atan2(v - 0.5, u - 0.5)
			# a broken ring: four gaps so bouncers can cross
			if absf(d2 - float(st[1]) * 0.75) < 0.022 and fposmod(ang, PI / 2.0) > 0.35:
				return true
	return false
