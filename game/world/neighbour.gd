class_name Neighbour
extends Villager
## Osric, Edda's neighbour in the stone cottage across the yard: an old shepherd gone stiff in
## the knees, whose hens they are (Edda feeds them for him over the garth wall; he keeps the
## house and the eggs). Edda's rig and garb builder, cut as an old working man: a battered felt
## hat, an oiled wool cape, a long fleece-grey smock, a rope girdle, and no face cloth: his own
## weathered face with a nose and a grizzled grey beard (HeroGarb.beard). His cottage's lamp
## burns only while he is in (StoneCottage.keeper). His day by the clock:
##   06:45 out on his step, looking over the yard
##   07:15 round to the garth by the squeeze gap in the east yard wall, down the outside of
##         the gable and in at the field gate (it swings for him as it does for the hero);
##         lifts the nest box lid on the hen house and stoops in for the eggs
##   08:00 leans on the back wall of the garth with his forearms on the cope, looking out
##         over the field
##   10:30 tends the garth: stooping over the scratched ground (stones, muck, a dropped feather)
##   12:15 in for his dinner, the long way round again
##   13:00 back to the wall, 15:30 the garth again
##   16:45 out through the squeeze stile in the back wall and a few steps up the fell footpath,
##         to stand and look up the fell where his flock grazed (and back in the same way)
##   17:30 the wall in the evening light
##   19:00 stands by the hen house while they go up the ladder for the night
##   19:40 back to his step for the last of the light, 21:00 in to bed
## Rain sends him in, as it does Edda. He stops and turns to the hero when he comes close,
## and has his own lines for what he is about. Bots read Villager's counters plus `lean`.

const C_DOOR := Vector2(0.6, 3.8)            # on the step, before the door (cottage-local)
const C_DOOR_IN := Vector2(0.6, 1.9)
## The way between the yard and the garth: through the squeeze gap in the east yard wall,
## down the outside of the east gable and in at the field gate (DryWall run 0).
const WAY := [Vector2(4.0, 9.58), Vector2(5.97, 9.22), Vector2(7.3, 3.2), Vector2(6.9, -2.6), Vector2(5.85, -6.2), Vector2(2.67, -6.56)]
## Garth spots: [stand, look-at] in the cottage's frame.
const GARTH := {
	"eggs": [Vector2(-3.35, -7.05), Vector2(-3.47, -7.8)],    # before the nest box lid
	"lean": [Vector2(1.0, -9.5), Vector2(1.0, -14.0)],        # forearms on the back wall's cope
	"tend": [Vector2(-0.9, -5.6), Vector2(-1.3, -7.2)],
	"shut": [Vector2(-1.25, -8.25), Vector2(-2.06, -8.55)],   # by the ladder's foot at dusk
}
## Through the squeeze stile in the back wall (DryWall.STILE_AT, the slot at about
## (-1.2, -10.5)) and out onto the fell footpath (YardGround.PATHS_LOCAL[2]).
const STILE_WAY := [Vector2(-1.1, -9.4), Vector2(-1.18, -10.0), Vector2(-1.22, -10.5), Vector2(-1.26, -11.05), Vector2(-1.7, -13.15)]
## His spot on the fell side: [stand, look-at], up the slope where the flock was.
const FELL := [Vector2(-2.3, -15.4), Vector2(-4.6, -23.0)]
const LEAN_IN := 1.6             # s to settle onto the wall
const GAZE_IN := 1.4             # s to settle into his stance on the fell
const SHADE_CYCLE := 15.0        # s between raising a hand to the brim against the low sun

var cottage: StoneCottage
var lean := 0.0                  # 0 upright .. 1 forearms on the wall
var leans := 0                   # times he settled onto the wall (bots)
var stiles := 0                  # times he squeezed through the stile, either way (bots)
var gaze := 0.0                  # 0 .. 1 standing on the fell side, looking up where the flock was
var shades := 0                  # times he raised a hand to the brim on the fell (bots)
var _gt := 0.0                   # seconds into his stance on the fell (sway, scan, shading)

func _init() -> void:
	exchanges = {}                   # Edda opens; he answers
	who = "Osric"
	who_title = "Shepherd, the stone cottage"
	intro = [
		"Those are my hens Edda's feeding. Don't tell her I said mine. She thinks they're hers by now.",
		"Osric. I had the flock on the high fell forty years. Now I have a wall, and I lean on it.",
	]
	lines = {
		"wake": [
			"Wind's backed westerly. That's rain by the afternoon or I'm a liar, and I'm not, mostly.",
			"Morning. Mind the step, it's had my knees and it'll have yours.",
		],
		"eggs": [
			"Four. Bishop's laid away again. Under the woodpile, I'd wager, out of spite.",
			"Warm still. There's no breakfast like the one you take out from under a cross hen.",
		],
		"lean": [
			"That's where the fold was. You can see the line of it in the grass when the sun's low.",
			"I count them still, the sheep. In my head. Nine hundred and some. They don't get fewer there.",
			"The keep's gone dark up there for longer than you've been alive. Edda still looks at it. I look at the field.",
		],
		"tend": [
			"Hens are like the gentry. They scratch up a mess and leave it for the likes of me.",
			"Pick the stones out or they'll have the turf off down to the rock.",
		],
		"fell": [
			"Up there was the fold, and the fold was me. Now it's thistles, and I come and look at the thistles.",
			"You don't stop being a shepherd. You only stop having sheep.",
			"Wind off the tops. Smell it? Snow on the far fells already.",
		],
		"shut": [
			"Up you go. One at a time, like a sermon.",
			"Count them in. Fox counts them too, and he's better at it.",
		],
		"step": [
			"She'll have that lamp lit soon. Every night. I've stopped telling her.",
			"Sit on the wall if you like. It's the warmest stone in the vale at this hour.",
		],
	}

func _dress() -> void:
	# a battered felt hat, an oiled grey-brown wool cape, a long smock of undyed fleece-grey
	# wool to below the knee, a hemp rope girdle, grey wraps
	garb.palette = {
		# a dark hood under the hat (a pale one read as a ski mask round his face)
		"hood": [Color(0.035, 0.032, 0.028), Color(0.15, 0.14, 0.12), 0.4],
		# weathered near-black felt, near-neutral: any warmth read orange-brown in the dawn light
		"hat": [Color(0.03, 0.03, 0.029), Color(0.15, 0.145, 0.135), 0.3],
		"mantle": [Color(0.05, 0.046, 0.04), Color(0.24, 0.22, 0.18), 0.35],
		# a touch darker: the undyed fleece-grey read bright against the dusk
		"robe": [Color(0.10, 0.09, 0.078), Color(0.38, 0.355, 0.31), 0.4],
		"sash": [Color(0.12, 0.10, 0.065), Color(0.42, 0.36, 0.24), 0.3],
		"wraps": [Color(0.09, 0.085, 0.075), Color(0.40, 0.38, 0.34), 0.4],
	}
	garb.robe_len = 0.85
	garb.felt_hat = true
	# no face cloth: his own weathered face, the nose, and a grizzled grey beard
	garb.beard = true
	# grizzled: dark hair shot with grey, not white (a pale beard under the fill read as a
	# white mask in the shade at 3 m)
	garb.beard_col = Color(0.20, 0.19, 0.175)
	# weathered and wind-reddened, darker than the old default: a pale grey face glowed; a touch
	# greyer again (0.27/0.195/0.16 read as a flat orange-red mask under the low sun)
	garb.skin_col = Color(0.24, 0.18, 0.155)
	# the felt brim and the dark hood put his face in deep shade: a fill under it, but no more
	# than the shade around him (1.9 lit his face and beard as a pale mask on the fell at dusk)
	garb.fill_gain = 1.3
	# a wool smock over his chest: no armour plates under the cape's hem or in its open front
	garb.smock = true
	# an oiled wool cape, fuzzed and pilled like the smock: smooth cloth read as plastic
	garb.mantle_wool = true

func _kit() -> void:
	pass

## His day's spots round the stone cottage and in the garth, then where he is now.
func settle(w: Node3D, at_hour: float) -> void:
	world = w
	_reset_greet()
	weather = w.get("weather")
	player = w.get_node_or_null("Player")
	terrain = w.get_node("Terrain")
	cottage = w.get("stone_cottage")
	cottage.keeper = self             # his lamp burns only while he is in
	_rng.seed = 5353
	var fy := cottage.global_rotation.y      # the door side's facing (local +z)
	_spots["door"] = [_at(C_DOOR), fy]
	_spots["door_in"] = [_at(C_DOOR_IN), fy]
	for i in WAY.size():
		_spots["way%d" % i] = [_at(WAY[i]), 0.0]
	for i in STILE_WAY.size():
		_spots["stile%d" % i] = [_at(STILE_WAY[i]), 0.0]
	var fs := _at(FELL[0])
	var fl := _at(FELL[1])
	_spots["fell"] = [fs, atan2(fl.x - fs.x, fl.z - fs.z)]
	for k in GARTH:
		var st := _at(GARTH[k][0])
		var lk := _at(GARTH[k][1])
		_spots[k] = [st, atan2(lk.x - st.x, lk.z - st.z)]
	var dg = w.get("dry_wall")
	if dg != null and dg.field_gate != null and not dg.field_gate.walkers.has(self):
		dg.field_gate.walkers.append(self)
	activity = ""
	path.clear()
	var a := _want_for(at_hour)
	var sp: Array = _spots[_spot_for(a)]
	_place(sp[0])
	goal_yaw = sp[1]
	body.rotation.y = goal_yaw
	activity = a
	state = IN if a == "in" else STAND
	lean = 1.0 if a == "lean" else 0.0
	gaze = 1.0 if a == "fell" else 0.0
	_gt = 2.6 if a == "fell" else 0.0      # a hand already rising to the brim (shots)
	_show(state != IN)

func _at(l: Vector2) -> Vector3:
	return cottage.to_global(Vector3(l.x, 0, l.y))

func _want_for(h: float) -> String:
	if h < 6.75 or h >= 21.0:
		return "in"
	if h < 7.25:
		return "wake"
	if h < 8.0:
		return "eggs"
	if h < 10.5:
		return "lean"
	if h < 12.25:
		return "tend"
	if h < 13.0:
		return "in"
	if h < 15.5:
		return "lean"
	if h < 16.75:
		return "tend"
	if h < 17.5:
		return "fell"
	if h < 19.0:
		return "lean"
	if h < 19.67:
		return "shut"
	return "step"

func _spot_for(a: String) -> String:
	if a == "in" or a == "shelter":
		return "door_in"
	if a == "wake" or a == "step":
		return "door"
	return a

func _door_point() -> Vector3:
	return cottage.to_global(Vector3(C_DOOR.x, 1.0, StoneCottage.DEP * 0.5))

func _works(a: String) -> bool:
	return a == "eggs" or a == "tend"

static func in_garth(a: String) -> bool:
	return GARTH.has(a) or a == "fell"

## Out on the fell side of the garth's back wall (cottage-local), past the stile.
static func past_stile(l: Vector3) -> bool:
	return l.z < -10.75 and l.x < 4.3

## Out of the door onto the step, and between the yard and the garth the long way round.
func _route(to: Vector3) -> void:
	path.clear()
	var here_garth := false
	var here_fell := false
	if state == IN:
		_place(_spots["door"][0])
		_show(true)
		door.emit(_door_point())
	else:
		var lh := cottage.to_local(global_position)
		here_garth = lh.z < -3.0 and lh.x < 4.3
		here_fell = past_stile(lh)
	if to.distance_to(_spots["door_in"][0]) < 0.1:
		to = _spots["door"][0]
	var to_garth := in_garth(activity)
	var to_fell := activity == "fell"
	if here_fell and not to_fell:
		for i in range(STILE_WAY.size() - 1, -1, -1):
			path.append(_spots["stile%d" % i][0])
		stiles += 1
	if here_garth and not to_garth:
		for i in range(WAY.size() - 1, -1, -1):
			path.append(_spots["way%d" % i][0])
	elif to_garth and not here_garth:
		for i in WAY.size():
			path.append(_spots["way%d" % i][0])
	if to_fell and not here_fell:
		for i in STILE_WAY.size():
			path.append(_spots["stile%d" % i][0])
		stiles += 1
	path.append(to)
	state = WALK
	stuck_t = 0.0

func _arrive() -> void:
	super._arrive()
	if activity == "lean":
		leans += 1

func _physics_process(delta: float) -> void:
	var on := state == STAND and activity == "lean" and not noticing and talking <= 0.0
	lean = move_toward(lean, 1.0 if on else 0.0, delta / LEAN_IN)
	var up := state == STAND and activity == "fell" and not noticing and talking <= 0.0
	gaze = move_toward(gaze, 1.0 if up else 0.0, delta / GAZE_IN)
	if gaze > 0.0:
		var was := fmod(_gt, SHADE_CYCLE)
		_gt += delta
		if was < 1.5 and fmod(_gt, SHADE_CYCLE) >= 1.5:
			shades += 1
	else:
		_gt = 0.0
	super._physics_process(delta)

## Leaning on the wall: bent forward at the hips over the cope, forearms laid on it, head up
## to look out over the field.
func _pose() -> void:
	super._pose()
	if crumple == null:
		return
	if gaze > 0.0:
		_pose_fell()
	if lean <= 0.0:
		return
	var l := lean * lean * (3.0 - 2.0 * lean)
	crumple.hip = lerpf(crumple.hip, 0.32, l)
	crumple.knee = lerpf(crumple.knee, 0.12, l)
	crumple.spine = lerpf(crumple.spine, 0.42, l)
	crumple.arm = lerpf(crumple.arm, 1.15, l)
	crumple.elbow = lerpf(crumple.elbow, 1.55, l)
	# (positive lifts the head: -0.45 bowed it so far the hat brim hid his face)
	crumple.neck = lerpf(crumple.neck, 0.3, l)
	crumple.clasp = lerpf(crumple.clasp, 0.45, l)

## Standing on the fell side looking up where his flock grazed: knees soft, the head lifted and
## slowly scanning the slope, his weight rocking from foot to foot, and now and then a hand
## raised to the hat brim against the low sun (the right arm, as the lantern reach does).
func _pose_fell() -> void:
	var g := gaze * gaze * (3.0 - 2.0 * gaze)
	crumple.knee += 0.07 * g
	crumple.hip += 0.04 * g
	crumple.spine += 0.06 * g
	crumple.neck += 0.16 * g
	crumple.head_turn += 0.22 * g * sin(_gt * TAU / 11.0)
	# the hand up from 1.5 s into each cycle, held about five seconds, then down again
	var c := fmod(_gt, SHADE_CYCLE)
	var sh := smoothstep(1.5, 2.6, c) * (1.0 - smoothstep(6.8, 8.0, c)) * g
	if sh > crumple.flick:
		crumple.flick = sh
		crumple.flick_arm = 2.05
		crumple.flick_elbow = 1.8
	# weight from one foot to the other: a slow roll of the whole body about the feet
	var sway := sin(_gt * TAU / 7.5) * g
	model.transform = model.transform.rotated_local(Vector3.BACK, 0.022 * sway)
