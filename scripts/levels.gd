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
	"Guardians", "Swarm", "Holy Orders", "Bone Yard", "Labyrinth", "Eclipse", "Midnight"]

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
	"curse": ["Curses", "A cursed shrine works for the color that holds it: slow walls, fast creatures, or stiff lines. Take it to lift the curse."],
	"idol": ["The bone idol", "The idol must fall before you can win. Claim the ground under it for Cute, even though tonight you want Scary."],
	"idols": ["Sugar idols", "Both idols must fall. Claim the Cute ground they stand on, then make the night Cute again."],
	"elite": ["The crowned bat", "The crowned bat must be trapped before you can win. Squeeze it into a tiny pocket."],
	"gift": ["Gift boxes", "Gift boxes keep hatching fuzzies until their ground turns Scary. Push into them early, before the fuzzies crowd you out."],
	"guard": ["Guarded rings", "A creature starts inside each ring you must take. Wall it into a small corner of the ring, or trap it, then fill the rest."],
	"halo": ["Stone halos", "A round stone wall with one door keeps its creature close to the ring. Your walls can end on the stone."],
	"pens": ["Lone bats", "Split the Scary ground so each bat is alone in its own pocket. A gold ring marks a lone bat. Don't make pockets so small you trap them!"],
	"pen2": ["Doors", "Bats slip through the doors between rooms. Draw a Cute wall across a doorway to shut it."],
	"den": ["Hunter dens", "Dens keep sending out hunter bats that chase your growing walls. Claim the den's ground to close it."],
	"huggy": ["Huggy huts", "Huggy puffs come out of this hut and chase your growing walls. Turn its ground Scary to shut it."],
	"burrow": ["Grub burrows", "Burrows keep sending out gloom grubs that tunnel Scary through Cute land. Claim the burrow to stop them."],
	"candy": ["Candy burrows", "Sugar slugs crawl out of this burrow and paint Cute trails. Turn its ground Scary to stop them."],
	"lantern": ["Wisp lanterns", "Lanterns keep releasing wisps that snap any wall. Take the lantern's ground to put it out."],
	"maze": ["Stone halls", "Stone walls make corridors. Your walls can end on stone, so short walls across a corridor go a long way."],
	"shores": ["Strange shores", "New ground shapes tonight. Look for narrow spots, where a short wall cuts off a lot."],
	"swarm": ["Swarm", "Everything is hatching. Close the generators before they bury you."],
}

static func _b(kind: String, side: int, count := 1, speed := 1.0) -> Dictionary:
	return {"kind": kind, "side": side, "count": count, "speed": speed}


## Creatures that start at given spots (u, v), one per spot.
static func _bat(kind: String, side: int, spots: Array, speed := 1.0) -> Dictionary:
	return {"kind": kind, "side": side, "count": spots.size(), "speed": speed, "at": spots}


static func _i(kind: String, side: int, u: float, v: float) -> Dictionary:
	return {"kind": kind, "side": side, "at": Vector2(u, v)}


## Zone: kind "hold" (must be held by `side` to win) or "shrine" (its effect
## is active while `side` holds it). r is a fraction of the field's width.
static func _z(kind: String, side: int, u: float, v: float, r: float, effect := "") -> Dictionary:
	return {"kind": kind, "side": side, "at": Vector2(u, v), "r": r, "effect": effect}


## Creature speed per night, tuned against the bot's win rate by
## tools/tune_tempo.py (difficulty knob that keeps the 30-point rule).
const TEMPO := {
	"1-1": 0.75, "1-2": 0.85, "1-3": 0.58, "1-4": 0.97, "1-5": 0.66,
	"2-1": 0.86, "2-2": 0.90, "2-3": 0.86, "2-4": 0.86, "2-5": 0.55,
	"3-1": 0.79, "3-2": 0.87, "3-3": 0.68, "3-4": 0.87, "3-5": 0.55,
	"4-1": 0.55, "4-2": 0.68, "4-3": 0.70, "4-4": 0.88, "4-5": 0.88,
	"5-1": 0.55, "5-2": 0.79, "5-3": 0.58, "5-4": 0.55, "5-5": 0.83,
	"6-1": 0.90, "6-2": 0.96, "6-3": 0.62, "6-4": 0.70, "6-5": 1.00,
	"7-1": 0.55, "7-2": 0.91, "7-3": 0.80, "7-4": 0.55, "7-5": 1.11,
	"8-1": 0.81, "8-2": 0.92, "8-3": 0.87, "8-4": 0.98, "8-5": 0.81,
	"9-1": 0.93, "9-2": 0.93, "9-3": 1.00, "9-4": 1.00, "9-5": 1.00,
	"10-1": 0.94, "10-2": 1.16, "10-3": 0.83, "10-4": 1.00, "10-5": 1.00,
	"11-1": 0.95, "11-2": 1.09, "11-3": 0.95, "11-4": 0.95, "11-5": 1.00,
	"12-1": 1.03, "12-2": 0.96, "12-3": 0.84, "12-4": 1.03, "12-5": 1.00,
	"13-1": 0.85, "13-2": 0.97, "13-3": 0.62, "13-4": 0.97, "13-5": 0.88,
	"14-1": 0.76, "14-2": 0.98, "14-3": 1.07, "14-4": 0.98, "14-5": 0.98,
	"15-1": 0.90, "15-2": 1.00, "15-3": 1.00, "15-4": 1.13, "15-5": 0.99,
	"16-1": 1.07, "16-2": 1.14, "16-3": 0.78, "16-4": 1.00, "16-5": 0.88,
	"17-1": 1.01, "17-2": 1.00, "17-3": 1.16, "17-4": 0.89, "17-5": 1.01,
	"18-1": 1.17, "18-2": 1.23, "18-3": 1.02, "18-4": 1.02, "18-5": 1.03,
	"19-1": 1.00, "19-2": 1.18, "19-3": 1.03, "19-4": 1.10, "19-5": 1.03,
	"20-1": 1.20, "20-2": 1.20, "20-3": 0.92, "20-4": 1.22, "20-5": 1.00,
}


static func all() -> Array:
	var out: Array = _levels()
	for lv in out:
		lv["par"] = int(lv.get("par", 0)) if lv.has("par") else 50 + 8 * (int(lv.id.split("-")[0]) - 1)
		for k in ["items", "zones"]:
			if not lv.has(k):
				lv[k] = []
		if not lv.has("tip"):
			lv["tip"] = ""
		lv["tempo"] = float(TEMPO.get(lv.id, 1.0))
		if not lv.has("goal"):
			lv["goal"] = [0, 100]   # set from "push" when the night's ground is built
	return out


## Design rules for every night:
##  * the band starts 30+ points away ("push": [dir, dist, width]; +1 = make
##    it Scarier, -1 = make it Cuter), so one or two swipes never win it;
##  * the ground you push into is guarded by several creatures, so huge
##    early claims are risky;
##  * generators sit in the ground you're pushing into;
##  * each night combines mechanics instead of adding one in isolation.
static func _levels() -> Array:
	var V := func(u: float, v: float) -> Vector2: return Vector2(u, v)
	return [
		# ================================================ World 1: Moonrise - learn the claim
		{"id": "1-1", "name": "First Claim", "layout": ["split_h", 0.7], "push": [1, 30, 12],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.2, 0.25), V.call(0.5, 0.45), V.call(0.8, 0.2)]), _b("basic", SCARY)], "tip": "claim"},
		{"id": "1-2", "name": "Sweet Revenge", "layout": ["split_h", 0.3], "push": [-1, 30, 12],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.2, 0.6), V.call(0.5, 0.85), V.call(0.8, 0.55)]), _b("basic", CUTE)], "tip": "band"},
		{"id": "1-3", "name": "Steady Paws", "layout": ["split_v", 0.3], "push": [-1, 32, 12],
		 "bouncers": [_b("basic", SCARY, 4, 0.8), _b("basic", CUTE)], "tip": ""},
		{"id": "1-4", "name": "Trapped!", "layout": ["island", 0.42, CUTE], "push": [1, 31, 10],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.35, 0.4), V.call(0.65, 0.45), V.call(0.5, 0.65)]), _b("basic", SCARY)], "tip": "trap"},
		{"id": "1-5", "name": "Balancing Act", "layout": ["checker", 2, 2], "push": [-1, 32, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE, 2)], "tip": "finale"},
		# ================================================ World 2: Moonstone - tools that help
		{"id": "2-1", "name": "Boom", "layout": ["split_h", 0.3], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("bomb", 0, 0.25, 0.6), _i("bomb", 0, 0.75, 0.72), _i("bomb", 0, 0.5, 0.88)], "tip": "bomb"},
		{"id": "2-2", "name": "Moonstones", "layout": ["split_v", 0.65], "stone": ["pillars", 5], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)], "tip": "stone"},
		{"id": "2-3", "name": "Frozen Stiff", "layout": ["split_h", 0.35], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 4, 1.25), _b("basic", CUTE)],
		 "items": [_i("charm", 0, 0.25, 0.65), _i("charm", 0, 0.75, 0.82)], "tip": "charm"},
		{"id": "2-4", "name": "Hold the Altar", "layout": ["split_h", 0.7], "push": [1, 32, 10],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.5, 0.3)]), _b("basic", CUTE, 2), _b("basic", SCARY)],
		 "zones": [_z("hold", SCARY, 0.5, 0.3, 0.12)], "tip": "guard"},
		{"id": "2-5", "name": "Rubble", "layout": ["split_h", 0.3], "stone": ["cross"], "push": [-1, 35, 10],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.25, 0.75), V.call(0.75, 0.75)]), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("bomb", 0, 0.25, 0.45), _i("bomb", 0, 0.75, 0.9)],
		 "zones": [_z("hold", CUTE, 0.25, 0.75, 0.1), _z("hold", CUTE, 0.75, 0.75, 0.1)], "tip": "finale"},
		# ================================================ World 3: Creeping Dark - threats that grow
		{"id": "3-1", "name": "Thorns", "layout": ["split_h", 0.35], "push": [-1, 32, 12],
		 "bouncers": [_b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("seed", SCARY, 0.3, 0.75)], "tip": "seed"},
		{"id": "3-2", "name": "The Roost", "layout": ["split_h", 0.4], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.25, 0.8), _i("nest", SCARY, 0.75, 0.86)], "tip": "nest"},
		{"id": "3-3", "name": "Gloom Grub", "layout": ["waves", 0.4, 0.1, 3], "push": [-1, 33, 10],
		 "bouncers": [_b("carver", SCARY, 2), _b("basic", SCARY, 2), _b("basic", CUTE)], "tip": "grub"},
		{"id": "3-4", "name": "Sugar Slug", "layout": ["waves", 0.6, 0.1, 2], "push": [1, 33, 10],
		 "bouncers": [_b("carver", CUTE, 2), _b("basic", CUTE, 2), _b("basic", SCARY)], "tip": "slug"},
		{"id": "3-5", "name": "Overgrowth", "layout": ["split_v", 0.35], "stone": ["pillars", 3], "push": [-1, 34, 10],
		 "bouncers": [_b("carver", SCARY), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("seed", SCARY, 0.7, 0.25), _i("seed", SCARY, 0.85, 0.7), _i("nest", SCARY, 0.6, 0.85)], "tip": "finale"},
		# ================================================ World 4: Hallowed Ground - rules that change
		{"id": "4-1", "name": "Swift Shrine", "layout": ["split_h", 0.3], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("carver", SCARY)],
		 "zones": [_z("shrine", CUTE, 0.5, 0.14, 0.1, "swift")], "tip": "shrine"},
		{"id": "4-2", "name": "Straight and Narrow", "layout": ["split_v", 0.7], "stone": ["pillars", 4], "curl": "straight", "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 4), _b("basic", SCARY)], "tip": "curl"},
		{"id": "4-3", "name": "Gentle Arcs", "layout": ["split_h", 0.35], "curl": "arc", "push": [-1, 32, 12],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "tip": "arcs"},
		{"id": "4-4", "name": "Cursed Ground", "layout": ["split_h", 0.35], "stone": ["dots", 3, 3, 0.035], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "zones": [_z("shrine", SCARY, 0.3, 0.75, 0.1, "straight"), _z("shrine", SCARY, 0.72, 0.82, 0.1, "slow")], "tip": "curse"},
		{"id": "4-5", "name": "Rings", "layout": ["split_h", 0.65], "stone": ["ring", 0.42], "curl": "curly", "push": [1, 34, 10],
		 "bouncers": [_b("basic", CUTE, 4), _b("basic", SCARY)],
		 "zones": [_z("shrine", SCARY, 0.5, 0.3, 0.1, "true")], "tip": "finale"},
		# ================================================ World 5: Blood Moon - hunters of the night
		{"id": "5-1", "name": "Bone Idol", "layout": ["frame", 0.14, SCARY], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 4), _b("basic", SCARY)],
		 "items": [_i("idol", CUTE, 0.35, 0.4), _i("idol", CUTE, 0.65, 0.6)], "tip": "idol"},
		{"id": "5-2", "name": "Crowned Bat", "layout": ["donut", 0.12, 0.45, SCARY], "push": [-1, 33, 10],
		 "bouncers": [_b("elite", SCARY), _b("basic", SCARY, 2), _b("basic", CUTE)], "tip": "elite"},
		{"id": "5-3", "name": "Will-o'-Wisps", "layout": ["waves", 0.3, 0.12, 2], "push": [-1, 33, 10],
		 "bouncers": [_b("wisp", SCARY, 2), _b("basic", SCARY, 3), _b("basic", CUTE)], "tip": "wisp"},
		{"id": "5-4", "name": "Hunters", "layout": ["split_h", 0.4], "stone": ["pillars", 3], "push": [-1, 34, 10],
		 "bouncers": [_b("stalker", SCARY, 2), _b("basic", SCARY, 2), _b("basic", CUTE)], "tip": "stalker"},
		{"id": "5-5", "name": "Night Mother", "layout": ["island", 0.4, SCARY], "push": [-1, 36, 10],
		 "bouncers": [_b("boss", SCARY, 1, 0.8), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.5, 0.62), _i("charm", 0, 0.12, 0.1), _i("charm", 0, 0.88, 0.9), _i("bomb", 0, 0.3, 0.4)], "tip": "boss"},
		# ================================================ World 6: The Hunt - mastery
		{"id": "6-1", "name": "Witching Hour", "layout": ["split_h", 0.68], "push": [1, 33, 10],
		 "stone": [["halo", 0.25, 0.3, 0.16, 90, 50], ["halo", 0.75, 0.3, 0.16, 90, 50]],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.25, 0.3), V.call(0.75, 0.3)]), _b("basic", CUTE, 2), _b("basic", SCARY)],
		 "zones": [_z("hold", SCARY, 0.25, 0.3, 0.11), _z("hold", SCARY, 0.75, 0.3, 0.11)], "tip": "halo"},
		{"id": "6-2", "name": "Spiral", "layout": ["spiral"], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "items": [_i("nest", SCARY, 0.8, 0.85)], "tip": "remix"},
		{"id": "6-3", "name": "Sugar Idols", "layout": ["diag", 0.35], "push": [-1, 34, 10],
		 "bouncers": [_b("elite", SCARY), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("idol", SCARY, 0.55, 0.88), _i("idol", SCARY, 0.88, 0.55), _i("charm", 0, 0.15, 0.15)], "tip": "idols"},
		{"id": "6-4", "name": "Curled Hunt", "layout": ["split_v", 0.3], "push": [-1, 34, 10],
		 "bouncers": [_b("stalker", SCARY, 2), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "zones": [_z("shrine", SCARY, 0.8, 0.5, 0.12, "curly")], "tip": "curse"},
		{"id": "6-5", "name": "The Last Idol", "layout": ["split_h", 0.3], "stone": ["chambers", 2, 2, 0.16], "push": [-1, 36, 10],
		 "bouncers": [_b("elite", SCARY), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("idol", SCARY, 0.75, 0.86), _i("nest", SCARY, 0.25, 0.86)], "tip": "lastidol"},
		# ================================================ World 7: Gift Boxes - generators to push into
		{"id": "7-1", "name": "Special Delivery", "layout": ["waves", 0.62, 0.1, 1.5], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)], "items": [_i("nest", CUTE, 0.5, 0.18)], "tip": "gift"},
		{"id": "7-2", "name": "Party Favors", "layout": ["split_v", 0.65], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)],
		 "items": [_i("nest", CUTE, 0.15, 0.25), _i("nest", CUTE, 0.15, 0.75), _i("bomb", 0, 0.42, 0.5)], "tip": ""},
		{"id": "7-3", "name": "Pass the Parcel", "layout": ["island", 0.36, CUTE], "push": [1, 34, 8],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)], "items": [_i("nest", CUTE, 0.5, 0.5)], "tip": ""},
		{"id": "7-4", "name": "Wrapping Paper", "layout": ["split_h", 0.65], "stone": ["bars", 3, 0.2], "curl": "arc", "push": [1, 34, 8],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)],
		 "items": [_i("nest", CUTE, 0.15, 0.12), _i("nest", CUTE, 0.85, 0.4)], "tip": "arcs"},
		{"id": "7-5", "name": "Surprise Party", "layout": ["split_v", 0.68], "stone": ["ring", 0.42], "push": [1, 35, 8],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)],
		 "items": [_i("nest", CUTE, 0.15, 0.15), _i("nest", CUTE, 0.2, 0.85), _i("den", CUTE, 0.5, 0.5), _i("charm", 0, 0.85, 0.5)], "tip": "finale"},
		# ================================================ World 8: Strange Shores - new ground shapes
		{"id": "8-1", "name": "Driftwood", "layout": ["diag", 0.62], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 4), _b("basic", SCARY)], "tip": "shores"},
		{"id": "8-2", "name": "Donut", "layout": ["donut", 0.12, 0.45, SCARY], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "tip": ""},
		{"id": "8-3", "name": "Archipelago", "layout": ["blobs", 7, CUTE, 0.12, 3], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "tip": ""},
		{"id": "8-4", "name": "High Tide", "layout": ["waves", 0.35, 0.12, 2], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "items": [_i("bomb", 0, 0.5, 0.75)], "tip": ""},
		{"id": "8-5", "name": "Hourglass", "layout": ["hourglass"], "stone": ["rocks", 5, 5], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("seed", SCARY, 0.5, 0.1), _i("seed", SCARY, 0.5, 0.9)], "tip": "finale"},
		# ================================================ World 9: Hunter Dens
		{"id": "9-1", "name": "The Den", "layout": ["diag", 0.38, true], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "items": [_i("den", SCARY, 0.3, 0.8)], "tip": "den"},
		{"id": "9-2", "name": "Hug Hut", "layout": ["waves", 0.62, 0.1, 2], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)], "items": [_i("den", CUTE, 0.5, 0.18)], "tip": "huggy"},
		{"id": "9-3", "name": "Den Mother", "layout": ["split_v", 0.35], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("den", SCARY, 0.82, 0.3), _i("nest", SCARY, 0.82, 0.75)], "tip": ""},
		{"id": "9-4", "name": "Ambush", "layout": ["checker", 2, 2], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("den", SCARY, 0.75, 0.25), _i("den", SCARY, 0.25, 0.75), _i("charm", 0, 0.25, 0.25)], "tip": ""},
		{"id": "9-5", "name": "Hunting Grounds", "layout": ["split_h", 0.35], "stone": ["pillars", 4], "push": [-1, 36, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("den", SCARY, 0.2, 0.85), _i("den", SCARY, 0.8, 0.85), _i("idol", SCARY, 0.5, 0.9), _i("bomb", 0, 0.5, 0.6)], "tip": "finale"},
		# ================================================ World 10: Burrows
		{"id": "10-1", "name": "Grub Burrow", "layout": ["frame", 0.12, CUTE], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "items": [_i("burrow", SCARY, 0.5, 0.6)], "tip": "burrow"},
		{"id": "10-2", "name": "Candy Burrow", "layout": ["island", 0.32, SCARY], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)], "items": [_i("burrow", CUTE, 0.15, 0.15)], "tip": "candy"},
		{"id": "10-3", "name": "Tunnels", "layout": ["split_v", 0.65], "push": [1, 33, 10],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.42, 0.5)]), _b("basic", CUTE, 2), _b("basic", SCARY)],
		 "items": [_i("burrow", CUTE, 0.15, 0.25), _i("burrow", CUTE, 0.15, 0.78)],
		 "zones": [_z("hold", SCARY, 0.42, 0.5, 0.1)], "tip": "guard"},
		{"id": "10-4", "name": "Sweet Tooth", "layout": ["split_h", 0.6], "push": [1, 34, 10],
		 "bouncers": [_b("basic", CUTE, 4), _b("basic", SCARY)],
		 "items": [_i("burrow", CUTE, 0.3, 0.18), _i("nest", CUTE, 0.7, 0.18), _i("idol", CUTE, 0.15, 0.1)], "tip": ""},
		{"id": "10-5", "name": "Undermine", "layout": ["checker", 3, 3], "push": [1, 36, 8],
		 "bouncers": [_b("basic", CUTE, 5), _b("basic", SCARY)],
		 "items": [_i("burrow", CUTE, 0.17, 0.17), _i("burrow", CUTE, 0.83, 0.83), _i("bomb", 0, 0.5, 0.17), _i("bomb", 0, 0.17, 0.5)], "tip": "finale"},
		# ================================================ World 11: Lantern Light
		{"id": "11-1", "name": "Lantern", "layout": ["waves", 0.35, 0.12, 3], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "items": [_i("lantern", SCARY, 0.5, 0.82)], "tip": "lantern"},
		{"id": "11-2", "name": "Twin Lights", "layout": ["diag", 0.62], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)],
		 "items": [_i("lantern", CUTE, 0.15, 0.2), _i("lantern", CUTE, 0.15, 0.7), _i("charm", 0, 0.45, 0.5)], "tip": ""},
		{"id": "11-3", "name": "Night Watch", "layout": ["split_h", 0.35], "stone": ["dots", 4, 4, 0.03], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "items": [_i("lantern", SCARY, 0.5, 0.85)], "tip": ""},
		{"id": "11-4", "name": "Ghost Lights", "layout": ["split_h", 0.65], "push": [1, 34, 10],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.7, 0.3)]), _b("basic", CUTE, 2), _b("basic", SCARY)],
		 "items": [_i("lantern", CUTE, 0.2, 0.2)], "zones": [_z("hold", SCARY, 0.7, 0.3, 0.1)], "tip": ""},
		{"id": "11-5", "name": "Festival of Lights", "layout": ["split_v", 0.32], "stone": ["ring", 0.42], "push": [-1, 35, 8],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("lantern", SCARY, 0.8, 0.2), _i("lantern", SCARY, 0.8, 0.8), _i("nest", SCARY, 0.6, 0.5), _i("charm", 0, 0.15, 0.5)], "tip": "finale"},
		# ================================================ World 12: Stone Halls - bricks and straight lines
		{"id": "12-1", "name": "Corridors", "layout": ["split_v", 0.35], "stone": ["bars", 4, 0.22], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "tip": "maze"},
		{"id": "12-2", "name": "Pachinko", "layout": ["split_h", 0.65], "stone": ["dots", 4, 5, 0.035], "curl": "straight", "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 4), _b("basic", SCARY)], "tip": "curl"},
		{"id": "12-3", "name": "The Vault", "layout": ["split_h", 0.35], "stone": ["box", 0.3, 0.2, 0.06], "push": [-1, 33, 10],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.42, 0.6), V.call(0.58, 0.62)]), _b("basic", SCARY, 2), _b("basic", CUTE)], "tip": ""},
		{"id": "12-4", "name": "Diamond Hall", "layout": ["split_h", 0.65], "stone": ["diamond", 0.33, 0.06], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)], "items": [_i("idol", CUTE, 0.5, 0.42)],
		 "zones": [_z("shrine", CUTE, 0.18, 0.18, 0.1, "straight")], "tip": "curse"},
		{"id": "12-5", "name": "Labyrinth", "layout": ["split_v", 0.35], "stone": ["maze", 4, 5, 7], "push": [-1, 36, 8],
		 "bouncers": [_b("basic", SCARY, 5), _b("basic", CUTE)], "items": [_i("nest", SCARY, 0.875, 0.9)], "tip": "finale"},
		# ================================================ World 13: Bat Pens - lone bats
		{"id": "13-1", "name": "Lonely Bats", "layout": ["split_h", 0.3], "push": [-1, 30, 14], "pens": 2,
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "tip": "pens"},
		{"id": "13-2", "name": "Two Rooms", "layout": ["split_h", 0.3], "stone": ["chambers", 2, 1, 0.16], "push": [-1, 31, 12], "pens": 2,
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "tip": "pen2"},
		{"id": "13-3", "name": "Three's Company", "layout": ["split_h", 0.25], "stone": ["chambers", 3, 1, 0.14], "push": [-1, 30, 16], "pens": 3,
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "tip": ""},
		{"id": "13-4", "name": "Roost Rooms", "layout": ["split_h", 0.3], "stone": ["chambers", 2, 2, 0.14], "push": [-1, 32, 10], "pens": 2,
		 "bouncers": [_b("basic", SCARY, 2), _b("basic", CUTE)], "items": [_i("nest", SCARY, 0.25, 0.8)], "tip": ""},
		{"id": "13-5", "name": "Bat Hotel", "layout": ["split_h", 0.25], "stone": ["chambers", 2, 2, 0.16], "push": [-1, 33, 10], "pens": 3,
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "items": [_i("charm", 0, 0.5, 0.12)], "tip": "finale"},
		# ================================================ World 14: Guardians - rings with a creature inside
		{"id": "14-1", "name": "Guarded Rings", "layout": ["split_h", 0.65], "push": [1, 33, 10],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.25, 0.3), V.call(0.75, 0.3)]), _b("basic", CUTE, 2), _b("basic", SCARY)],
		 "zones": [_z("hold", SCARY, 0.25, 0.3, 0.11), _z("hold", SCARY, 0.75, 0.3, 0.11)], "tip": "guard"},
		{"id": "14-2", "name": "Halo", "layout": ["split_h", 0.35], "stone": ["halo", 0.5, 0.72, 0.17, 270, 40], "push": [-1, 33, 10],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.5, 0.72)]), _b("basic", SCARY, 3), _b("basic", CUTE)],
		 "zones": [_z("hold", CUTE, 0.5, 0.72, 0.12)], "tip": "halo"},
		{"id": "14-3", "name": "Twin Halos", "layout": ["split_v", 0.65], "push": [1, 34, 10],
		 "stone": [["halo", 0.25, 0.3, 0.15, 0, 45], ["halo", 0.25, 0.72, 0.15, 0, 45]],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.25, 0.3), V.call(0.25, 0.72)]), _b("basic", CUTE, 4), _b("basic", SCARY)],
		 "zones": [_z("hold", SCARY, 0.25, 0.3, 0.11), _z("hold", SCARY, 0.25, 0.72, 0.11)], "tip": ""},
		{"id": "14-4", "name": "Pen and Ring", "layout": ["split_h", 0.3], "push": [-1, 34, 10], "pens": 2,
		 "bouncers": [_bat("basic", SCARY, [V.call(0.5, 0.82)]), _b("basic", SCARY, 3), _b("basic", CUTE)],
		 "zones": [_z("hold", CUTE, 0.5, 0.82, 0.11)], "tip": ""},
		{"id": "14-5", "name": "Sentinels", "layout": ["split_h", 0.3], "stone": [["halo", 0.2, 0.72, 0.14, 270, 45], ["halo", 0.8, 0.72, 0.14, 270, 45]], "push": [-1, 35, 8],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.2, 0.72), V.call(0.8, 0.72), V.call(0.5, 0.88)]), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "zones": [_z("hold", CUTE, 0.2, 0.72, 0.1), _z("hold", CUTE, 0.8, 0.72, 0.1), _z("hold", CUTE, 0.5, 0.88, 0.09)], "tip": "finale"},
		# ================================================ World 15: Swarm - generators everywhere
		{"id": "15-1", "name": "Hatching", "layout": ["frame", 0.1, CUTE], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.3, 0.65), _i("nest", SCARY, 0.7, 0.65), _i("den", SCARY, 0.5, 0.4)], "tip": "swarm"},
		{"id": "15-2", "name": "Nest Egg", "layout": ["corners", 0.42], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.1, 0.08), _i("nest", SCARY, 0.9, 0.08), _i("nest", SCARY, 0.1, 0.92), _i("nest", SCARY, 0.9, 0.92)], "tip": ""},
		{"id": "15-3", "name": "Infestation", "layout": ["island", 0.42, SCARY], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)],
		 "items": [_i("burrow", SCARY, 0.5, 0.3), _i("den", SCARY, 0.5, 0.7), _i("nest", SCARY, 0.35, 0.5)], "tip": ""},
		{"id": "15-4", "name": "Swarm", "layout": ["split_h", 0.62], "push": [1, 35, 8],
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY)],
		 "items": [_i("nest", CUTE, 0.15, 0.12), _i("den", CUTE, 0.85, 0.12), _i("burrow", CUTE, 0.5, 0.3), _i("lantern", CUTE, 0.3, 0.45)], "tip": ""},
		{"id": "15-5", "name": "Hive Queen", "layout": ["island", 0.4, SCARY], "push": [-1, 36, 8],
		 "bouncers": [_b("boss", SCARY, 1, 0.8), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.35, 0.5), _i("nest", SCARY, 0.65, 0.5), _i("den", SCARY, 0.5, 0.72), _i("charm", 0, 0.1, 0.08), _i("charm", 0, 0.9, 0.92)], "tip": "finale"},
		# ================================================ World 16: Holy Orders - rings, shrines and generators
		{"id": "16-1", "name": "Sanctuary", "layout": ["waves", 0.35, 0.1, 2.5], "push": [-1, 33, 10],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.6, 0.72)]), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.2, 0.86)], "zones": [_z("hold", CUTE, 0.6, 0.72, 0.12)], "tip": "guard"},
		{"id": "16-2", "name": "Pilgrims", "layout": ["diag", 0.6], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 3), _b("basic", SCARY)], "items": [_i("nest", CUTE, 0.12, 0.12)],
		 "zones": [_z("shrine", CUTE, 0.2, 0.45, 0.11, "slow")], "tip": "curse"},
		{"id": "16-3", "name": "Cursed Roost", "layout": ["split_h", 0.35], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.2, 0.84), _i("den", SCARY, 0.8, 0.84)],
		 "zones": [_z("shrine", SCARY, 0.5, 0.74, 0.12, "haste")], "tip": "curse"},
		{"id": "16-4", "name": "Twin Altars", "layout": ["checker", 2, 2], "push": [1, 34, 8],
		 "bouncers": [_bat("basic", CUTE, [V.call(0.25, 0.25), V.call(0.75, 0.75)]), _b("basic", CUTE), _b("basic", SCARY)],
		 "items": [_i("lantern", CUTE, 0.62, 0.6)],
		 "zones": [_z("hold", SCARY, 0.25, 0.25, 0.1), _z("hold", SCARY, 0.75, 0.75, 0.1)], "tip": ""},
		{"id": "16-5", "name": "Cathedral", "layout": ["split_h", 0.3], "stone": ["box", 0.3, 0.2, 0.06], "push": [-1, 35, 8], "pens": 2,
		 "bouncers": [_bat("basic", SCARY, [V.call(0.5, 0.55)]), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.85, 0.88)],
		 "zones": [_z("hold", CUTE, 0.5, 0.55, 0.11), _z("shrine", SCARY, 0.15, 0.86, 0.09, "slow")], "tip": "finale"},
		# ================================================ World 17: Bone Yard - targets with backup
		{"id": "17-1", "name": "Grave Goods", "layout": ["frame", 0.12, CUTE], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("idol", SCARY, 0.3, 0.7), _i("idol", SCARY, 0.7, 0.3), _i("den", SCARY, 0.5, 0.5)], "tip": "idols"},
		{"id": "17-2", "name": "Bone Lanterns", "layout": ["waves", 0.62, 0.1, 1], "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 4), _b("basic", SCARY)],
		 "items": [_i("idol", CUTE, 0.2, 0.14), _i("idol", CUTE, 0.8, 0.14), _i("lantern", CUTE, 0.5, 0.25)], "tip": ""},
		{"id": "17-3", "name": "Ossuary", "layout": ["split_v", 0.35], "stone": ["chambers", 2, 3, 0.14], "push": [-1, 34, 10],
		 "bouncers": [_b("elite", SCARY), _b("basic", SCARY, 2), _b("basic", CUTE)], "items": [_i("idol", SCARY, 0.75, 0.5)], "tip": ""},
		{"id": "17-4", "name": "Crowned Fuzzy", "layout": ["split_h", 0.65], "push": [1, 34, 10],
		 "bouncers": [_b("elite", CUTE), _b("basic", CUTE, 2), _b("basic", SCARY)],
		 "items": [_i("nest", CUTE, 0.1, 0.08), _i("idol", CUTE, 0.85, 0.12)], "tip": ""},
		{"id": "17-5", "name": "King of Bones", "layout": ["split_h", 0.3], "stone": ["cross"], "push": [-1, 35, 8],
		 "bouncers": [_b("elite", SCARY), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("idol", SCARY, 0.2, 0.88), _i("idol", SCARY, 0.8, 0.6), _i("nest", SCARY, 0.8, 0.9)], "tip": "finale"},
		# ================================================ World 18: Labyrinth - mazes
		{"id": "18-1", "name": "Maze Runner", "layout": ["split_h", 0.35], "stone": ["maze", 4, 5, 11], "push": [-1, 33, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)], "tip": "maze"},
		{"id": "18-2", "name": "Straight Maze", "layout": ["split_v", 0.65], "stone": ["maze", 3, 4, 5], "curl": "straight", "push": [1, 33, 10],
		 "bouncers": [_b("basic", CUTE, 5), _b("basic", SCARY)],
		 "zones": [_z("shrine", SCARY, 0.17, 0.88, 0.09, "true")], "tip": "curl"},
		{"id": "18-3", "name": "Minotaur", "layout": ["split_h", 0.35], "stone": ["maze", 4, 4, 3], "push": [-1, 34, 10],
		 "bouncers": [_b("stalker", SCARY, 2), _b("basic", SCARY, 2), _b("basic", CUTE)], "items": [_i("charm", 0, 0.375, 0.125)], "tip": "stalker"},
		{"id": "18-4", "name": "Penned In", "layout": ["split_h", 0.25], "stone": ["maze", 3, 3, 9], "push": [-1, 32, 10], "pens": 3,
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)], "tip": ""},
		{"id": "18-5", "name": "The Heart of It", "layout": ["split_v", 0.3], "stone": ["maze", 5, 6, 21], "push": [-1, 35, 8],
		 "bouncers": [_b("basic", SCARY, 6), _b("basic", CUTE)], "items": [_i("idol", SCARY, 0.9, 0.5), _i("nest", SCARY, 0.9, 0.92)], "tip": "finale"},
		# ================================================ World 19: Eclipse - everything mixed
		{"id": "19-1", "name": "Penumbra", "layout": ["diag", 0.36, true], "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("den", SCARY, 0.2, 0.85), _i("den", SCARY, 0.75, 0.9)], "zones": [_z("shrine", SCARY, 0.55, 0.75, 0.1, "arc")], "tip": "curse"},
		{"id": "19-2", "name": "Umbra", "layout": ["blobs", 6, CUTE, 0.12, 8], "push": [-1, 34, 10],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.5, 0.5)]), _b("basic", SCARY, 3), _b("basic", CUTE)],
		 "items": [_i("lantern", SCARY, 0.5, 0.9)], "zones": [_z("hold", CUTE, 0.5, 0.5, 0.12)], "tip": ""},
		{"id": "19-3", "name": "Corona", "layout": ["donut", 0.12, 0.45, SCARY], "curl": "arc", "push": [-1, 34, 10], "pens": 2,
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)],
		 "zones": [_z("shrine", CUTE, 0.5, 0.2, 0.09, "true")], "tip": "arcs"},
		{"id": "19-4", "name": "Totality", "layout": ["split_h", 0.35], "stone": ["dots", 3, 4, 0.03], "curl": "straight", "push": [-1, 34, 10],
		 "bouncers": [_b("basic", SCARY, 3), _b("basic", CUTE)],
		 "items": [_i("burrow", SCARY, 0.5, 0.9), _i("seed", SCARY, 0.15, 0.7), _i("idol", SCARY, 0.85, 0.75)], "tip": ""},
		{"id": "19-5", "name": "Eclipse", "layout": ["spiral"], "push": [-1, 38, 7],
		 "bouncers": [_b("elite", SCARY), _b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.85, 0.85), _i("nest", SCARY, 0.15, 0.85), _i("charm", 0, 0.15, 0.15)], "zones": [_z("shrine", SCARY, 0.5, 0.5, 0.1, "curly")], "tip": "finale"},
		# ================================================ World 20: Midnight - the gauntlet
		{"id": "20-1", "name": "Eleven Bells", "layout": ["island", 0.38, CUTE], "push": [1, 36, 8],
		 "bouncers": [_b("basic", CUTE, 2), _b("basic", SCARY)],
		 "items": [_i("nest", CUTE, 0.4, 0.4), _i("den", CUTE, 0.6, 0.6), _i("lantern", CUTE, 0.6, 0.38), _i("burrow", CUTE, 0.4, 0.62)], "tip": "remix"},
		{"id": "20-2", "name": "Witch Light", "layout": ["split_h", 0.3], "curl": "curly", "push": [-1, 36, 8],
		 "bouncers": [_bat("basic", SCARY, [V.call(0.3, 0.7)]), _b("basic", SCARY, 2), _b("basic", CUTE)],
		 "items": [_i("lantern", SCARY, 0.8, 0.6), _i("idol", SCARY, 0.6, 0.9)],
		 "zones": [_z("hold", CUTE, 0.3, 0.7, 0.1), _z("shrine", CUTE, 0.15, 0.9, 0.08, "true")], "tip": "remix"},
		{"id": "20-3", "name": "Bat Cathedral", "layout": ["split_h", 0.25], "stone": ["chambers", 3, 2, 0.14], "push": [-1, 34, 10], "pens": 4,
		 "bouncers": [_b("basic", SCARY, 5), _b("basic", CUTE)], "items": [_i("nest", SCARY, 0.5, 0.9), _i("charm", 0, 0.5, 0.12)], "tip": "remix"},
		{"id": "20-4", "name": "Night Terrors", "layout": ["checker", 3, 4], "push": [-1, 36, 8],
		 "bouncers": [_b("basic", SCARY, 4), _b("basic", CUTE)],
		 "items": [_i("den", SCARY, 0.5, 0.125), _i("den", SCARY, 0.17, 0.875), _i("burrow", SCARY, 0.83, 0.375), _i("idol", SCARY, 0.5, 0.625),
			_i("charm", 0, 0.17, 0.125), _i("charm", 0, 0.83, 0.875), _i("bomb", 0, 0.5, 0.375)], "tip": "remix"},
		{"id": "20-5", "name": "Midnight", "layout": ["split_h", 0.3], "stone": ["ring", 0.42], "push": [-1, 40, 6],
		 "bouncers": [_b("boss", SCARY, 1, 0.85), _bat("basic", SCARY, [V.call(0.2, 0.85)]), _b("basic", SCARY, 3), _b("basic", CUTE)],
		 "items": [_i("nest", SCARY, 0.8, 0.88), _i("idol", SCARY, 0.5, 0.92), _i("charm", 0, 0.12, 0.1), _i("charm", 0, 0.88, 0.1)],
		 "zones": [_z("hold", CUTE, 0.2, 0.85, 0.1)], "tip": "finale"},
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
		"halo":
			# ["halo", u, v, r, door_deg, door_width_deg]: a round wall with one door
			var c := Vector2((u - float(st[1])) * asp, v - float(st[2]))
			if absf(c.length() - float(st[3])) > wall * 0.9:
				return false
			var ang := rad_to_deg(atan2(c.y, c.x))
			return absf(wrapf(ang - float(st[4]), -180.0, 180.0)) > float(st[5]) * 0.5
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
