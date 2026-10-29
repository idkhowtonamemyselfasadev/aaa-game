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
##   05:50 round to the garth at first light to lift the hen house's pop-hole slide (they
##         stay in until he does), then back to his step
##   19:00 stands by the hen house while they go up the ladder for the night; when the last
##         is in he steps up beside the ladder and drops the slide over the hole against the
##         fox (he waits on, up to 21:00, if one is still out)
##   19:40 back to his step for the last of the light, 21:00 in to bed
## Woken in the night (Brack barking at a fox at the hens: StoneCottage.rouse), he lights a
## candle, and a little after comes out with his horn lantern lit, across the yard to the
## squeeze gap in the east wall, where he holds it up to look down the gable toward the garth
## and calls out into the dark; then back in to bed.
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
	"slide": [Vector2(-2.82, -7.8), Vector2(-3.2, -8.5)],     # beside the ladder, at the slide
}
const OPEN_H := 5.8              # out to lift the slide at first light
const SHUT_BY := 19.67           # the slide is down by now on a quiet evening
const LATCH_UP := 0.8            # s to reach the slide's handle (and as long back)
## Through the squeeze stile in the back wall (DryWall.STILE_AT, the slot at about
## (-1.2, -10.5)) and out onto the fell footpath (YardGround.PATHS_LOCAL[2]).
const STILE_WAY := [Vector2(-1.1, -9.4), Vector2(-1.18, -10.0), Vector2(-1.22, -10.5), Vector2(-1.26, -11.05), Vector2(-1.7, -13.15)]
## His spot on the fell side: [stand, look-at], up the slope where the flock was.
const FELL := [Vector2(-2.3, -15.4), Vector2(-4.6, -23.0)]
const LEAN_IN := 1.6             # s to settle onto the wall
const GAZE_IN := 1.4             # s to settle into his stance on the fell
const SHADE_CYCLE := 15.0        # s between raising a hand to the brim against the low sun
const ROUSE_OUT := 11.0          # s from the barking waking him to his door opening (boots, lantern)
const LOOKOUT_HOLD := 26.0       # s stood at the gap with the lantern up, then back in
const LIFT_IN := 0.9             # s to raise the lantern / lower it

var cottage: StoneCottage
var lean := 0.0                  # 0 upright .. 1 forearms on the wall
var leans := 0                   # times he settled onto the wall (bots)
var stiles := 0                  # times he squeezed through the stile, either way (bots)
var gaze := 0.0                  # 0 .. 1 standing on the fell side, looking up where the flock was
var shades := 0                  # times he raised a hand to the brim on the fell (bots)
var _gt := 0.0                   # seconds into his stance on the fell (sway, scan, shading)
var latch := 0.0                 # 0 arm down .. 1 the hand on the slide's handle
var shuts := 0                   # times he dropped the slide at dusk (bots)
var opens := 0                   # and lifted it at first light
var _latch_t := -1.0             # s into a reach for the slide (-1 not reaching)
var _seen_in := 0.0              # s since he saw the last hen go in
var hold_latch := false          # shots: keep the hand on the slide
var hand_lantern: HandLantern    # carried out lit when woken in the night
var lift := 0.0                  # 0 the lantern at his knee .. 1 held up before him
var lookouts := 0                # times he came out to look when woken (bots)
var calls := 0                   # times he called out into the dark (bots)
var _out_in := -1.0              # s until he comes out (negative: not woken)
var _look_t := -1.0              # s stood at the gap (negative: not there yet)
var _looking := false            # out of bed to look (until LOOKOUT_HOLD at the gap)
var hold_lift := false           # shots: keep the lantern up

func _init() -> void:
	exchanges = {}                   # Edda opens; he answers
	who = "Osric"
	# his sleeves and cuffs are the same undyed fleece-grey as the smock, not Edda's rust kirtle
	# wool (the base Villager value), which read as red cuffs under the grey cape
	body_wool = Color(0.15, 0.14, 0.125)
	body_patch = Color(0.08, 0.075, 0.065)
	idle_roll = 0.018                # an old man's weight shift: wider, slower, slow old lungs
	idle_cycle = 9.0
	idle_breath = 4.6
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
		"open": [
			"Out you come. Mind the fox's been round. I can smell him on the wall.",
			"First light and they're shouting at me through the boards. Like being married.",
		],
		"lookout": [
			"Was that the fox? Brack's not a dog to bark at nothing. Not at my age, nor his.",
			"Hold that light still. No, you've no light. Hold yourself still, then.",
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
		# darker oiled wool: at 0.24 the cape read pale grey and flat against the field at dusk
		"mantle": [Color(0.045, 0.041, 0.036), Color(0.19, 0.172, 0.142), 0.35],
		# darker again: the undyed fleece-grey read bright against the dusk (0.38 too)
		"robe": [Color(0.09, 0.081, 0.07), Color(0.32, 0.298, 0.26), 0.4],
		# old grey-brown hemp: at 0.42 ochre the girdle was the brightest patch on him at dusk
		"sash": [Color(0.07, 0.061, 0.046), Color(0.25, 0.218, 0.162), 0.35],
		# mud-greyed linen: at 0.40 the shin wraps lit up under the darker smock
		"wraps": [Color(0.075, 0.07, 0.062), Color(0.31, 0.294, 0.262), 0.4],
	}
	# to the calf with side gores: at 0.85 the old plate knee cops showed below the hem
	garb.robe_len = 1.05
	garb.robe_wide = 1.15
	garb.skirt = true
	garb.felt_hat = true
	# no face cloth: his own weathered face, the nose, and a grizzled grey beard
	garb.beard = true
	# grizzled: dark hair shot with grey, not white (a pale beard under the fill read as a
	# white mask in the shade at 3 m; 0.20 still read pale grey-white at 1 m)
	garb.beard_col = Color(0.14, 0.135, 0.125)
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
	# a horn lantern by its ring in the right fist, taken out when he is woken in the night
	hand_lantern = HandLantern.new()
	hand_lantern.name = "HandLantern"
	hand_lantern.facing = body
	hand_mark.add_child(hand_lantern)
	hand_lantern.position = Vector3(0.0, 0.08, 0.025)
	hand_lantern.visible = false

## The calls he puts out into the dark from the gap (to the hero on the HUD when near).
const CALLS := [
	"Who's that down there? Go on! Get off out of it, you red thief!",
	"Is that you, fox? I've a stick and I've a long memory. Off with you!",
]

## Woken by the dog in the night (StoneCottage.rouse): out with the lantern in a little while.
func roused() -> void:
	if state != IN or activity != "in" or _out_in >= 0.0 or _looking:
		return
	if weather != null and weather.rain > RAIN_IN:
		return                        # not out in that; he listens from his bed
	_out_in = ROUSE_OUT

## Out of his door to look at the gap with the lantern (Brack trots over to sit by him).
func out_looking() -> bool:
	return _looking and state != IN

## Where he stands at the gap and the way he faces there, down the gable to the garth.
func lookout_spot() -> Array:
	return _spots["lookout"]

## His day's spots round the stone cottage and in the garth, then where he is now.
func settle(w: Node3D, at_hour: float) -> void:
	world = w
	_reset_greet()
	weather = w.get("weather")
	player = w.get_node_or_null("Player")
	terrain = w.get_node("Terrain")
	cottage = w.get("stone_cottage")
	cottage.keeper = self             # his lamp burns only while he is in
	hens = w.get("hens")
	_rng.seed = 5353
	var fy := cottage.global_rotation.y      # the door side's facing (local +z)
	_spots["door"] = [_at(C_DOOR), fy]
	_spots["door_in"] = [_at(C_DOOR_IN), fy]
	for i in WAY.size():
		_spots["way%d" % i] = [_at(WAY[i]), 0.0]
	for i in STILE_WAY.size():
		_spots["stile%d" % i] = [_at(STILE_WAY[i]), 0.0]
	# the squeeze gap in the east yard wall, looking down the outside of the gable to the garth
	var la := _at(WAY[1])
	var lb := _at(WAY[2])
	_spots["lookout"] = [la, atan2(lb.x - la.x, lb.z - la.z)]
	_out_in = -1.0
	_look_t = -1.0
	_looking = false
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

func _house() -> HenHouse:
	return hens.house if hens != null else null

func _want_for(h: float) -> String:
	if _looking:
		return "lookout"
	var hh := _house()
	if hh != null and h >= 19.0 and h < 21.0 and hh.shut < 0.5:
		return "shut"                 # until they are in and the slide is down
	if hh != null and h >= OPEN_H and h < 19.0 and hh.shut > 0.5:
		return "open"                 # first light (or after the rain kept him in)
	if h >= OPEN_H and h < 6.75:
		return "wake"                 # lifted: on his step till the day starts
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
	if a == "open":
		return "slide"
	return a

func _door_point() -> Vector3:
	return cottage.to_global(Vector3(C_DOOR.x, 1.0, StoneCottage.DEP * 0.5))

func _works(a: String) -> bool:
	return a == "eggs" or a == "tend"

static func in_garth(a: String) -> bool:
	return GARTH.has(a) or a == "fell" or a == "open"

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
	# to and from the gap in the east yard wall by the yard side of it
	var at_look := global_position.distance_to(_spots["lookout"][0]) < 0.8
	if (activity == "lookout") != at_look and state != IN or (activity == "lookout" and state == IN):
		path.append(_spots["way0"][0])
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
	if global_position.distance_to(_spots["slide"][0]) < 0.45:
		goal_yaw = _spots["slide"][1]
	if activity == "lookout" and _look_t < 0.0:
		_look_t = 0.0
		lookouts += 1

func _physics_process(delta: float) -> void:
	var on := state == STAND and activity == "lean" and not noticing and talking <= 0.0
	lean = move_toward(lean, 1.0 if on else 0.0, delta / LEAN_IN)
	var up := state == STAND and activity == "fell" and not noticing and talking <= 0.0
	gaze = move_toward(gaze, 1.0 if up else 0.0, delta / GAZE_IN)
	_update_slide(delta)
	_update_lookout(delta)
	if gaze > 0.0:
		var was := fmod(_gt, SHADE_CYCLE)
		_gt += delta
		if was < 1.5 and fmod(_gt, SHADE_CYCLE) >= 1.5:
			shades += 1
	else:
		_gt = 0.0
	super._physics_process(delta)

## Woken: the door opens after ROUSE_OUT s and he walks to the gap with the lantern lit at his
## knee; there he lifts it before him, peers down the gable, calls out once and again, and
## after LOOKOUT_HOLD s goes back in (the lantern dies as he shuts the door behind him).
func _update_lookout(delta: float) -> void:
	if _out_in >= 0.0:
		_out_in -= delta
		if _out_in < 0.0:
			_looking = true              # the door opens: out to the gap
			_look_t = -1.0
	if _looking and weather != null and weather.rain > RAIN_IN:
		_looking = false                 # rain coming on: back in
	if _looking and _look_t >= 0.0 and state == STAND and activity == "lookout":
		var was := _look_t
		if talking <= 0.0:
			_look_t += delta
		if (was < 2.4 and _look_t >= 2.4) or (was < 13.0 and _look_t >= 13.0):
			_call_out()
		if _look_t >= LOOKOUT_HOLD:
			_looking = false             # nothing more to see: back to bed
	if not _looking and state == IN:
		_look_t = -1.0
	# lit from the door out and back to it (it dies as he shuts the door)
	var out := _looking or (_look_t >= LOOKOUT_HOLD and state == WALK)
	var up := (_looking and activity == "lookout" and state == STAND and not noticing) or hold_lift
	lift = move_toward(lift, 1.0 if up else 0.0, delta / LIFT_IN)
	if hand_lantern != null:
		hand_lantern.want = 1.0 if out or hold_lift else 0.0
		hand_lantern.face_fill = lift
		var hb := skel.find_bone("mixamorig_Head") if skel != null else -1
		if hb >= 0:
			var head := skel.global_transform * skel.get_bone_global_pose(hb).origin
			hand_lantern.face_at = head + Vector3.UP * 0.11 + body.global_transform.basis.z * 0.18   # up 0.16 / out 0.26 lit a hard band on the brim; this sits behind its edge
		hand_lantern.visible = (out or hold_lift or hand_lantern.lit > 0.02) and state != IN

func _call_out() -> void:
	var line: String = CALLS[calls % CALLS.size()]
	calls += 1
	spoke.emit(global_position + Vector3.UP * 1.6, false)
	if player == null:
		return
	var hud = player.get_node_or_null("Hud")
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if hud != null and d < HEAR_R * 2.0 and not hud.saying():
		var secs := 2.4 + 0.055 * line.length()
		hud.say(who, line, secs)
		last_line = line
		heard += 1

## The slide: at dusk, a few seconds after the last hen has gone in, he steps up beside the
## ladder, reaches down to the handle and lets the slide drop; at first light he reaches and
## draws it up. Then back to his stand (dusk) or on with his day (it is "open" no longer).
func _update_slide(delta: float) -> void:
	var hh := _house()
	if hh == null:
		return
	var free := not noticing and talking <= 0.0
	if hold_latch:
		latch = 1.0
		return
	if _latch_t >= 0.0:
		_latch_t += delta
		latch = move_toward(latch, 1.0 if _latch_t < LATCH_UP + 0.5 else 0.0, delta / LATCH_UP)
		if _latch_t >= LATCH_UP + 0.1 and _latch_t - delta < LATCH_UP + 0.1:
			if activity == "shut":
				hh.close()
				shuts += 1
			else:
				hh.open()
				opens += 1
		if _latch_t > LATCH_UP * 2.0 + 0.6:
			_latch_t = -1.0
			if activity == "shut":
				# back from the ladder to his stand till he goes in
				path.clear()
				path.append(_spots["shut"][0])
				state = WALK
		return
	latch = move_toward(latch, 0.0, delta / LATCH_UP)
	if state != STAND or not free:
		_seen_in = 0.0
		return
	var at_slide := global_position.distance_to(_spots["slide"][0]) < 0.45
	if activity == "open" and at_slide and hh.shut > 0.5:
		_latch_t = 0.0
	elif activity == "shut" and hh.shut < 0.5 and hens.all_in():
		_seen_in += delta
		if _seen_in > 2.5:
			_seen_in = 0.0
			if at_slide:
				_latch_t = 0.0
			else:
				path.clear()
				path.append(_spots["slide"][0])
				state = WALK
	else:
		_seen_in = 0.0

## Leaning on the wall: bent forward at the hips over the cope, forearms laid on it, head up
## to look out over the field.
func _pose() -> void:
	super._pose()
	if crumple == null:
		return
	if gaze > 0.0:
		_pose_fell()
	if lift > 0.0:
		# the lantern held up and out before him at the height of his chin, to throw its light
		# down the dark beyond the wall; the head a little forward under the brim, peering
		var u := lift * lift * (3.0 - 2.0 * lift)
		crumple.flick = maxf(crumple.flick, u)
		# (1.45/0.75 left it hanging at his waist: the henfox bot now holds the ring at 1.5 m+,
		# a hand's length out before him)
		crumple.flick_arm = 2.2
		crumple.flick_elbow = 0.15
		crumple.flick_out = 0.4
		# (an open hand read as a wave in `lookout4`: the fist closes round the bail)
		crumple.grip = maxf(crumple.grip, u)
		crumple.spine += 0.06 * u
		# (0.08 left his face a dark smudge under the brim in `lookout2`: chin up, eyes out)
		crumple.neck += 0.2 * u
	if latch > 0.0:
		# a stiff old man's reach down to the handle at hip height: bent at the hips and the
		# knees, the right arm out and down, the head bowed to see it
		var k := latch * latch * (3.0 - 2.0 * latch)
		crumple.hip += 0.38 * k
		crumple.knee += 0.22 * k
		crumple.spine += 0.3 * k
		crumple.neck -= 0.2 * k
		crumple.flick = maxf(crumple.flick, k)
		crumple.flick_arm = 1.15
		crumple.flick_elbow = 0.35
		crumple.flick_out = 0.0
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
		crumple.flick_out = 0.0
	# weight from one foot to the other: a slow roll of the whole body about the feet
	var sway := sin(_gt * TAU / 7.5) * g
	roll += 0.022 * sway
	model.transform = model.transform.rotated_local(Vector3.BACK, 0.022 * sway)

## Stood still in the yard, on his step or at the gap: Villager's weight shift, wider and slower
## (an old man's), breathing slower. Muted while he leans on the wall or reaches for the slide;
## kept, smaller, with the lantern up (he holds it out, so less roll). The fell has its own sway.
func _idle_still() -> bool:
	return super._idle_still() and gaze <= 0.0

func _idle_weight() -> float:
	return super._idle_weight() * (1.0 - lean) * (1.0 - 0.9 * latch) * (1.0 - 0.5 * lift)
