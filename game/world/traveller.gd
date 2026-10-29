class_name Traveller
extends Pedlar
## Hild Ashby, a wool-wife from the fell farms carrying a bundle of fleeces down to the coast
## market: the second walker on the old road, Wat's rig and road cut as a woman. She comes over
## the fell from the north-west at 14:30, the hour Wat walks back the other way, so the two of
## them meet on the road through the village: whoever sees the other first slows, Wat calls the
## news across, she answers, and they go on, keeping to their right so they pass left side to
## left side. She does not stand about in the village (she has a market to make), but she
## does not walk past a neighbour without a word: when Edda or Osric is out of doors near her
## line (Edda about her round, Osric on his wall) she stops, calls a word across, gets an answer
## and goes on, once each per walk; Wat coming the other way always has the first claim on her.
## She nods to the hero if he comes close and can be spoken to like the others. Bots read
## `journeys` and `greeted`.

const NOD_R := 7.5                         # she passes a word with a neighbour this near her line
const WAT_FIRST := 14.0                    # ...unless Wat is this near: she keeps herself for him
## What she calls to a neighbour in passing, by the hour, and what they say back.
const HILD_EX := {
	"Edda": {
		"morning": [
			["Morning, Edda! Anything for the coast?", "Only my love to the sea, Hild, and mind it doesn't spill."],
		],
		"day": [
			["Edda! Is that lantern of yours still leaning?", "It's leaned since your mother walked this road. Go on with you."],
			["Wat's on the road behind me, Edda, talking to the sheep.", "Then the sheep have my sympathy. Safe down, Hild."],
		],
		"evening": [
			["Light it early tonight, Edda. There's weather on the fell.", "I always light it early. It's the rest of you that's late."],
		],
	},
	"Osric": {
		"morning": [
			["Morning, Osric. Still on that wall?", "Still here, lass. The wall and me, we've an understanding."],
		],
		"day": [
			["Osric! Your ewe with the limp is down by the ford.", "Is she now. She'll come up when she's hungry, like the rest of us."],
			["Three ewes' worth on my back, Osric. Want to lift it?", "I lifted my share of fleeces, Hild. Forty years of them. You carry on."],
		],
		"evening": [
			["You'll catch your death on that wall, old man.", "Then it'll find me leaning, and comfortable."],
		],
	},
}

func _init() -> void:
	exchanges = {}
	who = "Hild"
	who_title = "Wool-wife on the coast road"
	body_wool = Color(0.15, 0.14, 0.12)
	body_patch = Color(0.09, 0.08, 0.07)
	idle_roll = 0.013
	idle_cycle = 6.6
	idle_breath = 3.9
	_it = 2.0
	set_outs = [14.5]
	back_i = -1                      # always the morning way: in from the fell, out to the meadow
	stand_k = 0.0
	keep_right = 1.0
	intro = [
		"Hild Ashby. Fleeces, from the fell farms, for the coast. No, you can't have one, they're counted.",
		"Wat'll be on the road the other way about now. He always is. You can set a sundial by that man's mouth.",
	]
	lines = {
		"road": [
			"Three days to the coast and two back, with the bundle lighter. That's the whole of my year, near enough.",
			"Don't go up by the keep after dark. My mother said it, her mother said it. I've never asked why.",
			"Edda's lantern's the last light before the fell. After that you go by the ruts and the stars.",
		],
		"shelter": [
			"Wet fleece weighs twice. Out of my way, there's a good lad.",
			"Rain off the sea. It'll follow me all the way down now.",
		],
	}

func _dress() -> void:
	# a linen coif under a dark wool hood, a grey-brown shawl, a kirtle of undyed brown wool
	# to the ankle, a hemp girdle, mud-greyed wraps; the fleeces in a creel on her back
	garb.palette = {
		"hood": [Color(0.17, 0.16, 0.14), Color(0.27, 0.255, 0.22), 0.3],
		"hat": [Color(0.035, 0.03, 0.026), Color(0.19, 0.17, 0.145), 0.3],
		"mantle": [Color(0.05, 0.045, 0.038), Color(0.24, 0.215, 0.18), 0.35],
		"robe": [Color(0.075, 0.058, 0.042), Color(0.32, 0.25, 0.18), 0.4],
		"sash": [Color(0.07, 0.061, 0.046), Color(0.25, 0.218, 0.162), 0.35],
		"wraps": [Color(0.075, 0.07, 0.062), Color(0.31, 0.294, 0.262), 0.4],
		"basket": [Color(0.065, 0.055, 0.042), Color(0.34, 0.30, 0.24), 0.45],
	}
	garb.hatless = true
	garb.hood_linen = true
	# a long kirtle near the ankle: kilted to the knee, the plate knees and boots read as armour
	garb.robe_len = 1.25
	garb.robe_wide = 1.2
	garb.skirt = true
	garb.smock = true
	garb.mantle_wool = true
	garb.basket = true
	garb.basket_wares = true
	garb.skin_col = Color(0.27, 0.205, 0.175)
	garb.fill_gain = 1.4

## A walking staff in her right hand; no lantern (she is off the road by dusk).
func _kit() -> void:
	if hand_mark == null:
		return
	staff = garb.walking_staff()
	staff.name = "Staff"
	hand_mark.add_child(staff)
	staff.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 0.25), Vector3(0.0, 0.08, 0.02))

func settle(w: Node3D, at_hour: float) -> void:
	super.settle(w, at_hour)
	road_mate = w.get("pedlar")

## Wat she answers (he opens on her); Edda and Osric she opens on herself, in passing.
func _pick_mate() -> void:
	if greeting > 0.0:
		return
	if road_mate != null and road_mate.visible and global_position.distance_to(road_mate.global_position) < WAT_FIRST:
		mate = road_mate
		exchanges = {}
		_greet_armed = false
		return
	var best: Villager = null
	var bd := INF
	for v in [edda, osric]:
		if v == null or v.state == IN or not v.visible or greeted.has(v.who):
			continue
		var d := global_position.distance_to(v.global_position)
		if d < bd:
			bd = d
			best = v
	mate = best
	if mate == null or not on_road:
		exchanges = {}
		_greet_armed = false
		return
	exchanges = HILD_EX.get(mate.who, {})
	greet_r = NOD_R
	part_r = NOD_R + 4.0
	_greet_armed = true
