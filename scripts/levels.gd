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

const WORLDS := ["Moonrise", "Moonstone", "Creeping Dark", "Hallowed Ground", "Blood Moon", "The Hunt",
	"Gift Boxes", "Strange Shores", "Hunter Dens", "Burrows", "Lantern Light", "Stone Halls", "Bat Pens",
	"Shepherd", "Swarm", "Holy Orders", "Bone Yard", "Labyrinth", "Eclipse", "Midnight"]

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
	"gift": ["Gift boxes", "Gift boxes hatch fuzzies until their ground turns Scary. Tonight you need 3 fuzzies alive to win."],
	"fuzzies": ["Keep the fuzzies", "You need enough fuzzies alive to win. Trapping one counts against you, so give them room."],
	"pens": ["Lone bats", "Split the Scary ground so each bat is alone in its own pocket. A gold ring marks a lone bat. Don't make pockets so small you trap them!"],
	"pen2": ["Doors", "Bats slip through the doors between rooms. Draw a Cute wall across a doorway to shut it."],
	"den": ["Hunter dens", "Dens keep sending out hunter bats that chase your growing walls. Claim the den's ground to close it."],
	"huggy": ["Huggy huts", "Huggy puffs come out of this hut and chase your growing walls. Turn its ground Scary to shut it."],
	"burrow": ["Grub burrows", "Burrows keep sending out gloom grubs that tunnel Scary through Cute land. Claim the burrow to stop them."],
	"candy": ["Candy burrows", "Sugar slugs crawl out of this burrow and paint Cute trails. Turn its ground Scary to stop them."],
	"lantern": ["Wisp lanterns", "Lanterns keep releasing wisps that snap any wall. Take the lantern's ground to put it out."],
	"maze": ["Stone halls", "Stone walls make corridors. Your walls can end on stone, so short walls across a corridor go a long way."],
	"shores": ["Strange shores", "New ground shapes tonight. Look for narrow spots, where a short wall cuts off a lot."],
	"shepherd": ["Shepherd", "Keep the fuzzies safe while you corner the bats."],
	"swarm": ["Swarm", "Everything is hatching. Close the generators before they bury you."],
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
	return _classic() + _more()


static func _classic() -> Array:
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


## Worlds 7-20. Win conditions beyond the band: "fuzzies": N (that many Cute
## basics alive), "pens": N (that many bats each alone in its own pocket of
## Scary ground), plus idols, crowned creatures and hold rings as before.
static func _more() -> Array:
	return [
		# ================================================ World 7: Gift Boxes - fuzzies to keep
		{"id": "7-1", "name": "Special Delivery", "layout": ["split_h", 0.5], "goal": [30, 50], "par": 70, "fuzzies": 3,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("nest", CUTE, 0.5, 0.2)], "tip": "gift"},
		{"id": "7-2", "name": "Party Favors", "layout": ["split_v", 0.5], "goal": [55, 70], "par": 80, "fuzzies": 5,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)],
		 "items": [_i("nest", CUTE, 0.2, 0.25), _i("nest", CUTE, 0.2, 0.75)], "tip": "fuzzies"},
		{"id": "7-3", "name": "Pass the Parcel", "layout": ["island", 0.3, CUTE], "goal": [50, 65], "par": 85, "fuzzies": 4,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("nest", CUTE, 0.5, 0.5), _i("bomb", 0, 0.15, 0.12)], "tip": ""},
		{"id": "7-4", "name": "Wrapping Paper", "layout": ["stripes", 4], "goal": [40, 55], "par": 95, "fuzzies": 6,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)],
		 "items": [_i("nest", CUTE, 0.25, 0.3), _i("nest", CUTE, 0.75, 0.7)], "tip": ""},
		{"id": "7-5", "name": "Surprise Party", "layout": ["rings", 3], "goal": [45, 55], "par": 120, "fuzzies": 6,
		 "bouncers": [_b("basic", SCARY, 2)],
		 "items": [_i("nest", CUTE, 0.5, 0.5), _i("nest", CUTE, 0.15, 0.85), _i("nest", SCARY, 0.85, 0.15), _i("charm", 0, 0.15, 0.15)], "tip": "finale"},
		# ================================================ World 8: Strange Shores - new ground shapes
		{"id": "8-1", "name": "Driftwood", "layout": ["diag", 0.5], "goal": [60, 75], "par": 80,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [], "tip": "shores"},
		{"id": "8-2", "name": "Donut", "layout": ["donut", 0.18, 0.36, SCARY], "goal": [15, 30], "par": 90,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [], "tip": ""},
		{"id": "8-3", "name": "Archipelago", "layout": ["blobs", 6, SCARY, 0.11, 3], "goal": [55, 70], "par": 95,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY, 2)], "items": [], "tip": ""},
		{"id": "8-4", "name": "High Tide", "layout": ["waves", 0.5, 0.12, 2], "goal": [30, 45], "par": 95,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [_i("bomb", 0, 0.5, 0.2)], "tip": ""},
		{"id": "8-5", "name": "Hourglass", "layout": ["hourglass"], "stone": ["rocks", 4, 5], "goal": [47, 53], "par": 120,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY, 2)],
		 "items": [_i("seed", SCARY, 0.5, 0.1), _i("seed", CUTE, 0.1, 0.5)], "tip": "finale"},
		# ================================================ World 9: Hunter Dens - generators that hunt
		{"id": "9-1", "name": "The Den", "layout": ["split_h", 0.5], "goal": [12, 22], "par": 75,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("den", SCARY, 0.5, 0.8)], "tip": "den"},
		{"id": "9-2", "name": "Hug Hut", "layout": ["split_h", 0.5], "goal": [65, 85], "par": 75,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("den", CUTE, 0.5, 0.2)], "tip": "huggy"},
		{"id": "9-3", "name": "Den Mother", "layout": ["split_v", 0.5], "goal": [10, 25], "par": 95,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("den", SCARY, 0.8, 0.3), _i("nest", SCARY, 0.8, 0.75)], "tip": ""},
		{"id": "9-4", "name": "Ambush", "layout": ["checker", 2, 2], "goal": [60, 70], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("den", CUTE, 0.25, 0.25), _i("den", SCARY, 0.75, 0.25), _i("charm", 0, 0.5, 0.5)], "tip": ""},
		{"id": "9-5", "name": "Hunting Grounds", "layout": ["split_h", 0.45], "stone": ["pillars", 4], "goal": [20, 35], "par": 130,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY)],
		 "items": [_i("den", SCARY, 0.2, 0.85), _i("den", SCARY, 0.8, 0.85), _i("idol", SCARY, 0.5, 0.9), _i("charm", 0, 0.5, 0.2), _i("bomb", 0, 0.5, 0.6)], "tip": "finale"},
		# ================================================ World 10: Burrows - tunnelers on tap
		{"id": "10-1", "name": "Grub Burrow", "layout": ["split_h", 0.55], "goal": [15, 30], "par": 80,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("burrow", SCARY, 0.5, 0.82)], "tip": "burrow"},
		{"id": "10-2", "name": "Candy Burrow", "layout": ["split_h", 0.45], "goal": [70, 85], "par": 80,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("burrow", CUTE, 0.5, 0.18)], "tip": "candy"},
		{"id": "10-3", "name": "Tunnels", "layout": ["split_v", 0.5], "goal": [56, 66], "par": 95,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("burrow", SCARY, 0.82, 0.5), _i("burrow", CUTE, 0.18, 0.5)], "tip": ""},
		{"id": "10-4", "name": "Sweet Tooth", "layout": ["split_h", 0.5], "goal": [30, 45], "par": 100, "fuzzies": 4,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("burrow", CUTE, 0.3, 0.2), _i("nest", CUTE, 0.7, 0.2)], "tip": ""},
		{"id": "10-5", "name": "Undermine", "layout": ["checker", 3, 3], "goal": [60, 70], "par": 130,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)],
		 "items": [_i("burrow", SCARY, 0.5, 0.17), _i("burrow", SCARY, 0.17, 0.5), _i("burrow", CUTE, 0.5, 0.5), _i("bomb", 0, 0.83, 0.83), _i("bomb", 0, 0.17, 0.83)], "tip": "finale"},
		# ================================================ World 11: Lantern Light - wisps on tap
		{"id": "11-1", "name": "Lantern", "layout": ["split_h", 0.5], "goal": [60, 80], "par": 80,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("lantern", CUTE, 0.5, 0.25)], "tip": "lantern"},
		{"id": "11-2", "name": "Twin Lights", "layout": ["split_v", 0.5], "goal": [25, 40], "par": 95,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("lantern", SCARY, 0.8, 0.3), _i("lantern", CUTE, 0.2, 0.7), _i("charm", 0, 0.5, 0.5)], "tip": ""},
		{"id": "11-3", "name": "Night Watch", "layout": ["split_h", 0.4], "goal": [36, 46], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [_i("lantern", SCARY, 0.5, 0.88)], "tip": ""},
		{"id": "11-4", "name": "Ghost Lights", "layout": ["split_h", 0.5], "goal": [58, 66], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("lantern", CUTE, 0.2, 0.2)],
		 "zones": [_z("hold", SCARY, 0.75, 0.3, 0.1)], "tip": ""},
		{"id": "11-5", "name": "Festival of Lights", "layout": ["rings", 3], "goal": [44, 52], "par": 130, "fuzzies": 4,
		 "bouncers": [_b("basic", SCARY, 2)],
		 "items": [_i("lantern", SCARY, 0.15, 0.15), _i("lantern", CUTE, 0.85, 0.85), _i("nest", CUTE, 0.5, 0.5), _i("charm", 0, 0.85, 0.15)], "tip": "finale"},
		# ================================================ World 12: Stone Halls - geometry
		{"id": "12-1", "name": "Corridors", "layout": ["split_v", 0.5], "stone": ["bars", 4, 0.22], "goal": [20, 28], "par": 85,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [], "tip": "maze"},
		{"id": "12-2", "name": "Pachinko", "layout": ["split_h", 0.5], "stone": ["dots", 4, 5, 0.035], "goal": [60, 75], "par": 85,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY)], "items": [], "tip": ""},
		{"id": "12-3", "name": "The Vault", "layout": ["island", 0.26, SCARY], "stone": ["box", 0.32, 0.22, 0.06], "goal": [5, 18], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [], "tip": ""},
		{"id": "12-4", "name": "Diamond Hall", "layout": ["split_h", 0.5], "stone": ["diamond", 0.33, 0.06], "goal": [55, 70], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("idol", CUTE, 0.5, 0.42)], "tip": ""},
		{"id": "12-5", "name": "Labyrinth", "layout": ["split_v", 0.5], "stone": ["maze", 4, 5, 7], "goal": [56, 66], "par": 140,
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY, 2)], "items": [_i("nest", SCARY, 0.875, 0.9)], "tip": "finale"},
		# ================================================ World 13: Bat Pens - lone bats
		{"id": "13-1", "name": "Lonely Bats", "layout": ["split_h", 0.4], "goal": [42, 58], "par": 70, "pens": 2,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 3)], "items": [], "tip": "pens"},
		{"id": "13-2", "name": "Two Rooms", "layout": ["split_h", 0.4], "stone": ["chambers", 2, 1, 0.16], "goal": [44, 54], "par": 75, "pens": 2,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 3)], "items": [], "tip": "pen2"},
		{"id": "13-3", "name": "Three's Company", "layout": ["split_h", 0.35], "stone": ["chambers", 3, 1, 0.14], "goal": [50, 60], "par": 90, "pens": 3,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 3)], "items": [], "tip": ""},
		{"id": "13-4", "name": "Roost Rooms", "layout": ["split_h", 0.4], "stone": ["chambers", 2, 2, 0.14], "goal": [40, 75], "par": 95, "pens": 2,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("nest", SCARY, 0.25, 0.8)], "tip": ""},
		{"id": "13-5", "name": "Bat Hotel", "layout": ["split_h", 0.3], "stone": ["chambers", 2, 2, 0.16], "goal": [56, 64], "par": 120, "pens": 4,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 4)], "items": [_i("charm", 0, 0.5, 0.12)], "tip": "finale"},
		# ================================================ World 14: Shepherd - fuzzies and lone bats
		{"id": "14-1", "name": "The Flock", "layout": ["frame", 0.13, SCARY], "goal": [30, 45], "par": 90, "fuzzies": 5,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("nest", CUTE, 0.5, 0.5)], "tip": "shepherd"},
		{"id": "14-2", "name": "Sheepdog", "layout": ["split_h", 0.45], "goal": [36, 50], "par": 100, "fuzzies": 4, "pens": 2,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("nest", CUTE, 0.5, 0.15)], "tip": ""},
		{"id": "14-3", "name": "The Fold", "layout": ["split_h", 0.5], "stone": ["chambers", 2, 2, 0.16], "goal": [35, 46], "par": 110, "fuzzies": 5, "pens": 2,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("nest", CUTE, 0.25, 0.2)], "tip": ""},
		{"id": "14-4", "name": "Wolf at the Door", "layout": ["split_v", 0.55], "goal": [35, 50], "par": 110, "fuzzies": 5,
		 "bouncers": [_b("basic", SCARY)], "items": [_i("den", SCARY, 0.85, 0.5), _i("nest", CUTE, 0.25, 0.5)], "tip": ""},
		{"id": "14-5", "name": "Shepherd's Night", "layout": ["rings", 3], "stone": ["ring", 0.42], "goal": [40, 55], "par": 140, "fuzzies": 5, "pens": 2,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("nest", CUTE, 0.5, 0.5), _i("nest", SCARY, 0.9, 0.1)], "tip": "finale"},
		# ================================================ World 15: Swarm - generators everywhere
		{"id": "15-1", "name": "Hatching", "layout": ["split_h", 0.5], "goal": [30, 42], "par": 95,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("nest", SCARY, 0.25, 0.8), _i("nest", SCARY, 0.75, 0.8), _i("nest", CUTE, 0.5, 0.2)], "tip": "swarm"},
		{"id": "15-2", "name": "Nest Egg", "layout": ["corners", 0.3], "goal": [4, 10], "par": 110,
		 "bouncers": [_b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.1, 0.08), _i("nest", SCARY, 0.9, 0.08), _i("nest", SCARY, 0.1, 0.92), _i("nest", SCARY, 0.9, 0.92)], "tip": ""},
		{"id": "15-3", "name": "Infestation", "layout": ["split_v", 0.5], "goal": [10, 20], "par": 120,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("burrow", SCARY, 0.85, 0.2), _i("den", SCARY, 0.85, 0.8), _i("nest", SCARY, 0.7, 0.5)], "tip": ""},
		{"id": "15-4", "name": "Swarm", "layout": ["checker", 2, 3], "goal": [60, 70], "par": 130,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("nest", SCARY, 0.75, 0.17), _i("den", SCARY, 0.25, 0.5), _i("burrow", CUTE, 0.25, 0.17), _i("lantern", CUTE, 0.75, 0.83)], "tip": ""},
		{"id": "15-5", "name": "Hive Queen", "layout": ["island", 0.34, SCARY], "goal": [0, 15], "par": 160,
		 "bouncers": [_b("boss", SCARY, 1, 0.75), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.35, 0.5), _i("nest", SCARY, 0.65, 0.5), _i("charm", 0, 0.1, 0.08), _i("charm", 0, 0.9, 0.92)], "tip": "finale"},
		# ================================================ World 16: Holy Orders - rings and generators
		{"id": "16-1", "name": "Sanctuary", "layout": ["split_h", 0.5], "goal": [30, 45], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("nest", SCARY, 0.2, 0.85)],
		 "zones": [_z("hold", CUTE, 0.6, 0.72, 0.12)], "tip": ""},
		{"id": "16-2", "name": "Pilgrims", "layout": ["split_v", 0.5], "goal": [55, 70], "par": 100, "fuzzies": 4,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("nest", CUTE, 0.2, 0.2)],
		 "zones": [_z("shrine", CUTE, 0.2, 0.6, 0.11, "swift")], "tip": ""},
		{"id": "16-3", "name": "Cursed Roost", "layout": ["split_h", 0.5], "goal": [18, 26], "par": 110,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("nest", SCARY, 0.2, 0.82), _i("den", SCARY, 0.8, 0.82)],
		 "zones": [_z("shrine", SCARY, 0.5, 0.75, 0.12, "haste")], "tip": "curse"},
		{"id": "16-4", "name": "Twin Altars", "layout": ["checker", 2, 2], "goal": [45, 55], "par": 110,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("lantern", CUTE, 0.75, 0.8)],
		 "zones": [_z("hold", SCARY, 0.25, 0.25, 0.1), _z("hold", CUTE, 0.75, 0.25, 0.1)], "tip": ""},
		{"id": "16-5", "name": "Cathedral", "layout": ["split_h", 0.5], "stone": ["box", 0.3, 0.2, 0.06], "goal": [38, 52], "par": 150, "pens": 2,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [_i("nest", SCARY, 0.85, 0.88)],
		 "zones": [_z("hold", CUTE, 0.5, 0.5, 0.11), _z("shrine", CUTE, 0.85, 0.15, 0.09, "calm")], "tip": "finale"},
		# ================================================ World 17: Bone Yard - targets with backup
		{"id": "17-1", "name": "Grave Goods", "layout": ["split_h", 0.5], "goal": [22, 30], "par": 100,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("idol", SCARY, 0.2, 0.85), _i("idol", SCARY, 0.8, 0.85), _i("den", SCARY, 0.5, 0.8)], "tip": ""},
		{"id": "17-2", "name": "Bone Lanterns", "layout": ["split_h", 0.5], "goal": [58, 78], "par": 110,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("idol", CUTE, 0.2, 0.15), _i("idol", CUTE, 0.8, 0.15), _i("lantern", SCARY, 0.5, 0.85)], "tip": ""},
		{"id": "17-3", "name": "Ossuary", "layout": ["split_v", 0.5], "stone": ["chambers", 2, 3, 0.14], "goal": [25, 40], "par": 120,
		 "bouncers": [_b("basic", CUTE), _b("elite", SCARY)], "items": [_i("idol", SCARY, 0.75, 0.5)], "tip": ""},
		{"id": "17-4", "name": "Crowned Fuzzy", "layout": ["split_h", 0.5], "goal": [50, 80], "par": 110, "fuzzies": 2,
		 "bouncers": [_b("elite", CUTE)], "items": [_i("nest", CUTE, 0.1, 0.08), _i("nest", CUTE, 0.9, 0.08)], "tip": ""},
		{"id": "17-5", "name": "King of Bones", "layout": ["rings", 4], "goal": [44, 52], "par": 160,
		 "bouncers": [_b("basic", CUTE), _b("elite", SCARY)],
		 "items": [_i("idol", SCARY, 0.5, 0.5), _i("idol", CUTE, 0.12, 0.1), _i("nest", SCARY, 0.88, 0.9)], "tip": "finale"},
		# ================================================ World 18: Labyrinth - mazes
		{"id": "18-1", "name": "Maze Runner", "layout": ["split_h", 0.5], "stone": ["maze", 4, 5, 11], "goal": [30, 45], "par": 110,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)], "items": [], "tip": "maze"},
		{"id": "18-2", "name": "Straight Maze", "layout": ["split_v", 0.5], "stone": ["maze", 3, 4, 5], "curl": "straight", "goal": [64, 74], "par": 120,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [],
		 "zones": [_z("shrine", CUTE, 0.17, 0.88, 0.09, "true")], "tip": "curl"},
		{"id": "18-3", "name": "Minotaur", "layout": ["split_h", 0.5], "stone": ["maze", 4, 4, 3], "goal": [25, 40], "par": 120,
		 "bouncers": [_b("basic", CUTE), _b("stalker", SCARY)], "items": [_i("charm", 0, 0.375, 0.125)], "tip": ""},
		{"id": "18-4", "name": "Penned In", "layout": ["split_h", 0.3], "stone": ["maze", 3, 3, 9], "goal": [52, 62], "par": 130, "pens": 3,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 3)], "items": [], "tip": ""},
		{"id": "18-5", "name": "The Heart of It", "layout": ["donut", 0.2, 0.4, CUTE], "stone": ["maze", 5, 6, 21], "goal": [30, 40], "par": 170,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("idol", SCARY, 0.5, 0.5), _i("nest", SCARY, 0.9, 0.92)], "tip": "finale"},
		# ================================================ World 19: Eclipse - everything mixed
		{"id": "19-1", "name": "Penumbra", "layout": ["diag", 0.5, true], "goal": [40, 55], "par": 120, "fuzzies": 3,
		 "bouncers": [_b("basic", SCARY)], "items": [_i("nest", CUTE, 0.82, 0.15), _i("den", SCARY, 0.2, 0.85), _i("den", CUTE, 0.6, 0.12)], "tip": ""},
		{"id": "19-2", "name": "Umbra", "layout": ["blobs", 5, CUTE, 0.12, 8], "goal": [45, 60], "par": 120,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("lantern", SCARY, 0.5, 0.9)],
		 "zones": [_z("hold", CUTE, 0.5, 0.5, 0.12)], "tip": ""},
		{"id": "19-3", "name": "Corona", "layout": ["donut", 0.15, 0.34, SCARY], "curl": "arc", "goal": [25, 38], "par": 130, "pens": 2,
		 "bouncers": [_b("basic", SCARY, 2)], "items": [],
		 "zones": [_z("shrine", CUTE, 0.5, 0.5, 0.1, "true")], "tip": "arcs"},
		{"id": "19-4", "name": "Totality", "layout": ["hourglass"], "stone": ["dots", 3, 4, 0.03], "goal": [50, 65], "par": 130,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("burrow", SCARY, 0.5, 0.9), _i("burrow", CUTE, 0.12, 0.5), _i("idol", CUTE, 0.88, 0.5)], "tip": ""},
		{"id": "19-5", "name": "Eclipse", "layout": ["spiral"], "goal": [36, 46], "par": 170, "fuzzies": 3,
		 "bouncers": [_b("elite", SCARY)], "items": [_i("nest", CUTE, 0.5, 0.5), _i("charm", 0, 0.15, 0.85)], "tip": "finale"},
		# ================================================ World 20: Midnight - the gauntlet
		{"id": "20-1", "name": "Eleven Bells", "layout": ["stripes", 5], "goal": [45, 55], "par": 140, "fuzzies": 3,
		 "bouncers": [_b("basic", SCARY)],
		 "items": [_i("nest", SCARY, 0.8, 0.85), _i("den", SCARY, 0.2, 0.15), _i("lantern", CUTE, 0.8, 0.15), _i("nest", CUTE, 0.25, 0.8), _i("nest", CUTE, 0.6, 0.45)], "tip": "remix"},
		{"id": "20-2", "name": "Witch Light", "layout": ["split_h", 0.5], "curl": "curly", "goal": [55, 70], "par": 140,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY)], "items": [_i("lantern", CUTE, 0.15, 0.2), _i("lantern", SCARY, 0.85, 0.8), _i("idol", SCARY, 0.5, 0.88)],
		 "zones": [_z("hold", SCARY, 0.6, 0.22, 0.1)], "tip": "remix"},
		{"id": "20-3", "name": "Bat Cathedral", "layout": ["split_h", 0.3], "stone": ["chambers", 3, 2, 0.14], "goal": [50, 64], "par": 150, "pens": 4,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 4)], "items": [_i("charm", 0, 0.5, 0.15)], "tip": "remix"},
		{"id": "20-4", "name": "Night Terrors", "layout": ["checker", 3, 4], "goal": [33, 38], "par": 160,
		 "bouncers": [_b("basic", CUTE), _b("basic", SCARY, 2)],
		 "items": [_i("den", SCARY, 0.5, 0.125), _i("charm", 0, 0.83, 0.125), _i("charm", 0, 0.17, 0.875), _i("bomb", 0, 0.5, 0.625), _i("idol", SCARY, 0.83, 0.375)], "tip": "remix"},
		{"id": "20-5", "name": "Midnight", "layout": ["rings", 4], "stone": ["ring", 0.42], "goal": [10, 32], "par": 200, "fuzzies": 3,
		 "bouncers": [_b("boss", SCARY, 1, 0.85), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.5, 0.36), _i("nest", CUTE, 0.15, 0.12), _i("idol", CUTE, 0.88, 0.1), _i("charm", 0, 0.12, 0.9)], "tip": "finale"},
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
		# one spec, or a list of specs that are combined
		var specs: Array = level.stone if level.stone[0] is Array else [level.stone]
		for st in specs:
			var ctx := _stone_ctx(st)
			for y in gh:
				for x in gw:
					if _stone_at(st, (x + 0.5) / gw, (y + 0.5) / gh, asp, ctx):
						mask[y * gw + x] = STONE
	return [mask, under]


## Deterministic pseudo-random 0..1 from integers (layouts must not change
## between runs, so no RNG state).
static func _h(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453, 1.0)


## Precomputed data for stone layouts that need it (mazes, scattered rocks).
static func _stone_ctx(st: Array) -> Dictionary:
	match st[0]:
		"maze":
			# spanning-tree maze on a cols x rows grid: an open[] edge set
			var cols: int = st[1]
			var rows: int = st[2]
			var seed_v: int = st[3] if st.size() > 3 else 1
			var seen := {}
			var open := {}
			var stack: Array = [Vector2i(0, 0)]
			seen[Vector2i(0, 0)] = true
			var k := 0
			while not stack.is_empty():
				var c: Vector2i = stack[stack.size() - 1]
				var nbrs: Array = []
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and not seen.has(n):
						nbrs.append(n)
				if nbrs.is_empty():
					stack.pop_back()
					continue
				k += 1
				var n2: Vector2i = nbrs[int(_h(seed_v * 31 + k, c.x * 7 + c.y * 13) * nbrs.size()) % nbrs.size()]
				seen[n2] = true
				open[[c, n2]] = true
				open[[n2, c]] = true
				stack.append(n2)
			# a few extra openings so it isn't a single path
			for e in int(cols * rows * 0.25):
				var a := Vector2i(int(_h(seed_v, 100 + e) * cols), int(_h(seed_v, 200 + e) * rows))
				var b := a + (Vector2i(1, 0) if _h(seed_v, 300 + e) < 0.5 else Vector2i(0, 1))
				if b.x < cols and b.y < rows:
					open[[a, b]] = true
					open[[b, a]] = true
			return {"open": open}
		"rocks":
			var pts: Array = []
			for i in int(st[1]):
				var sv: int = st[2] if st.size() > 2 else 1
				pts.append(Vector3(0.1 + 0.8 * _h(sv, i * 2), 0.08 + 0.84 * _h(sv, i * 2 + 1), 0.035 + 0.03 * _h(sv + 9, i)))
			return {"pts": pts}
	return {}


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
		"diag":
			# ["diag", t, flip]: Cute in the top-left (top-right if flipped) corner
			var uu := (1.0 - u) if lay.size() > 2 and lay[2] else u
			return CUTE if (uu * asp + v) / (asp + 1.0) < float(lay[1]) + _wave(u - v, 0.03) else SCARY
		"donut":
			# ["donut", r_in, r_out, ring_side]
			var d3 := Vector2((u - 0.5) * asp, v - 0.5).length() + 0.012 * sin(atan2(v - 0.5, u - 0.5) * 5.0)
			var ring: int = lay[3]
			return ring if d3 > float(lay[1]) and d3 < float(lay[2]) else 1 - ring
		"bands":
			# ["bands", n, vertical]
			var t: float = (u if lay.size() > 2 and lay[2] else v)
			var w2: float = (v if lay.size() > 2 and lay[2] else u)
			return posmod(int(floor((t + _wave(w2, 0.015)) * float(lay[1]))), 2)
		"blobs":
			# ["blobs", n, side, size, seed]: round patches of `side` on the other color
			var side: int = lay[2]
			var sv: int = lay[4] if lay.size() > 4 else 1
			for i in int(lay[1]):
				var c := Vector2(0.14 + 0.72 * _h(sv, i * 2), 0.12 + 0.76 * _h(sv, i * 2 + 1))
				var rr: float = float(lay[3]) * (0.75 + 0.5 * _h(sv + 5, i))
				var ang2 := atan2(v - c.y, u - c.x)
				if Vector2((u - c.x) * asp, v - c.y).length() < rr * (1.0 + 0.1 * sin(ang2 * 5.0 + i)):
					return side
			return 1 - side
		"frame":
			# ["frame", width, side]: a border of `side` around the other color
			var e: float = min(min(u * asp, (1.0 - u) * asp), min(v, 1.0 - v))
			return int(lay[2]) if e < float(lay[1]) + _wave(u + v, 0.012) else 1 - int(lay[2])
		"waves":
			# ["waves", t, amp, freq]
			return CUTE if v < float(lay[1]) + float(lay[2]) * sin(u * TAU * float(lay[3])) + _wave(u, 0.015) else SCARY
		"hourglass":
			# Scary hourglass (top and bottom wedges), Cute at the sides
			return SCARY if absf(u - 0.5) * asp < absf(v - 0.5) * 0.9 + 0.04 + _wave(v, 0.02) else CUTE
	return CUTE


static func _stone_at(st: Array, u: float, v: float, asp: float, ctx := {}) -> bool:
	var wall := 0.022           # wall half-thickness in v units (~4 cells)
	var wu := wall / asp
	match st[0]:
		"chambers", "maze":
			# grid walls between rooms. chambers: a door in every wall.
			# maze: walls only where the maze has no passage.
			var cols: int = st[1]
			var rows: int = st[2]
			var door: float = float(st[3]) if st[0] == "chambers" and st.size() > 3 else 0.0
			var cx := u * cols
			var cy := v * rows
			var ix := int(floor(cx))
			var iy := int(floor(cy))
			var fx := cx - ix
			var fy := cy - iy
			# vertical wall on the nearest interior column line
			var lx := int(round(cx))
			if lx > 0 and lx < cols and absf(cx - lx) < wu * cols:
				var row := clampi(iy, 0, rows - 1)
				if st[0] == "maze":
					return not ctx.open.has([Vector2i(lx - 1, row), Vector2i(lx, row)])
				return absf(fy - 0.5) > door * 0.5 * rows
			var ly := int(round(cy))
			if ly > 0 and ly < rows and absf(cy - ly) < wall * rows:
				var col := clampi(ix, 0, cols - 1)
				if st[0] == "maze":
					return not ctx.open.has([Vector2i(col, ly - 1), Vector2i(col, ly)])
				return absf(fx - 0.5) > door * 0.5 * cols
			return false
		"bars":
			# ["bars", n, gap]: horizontal bars with the gap on alternating ends (a zigzag)
			var n2: int = st[1]
			for i in n2:
				var y := (i + 1.0) / (n2 + 1.0)
				if absf(v - y) < wall:
					var gap: float = st[2]
					return (u > gap) if i % 2 == 0 else (u < 1.0 - gap)
			return false
		"dots":
			# ["dots", cols, rows, r]: a peg grid, odd rows offset
			var cols2: int = st[1]
			var rows2: int = st[2]
			for j in rows2:
				var y2 := (j + 0.5) / rows2
				var off := 0.5 if j % 2 == 1 else 0.0
				for i in cols2:
					var x2 := (i + 0.5 + off * 0.5) / (cols2 + 0.25)
					if Vector2((u - x2) * asp, v - y2).length() < float(st[3]):
						return true
			return false
		"rocks":
			for pt in ctx.pts:
				var ang := atan2(v - pt.y, u - pt.x)
				if Vector2((u - pt.x) * asp, v - pt.y).length() < pt.z * (1.0 + 0.18 * sin(ang * 4.0 + pt.x * 20.0)):
					return true
			return false
		"box":
			# ["box", half_w, half_h, gap]: a walled box with a door in each side
			var hw: float = st[1]
			var hh: float = st[2]
			var gap2: float = st[3]
			var dx := absf(u - 0.5)
			var dy := absf(v - 0.5)
			if absf(dx - hw) < wu and dy < hh + wall and dy > gap2:
				return true
			if absf(dy - hh) < wall and dx < hw + wu and dx > gap2 / asp:
				return true
			return false
		"diamond":
			# ["diamond", r, gap]: a diamond wall, open at its four points
			var q: float = absf(u - 0.5) * asp + absf(v - 0.5)
			return absf(q - float(st[1])) < wall * 1.2 and absf(u - 0.5) * asp > float(st[2]) and absf(v - 0.5) > float(st[2])
		"comb":
			# ["comb", n, len]: teeth from the top and bottom edges, alternating
			var n3: int = st[1]
			for i in n3:
				var x3 := (i + 0.5) / n3
				if absf(u - x3) < wu:
					return v < float(st[2]) if i % 2 == 0 else v > 1.0 - float(st[2])
			return false
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
