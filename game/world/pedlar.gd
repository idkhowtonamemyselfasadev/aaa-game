class_name Pedlar
extends Villager
## Wat Pennock, a pedlar on the old road over the vale: Harrowmere's passer-by. Edda's rig and
## garb builder, cut as a man on the road: a dark hood under a felt hat, a weathered russet
## cape, a long dun smock to the calf, a willow creel on his back with bolts of dyed
## cloth across its mouth, and an ash staff in his hand. He walks through twice a day:
##   09:00 up out of the south-east meadow, onto the green by the lantern post, where he stands
##         a while and calls a word to Edda across it; then on round the east gable of the
##         stone cottage and along the field side of its garth wall, where he stops for a word
##         with Osric if he is leaning on it, and off north-west over the fell
##   14:30 back the other way, the same stops in reverse
##   19:24 in the dusk, up out of the south-east meadow again with a horn lantern lit in his
##         left hand, its light swinging along the ruts, the same stops (he lodges at the fell
##         farm the nights he is late on the coast road); the lantern is put out by daylight
## Rain does not stop him; he hurries. When the hero comes close he stops and turns to him and
## can be spoken to like the others. Off the road he is not drawn. Bots read `journeys`,
## `stops`, `greeted` and Villager's counters.

## The road through, morning direction (world x, z): far out in the south-east meadow, up to
## the green below the lantern post; the rest is laid off the stone cottage (LEG_SC).
const ROAD_IN := [Vector2(44.0, -58.0), Vector2(14.0, -20.0), Vector2(-4.0, -2.0)]
const GREEN := Vector2(-8.6, 1.4)          # his stand on the green, by the lantern post
## Legs in the stone cottage's frame: round its east gable, along the outside of the garth's
## back wall (a stop facing Osric's lean spot over it), and away over the fell.
const LEG_SC := [Vector2(10.5, 7.0), Vector2(10.5, -4.0), Vector2(6.5, -12.0), Vector2(1.0, -12.4),
		Vector2(-10.0, -16.0), Vector2(-26.0, -40.0), Vector2(-40.0, -66.0)]
const WALL_STOP := 3                       # index in LEG_SC of the stop behind Osric's wall
const SET_OUT := [9.0, 14.5, 19.4]         # hours he sets off (morning and dusk in from the south-east)
const BACK := 1                            # the window that walks the road the other way
const STAND_GREEN := 26.0                  # s he stands on the green
const STAND_WALL := 14.0                   # s he stands at Osric's wall
const CALL_R := 15.0                       # he calls a word across the green this far
const MEET_R := 3.0                        # ...but a word with a fellow walker when they meet, near enough to touch
const CLEAR := 1.1                         # m he keeps between his line and the dog

var journeys := 0                # walks through finished (bots)
var stops := 0                   # stands reached on the way (bots)
var greeted := {}                # who he has passed a word with this walk -> true
var on_road := false
var sidesteps := 0               # times he has stepped round the dog (bots)
var set_outs: Array = SET_OUT    # hours he sets off (a fellow traveller keeps her own)
var back_i := BACK               # which of them walks the road the other way (-1: none)
var stand_k := 1.0               # share of his stands' length he stops for (0: walks straight through)
var keep_right := 0.0            # m his line keeps to the right of the road's centre
var road_mate: Pedlar            # the other walker on the fell road: he steps round her too
var _side_on := false
var edda: Villager
var osric: Villager
var staff: MeshInstance3D
var hand_lantern: HandLantern    # carried lit on the dusk walk
var _legs: Array = []            # [ground point, stand s, facing point or null]
var _leg := 0
var _stand_t := 0.0
var _set_out := {}               # window index -> true once walked today
var _last_h := -1.0
var _greets_seen := 0

const EX := {
	"Edda": {
		"morning": [
			["Morning, mistress! Salt from the coast, needles, a good brown thread?",
				"Salt! Leave me a twist of it on the step, Wat, I'll have eggs for you on your way back."],
			["Edda! Still splitting the whole oak wood on your own?",
				"Someone has to, and you never stop long enough to lift an axe."],
		],
		"day": [
			["That's me back over, Edda. Anything wanted before the fell?",
				"Thread, if you've a brown. And the news. You always have news."],
			["Your lantern's leaning. I'll not charge you for saying so.",
				"It's leaned twenty years. It knows the way it likes to stand."],
		],
		"evening": [
			["Benighted again, mistress. Hob's fire'll be in before I'm there.",
				"Then walk faster and talk less. Mind the ford in the dark."],
			["Two lanterns on the green tonight. Yours is the prettier.",
				"Mine stays where it's put. Go on, Wat, before the Hollows wake."],
		],
	},
	# Hild coming the other way on the afternoon road: they stop and pass the news
	"Hild": {
		"morning": [
			["Hild! You're early on the road. Fleeces fetch more before noon?",
				"They fetch the same. I just like to see your face fall when I'm there first."],
		],
		"day": [
			["Hild Ashby, as I live. Is the coast market worth the walk this week?",
				"Salt's dear and herring's cheap. And they're saying the keep's lamp was out again."],
			["Mind the ford, Hild, it's up past the stones since the rain.",
				"I've waded it with a fleece on my back since before you sold your first needle, Wat."],
			["Your bundle's bigger than you are today.",
				"It's three ewes' worth and a lamb's. Carry it for me then, if you're so taken with it."],
		],
		"evening": [
			["Late for the fell, Hild. Walk back with me to Hob's?",
				"And have the whole valley talking by morning? Keep your lantern, Wat, I know the way."],
		],
	},
	"Osric": {
		"morning": [
			["Still holding that wall up, Osric?",
				"It holds me up, lad. Mind the bull in the low field."],
			["Any word for the coast, old man?",
				"Tell the sea I'm not coming. It'll know what I mean."],
		],
		"day": [
			["Your hens are in the turnips at Hob's again.",
				"They're Edda's hens when they're in the turnips."],
			["Fine weather for leaning.",
				"There's no other kind, if you lean right."],
		],
		"evening": [
			["Hens shut in, Osric?",
				"Every one. The fox can read the latch, but it can't lift it."],
			["A late road and a cold one.",
				"Keep the light low and your feet on the ruts, lad."],
		],
	},
}

func _init() -> void:
	exchanges = {}
	who = "Wat"
	# dun road wool and dull leather trim, not Edda's rust kirtle: under his own candle at the
	# bail the rust sleeves and glove read as a glowing red blot (lampcube shot)
	body_wool = Color(0.17, 0.15, 0.12)
	body_patch = Color(0.10, 0.08, 0.06)
	idle_roll = 0.012                # a road-hardened man on his staff: a smaller, quicker shift
	idle_cycle = 6.0
	idle_breath = 3.6
	_it = 5.0                        # out of step with the others when they stand together
	who_title = "Pedlar on the fell road"
	intro = [
		"Wat Pennock. Needles, salt, thread, a tin cup that won't rust before Lammas. Buy nothing, then, but don't stand on my feet.",
		"I come over the fell twice a day while the road's open. Past the keep, mind. Nobody goes past the keep slow.",
	]
	lines = {
		"road": [
			"Every village on this road has a lantern on a post and a woman who lights it. Here it's Edda. She's the only one who waves.",
			"There's Hollows in the low meadow again. They don't trouble a pedlar. Nothing worth having in my creel, to them.",
			"The keep's lamp was out last night. Hesper's, up there. That's twice this month.",
		],
		"shelter": [
			"Wet road, light creel. The cloth's oiled. I'm not.",
			"Keep walking and the rain gets bored of you. That's the trick of it.",
		],
	}

func _dress() -> void:
	# a dark hood under a weathered felt hat, a russet cape gone brown with road dust, a dun
	# smock kilted to the shin, a cord girdle, grey wraps; an ash staff
	garb.palette = {
		"hood": [Color(0.04, 0.036, 0.03), Color(0.19, 0.17, 0.14), 0.4],
		"hat": [Color(0.035, 0.03, 0.026), Color(0.19, 0.17, 0.145), 0.3],
		"mantle": [Color(0.075, 0.04, 0.026), Color(0.33, 0.20, 0.13), 0.4],
		"robe": [Color(0.11, 0.095, 0.07), Color(0.42, 0.37, 0.28), 0.45],
		"sash": [Color(0.09, 0.075, 0.05), Color(0.36, 0.30, 0.20), 0.3],
		"wraps": [Color(0.08, 0.075, 0.065), Color(0.36, 0.34, 0.30), 0.45],
		# old peeled willow gone grey-brown: the fresh tan read as a red-orange grid by lantern light
		"basket": [Color(0.065, 0.055, 0.042), Color(0.34, 0.30, 0.24), 0.45],
	}
	# a long smock to the calf with side gores, so the old knee cops and boots under it
	# never show as armour (kilted to the shin, the plate knees read through)
	garb.robe_len = 1.05
	garb.robe_wide = 1.15
	garb.skirt = true
	garb.felt_hat = true
	garb.beard = true
	garb.beard_col = Color(0.25, 0.21, 0.165)
	garb.fill_gain = 1.7
	garb.smock = true
	garb.mantle_wool = true
	garb.basket = true
	garb.basket_wares = true

## His ash staff, gripped in the right hand.
func _kit() -> void:
	if hand_mark == null:
		return
	staff = garb.walking_staff()
	staff.name = "Staff"
	hand_mark.add_child(staff)
	# across the palm (the hand bone's x), foot forward and down ahead of the stride
	staff.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 0.25), Vector3(0.0, 0.08, 0.02))
	if left_mark == null:
		return
	# a horn lantern by its ring in the left fist, hanging plumb at his knee
	hand_lantern = HandLantern.new()
	hand_lantern.name = "HandLantern"
	hand_lantern.facing = body
	left_mark.add_child(hand_lantern)
	hand_lantern.position = Vector3(0.0, 0.08, 0.025)

## Lantern light wanted: on the road between dusk and first light.
static func lantern_for(h: float) -> bool:
	return h >= 19.0 or h < 5.8

## The dusk walk is his third road of the day: a shorter, wearier step.
func _pace() -> float:
	return 0.8 if world != null and lantern_for(_hour()) else 1.0

func settle(w: Node3D, at_hour: float) -> void:
	world = w
	_reset_greet()
	weather = w.get("weather")
	player = w.get_node_or_null("Player")
	terrain = w.get_node("Terrain")
	edda = w.get("villager")
	osric = w.get("neighbour")
	greet_r = CALL_R
	part_r = CALL_R + 4.0
	_rng.seed = 6161
	on_road = false
	_set_out.clear()
	_last_h = at_hour
	for i in set_outs.size():
		if at_hour > set_outs[i] + 0.05:
			_set_out[i] = true           # already gone by today
	state = IN
	activity = "in"
	path.clear()
	_show(false)
	for i in set_outs.size():
		if absf(at_hour - set_outs[i]) <= 0.05:
			set_out(i == back_i)
			_set_out[i] = true

## Sets off on the road through the village now (`back`: the afternoon way, north-west in).
func set_out(back: bool) -> void:
	var sc: StoneCottage = world.get("stone_cottage")
	_legs.clear()
	for p in ROAD_IN:
		_legs.append([_ground(p), 0.0, null])
	var lp: Vector3 = world.get("lantern_post").global_position if world.get("lantern_post") != null else _ground(GREEN)
	var hm: Node3D = world.get("white_cottage")
	# stands on the green looking between the lantern post and Edda's door
	_legs.append([_ground(GREEN), STAND_GREEN * stand_k, (lp + hm.global_position) * 0.5 if hm != null else lp])
	for i in LEG_SC.size():
		var g := sc.to_global(Vector3(LEG_SC[i].x, 0, LEG_SC[i].y))
		var look = sc.to_global(Vector3(1.0, 0, -9.5)) if i == WALL_STOP else null
		_legs.append([_ground(Vector2(g.x, g.z)), STAND_WALL * stand_k if i == WALL_STOP else 0.0, look])
	if back:
		_legs.reverse()
	if keep_right != 0.0:
		_keep_side()
	greeted.clear()
	on_road = true
	activity = "road"
	_leg = 0
	_place(_legs[0][0])
	_show(true)
	_leg = 0
	_go_leg(1)

## Moves each leg's point keep_right m off to the right of the way he walks through it, so two
## walkers coming at each other along the same road pass left side to left side.
func _keep_side() -> void:
	var pts: Array = []
	for l in _legs:
		pts.append(l[0])
	for i in _legs.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var f := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var r := Vector3(-f.z, 0.0, f.x)
		var q: Vector3 = pts[i] + r * keep_right
		_legs[i][0] = _ground(Vector2(q.x, q.z))

func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.y), p.y)

func _go_leg(i: int) -> void:
	_leg = i
	if _leg >= _legs.size():
		# off over the fell: out of the world's way until the next walk
		on_road = false
		journeys += 1
		state = IN
		activity = "in"
		path.clear()
		_show(false)
		return
	path.clear()
	path.append(_legs[_leg][0])
	state = WALK
	stuck_t = 0.0

## Steps round Brack where it sits or potters in his road instead of walking through it: if the
## dog is ahead within a few strides and closer than CLEAR to his line, he bends his course off
## to the side it is not on, more the closer it lies, and comes back onto the line past it.
func _steer(dir: Vector3) -> Vector3:
	dir = _steer_round(dir, world.get("dog"))
	return _steer_round(dir, road_mate)

func _steer_round(dir: Vector3, dg: Node3D) -> Vector3:
	if dg == null or not dg.visible:
		return dir
	var o: Vector3 = dg.global_position - global_position
	o.y = 0.0
	var ahead := o.dot(dir)
	if ahead < -0.3 or ahead > 3.0:
		return dir
	var side := Vector3(dir.z, 0.0, -dir.x)
	var lat := o.dot(side)
	if absf(lat) >= CLEAR:
		return dir
	# off the dog's side; strongest when it is right on his line and a stride ahead
	var k := (1.0 - absf(lat) / CLEAR) * clampf(1.0 - (ahead - 0.8) / 2.2, 0.0, 1.0) * 1.6
	if ahead < 0.8:
		k = maxf(k, (1.0 - absf(lat) / CLEAR) * 1.6)
	sidesteps += 1 if k > 0.3 and not _side_on else 0
	_side_on = k > 0.3
	return (dir - side * signf(lat if absf(lat) > 0.01 else 1.0) * k).normalized()

func _want_for(_h: float) -> String:
	return "road" if on_road else "in"

func _spot_for(a: String) -> String:
	return a

## The road takes him on whatever the weather; rain only hurries him (activity "shelter").
func _begin(a: String) -> void:
	activity = a

func _arrive() -> void:
	state = STAND
	var leg: Array = _legs[_leg]
	if leg[1] > 0.0:
		stops += 1
		visits["stand"] = visits.get("stand", 0) + 1
		_stand_t = leg[1]
		if leg[2] != null:
			var d: Vector3 = leg[2] - global_position
			goal_yaw = atan2(d.x, d.z)
	else:
		_go_leg(_leg + 1)

func _door_point() -> Vector3:
	return global_position + Vector3.UP

func _works(_a: String) -> bool:
	return false

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var h := _hour()
	if h < _last_h - 12.0:
		_set_out.clear()                 # a new day
	_last_h = h
	if not on_road:
		for i in set_outs.size():
			if h >= set_outs[i] and h < set_outs[i] + 1.0 and not _set_out.has(i):
				_set_out[i] = true
				set_out(i == back_i)
	elif state == STAND and greeting <= 0.0 and talking <= 0.0 and not noticing:
		_stand_t -= delta
		if _stand_t <= 0.0:
			_go_leg(_leg + 1)
	if hand_lantern != null:
		hand_lantern.weather = weather
		hand_lantern.want = 1.0 if on_road and lantern_for(h) else 0.0
		hand_lantern.visible = on_road and (lantern_for(h) or hand_lantern.lit > 0.0)
	_pick_mate()
	super._physics_process(delta)
	if greets > _greets_seen:
		_greets_seen = greets
		if mate != null:
			greeted[mate.who] = true

## Whoever of Edda and Osric is nearest and out of doors is the one he calls to, once a walk.
func _pick_mate() -> void:
	if greeting > 0.0:
		return
	var best: Villager = null
	var bd := INF
	for v in [edda, osric, road_mate]:
		if v == null or v.state == IN or not v.visible:
			continue
		var d := global_position.distance_to(v.global_position)
		if d < bd:
			bd = d
			best = v
	mate = best
	if mate == null:
		exchanges = {}
		return
	exchanges = EX.get(mate.who, {})
	# Edda he calls to across the green; Hild he meets on the road, face to face
	greet_r = MEET_R if mate == road_mate else CALL_R
	if greeted.has(mate.who) or not on_road:
		_greet_armed = false
		_greet_t = 0.0
	else:
		_greet_armed = true
