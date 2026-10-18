class_name Keeper
extends CharacterBody3D
## Hesper, the last keeper of the Shrine of Binding: the vale's first person. An old pilgrim in
## undyed wool and an ash-grey hood, stooped under a willow basket of deadwood (the hero's rig
## and garb, cut her own way: no hat, an ankle robe), living rough
## in the ruined keep on the knoll and keeping a day:
##   05:30 wakes against the inner wall, stands and walks out to the breach to watch the dawn
##   07:00 tends the sealed lid (stands over it, head bowed)
##   10:00 walks down to the nearest oaks and gathers under them, grove to grove
##   12:30 eats in the shade of the nearest oak to the keep
##   13:30 wanders out into the open meadow below the keep, stopping here and there to look
##         at the deer (who know her and graze on), 20-45 m out in front of the gateway
##   15:00 gathers again
##   17:30 watches the vale from the breach as the light goes
##   20:00 tends the lid again while the ember glows in the cuts
##   21:30 sits down against the inner wall and dozes, head on her knees, until dawn
## Under a rain front she breaks off and shelters under the nearest oak crown (Flora.shelter_at)
## until it passes, unless she is already in for the night. When the hero comes near she
## stops, turns to face him and watches him while he stays close; the first time, the HUD names
## her. Walks the ground with gravity; between the keep floor and the open slope she always
## passes through the breach. In reach the hero can speak to her (interact): the first time she
## introduces herself and the lid in three lines, after that each word gets a line that fits what
## she is doing and the hour; dozing, she only mumbles.

enum { WALK, STAND, SIT }

const WALK_SPEED := 1.25        # an old woman's unhurried pace
const SHELTER_SPEED := 1.9      # brisker in the rain
const ANIM_WALK_SPEED := 1.9    # the Walk clip's stride at 1x (Player)
const GRAVITY := 22.0
const NOTICE := 7.0             # stops and turns to the hero inside this
const NAME_AT := 4.5            # the HUD names her inside this, once
const RAIN_SHELTER := 0.35      # rain above this sends her under an oak
const KEEP_R := 3.6             # inside this of the site is the keep floor
const CURTAIN_R := 12.5         # the curtain wall ring (Ruins._curtain), gateway toward to_v
const TALK_R := 2.8             # the hero can speak to her inside this
const WANDER_R := Vector2(20.0, 45.0)   # her meadow walk: this far out from the keep...
const WANDER_CONE := 0.75       # ...within this of the line out through the gateway (rad), so a
								# straight leg between two stops never cuts the curtain wall

const INTRO := [
	"Mind the lid, lamplighter. Forty years I've swept it, and it has never once swept me back.",
	"That is the Shrine of Binding. Sealed since before the chain broke. No key, no handle, no manners.",
	"If that lantern of yours can bend the world, perhaps it can bend a stone. I should like to see that. I should like to see anything, once.",
]
const LINES := {
	"wake": [
		"Dawn comes a little later every year. I still get up for it. Someone ought to.",
		"Watch the far snow. When it goes pink, the Hollow walk back to their posts.",
		"Cold hands, cold stone, cold tea. Good morning.",
	],
	"tend": [
		"The seal kept quiet all night. It usually does.",
		"The cords on the lid warm when you stand near. They never once warmed for me.",
		"I sweep it so whoever opens it will know we did not forget.",
		"There was a bell for the keeper's hour. I ring it in my head now. Saves the rope.",
	],
	"tend_night": [
		"See the ember in the grooves? It wakes at night, like an old dog dreaming.",
		"Go and sleep, child. The lid is not going anywhere. That is rather its whole trouble.",
		"Sit by the fire if you like. The moths have the best seats, but they can be argued with.",
		"Every stick in that fire I carried up the hill on my back. Warm your hands slowly; they were expensive.",
	],
	"gather": [
		"Acorns, ceps, the odd honest root. The oaks feed anyone willing to stoop.",
		"Do not tell the deer I take their acorns. They have long memories and short tempers.",
		"My knees and I have an arrangement. I bend, they complain.",
	],
	"eat": [
		"Sit, if you like. The shade is free and the bread is terrible.",
		"I would offer you some, but then I should have less, and I am old and selfish.",
	],
	"wander": [
		"I walk out at noon so my legs remember they are legs. The deer have stopped minding.",
		"That hind with the torn ear is older than you. She was a calf the year the bells stopped.",
		"Grass grows over everything here, child. Roads, walls, names. Given time, it will grow over me, and I shall let it.",
	],
	"watch": [
		"Down there was Harrowmere. It had bells once, and a baker who sang flat.",
		"There is a soldier in the meadow who has not noticed he is dead. Be kind to him. Be quick.",
		"The light goes earlier every evening. I watch it go so it knows someone minded.",
	],
	"shelter": [
		"Rain is the only thing in this vale that still arrives on time.",
		"Under the oak, child. Even the Hollow have the sense to stand still in this.",
		"Under here. The keep lost its roof before my grandmother was born.",
	],
	"warm": [
		"Sit, if you like. The fire does not mind who it warms.",
		"Oak burns slow. Willow spits. My mother could tell them apart by the smoke.",
		"I will drop off soon. When I do, put a stick on. A dry one.",
		"That one comes most nights. I keep the crusts back for it. Don't tell the deer.",
	],
	"sleep": [
		"Mm... the lid is swept... come back at first light...",
		"...forty years... nnh... mind the step...",
		"...mm... put a stick on, would you... the dry ones...",
	],
}
# an old woman's stoop, held under every pose: the back rounds, hips and knees a little bent,
# the neck lifts the face back up to look ahead
const STOOP_SPINE := 0.26
const STOOP_HIP := 0.06
const STOOP_KNEE := 0.16
const STOOP_NECK := 0.16
# warming her hands at the fire before she dozes: back up, face lifted, both arms out over
# the knees, forearms a little bent so the palms come up to the heat; half turned to it
const WARM_SPINE := 0.3
const WARM_NECK := 0.22
const WARM_ARM := 1.4
const WARM_ELBOW := 0.45
const WARM_TURN := 0.85
# gathering under the oaks: every few seconds she crouches, curls right down over the litter
# and reaches for an acorn or a stick, then straightens with a hand on her back
const PICK_HIP := 1.0           # thighs forward; the knees fold twice that so the feet stay put
const PICK_PELVIS := 0.6        # she bends at the waist as well as the knees
const PICK_SPINE := 1.2
const PICK_ARM := 2.4          # the arms hang straight down and a little ahead of the toes
const PICK_ELBOW := -0.35
const PICK_DOWN := 0.9          # s to get down (an old back: slower up than down)
const PICK_HOLD := 1.3
const PICK_UP := 1.4
const TOSS_AT := 1.9            # s after the hold: upright again, the find goes over her shoulder
const TOSS_LEN := 1.0           # s with the hand up at the basket mouth
const TOSS_DROP := 0.45         # s into the reach when she lets go of it
# tossing the fox a crust from her seat: the arm comes up with the crust by her ear, then
# flicks out straight toward it and drops back to the warmth
const SCRAP_WAIT := Vector2(6.0, 14.0)   # s after the fox has sat before she throws
const FLICK_UP := 0.7           # s raising it
const FLICK_OUT := 0.22         # s the arm snaps out; the crust leaves her hand halfway
const FLICK_BACK := 1.1         # s settling back to her hands-out pose
const SCRAP_FLIGHT := 0.75      # s in the air
const KINDLE_STRIKES := 5       # flint strikes before the tinder catches
const KINDLE_EVERY := 0.85      # s between strikes
const KINDLE_NURSE := 9.0       # s at least she stays down after it catches, until the flames show

signal activity_changed(name: String)

var world: Node3D
var weather: Weather
var player: Node3D
var terrain: Terrain
var site := Vector3.ZERO
var hearth_at := Vector3.ZERO    # her cookfire on the keep floor (World builds the Hearth)
var to_v := Vector3.FORWARD     # from the keep out through the breach (toward the village)

var activity := ""              # wake, watch, tend, gather, eat, wander, sleep, shelter
var state := STAND
var named := false              # the HUD has named her
var noticing := false           # stopped to watch the hero
var visits := {}                # activity -> count of times reached its spot (bots)
var talks := 0                  # lines spoken to the hero (bots)
var last_line := ""
var talking := 0.0              # > 0 while her line is on screen: she holds still, facing him
var _intro_i := 0
var _line_i := {}
var _seen_interacts := 0
var path: Array[Vector3] = []
var goal_yaw := 0.0
var sit := 0.0                  # 0 standing .. 1 seated in the doze
var warm := 0.0                 # 0 head on her knees .. 1 sat up to the fire, hands out to it
var warm_hold := -1.0           # shots: hold `warm` at this (negative: by the hour and fire)
var pick := 0.0                 # 0 upright .. 1 crouched over the leaf litter, reaching
var picks := 0                  # times she has stooped to pick something up (bots)
var _pick_t := 3.0              # s until the next stoop (negative: in the stoop)
var pick_hold := false          # shots: stay down in the stoop
var toss_hold := false          # shots: hold the hand up at the basket mouth, stick in hand
var hand_mark: BoneAttachment3D
var _back_hand := 0.0           # 0..1 the right hand on the small of her back
var _rise_t := 0.0              # s left of straightening up with the hand on her back
var toss := 0.0                 # 0..1 the right hand up over her shoulder at the basket mouth
var tosses := 0                 # finds dropped into the basket (bots)
var _toss_t := -1.0             # s since she started up out of the last pick (negative: none)
var _held: Node3D               # the stick in her hand, from the hold until it drops
var stuck_t := 0.0
var warps := 0                  # times she was lifted past an obstacle she could not get round
var last_warp := Vector3.ZERO

var body: Node3D
var model: Node3D
var skel: Skeleton3D
var garb: HeroGarb
var soak: Soak
var anim_tree: AnimationTree
var crumple: Crumple
var square: SpineTwist          # squares her shoulders: the idle stands chest-turned to the right
var _shoulders: Array[BoneAttachment3D] = []
var _square_t := 0.0
var _blend := 0.0
var _model_rest: Transform3D
var _hip_h := 0.95
var _spots := {}
var _oaks: Array[Vector3] = []
var _gather_i := 0
var _gather_t := 0.0
var _wander_at := Vector3.ZERO
var _rest_yaw := 0.0
var wander_stops: Array[Vector3] = []   # where she stopped on her meadow walks (bots)
var _last_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _floor_basket: Node3D
var _kindle_t := -1.0           # s down at the ring this evening (-1: not kneeling yet)
var _strikes := 0
var kindles := 0                # times she has lit the fire herself (bots)
var scraps := 0                 # crusts tossed to the fox (bots)
var _scrap_t := -1.0            # s until she throws tonight's crust (negative: not waiting)
var _scrap_night := -1          # the night she last threw one
var _flick_t := -1.0            # s into the throw (negative: none)
var _scrap: Node3D              # the crust: in her hand, in the air, then on the floor
var _scrap_from := Vector3.ZERO
var _scrap_to := Vector3.ZERO
var _scrap_air := -1.0          # s in flight (negative: not flying)
var flick_hold := -1.0          # shots: hold the throw at this many s in (negative: free)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_max_angle = 0.9
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	model = (preload("res://player/models/vanguard.glb") as PackedScene).instantiate()
	model.name = "Model"
	model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	body.add_child(model)
	_model_rest = model.transform
	skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_skin()
	_setup_animation()
	garb = HeroGarb.new()
	garb.name = "Garb"
	# undyed grey-brown wool, an ash hood, a robe of woad washed out to slate grey, a rope-brown sash, old linen
	garb.palette = {
		"hood": [Color(0.040, 0.038, 0.036), Color(0.20, 0.19, 0.18), 0.3],
		"hat": [Color(0.15, 0.12, 0.07), Color(0.50, 0.42, 0.28), 0.3],
		"mantle": [Color(0.070, 0.058, 0.044), Color(0.36, 0.31, 0.24), 0.35],
		"robe": [Color(0.075, 0.078, 0.085), Color(0.36, 0.37, 0.385), 0.4],
		"sash": [Color(0.075, 0.050, 0.030), Color(0.34, 0.24, 0.14), 0.3],
		"wraps": [Color(0.14, 0.13, 0.11), Color(0.50, 0.47, 0.41), 0.4],
	}
	# her own cut, so at range she never reads as a second hero: no straw hat (the hood alone),
	# the robe to the ankles, and a willow gathering basket of deadwood on her back
	garb.hatless = true
	garb.robe_len = 1.1
	garb.robe_wide = 1.3
	garb.basket = true
	# side gores close the long robe into a skirt: from the side no legs or old armour show
	garb.skirt = true
	add_child(garb)
	if skel != null:
		garb.build(skel, body)
		# her ankle-length robe would let the idle stance's forward shin poke through the
		# front panel; it rides on the leg sooner than the hero's knee-length one
		garb.swing_slack = 0.3
		# she bends at the waist to pick: the robe hangs to gravity, over the knees and onto the litter
		garb.hang = 1.0
		# before the Crumple, so the stoop bends a chest that already faces forward: the hero's
		# idle stands with the chest turned ~17 deg to the right, which swung her basket 11 cm
		# off her spine to the left
		square = SpineTwist.new()
		square.name = "Square"
		square.up = body
		skel.add_child(square)
		for side in ["Left", "Right"]:
			var sh := BoneAttachment3D.new()
			sh.bone_name = "mixamorig_%sArm" % side
			skel.add_child(sh)
			_shoulders.append(sh)
		crumple = Crumple.new()
		crumple.name = "Crumple"
		skel.add_child(crumple)
		crumple.frame = (body.global_basis.inverse() * skel.global_basis).orthonormalized()
		# rides the right hand through the modifier (bots measure her reach with it)
		hand_mark = BoneAttachment3D.new()
		hand_mark.name = "HandMark"
		hand_mark.bone_name = "mixamorig_RightHand"
		skel.add_child(hand_mark)
		# the find: a short stick of deadwood across her fingers
		_held = garb.held_stick()
		_held.name = "HeldStick"
		_held.position = Vector3(0.0, 0.085, 0.02)
		_held.rotation = Vector3(0.0, 0.0, 0.35)
		_held.visible = false
		hand_mark.add_child(_held)
		var hb := skel.find_bone("mixamorig_Hips")
		if hb >= 0:
			_hip_h = (skel.global_transform * skel.get_bone_global_rest(hb).origin).y - global_position.y
	soak = Soak.new()
	soak.name = "Soak"
	add_child(soak)

## Her cookfire and the spot she kneels at to light it, from the keep site alone (Ruins
## keeps that bit of floor swept before she is built): [hearth, kneel].
static func hearth_layout(at: Vector3) -> Array[Vector3]:
	var tv := Vector3(-at.x, 0, -at.z).normalized()
	var sd := (-tv).rotated(Vector3.UP, 0.7)
	return [at + sd.rotated(Vector3.UP, -0.6) * 2.35, at + sd.rotated(Vector3.UP, -0.95) * 2.4]

## Where the `kindle` shot looks from: 1.9 m out from her kneel spot, swung 55 deg off the
## line to the fire toward the keep centre, 1.25 m up -- low enough to see under her bowed
## hood (from 1.5 m it looked onto her bent back), high enough to clear the plinth's laid
## blocks (at 67 deg / 1.0 m 52 of them filled the lower half) (Ruins sweeps the floor out
## to it).
static func kindle_lens(at: Vector3) -> Vector3:
	var hl := hearth_layout(at)
	var hp: Vector3 = hl[0]
	var kn: Vector3 = hl[1]
	var f := Vector3(hp.x - kn.x, 0, hp.z - kn.z).normalized()
	var s := f.cross(Vector3.UP)
	if (kn + s).distance_to(at) > (kn - s).distance_to(at):
		s = -s
	var p := kn + (f * 0.57 + s * 0.82).normalized() * 1.9
	p.y = hp.y + 1.25
	return p

## Places her and works out her day's spots from the keep and the oaks round it.
func settle(w: Node3D, at_hour: float) -> void:
	world = w
	weather = w.get("weather")
	player = w.get_node_or_null("Player")
	terrain = w.get_node("Terrain")
	site = (w.get_node("Ruins") as Ruins).site
	to_v = Vector3(-site.x, 0, -site.z).normalized()
	var side := to_v.cross(Vector3.UP)
	var flora := w.get_node("Flora") as Flora
	var sorted := flora.tree_positions.duplicate()
	sorted.sort_custom(func(a, b): return a.distance_squared_to(site) < b.distance_squared_to(site))
	for q in sorted.slice(0, 3):
		_oaks.append(q)
	# against the inner face opposite the breach, a little round to one side, facing in
	var sleep_dir := (-to_v).rotated(Vector3.UP, 0.7)
	_spots = {
		"sleep": [site + sleep_dir * 2.45, atan2(-sleep_dir.x, -sleep_dir.z)],
		"tend": [site + to_v * 2.05 + side * 0.35, atan2(-to_v.x, -to_v.z)],
		"watch": [site + to_v * 6.0, atan2(to_v.x, to_v.z)],
		"breach_in": [site + to_v * 2.6],
		"breach_out": [site + to_v * 5.2],
		"gate_in": [site + to_v * 10.8],
		"gate_out": [site + to_v * 14.4],
	}
	_set_down_basket(sleep_dir)
	# her cookfire (Hearth): beside the bed on the far side from the basket and from her way
	# out to the breach, between the plinth (r 1.75) and the inner face
	var hl := hearth_layout(site)
	hearth_at = hl[0]
	# lighting it: knelt at the ring on the side away from her bed, facing the fire
	var kp: Vector3 = hl[1]
	var to_fire := Vector3(hearth_at.x - kp.x, 0, hearth_at.z - kp.z)
	_spots["kindle"] = [kp, atan2(to_fire.x, to_fire.z)]
	if not _oaks.is_empty():
		var o := _oaks[0]
		var away := Vector3(o.x - site.x, 0, o.z - site.z).normalized()
		_spots["eat"] = [o + away.rotated(Vector3.UP, 1.4) * 2.2, atan2(away.x, away.z)]
	var a := _activity_for(at_hour)
	var s: Array = _spots.get(_spot_of(a), _spots["tend"])
	if a == "gather" and not _oaks.is_empty():
		_gather_i = 0
		var g := _gather_spot(0)
		var tg := Vector3(_oaks[0].x - g.x, 0, _oaks[0].z - g.z).cross(Vector3.UP)
		s = [g, atan2(tg.x, tg.z)]
		_gather_t = _rng.randf_range(25.0, 50.0)
	elif a == "wander":
		_wander_at = _wander_spot()
		s = [_wander_at, atan2(to_v.x, to_v.z)]
		_gather_t = _rng.randf_range(15.0, 40.0)
	_place(s[0])
	body.rotation.y = s[1] if s.size() > 1 else 0.0
	goal_yaw = body.rotation.y
	activity = a
	path.clear()
	state = STAND
	sit = 0.0
	if a == "sleep":
		sit = 1.0
		state = SIT
		var h := _hour()
		warm = 1.0 if (h >= 21.0 and h < 23.35 and Hearth.level_for(h) > 0.6) else 0.0
		var to_f := Vector3(hearth_at.x - s[0].x, 0, hearth_at.z - s[0].z)
		if warm > 0.0 and to_f.length() > 0.1:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(to_f.x, to_f.z), WARM_TURN)
			goal_yaw = body.rotation.y
	_last_pos = global_position

## Her shoulder line as posed (two attachments ride the arms through the modifiers): its yaw
## off the body's right axis is the stance's chest turn, which the twist slowly integrates
## back out (~1.5 s), so the walk's stride-by-stride shoulder swing stays in.
func _square_shoulders(delta: float) -> void:
	if square == null:
		return
	var d := body.global_basis.inverse() * (_shoulders[0].global_position - _shoulders[1].global_position)
	var yaw := atan2(d.z, d.x)
	# settles fast at spawn, then only follows the slow stance changes
	_square_t += delta
	square.twist = clampf(square.twist + yaw * minf(delta / (0.25 if _square_t < 2.0 else 1.5), 1.0), -0.7, 0.7)

## At night the basket comes off her back and stands on the keep floor beside her bed, against
## the inner wall; the worn one hides while she sits (see _physics_process).
func _set_down_basket(sleep_dir: Vector3) -> void:
	if garb.basket_node == null or _floor_basket != null:
		return
	_floor_basket = Node3D.new()
	_floor_basket.name = "FloorBasket"
	var copy := garb.basket_node.duplicate()
	copy.transform = Transform3D.IDENTITY
	# body space puts its foot at BASKET_FOOT behind the back: stand it on the floor
	copy.position = Vector3(0, -HeroGarb.BASKET_FOOT + 0.01, -HeroGarb.BASKET_Z)
	_floor_basket.add_child(copy)
	var d := sleep_dir.rotated(Vector3.UP, 0.34)
	var p := site + d * 2.5
	_floor_basket.position = Vector3(p.x, terrain.height_at(p.x, p.z), p.z)
	_floor_basket.rotation.y = atan2(-d.x, -d.z) + 0.4
	world.add_child.call_deferred(_floor_basket)

func _place(p: Vector3) -> void:
	global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.05, p.z)

func _hour() -> float:
	return world.time_of_day if world != null else 12.0

static func _activity_for(h: float) -> String:
	if h < 5.5 or h >= 21.5:
		return "sleep"
	if h < 7.0:
		return "wake"
	if h < 10.0:
		return "tend"
	if h < 12.5:
		return "gather"
	if h < 13.5:
		return "eat"
	if h < 15.0:
		return "wander"
	if h < 17.5:
		return "gather"
	if h < 19.5:
		return "watch"
	if h < 20.3:
		return "kindle"                      # down on her knees at the ring with the flint
	return "tend"

static func _spot_of(a: String) -> String:
	return "watch" if a == "wake" else a

## 0 on the keep floor, 1 in the yard inside the curtain wall, 2 out on the open slope.
func _ring(p: Vector3) -> int:
	var r := Vector2(p.x - site.x, p.z - site.z).length()
	return 0 if r < KEEP_R else 1 if r < CURTAIN_R else 2

func _inside(p: Vector3) -> bool:
	return Vector2(p.x - site.x, p.z - site.z).length() < KEEP_R

## A route to `to`: through the breach whenever it crosses the keep wall, and through the
## gateway whenever it crosses the curtain wall.
func _route(to: Vector3) -> void:
	path.clear()
	var a := _ring(global_position)
	var b := _ring(to)
	# doors outward: [keep side, yard side] of the breach, then of the gateway
	var doors := [[_spots["breach_in"][0], _spots["breach_out"][0]],
			[_spots["gate_in"][0], _spots["gate_out"][0]]]
	if a < b:
		for i in range(a, b):
			path.append(doors[i][0])
			path.append(doors[i][1])
	else:
		for i in range(a - 1, b - 1, -1):
			path.append(doors[i][1])
			path.append(doors[i][0])
	path.append(to)
	# on the keep floor she walks round the plinth, not over it
	var out: Array[Vector3] = []
	var prev := global_position
	for q in path:
		if _inside(prev) and _inside(q):
			var a0 := atan2(prev.z - site.z, prev.x - site.x)
			var a1 := atan2(q.z - site.z, q.x - site.x)
			var da := wrapf(a1 - a0, -PI, PI)
			var steps := int(absf(da) / 0.5)
			for k in range(1, steps + 1):
				var ang := a0 + da * float(k) / float(steps + 1)
				out.append(site + Vector3(cos(ang), 0, sin(ang)) * 2.45)
		out.append(q)
		prev = q
	path = out
	state = WALK
	stuck_t = 0.0

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var want := _activity_for(_hour())
	var raining := weather != null and weather.rain > RAIN_SHELTER
	if raining and want != "sleep":
		want = "shelter"
	elif activity == "shelter" and weather != null and weather.rain > RAIN_SHELTER * 0.5:
		want = "shelter"                       # wait for it to ease off properly
	if want != activity:
		_begin(want)
	elif state == STAND and activity == "gather":
		_gather_t -= delta
		if pick > 0.02 or _pick_t < 0.0 or _toss_t >= 0.0:
			_gather_t = maxf(_gather_t, 0.1)    # finish the pick (and the toss) before she moves on
		if _gather_t <= 0.0 and _oaks.size() > 1:
			_gather_i = (_gather_i + 1) % _oaks.size()
			_route(_gather_spot(_gather_i))
	elif state == STAND and activity == "wander":
		_gather_t -= delta
		if _gather_t <= 0.0:
			_wander_at = _wander_spot()
			_route(_wander_at)
	_update_notice()
	_update_talk(delta)
	var v := Vector3.ZERO
	if state == WALK and not noticing and talking <= 0.0 and sit < 0.05 and pick < 0.05:
		var tgt: Vector3 = path[0]
		var d := Vector3(tgt.x - global_position.x, 0, tgt.z - global_position.z)
		if d.length() < 0.35:
			path.pop_front()
			if path.is_empty():
				_arrive()
		else:
			var sp := SHELTER_SPEED if activity == "shelter" else WALK_SPEED
			v = d.normalized() * sp
			goal_yaw = atan2(d.x, d.z)
			# boulders and oak boles: if she is making no headway, sidestep round them
			var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
			stuck_t = stuck_t + delta if moved < sp * delta * 0.3 else maxf(stuck_t - delta, 0.0)
			if stuck_t > 0.6:
				v = v.rotated(Vector3.UP, 1.2)
				if stuck_t > 4.0:
					_place(tgt)               # never wedge for good
					warps += 1
					last_warp = tgt
					stuck_t = 0.0
	_last_pos = global_position
	velocity.x = lerpf(velocity.x, v.x, 1.0 - exp(-6.0 * delta))
	velocity.z = lerpf(velocity.z, v.z, 1.0 - exp(-6.0 * delta))
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_update_warm(delta)
	_update_scrap(delta)
	body.rotation.y = lerp_angle(body.rotation.y, goal_yaw, 1.0 - exp(-4.0 * delta))
	var sit_goal := 1.0 if (state == SIT and activity == "sleep") else 0.0
	sit = move_toward(sit, sit_goal, delta / 2.2)
	_update_kindle(delta)
	_update_pick(delta)
	_square_shoulders(delta)
	_pose_sit()
	if garb.basket_node != null:
		var down := basket_down()
		garb.basket_node.visible = not down
		if _floor_basket != null:
			_floor_basket.visible = down
	_update_animation(delta)
	# her face fill follows the hero's (World.light_face sets it by hour); dozing, the hat
	# hangs over her knees and the fill would only light the floor
	var pg = player.get("garb") if player != null else null
	if garb.fill != null and pg != null and pg.fill != null:
		garb.fill.light_energy = pg.fill.light_energy * (1.0 - 0.85 * sit)
		garb.fill.light_color = pg.fill.light_color

func _begin(a: String) -> void:
	activity = a
	activity_changed.emit(a)
	if a == "shelter":
		_route(_shelter_spot())
	elif a == "gather":
		_gather_i = 1 if _oaks.size() > 1 else 0
		_route(_gather_spot(_gather_i))
	elif a == "wander":
		_wander_at = _wander_spot()
		_route(_wander_at)
	else:
		var s: Array = _spots.get(_spot_of(a), _spots["tend"])
		_route(s[0])
	if a == "kindle":
		_kindle_t = -1.0
		_strikes = 0
	state = WALK                             # from the doze she stands up first (see sit)

func _gather_spot(i: int) -> Vector3:
	var o := _oaks[i]
	var a := float(i) * 2.1 + 0.6
	return o + Vector3(cos(a), 0, sin(a)) * 2.6

## A stop on her meadow walk: open, gently sloping ground clear of boles and boulders, out in
## front of the gateway; of a handful of candidates the one that brings her nearest a grazing
## distance (10-16 m) from the herd, so she is seen among the deer.
func _wander_spot() -> Vector3:
	var flora := world.get_node("Flora") as Flora
	var herd = world.get("herd")
	var hc: Vector3 = herd.centre() if herd != null else Vector3.INF
	var base := atan2(to_v.z, to_v.x)
	var best := Vector3.INF
	var bs := INF
	for i in 28:
		var ang := base + _rng.randf_range(-WANDER_CONE, WANDER_CONE)
		var r := _rng.randf_range(WANDER_R.x, WANDER_R.y)
		var q := site + Vector3(cos(ang), 0, sin(ang)) * r
		q.y = terrain.height_at(q.x, q.z)
		if terrain.normal_at(q.x, q.z, 1.5).y < 0.9:
			continue
		if _wander_at != Vector3.ZERO and Vector2(q.x - _wander_at.x, q.z - _wander_at.z).length() < 6.0:
			continue
		var clear := true
		for t in flora.tree_positions:
			if Vector2(t.x - q.x, t.z - q.z).length() < 4.0:
				clear = false
				break
		if clear:
			for b in flora.rock_positions:
				if Vector2(b.x - q.x, b.z - q.z).length() < 3.5:
					clear = false
					break
		if not clear:
			continue
		var score := _rng.randf() * 6.0
		if hc != Vector3.INF:
			score += absf(Vector2(q.x - hc.x, q.z - hc.z).length() - 13.0)
		if score < bs:
			bs = score
			best = q
	if best == Vector3.INF:
		best = site + to_v * WANDER_R.x          # nothing open: just out past the gate
	return best

## The nearest point well under a crown: the nearest oak to her, on its keep side.
func _shelter_spot() -> Vector3:
	var flora := world.get_node("Flora") as Flora
	var best := Vector3.ZERO
	var bd := INF
	for q in flora.tree_positions:
		var d := q.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = q
	var off := Vector3(global_position.x - best.x, 0, global_position.z - best.z)
	off = off.normalized() if off.length() > 0.1 else Vector3.RIGHT
	return best + off * 1.6

func _arrive() -> void:
	visits[activity] = int(visits.get(activity, 0)) + 1
	var s: Array = _spots.get(_spot_of(activity), [])
	if activity == "gather" or activity == "shelter":
		var o := _oaks[_gather_i] if activity == "gather" else _shelter_spot()
		var d := Vector3(o.x - global_position.x, 0, o.z - global_position.z)
		if activity == "gather" and d.length() > 0.1:
			# working the ground round the bole: side-on to the trunk, not staring into it
			var t := d.cross(Vector3.UP)
			goal_yaw = atan2(t.x, t.z)
		_gather_t = _rng.randf_range(25.0, 50.0)
	elif activity == "wander":
		wander_stops.append(global_position)
		_gather_t = _rng.randf_range(15.0, 40.0)
		# stands looking at the deer if they are in sight, else out over the vale
		var herd = world.get("herd")
		var look: Vector3 = herd.centre() - global_position if herd != null else to_v
		look.y = 0.0
		if look.length() > 60.0 or look.length() < 0.5:
			look = to_v
		goal_yaw = atan2(look.x, look.z)
		_rest_yaw = goal_yaw
	elif s.size() > 1:
		goal_yaw = s[1]
	state = SIT if activity == "sleep" else STAND

## The hero close by: she stops and turns to him (not while dozing); the first time the HUD
## names her.
func _update_notice() -> void:
	noticing = false
	if player == null or state == SIT or sit > 0.05:
		return
	if talking > 0.0:
		noticing = true                      # holds still and keeps facing him mid-line
		return
	var d := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
	if d.length() < NOTICE:
		noticing = true
		goal_yaw = atan2(d.x, d.z)
		if not named and d.length() < NAME_AT:
			named = true
			var hud = player.get_node_or_null("Hud")
			if hud != null:
				hud.caption("Hesper", "Last keeper of the Shrine of Binding")
	elif state == STAND:
		var s: Array = _spots.get(_spot_of(activity), [])
		if s.size() > 1:
			goal_yaw = s[1]
		elif activity == "wander":
			goal_yaw = _rest_yaw

## In reach the HUD offers "Speak"; each press gets the next line (the intro first, then the
## pool for what she is doing). A press while a line shows skips on to the next one.
func _update_talk(delta: float) -> void:
	talking = maxf(talking - delta, 0.0)
	if player == null:
		return
	var hud = player.get_node_or_null("Hud")
	var presses: int = player.get("interacts")
	var d := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
	var near: bool = d.length() < TALK_R and not player.is_dead() and player.get("lock_target") == null
	if not near:
		_seen_interacts = presses
		return
	if hud != null:
		hud.prompt("E", "Speak" if (sit < 0.5 or warm > 0.5) else "Listen")
	if presses == _seen_interacts:
		return
	_seen_interacts = presses
	var line := _next_line()
	last_line = line
	talks += 1
	talking = 2.4 + 0.055 * line.length()
	if sit < 0.05:
		goal_yaw = atan2(d.x, d.z)
	if hud != null:
		hud.say("Hesper", line, talking)

func _next_line() -> String:
	if warm > 0.5:
		return _pool_line("warm")
	if sit >= 0.5 or activity == "sleep":
		return _pool_line("sleep")
	if _intro_i < INTRO.size():
		_intro_i += 1
		return INTRO[_intro_i - 1]
	var key := activity
	if (activity == "tend" and _hour() >= 19.0) or activity == "kindle":
		key = "tend_night"
	if not LINES.has(key):
		key = "watch"
	return _pool_line(key)

func _pool_line(key: String) -> String:
	var pool: Array = LINES[key]
	var i := int(_line_i.get(key, 0))
	_line_i[key] = i + 1
	return pool[i % pool.size()]

## Stooping to the litter while she gathers: a slow crouch down, a hold with the hand at the
## ground, a slower straightening; not while she is walking, talking or watching the hero.
func _update_pick(delta: float) -> void:
	_rise_t -= delta
	_back_hand = move_toward(_back_hand, 1.0 if _rise_t > 0.0 else 0.0, delta / 0.45)
	# once she is up, the find goes over her right shoulder into the basket
	if _toss_t >= 0.0:
		var was := _toss_t
		_toss_t += delta
		var up := _toss_t > TOSS_AT and _toss_t < TOSS_AT + TOSS_LEN
		toss = move_toward(toss, 1.0 if up else 0.0, delta / 0.4)
		if was <= TOSS_AT + TOSS_DROP and _toss_t > TOSS_AT + TOSS_DROP:
			tosses += 1
			if _held != null:
				_held.visible = false
		if _toss_t > TOSS_AT + TOSS_LEN + 0.6:
			_toss_t = -1.0
		_pick_t = maxf(_pick_t, 0.8)       # no new stoop with the arm still up
	else:
		toss = move_toward(toss, 0.0, delta / 0.4)
	if pick_hold:
		pick = move_toward(pick, 1.0, delta / PICK_DOWN)
		return
	if toss_hold:
		toss = 1.0
		if _held != null:
			_held.visible = true
		return
	if activity == "kindle":
		return                               # _update_kindle has the pose
	var working := state == STAND and activity == "gather" and not noticing and talking <= 0.0
	if not working:
		if _held != null and _held.visible and _toss_t < 0.0:
			_toss_t = 0.0                      # cut short: the find still goes in the basket
		_pick_t = maxf(_pick_t, _rng.randf_range(1.5, 3.0))
		pick = move_toward(pick, 0.0, delta / PICK_UP)
		return
	_pick_t -= delta
	if _pick_t >= 0.0:
		pick = move_toward(pick, 0.0, delta / PICK_UP)
		return
	var t := -_pick_t
	if t < PICK_DOWN:
		pick = move_toward(pick, 1.0, delta / PICK_DOWN)
	elif t < PICK_DOWN + PICK_HOLD:
		pick = 1.0
		# her fingers close on something halfway through the hold
		if _held != null and t > PICK_DOWN + PICK_HOLD * 0.5 and garb.basket_node != null:
			_held.visible = true
	else:
		picks += 1
		_rise_t = PICK_UP + 0.3
		if _held != null and _held.visible:
			_toss_t = 0.0
		_pick_t = _rng.randf_range(3.5, 7.5)

## The basket is off her back and standing by her bed from the moment she reaches the ring
## to light the fire until she shoulders it for the dawn watch (so it does not ride up over
## her bent back while she kneels at the flames).
func basket_down() -> bool:
	if sit >= 0.3:
		return true
	if activity == "kindle":
		return state == STAND or pick > 0.05
	return activity == "tend" and _hour() >= 19.5

## Lighting the fire at dusk: down at the ring, a few strikes of flint into the tinder, then
## she stays down feeding it until the flames take, and gets up to stand over it. Not while
## the hero has her attention; she goes back down after.
func _update_kindle(delta: float) -> void:
	if activity != "kindle":
		return
	var hr = world.get("hearth")
	var lit: bool = hr != null and hr.kindled >= 0.0
	var working := state == STAND and not noticing and talking <= 0.0 and hr != null
	if lit and hr.kindled > KINDLE_NURSE and hr.level > 0.35:
		working = false                      # done: up, and stands over it
		if pick > 0.9 and _rise_t <= 0.0:
			_rise_t = PICK_UP + 0.3          # with a hand to the small of her back
	if not working:
		pick = move_toward(pick, 0.0, delta / PICK_UP)
		return
	pick = move_toward(pick, 1.0, delta / PICK_DOWN)
	if pick < 0.95:
		return
	_kindle_t = maxf(_kindle_t, 0.0) + delta
	if lit:
		return
	if _kindle_t > KINDLE_EVERY * float(_strikes + 1):
		_strikes += 1
		hr.strike_flint(global_position)
		if _strikes >= KINDLE_STRIKES:
			hr.kindle()
			kindles += 1

## Sat down for the night while the fire still blazes (21:30 to ~23:20), she sits up turned
## half round to it with her hands held out over her knees to the warmth; as it burns down
## she nods off, head going down onto her knees and the body back square to the keep.
func _update_warm(delta: float) -> void:
	var hr = world.get("hearth")
	var h := _hour()
	var lit: float = hr.level if hr != null else 0.0
	var want := 1.0 if (activity == "sleep" and h >= 21.0 and h < 23.35 and lit > 0.6) else 0.0
	if warm_hold >= 0.0:
		want = warm_hold
	warm = move_toward(warm, want, delta / 3.0) if warm_hold < 0.0 else want
	if activity != "sleep" or hr == null or not _spots.has("sleep"):
		return
	var to_f := Vector3(hearth_at.x - global_position.x, 0, hearth_at.z - global_position.z)
	if to_f.length() > 0.1:
		var e := warm * warm * (3.0 - 2.0 * warm)
		goal_yaw = lerp_angle(_spots["sleep"][1], atan2(to_f.x, to_f.z), WARM_TURN * e)

## Once a night, while she sits up warming her hands and the fox sits at the edge of the
## light, she tosses it a crust across the floor; it gets up for it (Fox.take_scrap).
func _update_scrap(delta: float) -> void:
	var fx = world.get("fox")
	var night := int(floor((_hour() + 12.0) / 24.0))
	if _scrap_air >= 0.0 and _scrap != null:
		_scrap_air += delta
		var f := minf(_scrap_air / SCRAP_FLIGHT, 1.0)
		var arc := maxf(_scrap_from.y, _scrap_to.y) + 0.9
		# a parabola through the apex: up out of her hand, over the flames, down by the fox
		var p := _scrap_from.lerp(_scrap_to, f)
		p.y = lerpf(_scrap_from.y, _scrap_to.y, f) + 4.0 * (arc - (_scrap_from.y + _scrap_to.y) * 0.5) * f * (1.0 - f)
		_scrap.global_position = p
		_scrap.rotation.x += delta * 11.0
		if f >= 1.0:
			_scrap_air = -1.0
			_scrap.rotation = Vector3(0.0, _rng.randf() * TAU, 0.0)
			if fx != null and fx.state == Fox.SIT:
				fx.take_scrap(_scrap)
			else:
				_scrap.queue_free()
			_scrap = null
	if _flick_t >= 0.0:
		_flick_t = flick_hold if flick_hold >= 0.0 else _flick_t + delta
		var t := _flick_t
		var up := smoothstep(0.0, FLICK_UP, t)
		var out := smoothstep(FLICK_UP, FLICK_UP + FLICK_OUT, t)
		var back := smoothstep(FLICK_UP + FLICK_OUT, FLICK_UP + FLICK_OUT + FLICK_BACK, t)
		crumple.flick = up * (1.0 - back)
		crumple.flick_arm = lerpf(2.2, 1.45, out)
		crumple.flick_elbow = lerpf(1.7, 0.1, out)
		if _scrap != null and _scrap_air < 0.0 and t >= FLICK_UP + FLICK_OUT * 0.5:
			_scrap.reparent(world)
			_scrap_from = _scrap.global_position
			_scrap_air = 0.0
			scraps += 1
		if back >= 1.0:
			_flick_t = -1.0
			crumple.flick = 0.0
		return
	var fox_sat: bool = fx != null and fx.state == Fox.SIT and fx.sit > 0.99
	if not fox_sat or warm < 0.9 or sit < 0.95 or _scrap_night == night or hand_mark == null:
		_scrap_t = -1.0
		return
	if _scrap_t < 0.0:
		_scrap_t = _rng.randf_range(SCRAP_WAIT.x, SCRAP_WAIT.y)
	_scrap_t -= delta
	if _scrap_t <= 0.0:
		throw_scrap()

## Starts the throw now (shots and bots may call it): the crust goes in her hand and lands
## a little way round the floor from the fox (`Fox.crust_of`), clear of the lid's plinth.
func throw_scrap() -> void:
	var fx = world.get("fox")
	if fx == null or hand_mark == null:
		return
	_scrap_night = int(floor((_hour() + 12.0) / 24.0))
	_scrap_t = -1.0
	_flick_t = 0.0
	if _scrap != null:
		_scrap.queue_free()
	_scrap = Keeper.crust()
	hand_mark.add_child(_scrap)
	_scrap.position = Vector3(0.0, 0.08, 0.03)
	var aim := Fox.crust_of(site)
	var along := Vector3(aim.x - fx.sit_at.x, 0, aim.z - fx.sit_at.z).normalized()
	var at: Vector3 = aim + along * _rng.randf_range(-0.12, 0.12)
	_scrap_to = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.018, at.z)

## A heel of dark bread: a squashed, lumpy round with a hard brown crust and a torn pale crumb face.
static func crust() -> Node3D:
	var root := Node3D.new()
	root.name = "Crust"
	var mi := MeshInstance3D.new()
	root.add_child(mi)
	var m := SphereMesh.new()
	m.radius = 0.045
	m.height = 0.05
	m.radial_segments = 14
	m.rings = 8
	mi.mesh = m
	mi.scale = Vector3(1.0, 0.7, 0.75)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/crust.gdshader")
	mi.material_override = mat
	return root

## Her body yaw turned toward the fire while she warms her hands (bots).
func warm_facing() -> float:
	var to_f := Vector3(hearth_at.x - global_position.x, 0, hearth_at.z - global_position.z)
	return absf(angle_difference(body.rotation.y, atan2(to_f.x, to_f.z)))

## The doze: knees drawn up, back to the wall, head down on the knees; the body sinks onto
## the floor as she sits.
func _pose_sit() -> void:
	if crumple == null:
		return
	var e := sit * sit * (3.0 - 2.0 * sit)
	var p := pick * pick * (3.0 - 2.0 * pick)
	# standing: the stoop, deepened into a crouch-and-reach while she picks at the litter
	var hip := lerpf(STOOP_HIP, PICK_HIP, p)
	var knee := lerpf(STOOP_KNEE, PICK_HIP * 2.0, p)
	crumple.active = true
	crumple.hip = lerpf(hip, 1.85, e)
	crumple.knee = lerpf(knee, 2.15, e)
	# warming her hands: sat up with only the old stoop in her back, head up to the flames
	var w := warm * warm * (3.0 - 2.0 * warm) * e
	crumple.spine = lerpf(lerpf(lerpf(STOOP_SPINE, PICK_SPINE, p), 0.55, e), WARM_SPINE, w)
	crumple.pelvis = PICK_PELVIS * p * (1.0 - e)
	crumple.neck = lerpf(lerpf(STOOP_NECK, 0.3, p) * (1.0 - e), WARM_NECK, w)
	# straightening with an old back: the right hand goes to the small of it on the way up
	crumple.back_hand = _back_hand * (1.0 - e)
	crumple.toss = toss * (1.0 - e)
	crumple.arm = lerpf(lerpf(PICK_ARM * p, 0.75, e), WARM_ARM, w)
	crumple.elbow = lerpf(lerpf(PICK_ELBOW * p, 1.1, e), WARM_ELBOW, w)
	crumple.head_turn = 0.25 * e * (1.0 - w)
	# the bent knees lower the hips: keep the feet on the ground (thigh and shin each half the
	# hip height; the shin leans forward as far as the thigh, so the feet stay under her)
	var bob := _hip_h * (1.0 - cos(STOOP_KNEE) * 0.5 - 0.5)
	if p > 0.0:
		# tipping the pelvis lifts the hip joints (they hang behind and below its pivot)
		bob = lerpf(bob, _hip_h * (1.0 - cos(hip)) + 0.1 * sin(PICK_PELVIS), p)
	model.transform = _model_rest.translated(Vector3.DOWN * ((_hip_h - 0.14) * e + bob * (1.0 - e)))

# --- look and animation (the hero's: Player._skin, Player._setup_animation) ---

func _skin() -> void:
	var shader := preload("res://shaders/hero.gdshader")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			mat.set_shader_parameter("albedo_col", src.albedo_color)
			mat.set_shader_parameter("roughness", src.roughness)
			mat.set_shader_parameter("restyle", 1.0)
			# no armour on her: the base body's plates and iron read as wool and linen
			mat.set_shader_parameter("cloth_body", 1.0)
			if src.normal_enabled and src.normal_texture != null:
				mat.set_shader_parameter("normal_tex", src.normal_texture)
				mat.set_shader_parameter("normal_depth", src.normal_scale)
			m.set_surface_override_material(s, mat)

func _setup_animation() -> void:
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for a in ["Idle", "Walk"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = ANIM_WALK_SPEED
	for pt in [["Idle", 0.0], ["Walk", ANIM_WALK_SPEED]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = pt[0]
		space.add_blend_point(clip, pt[1])
	var root := AnimationNodeBlendTree.new()
	root.add_node("move", space, Vector2(0, 0))
	root.add_node("speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	root.connect_node("speed", 0, "move")
	root.connect_node("output", 0, "speed")
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	model.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(ap)
	anim_tree.tree_root = root
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true

func _update_animation(delta: float) -> void:
	if anim_tree == null:
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	# her slow walk is the full Walk stride at a slower cadence, so the feet keep their plants
	_blend = lerpf(_blend, ANIM_WALK_SPEED if hs > 0.3 else hs, 1.0 - exp(-8.0 * delta))
	anim_tree.set("parameters/move/blend_position", _blend)
	var ts := 1.0
	if hs > 0.3:
		ts = clampf(hs / ANIM_WALK_SPEED, 0.55, 1.2)
	ts *= lerpf(1.0, 0.25, sit)
	anim_tree.set("parameters/speed/scale", ts)
