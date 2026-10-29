class_name Villager
extends CharacterBody3D
## Edda, the cottager in the limewashed house on the green: Harrowmere's first villager (the
## hero's rig and Hesper's garb builder, cut as a working woman: a linen coif, a madder-washed
## kirtle to the ankles, no basket). She keeps a day by the clock and the weather:
##   06:00 opens the door and stands on the step looking out over the green
##   06:30 draws water at the butt by the door corner (stoops to dip the pail, straightens)
##   07:20 takes the grain bag round the yard walls to the stone cottage's garth and casts
##         grain over its east wall to the hens (HenFeed; they come running for it)
##   08:25 splits wood at the chopping block by the lean-to (WoodChop: sets a round on the
##         block, heaves the axe over her head and brings it down; the halves jump off)
##   12:00 sits on the bench under the window to eat
##   13:00 back to the butt, then the woodpile through the afternoon
##   16:20 the hens' second feed, then back to the woodpile
##   18:50 walks out to the lantern post on the green with a taper and lights the lantern
##   19:40 sits out on the bench in the last of the light
##   20:40 goes in for the night (the windows stay lit until bedtime)
## Under a rain front she breaks off and goes indoors until it eases (the lantern round
## excepted: it still gets lit). Indoors she is not drawn. When the hero comes near she stops,
## turns to face him and watches him while he stays close.
## At the butt she takes up her pail from where it stands, dips it, and sets it down again
## before she goes on; the door creaks and its latch drops as she goes in and out, and the
## cottage's lamp burns only while she is indoors (WhiteCottage._lit_now).
## In reach the hero can speak to her (interact): the first time she introduces herself, after
## that each press gets a line for what she is about; she holds still facing him while it shows
## (sat on the bench she answers from where she sits). Out on the bench of an evening she
## hums to herself, a phrase every ten seconds or so, and stops while the hero is near.
## When she and Osric come within a few metres of each other out of doors (her feed round
## passes his garth) they stop, turn to each other and pass a word: she says hers, he
## answers; the hero overhears it on the HUD if he is near, and hears a murmur of voices
## from farther off. Once a meeting; they speak again after they have parted, or after a while.

signal door(at: Vector3)          # the cottage door opened or shut behind her (Foley)
signal hummed(at: Vector3)        # a phrase hummed to herself on the bench of an evening (Foley)
signal spoke(at: Vector3, low: bool)   # a line passed to the neighbour (Foley: a murmur)

enum { WALK, STAND, SIT, IN }

const WALK_SPEED := 1.4
const HURRY_SPEED := 2.0         # in out of the rain
const ANIM_WALK_SPEED := 1.9     # the Walk clip's stride at 1x (Player)
const GRAVITY := 22.0
const NOTICE := 6.0
const RAIN_IN := 0.35
const SEAT_H := 0.45             # the bench's seat above the ground at its foot
const LIGHT_LEN := 3.5           # s with the taper up at the lantern before it catches
const STOOP_DOWN := 0.9
const STOOP_HOLD := 1.4
const STOOP_UP := 1.1
const IDLE_IN := 1.2             # s to ease into (or out of) the idle weight shift
const TALK_R := 2.8              # the hero can speak to her inside this
const NAME_AT := 4.5             # the HUD names her inside this, once
const GREET_R := 9.5             # she and Osric pass a word inside this (over the garth wall)
const PART_R := 13.0             # ...and only again once they have been this far apart
const GREET_AGAIN := 150.0       # s: or this long together (Osric on his wall, her feed round)
const HEAR_R := 13.0             # the hero overhears it on the HUD inside this of either of them
## What she opens with when she meets Osric, by the hour, and what he says back.
const EXCHANGES := {
	"morning": [
		["Morning, Osric. Your Bishop's been in my woodpile again.", "Then she's your Bishop. I'll not have a hen that keeps company like that."],
		["You're out early for a man with knees.", "The knees wake first. I just follow them out."],
		["Rain later, you reckon?", "By three. Bring your washing in at two and call it wisdom."],
	],
	"day": [
		["Six handfuls, Osric. Not seven.", "I never said seven. I said they looked like seven."],
		["Still counting them, are you? The sheep?", "Nine hundred and four. One's limping. I'll see to her in the morning."],
		["You'll sit down at that wall one day and not get up.", "That's the plan, Edda. That's been the plan for years."],
	],
	"evening": [
		["I'll be lighting it soon.", "I know you will. I can set my supper by you."],
		["Hens in?", "Counted and in. Fox will have to make do with the moon."],
	],
}
const INTRO := [
	"You'll be the lamplighter's apprentice. Mind the hens' yard; they've had nothing but foxes and opinions all week.",
	"Edda. This is my house, that's my woodpile, and that lantern on the green is mine to light. Don't you go lighting it for me.",
]
const LINES := {
	"wake": [
		"Morning. The green's still wet; walk round it, not across, or you'll be tracking it in somebody's door.",
		"I like the first hour. Nobody wants anything of me yet.",
	],
	"water": [
		"The butt fills off the roof. Rain's the only thing in this village that comes to my door unasked.",
		"Two pails for the house, one for the hens, and one for whatever the day breaks.",
		"Don't drink from it. There's moss in there older than you.",
	],
	"feed": [
		"Six handfuls. Seven and they get ideas.",
		"The speckled one is called Bishop. She knows what she did.",
		"They come to the wall when they hear the bag. Like men to a bell.",
	],
	"wood": [
		"Stand off the block, love. The halves go where they please.",
		"Ash splits clean. Elm fights you. I keep the elm for days I'm angry.",
		"Winter's long in the vale now. Longer every year. The woodpile knows it before the almanac does.",
		"My Tam stacked better than this. Bark up, he'd say, so the rain runs off. I stack it bark down to spite him.",
	],
	"eat": [
		"Bread and a bit of hard cheese. Sit if you want; you're not having any.",
		"Noon's the only time the bench is mine. The rest of the day it's the cat's.",
	],
	"lamp": [
		"Every night. Someone up at the keep ought to be able to see the way down.",
		"Tam went up the hill one dusk to see to the old keeper. I lit this so he'd find the green coming home. I still light it.",
		"Hush now. It takes if you're patient and goes out if you're not.",
	],
	"evening": [
		"There it burns. Silly, isn't it. But the moths are grateful.",
		"Sit a moment. The evening's the one thing in this vale that's still worth the wait.",
		"When I can't do it any more, you'll light it for me? Only if I ask. Not before.",
	],
}
# the axe pose keys: hip, knee, spine, arm, elbow, neck (Crumple)
## The hens' feed, in the stone cottage's frame: where she stands outside the garth's east
## wall (clear of the field gate's swing), and the way there round the outside of the yard
## walls and past the cottage's east gable.
const FEED_STAND := Vector2(5.45, -8.3)
const FEED_WAY := [Vector2(8.6, 4.2), Vector2(6.7, -2.6)]
const CHOP_READY := [0.08, 0.12, 0.12, 0.5, 0.7, -0.1]
const CHOP_TOP := [0.0, 0.06, -0.12, 2.85, 1.05, 0.05]
const CHOP_HIT := [0.4, 0.45, 0.55, 1.05, 0.08, -0.25]
var clasp_amt := 0.85            # both arms drawn in onto the helve (Crumple.clasp)
## Who this is (the HUD's caption) and what they say: a neighbour (Neighbour) sets its own.
var who := "Edda"
# the model's sleeves and plates as wool (hero.gdshader cloth_body) and its red trim as a patch
var body_wool := Color(0.36, 0.18, 0.125)   # Edda's kirtle rust
var body_patch := Color(0.20, 0.12, 0.08)
# the base body's plates and iron sink in (hero.gdshader plate_inset/iron_inset) and the wraps
# follow, so no villager keeps the Vanguard's knee cops, shoulder humps and boot cuffs
const PLATE_INSET := 0.02
const IRON_INSET := 0.015
var who_title := "Cottager on Harrowmere green"
var intro: Array = INTRO
var lines: Dictionary = LINES

var world: Node3D
var weather: Weather
var player: Node3D
var terrain: Terrain
var home: WhiteCottage
var lantern: LanternPost

var activity := ""               # in, wake, water, wood, eat, lamp, evening, shelter
var state := STAND
var path: Array[Vector3] = []
var goal_yaw := 0.0
var noticing := false
var lantern_lit := false         # she has lit the lantern this evening (LanternPost reads it)
var lights := 0                  # times she has lit it (bots)
var stoops := 0                  # times she has bent to the pail or the woodpile (bots)
var carrying := false            # the pail in her hand
var dips := 0                    # times she has dipped the pail in the butt (bots)
var pail_moves := 0              # times she has taken it up or set it down (bots)
var _pail_k := 0.0               # 0 where it stood .. 1 hung from her hand
var _pail_from := Transform3D()
var visits := {}                 # activity -> times she reached its spot (bots)
var goings_in := 0               # times she went in at the door (bots)
var warps := 0
var stuck_t := 0.0
var named := false               # the HUD has named her
var talks := 0                   # lines spoken to the hero (bots)
var hums := 0                    # phrases hummed on the bench (bots)
var _hum_t := 3.0                # s until the next phrase
var last_line := ""
var talking := 0.0               # > 0 while her line is on screen: she holds still, facing him
var _intro_i := 0
var _line_i := {}
var _seen_interacts := 0
var mate: Villager               # the neighbour across the yard she passes a word with (World)
var exchanges: Dictionary = EXCHANGES   # her openers and his answers ({} for the one who answers)
var greeting := 0.0              # > 0 while turned to the mate mid-exchange
var greets := 0                  # lines passed to the mate (bots)
var heard := 0                   # of them, lines the hero overheard on the HUD (bots)
var greet_to: Villager           # whom she is turned to mid-exchange (the mate, or a passer-by)
var greet_r := GREET_R           # how near the mate must be for a word (a pedlar calls across the green)
var part_r := PART_R
var _greet_armed := true         # parted since the last word
var _greet_t := 0.0              # s together since the last word
var _answer := ""                # the mate's answer, due in _answer_in s
var _answer_in := -1.0
var _ex_i := {}

var idle := 0.0                  # 0 .. 1 stood still with nothing to do (step, green, a stand)
var _it := 0.0                   # seconds of idle time (weight shift, breath, looking about)
var roll := 0.0                  # the body's current lean onto one foot, rad (bots)
var idle_roll := 0.014           # rad the weight shift leans the body (an old man's is wider)
var idle_cycle := 7.0            # s for the weight to go from one foot to the other and back
var idle_breath := 4.0           # s a breath
var sit := 0.0                   # 0 standing .. 1 sat on the bench
var stoop := 0.0                 # 0 upright .. 1 bent to the pail / the logs
var reach := 0.0                 # 0 arm down .. 1 the taper up at the lantern
var _stoop_t := 2.0              # s until the next stoop (negative: in it)
var _light_t := -1.0             # s with the taper up (negative: not lighting)
var _spots := {}                 # name -> [ground point, facing yaw]
var _seat := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var body: Node3D
var model: Node3D
var skel: Skeleton3D
var garb: HeroGarb
var anim_tree: AnimationTree
var crumple: Crumple
var hand_mark: BoneAttachment3D
var left_mark: BoneAttachment3D
var taper: MeshInstance3D
var chop: WoodChop
var feed: HenFeed
var hens: Hens
var _taper_flame: OmniLight3D
var _blend := 0.0
var _model_rest: Transform3D
var _hip_h := 0.95

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_max_angle = 0.9
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.65
	col.shape = cap
	col.position.y = 0.83
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
	garb.wrap_inset = PLATE_INSET * 0.6
	_dress()
	add_child(garb)
	if skel != null:
		garb.build(skel, body)
		garb.swing_slack = 0.3
		garb.hang = 1.0
		crumple = Crumple.new()
		crumple.name = "Crumple"
		skel.add_child(crumple)
		crumple.frame = (body.global_basis.inverse() * skel.global_basis).orthonormalized()
		hand_mark = BoneAttachment3D.new()
		hand_mark.name = "HandMark"
		hand_mark.bone_name = "mixamorig_RightHand"
		skel.add_child(hand_mark)
		left_mark = BoneAttachment3D.new()
		left_mark.name = "LeftHandMark"
		left_mark.bone_name = "mixamorig_LeftHand"
		skel.add_child(left_mark)
		_kit()
		var hb := skel.find_bone("mixamorig_Hips")
		if hb >= 0:
			_hip_h = (skel.global_transform * skel.get_bone_global_rest(hb).origin).y - global_position.y

## Her clothes (HeroGarb's palette and cut).
func _dress() -> void:
	# a bleached linen coif, a brown wool shawl, a kirtle of madder washed out to rust, a
	# leather girdle, linen wraps
	garb.palette = {
		# a linen coif gone ivory-grey with wear: at 0.46 it read as a pale camouflage cowl
		# and at 0.085..0.36 the wide tone swing read as a blotchy cowl: a narrow, darker range
		"hood": [Color(0.19, 0.18, 0.158), Color(0.29, 0.275, 0.24), 0.3],
		"hat": [Color(0.15, 0.12, 0.07), Color(0.50, 0.42, 0.28), 0.3],
		"mantle": [Color(0.060, 0.042, 0.030), Color(0.30, 0.22, 0.15), 0.35],
		"robe": [Color(0.090, 0.040, 0.030), Color(0.42, 0.20, 0.14), 0.4],
		"sash": [Color(0.040, 0.028, 0.018), Color(0.22, 0.15, 0.09), 0.3],
		"wraps": [Color(0.15, 0.14, 0.12), Color(0.55, 0.52, 0.46), 0.4],
	}
	garb.hatless = true
	garb.robe_len = 1.1
	garb.robe_wide = 1.25
	garb.skirt = true
	# the kirtle's wool up over her chest under the shawl: without it the base body's plates
	# read as mottled pale-grey cloth at the woodpile, like a ghillie suit
	garb.smock = true
	garb.mantle_wool = true
	garb.hood_linen = true

## What she works with: the lamp taper and the axe at the woodpile.
func _kit() -> void:
	_build_taper()
	chop = WoodChop.new()
	chop.name = "WoodChop"
	add_child(chop)

## Her left palm in the world (the second hand on the axe helve).
func left_hand_pos() -> Vector3:
	# (a BoneAttachment: get_bone_global_pose would miss Crumple's bends)
	return left_mark.global_position + left_mark.global_basis.y.normalized() * 0.07

## A long rush taper in her right hand, its tip burning while she lights the lantern.
func _build_taper() -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.006
	m.bottom_radius = 0.008
	m.height = 0.55
	m.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.36, 0.24)
	mat.roughness = 0.8
	taper = MeshInstance3D.new()
	taper.name = "Taper"
	taper.mesh = m
	taper.material_override = mat
	taper.position = Vector3(0.0, 0.3, 0.03)
	taper.visible = false
	hand_mark.add_child(taper)
	_taper_flame = OmniLight3D.new()
	_taper_flame.light_color = Color(1.0, 0.6, 0.3)
	_taper_flame.omni_range = 2.5
	_taper_flame.light_energy = 0.0
	_taper_flame.position = Vector3(0, 0.28, 0)
	taper.add_child(_taper_flame)

## Her day's spots round the white cottage and out at the lantern, then where she is now.
func settle(w: Node3D, at_hour: float) -> void:
	world = w
	_reset_greet()
	weather = w.get("weather")
	player = w.get_node_or_null("Player")
	terrain = w.get_node("Terrain")
	home = w.get("white_cottage")
	lantern = w.get("lantern_post")
	hens = w.get("hens")
	if chop != null and chop.villager == null:
		chop.setup(self, home)
	if hens != null and feed == null:
		feed = HenFeed.new()
		feed.name = "HenFeed"
		add_child(feed)
		feed.setup(self, hens)
	_rng.seed = 4242
	var hd := WhiteCottage.W_DEP * 0.5
	var fy := home.global_rotation.y         # the door side's facing (local +z)
	_spots["door_in"] = [home.to_global(Vector3(-0.3, 0, hd - 0.9)), fy]
	_spots["door"] = [home.to_global(Vector3(-0.3, 0, hd + 1.0)), fy]
	var bt := WhiteCottage.BUTT_AT
	_spots["water"] = [home.to_global(Vector3(bt.x + 0.1, 0, bt.y + 0.62)), fy + PI]
	var bk := WhiteCottage.BLOCK_AT
	_spots["wood"] = [home.to_global(Vector3(bk.x - 0.75, 0, bk.y + 0.1)), fy + PI * 0.5]
	# round the front of the water butt to and from the woodpile
	_spots["round"] = [home.to_global(Vector3(3.7, 0, bt.y + 1.0)), fy]
	_seat = home.bench_seat
	_spots["eat"] = [home.to_global(Vector3(WhiteCottage.BENCH_X + 0.1, 0, hd + 0.75)), fy]
	_spots["evening"] = _spots["eat"]
	if hens != null:
		var sc := hens.cottage
		var fs := sc.to_global(Vector3(FEED_STAND.x, 0, FEED_STAND.y))
		var land := sc.to_global(Vector3(HenFeed.LAND.x, 0, HenFeed.LAND.y))
		_spots["feed"] = [fs, atan2(land.x - fs.x, land.z - fs.z)]
		for i in FEED_WAY.size():
			_spots["feed_way%d" % i] = [sc.to_global(Vector3(FEED_WAY[i].x, 0, FEED_WAY[i].y)), 0.0]
	if lantern != null:
		var lc := lantern.lantern_center()
		var out := Vector3(lc.x - lantern.global_position.x, 0, lc.z - lantern.global_position.z).normalized()
		var st := lc + out * 0.45
		_spots["lamp"] = [st, atan2(-out.x, -out.z)]
		lantern.lighter = self
	home.keeper = self
	carrying = false
	activity = ""
	var a := _activity_for(at_hour)
	if not _spots.has(_spot_name(a)):
		a = "wood"
	var sp: Array = _spots[_spot_name(a)]
	_place(sp[0])
	goal_yaw = sp[1]
	body.rotation.y = goal_yaw
	activity = a
	state = IN if a == "in" else STAND
	if a == "eat" or a == "evening":
		state = SIT
		sit = 1.0
	if a == "lamp" or a == "evening":
		lantern_lit = at_hour >= 19.3
	if a == "lamp" and not lantern_lit:
		_light_t = 0.0
	if a == "water" and home.pail != null:
		# already at it: the pail in her hand, filled
		carrying = true
		_pail_k = 1.0
		_pail_from = home.pail.global_transform
		home.pail.level = 0.82
	home.lit = WhiteCottage.lit_for(at_hour) if state == IN else 0.0
	_show(state != IN)

func _place(p: Vector3) -> void:
	global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.03, p.z)
	_last_pos = global_position

func _hour() -> float:
	return world.time_of_day if world != null else 12.0

static func _activity_for(h: float) -> String:
	if h < 6.0 or h >= 20.67:
		return "in"
	if h < 6.5:
		return "wake"
	if h < 7.33:
		return "water"
	if h < 8.42:
		return "feed"
	if h < 12.0:
		return "wood"
	if h < 13.0:
		return "eat"
	if h < 14.0:
		return "water"
	if h < 16.33:
		return "wood"
	if h < 17.33:
		return "feed"
	if h < 18.83:
		return "wood"
	if h < 19.67:
		return "lamp"
	return "evening"

## The activity for hour h and the spot it is done at (overridable: a neighbour keeps another day).
func _want_for(h: float) -> String:
	return _activity_for(h)

func _spot_for(a: String) -> String:
	return _spot_name(a)

## Where the door creaks (Foley).
func _door_point() -> Vector3:
	return home.to_global(Vector3(-0.3, 1.0, WhiteCottage.W_DEP * 0.5))

## True for the activities done stooping, bend after bend.
func _works(a: String) -> bool:
	return a == "water" or a == "wood"

static func _spot_name(a: String) -> String:
	if a == "in" or a == "shelter":
		return "door_in"
	if a == "wake":
		return "door"
	return a

## True while she is out of doors and drawn.
func outdoors() -> bool:
	return state != IN

func _show(on: bool) -> void:
	visible = on
	collision_layer = 4 if on else 0
	collision_mask = 1 if on else 0

## Walk to `to`; in and out of the house always through the door.
func _route(to: Vector3) -> void:
	path.clear()
	var from_in := state == IN
	if from_in:
		# out through the door onto the step
		_place(_spots["door"][0])
		_show(true)
		door.emit(_door_point())
	# going in: up to the step, and in at the door (the door leaf is shut geometry)
	if to.distance_to(_spots["door_in"][0]) < 0.1:
		to = _spots["door"][0]
	var wd: Vector3 = _spots["wood"][0]
	var here := global_position
	# to and from the garth: round the outside of the yard walls
	var fd: Vector3 = _spots["feed"][0] if _spots.has("feed") else Vector3.INF
	var at_feed := Vector2(here.x - fd.x, here.z - fd.z).length() < 2.0
	var to_feed := to.distance_to(fd) < 0.1
	if at_feed and not to_feed:
		for i in range(FEED_WAY.size() - 1, -1, -1):
			path.append(_spots["feed_way%d" % i][0])
		here = path[path.size() - 1]
	if (Vector2(here.x - wd.x, here.z - wd.z).length() < 1.0) != (to.distance_to(wd) < 1.0):
		path.append(_spots["round"][0])
	if to_feed and not at_feed:
		for i in FEED_WAY.size():
			path.append(_spots["feed_way%d" % i][0])
	path.append(to)
	state = WALK
	stuck_t = 0.0

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var h := _hour()
	var want := _want_for(h)
	var raining := weather != null and weather.rain > RAIN_IN
	if raining and want != "in" and want != "lamp":
		want = "shelter"
	elif activity == "shelter" and weather != null and weather.rain > RAIN_IN * 0.5 and want != "lamp":
		want = "shelter"
	if want == "wake" or want == "water":
		if h < 13.0:
			lantern_lit = false
	if want == "feed" and not _spots.has("feed"):
		want = "wood"
	if want != activity:
		_begin(want)
	_update_greet(delta)
	_update_notice()
	_update_talk(delta)
	if state == IN:
		velocity = Vector3.ZERO
		return
	var v := Vector3.ZERO
	if state == WALK and not noticing and sit < 0.05 and stoop < 0.05 and reach < 0.05:
		var tgt: Vector3 = path[0]
		var d := Vector3(tgt.x - global_position.x, 0, tgt.z - global_position.z)
		if d.length() < 0.3:
			path.pop_front()
			if path.is_empty():
				_arrive()
		else:
			var sp := HURRY_SPEED if activity == "shelter" else WALK_SPEED * _pace()
			v = _steer(d.normalized()) * sp
			goal_yaw = atan2(v.x, v.z)
			var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
			stuck_t = stuck_t + delta if moved < sp * delta * 0.3 else maxf(stuck_t - delta, 0.0)
			if stuck_t > 0.6:
				v = v.rotated(Vector3.UP, 1.2)
				if stuck_t > 4.0:
					_place(tgt)
					warps += 1
					stuck_t = 0.0
	_last_pos = global_position
	var sit_goal := 1.0 if state == SIT and not noticing else 0.0
	sit = move_toward(sit, sit_goal, delta / 1.4)
	if sit > 0.0 and _seat != Vector3.ZERO:
		# down onto the bench: the hips slide back over the seat, the feet stay before it
		var st: Vector3 = _spots["eat"][0]
		var e := sit * sit * (3.0 - 2.0 * sit)
		var p := st.lerp(Vector3(_seat.x, st.y, _seat.z), e)
		global_position = Vector3(p.x, terrain.height_at(st.x, st.z) + 0.03, p.z)
		velocity = Vector3.ZERO
	else:
		velocity.x = lerpf(velocity.x, v.x, 1.0 - exp(-6.0 * delta))
		velocity.z = lerpf(velocity.z, v.z, 1.0 - exp(-6.0 * delta))
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
	body.rotation.y = lerp_angle(body.rotation.y, goal_yaw, 1.0 - exp(-4.0 * delta))
	_update_work(delta)
	_update_hum(delta)
	if feed != null:
		feed.update(delta, state == STAND and activity == "feed" and not noticing, activity == "feed" and state != IN)
	_update_light(delta)
	idle = move_toward(idle, 1.0 if _idle_still() else 0.0, delta / IDLE_IN)
	_it += delta
	_pose()
	_update_animation(delta)
	var pg = player.get("garb") if player != null else null
	if garb.fill != null and pg != null and pg.fill != null:
		garb.fill.light_energy = pg.fill.light_energy * garb.fill_gain
		garb.fill.light_color = pg.fill.light_color
		if garb.eye_fill != null:
			garb.eye_fill.light_energy = garb.fill.light_energy * 0.5
			garb.eye_fill.light_color = garb.fill.light_color

## The walking direction toward the next path point, bent round anything in the way (none here).
func _steer(dir: Vector3) -> Vector3:
	return dir

func _begin(a: String) -> void:
	activity = a
	_light_t = -1.0
	var to: Vector3 = _spots[_spot_for(a)][0]
	if a == "in" or a == "shelter":
		if state == IN:
			return
	_route(to)

## Walking pace as a share of WALK_SPEED (the pedlar slows on his last leg of the day).
func _pace() -> float:
	return 1.0

func _arrive() -> void:
	state = STAND
	visits[activity] = visits.get(activity, 0) + 1
	goal_yaw = _spots[_spot_for(activity)][1]
	if activity == "in" or activity == "shelter":
		state = IN
		goings_in += 1
		_show(false)
		door.emit(_door_point())
	elif activity == "eat" or activity == "evening":
		state = SIT
	elif activity == "lamp":
		_light_t = 0.0 if not lantern_lit else -1.0
	_stoop_t = _rng.randf_range(1.0, 2.5)

## Stops and turns to the hero when he comes close (not while sat or mid-stoop).
func _update_notice() -> void:
	noticing = false
	if player == null or state == IN or state == SIT:
		return
	var d := player.global_position - global_position
	d.y = 0.0
	if talking > 0.0:
		noticing = true                      # holds still and keeps facing him mid-line
		if stoop < 0.1 and reach < 0.1:
			goal_yaw = atan2(d.x, d.z)
		return
	if greeting > 0.0 and mate != null:
		noticing = true                      # holds still, turned to the neighbour
		if stoop < 0.1 and reach < 0.1:
			var gt: Villager = greet_to if greet_to != null else mate
			var m := gt.global_position - global_position
			goal_yaw = atan2(m.x, m.z)
		return
	if stoop > 0.1 or reach > 0.1:
		return
	if d.length() < NOTICE:
		noticing = true
		goal_yaw = atan2(d.x, d.z)
		if not named and d.length() < NAME_AT:
			named = true
			var hud = player.get_node_or_null("Hud")
			if hud != null:
				hud.caption(who, who_title)

## In reach the HUD offers "Speak"; each press gets the next line (the intro first, then the
## pool for what she is about). A press while a line shows skips on to the next one.
func _update_talk(delta: float) -> void:
	talking = maxf(talking - delta, 0.0)
	if player == null:
		return
	var presses: int = player.get("interacts")
	var d := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
	var near: bool = state != IN and d.length() < TALK_R and not player.is_dead() and player.get("lock_target") == null
	if not near:
		_seen_interacts = presses
		return
	var hud = player.get_node_or_null("Hud")
	if hud != null:
		hud.prompt("E", "Speak")
	if presses == _seen_interacts:
		return
	_seen_interacts = presses
	var line := _next_line()
	last_line = line
	talks += 1
	talking = 2.4 + 0.055 * line.length()
	named = true
	if hud != null:
		hud.say(who, line, talking)

## Meeting the neighbour out of doors: whoever has openers says one for the hour, the other
## answers when it is done; both stop and face each other until the answer has been said.
func _update_greet(delta: float) -> void:
	greeting = maxf(greeting - delta, 0.0)
	if _answer_in >= 0.0:
		_answer_in -= delta
		if _answer_in < 0.0:
			_say_to_mate(_answer, true)
			_answer = ""
	if mate == null or exchanges.is_empty():
		return
	var d := Vector2(mate.global_position.x - global_position.x, mate.global_position.z - global_position.z).length()
	var out := state != IN and mate.state != IN and visible and mate.visible
	if not out or d > part_r:
		_greet_armed = true
		_greet_t = 0.0
		return
	if d > greet_r:
		return
	_greet_t += delta
	if not _greet_armed and _greet_t < GREET_AGAIN:
		return
	if greeting > 0.0 or mate.greeting > 0.0 or talking > 0.0 or mate.talking > 0.0 or noticing or mate.noticing:
		return                           # one of them is busy with the hero (or mid-word)
	if activity == "shelter" or mate.activity == "shelter":
		return
	var h := _hour()
	var key := "morning" if h < 10.0 else ("day" if h < 18.0 else "evening")
	var pool: Array = exchanges.get(key, [])
	if pool.is_empty():
		return
	var i := int(_ex_i.get(key, 0))
	_ex_i[key] = i + 1
	var ex: Array = pool[i % pool.size()]
	_greet_armed = false
	_greet_t = 0.0
	greet_to = mate
	mate.greet_to = self
	var t1 := _say_to_mate(ex[0], false)
	mate._answer = ex[1]
	mate._answer_in = t1 + 0.35
	var t2 := 2.4 + 0.055 * str(ex[1]).length()
	greeting = t1 + 0.35 + t2 + 0.6
	mate.greeting = greeting

## One line of an exchange: counted, murmured (Foley), and on the HUD if the hero is near and
## not already being spoken to. Returns how long it holds.
func _reset_greet() -> void:
	greeting = 0.0
	_answer = ""
	_answer_in = -1.0
	_greet_armed = true
	_greet_t = 0.0

func _say_to_mate(line: String, answer: bool) -> float:
	var secs := 2.4 + 0.055 * line.length()
	greets += 1
	spoke.emit(global_position + Vector3.UP * 1.6, who != "Edda" and who != "Hild")
	if player == null:
		return secs
	# within earshot of either of them: the hero who hears her hears his answer too
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var d := pp.distance_to(Vector2(global_position.x, global_position.z))
	if mate != null:
		d = minf(d, pp.distance_to(Vector2(mate.global_position.x, mate.global_position.z)))
	var hud = player.get_node_or_null("Hud")
	if hud != null and d < HEAR_R and (answer or not hud.saying()):
		hud.say(who, line, secs)
		last_line = line
		heard += 1
	return secs

func _next_line() -> String:
	if _intro_i < intro.size():
		_intro_i += 1
		return intro[_intro_i - 1]
	var key := activity
	if not lines.has(key):
		key = "wood" if lines.has("wood") else str(lines.keys()[0])
	var pool: Array = lines[key]
	var i := int(_line_i.get(key, 0))
	_line_i[key] = i + 1
	return pool[i % pool.size()]

## At the butt and the woodpile: bend down, hold, straighten, a pause, again.
func _update_work(delta: float) -> void:
	_update_pail(delta)
	if carrying and activity != "water":
		# done at the butt: stoop and set the pail down before going on
		stoop = move_toward(stoop, 1.0, delta / STOOP_DOWN)
		if stoop > 0.95:
			_drop_pail()
		return
	var working := state == STAND and _works(activity) and not noticing
	if chop != null:
		chop.update(delta, working and activity == "wood")
		if chop.holding:
			stoop = chop.bend
			if chop.bend > 0.95 and _stoop_t > 0.0:
				stoops += 1
				_stoop_t = -1.0
			elif chop.bend < 0.5:
				_stoop_t = 1.0
			return
	if not working:
		stoop = move_toward(stoop, 0.0, delta / STOOP_UP)
		_stoop_t = maxf(_stoop_t, 1.0)
		return
	_stoop_t -= delta
	if _stoop_t >= 0.0:
		stoop = move_toward(stoop, 0.0, delta / STOOP_UP)
		return
	var t := -_stoop_t
	if t < STOOP_DOWN + STOOP_HOLD:
		stoop = move_toward(stoop, 1.0, delta / STOOP_DOWN)
		if activity == "water" and stoop > 0.95:
			if not carrying and home.pail != null:
				# the first bend: take the pail up by its bail from where it stands
				carrying = true
				pail_moves += 1
				home.pail.level = minf(home.pail.level, 0.25)
				_pail_from = home.pail.global_transform
				_pail_k = 0.0
			elif carrying and _pail_k > 0.99 and t > STOOP_DOWN + STOOP_HOLD * 0.5 and home.pail.level < 0.8:
				home.pail.level = 0.82
				dips += 1
	else:
		stoops += 1
		_stoop_t = _rng.randf_range(2.5, 5.0) if activity != "water" else _rng.randf_range(4.0, 8.0)

func _update_hum(delta: float) -> void:
	if state != SIT or activity != "evening" or sit < 0.95 or noticing or talking > 0.0:
		_hum_t = maxf(_hum_t, 2.5)
		return
	_hum_t -= delta
	if _hum_t <= 0.0:
		hums += 1
		hummed.emit(global_position + Vector3.UP * 1.2)
		_hum_t = _rng.randf_range(8.0, 15.0)

## The pail hangs plumb from her right hand by its bail, turned across her stride; taken up,
## it swings over from where it stood. Bent to the butt it goes in over the rim.
func _update_pail(delta: float) -> void:
	if not carrying or home == null or home.pail == null or hand_mark == null:
		return
	_pail_k = move_toward(_pail_k, 1.0, delta / 0.45)
	var hp := hand_mark.global_position
	var foot := hp - Vector3(0, WhiteCottage.pail_grip(), 0)
	foot.y = maxf(foot.y, terrain.height_at(foot.x, foot.z))
	var carry := Transform3D(Basis(Vector3.UP, body.global_rotation.y + PI * 0.5).scaled(WhiteCottage.PAIL_SCALE), foot)
	var e := _pail_k * _pail_k * (3.0 - 2.0 * _pail_k)
	home.pail.global_transform = _pail_from.interpolate_with(carry, e)

func _drop_pail() -> void:
	carrying = false
	pail_moves += 1
	var p := home.pail.global_position
	home.put_pail(p, body.global_rotation.y + PI * 0.5)

## The taper up to the lantern's door until the wick catches.
func _update_light(delta: float) -> void:
	var lighting := _light_t >= 0.0 and activity == "lamp" and state == STAND
	if lighting and not noticing:
		_light_t += delta
		if _light_t > LIGHT_LEN and not lantern_lit:
			lantern_lit = true
			lights += 1
		if _light_t > LIGHT_LEN + 1.2:
			_light_t = -1.0
	reach = move_toward(reach, 1.0 if lighting and _light_t < LIGHT_LEN + 0.6 else 0.0, delta / 0.7)
	if taper != null:
		taper.visible = activity == "lamp"
		var burn := 1.0 if activity == "lamp" and state != WALK or reach > 0.05 else 0.0
		_taper_flame.light_energy = move_toward(_taper_flame.light_energy, burn * 0.3, delta)

func _pose() -> void:
	if crumple == null:
		return
	var s := sit * sit * (3.0 - 2.0 * sit)
	var p := stoop * stoop * (3.0 - 2.0 * stoop)
	var r := reach * reach * (3.0 - 2.0 * reach)
	crumple.active = true
	crumple.hip = lerpf(0.55 * p, 1.5, s)
	crumple.knee = lerpf(0.75 * p, 1.5, s)
	crumple.spine = lerpf(0.95 * p, 0.12, s)
	crumple.pelvis = 0.35 * p * (1.0 - s)
	crumple.neck = 0.15 * p - 0.25 * r
	crumple.arm = lerpf(1.7 * p, 0.6, s)
	crumple.elbow = lerpf(-0.2 * p, 1.2, s)
	crumple.head_turn = 0.0
	# the taper: right arm up and forward, the elbow a little soft, to the lantern's door
	if chop != null and chop.holding:
		# the axe in both hands: low before her, heaved up over the head, struck down through
		var lf := chop.lift
		var k: Array = CHOP_READY.duplicate()
		var to: Array = CHOP_TOP if lf >= 0.0 else CHOP_HIT
		var w := absf(lf)
		for i in k.size():
			k[i] = lerpf(lerpf(k[i], to[i], w), [0.55 * p, 0.75 * p, 0.95 * p, 1.7 * p, -0.2 * p, 0.15 * p][i], p)
		crumple.hip = k[0]
		crumple.knee = k[1]
		crumple.spine = k[2]
		crumple.arm = k[3]
		crumple.elbow = k[4]
		crumple.neck = k[5]
		crumple.clasp = clasp_amt * (1.0 - p)
		p = maxf(p, 0.6 * maxf(-lf, 0.0))
	else:
		crumple.clasp = 0.0
	crumple.grip = 0.0
	crumple.flick = r
	crumple.flick_arm = 2.75
	crumple.flick_elbow = 0.35
	if feed != null and feed.weight > 0.0:
		# the cast: the right arm from the bag at her hip up to her chest and out over the wall
		var fw := feed.weight * feed.weight * (3.0 - 2.0 * feed.weight)
		crumple.flick = fw
		crumple.flick_arm = feed.arm
		crumple.flick_elbow = feed.elbow
		crumple.spine += feed.lean * fw
	# bent knees lower the hips; sat, the hips come down onto the seat
	var bob := _hip_h * (1.0 - cos(0.75 * p * 0.5)) * 0.5 + 0.06 * p
	var down := lerpf(bob, _hip_h - SEAT_H - 0.05, s)
	model.transform = _model_rest.translated(Vector3.DOWN * down)
	roll = 0.0
	if idle > 0.0:
		_pose_idle()

## Stood about with nothing in hand: on the step, at a stand on the road, watching the green.
func _idle_still() -> bool:
	return state == STAND and visible and not noticing and talking <= 0.0 and greeting <= 0.0 \
			and sit < 0.05 and stoop < 0.05 and reach < 0.05 and not (chop != null and chop.holding) \
			and not (feed != null and feed.weight > 0.05)

## Never quite still when stood about: the weight going slowly from one foot to the other (the
## knee giving on the free side), a breath lifting the chest, and the head turning now and then
## to look about. Kept off while she works, sits or reaches (_idle_still); Neighbour mutes it more.
func _idle_weight() -> float:
	return idle * idle * (3.0 - 2.0 * idle)

func _pose_idle() -> void:
	var w := _idle_weight()
	if w <= 0.0:
		return
	# a lean that lingers on each foot and crosses over quickly: sin shaped toward a square
	var ph := sin(_it * TAU / idle_cycle)
	var side := signf(ph) * pow(absf(ph), 0.6)
	var r := idle_roll * side * w
	roll += r
	model.transform = model.transform.rotated_local(Vector3.BACK, r)
	# the free knee gives as the weight leaves it, lowering the hips a touch at the crossover
	crumple.knee += 0.04 * w * (1.0 - absf(side))
	crumple.hip += 0.02 * w * (1.0 - absf(side))
	# breath: the chest up, the head with it
	var br := sin(_it * TAU / idle_breath)
	crumple.spine -= 0.012 * br * w
	crumple.neck += 0.01 * br * w
	# looking about: two slow turns that never line up, so it does not read as a loop
	crumple.head_turn += w * (0.18 * sin(_it * TAU / 13.0 + 0.7) + 0.08 * sin(_it * TAU / 5.3))

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
			mat.set_shader_parameter("cloth_body", 1.0)
			mat.set_shader_parameter("plate_inset", PLATE_INSET)
			mat.set_shader_parameter("iron_inset", IRON_INSET)
			# her sleeves the kirtle's rust wool, not the default undyed grey (read pale mottled grey)
			mat.set_shader_parameter("wool", body_wool)
			mat.set_shader_parameter("patch_col", body_patch)
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
	_blend = lerpf(_blend, ANIM_WALK_SPEED if hs > 0.3 else hs, 1.0 - exp(-8.0 * delta))
	anim_tree.set("parameters/move/blend_position", _blend)
	var ts := 1.0
	if hs > 0.3:
		ts = clampf(hs / ANIM_WALK_SPEED, 0.6, 1.2)
	ts *= lerpf(1.0, 0.2, sit)
	anim_tree.set("parameters/speed/scale", ts)
