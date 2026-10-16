class_name Keeper
extends CharacterBody3D
## Hesper, the last keeper of the Shrine of Binding: the vale's first person. An old pilgrim in
## undyed wool and an ash-grey hood (the hero's rig and garb cut, her own dyes), living rough
## in the ruined keep on the knoll and keeping a day:
##   05:30 wakes against the inner wall, stands and walks out to the breach to watch the dawn
##   07:00 tends the sealed lid (stands over it, head bowed)
##   10:00 walks down to the nearest oaks and gathers under them, grove to grove
##   12:30 eats in the shade of the nearest oak to the keep
##   14:00 gathers again
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
		"The cords on the lid warm when you stand near. They never once warmed for me.",
		"I sweep it so whoever opens it will know we did not forget.",
		"There was a bell for the keeper's hour. I ring it in my head now. Saves the rope.",
	],
	"tend_night": [
		"See the ember in the grooves? It wakes at night, like an old dog dreaming.",
		"Go and sleep, child. The lid is not going anywhere. That is rather its whole trouble.",
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
	"watch": [
		"Down there was Harrowmere. It had bells once, and a baker who sang flat.",
		"There is a soldier in the meadow who has not noticed he is dead. Be kind to him. Be quick.",
		"The light goes earlier every evening. I watch it go so it knows someone minded.",
	],
	"shelter": [
		"Rain is the only thing in this vale that still arrives on time.",
		"Under the oak, child. Even the Hollow have the sense to stand still in this.",
	],
	"sleep": [
		"Mm... the lid is swept... come back at first light...",
		"...forty years... nnh... mind the step...",
	],
}

signal activity_changed(name: String)

var world: Node3D
var weather: Weather
var player: Node3D
var terrain: Terrain
var site := Vector3.ZERO
var to_v := Vector3.FORWARD     # from the keep out through the breach (toward the village)

var activity := ""              # wake, watch, tend, gather, eat, sleep, shelter
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
var _blend := 0.0
var _model_rest: Transform3D
var _hip_h := 0.95
var _spots := {}
var _oaks: Array[Vector3] = []
var _gather_i := 0
var _gather_t := 0.0
var _last_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

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
	# undyed grey-brown wool, an ash hood, a faded woad robe, a rope-brown sash, old linen
	garb.palette = {
		"hood": [Color(0.040, 0.038, 0.036), Color(0.20, 0.19, 0.18), 0.3],
		"hat": [Color(0.15, 0.12, 0.07), Color(0.50, 0.42, 0.28), 0.3],
		"mantle": [Color(0.070, 0.058, 0.044), Color(0.36, 0.31, 0.24), 0.35],
		"robe": [Color(0.040, 0.050, 0.062), Color(0.24, 0.28, 0.32), 0.4],
		"sash": [Color(0.075, 0.050, 0.030), Color(0.34, 0.24, 0.14), 0.3],
		"wraps": [Color(0.14, 0.13, 0.11), Color(0.50, 0.47, 0.41), 0.4],
	}
	add_child(garb)
	if skel != null:
		garb.build(skel, body)
		crumple = Crumple.new()
		crumple.name = "Crumple"
		skel.add_child(crumple)
		crumple.frame = (body.global_basis.inverse() * skel.global_basis).orthonormalized()
		var hb := skel.find_bone("mixamorig_Hips")
		if hb >= 0:
			_hip_h = (skel.global_transform * skel.get_bone_global_rest(hb).origin).y - global_position.y
	soak = Soak.new()
	soak.name = "Soak"
	add_child(soak)

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
	_last_pos = global_position

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
	if h < 14.0:
		return "eat"
	if h < 17.5:
		return "gather"
	if h < 20.0:
		return "watch"
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
		if _gather_t <= 0.0 and _oaks.size() > 1:
			_gather_i = (_gather_i + 1) % _oaks.size()
			_route(_gather_spot(_gather_i))
	_update_notice()
	_update_talk(delta)
	var v := Vector3.ZERO
	if state == WALK and not noticing and talking <= 0.0 and sit < 0.05:
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
	body.rotation.y = lerp_angle(body.rotation.y, goal_yaw, 1.0 - exp(-4.0 * delta))
	var sit_goal := 1.0 if (state == SIT and activity == "sleep") else 0.0
	sit = move_toward(sit, sit_goal, delta / 2.2)
	_pose_sit()
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
	else:
		var s: Array = _spots.get(_spot_of(a), _spots["tend"])
		_route(s[0])
	state = WALK                             # from the doze she stands up first (see sit)

func _gather_spot(i: int) -> Vector3:
	var o := _oaks[i]
	var a := float(i) * 2.1 + 0.6
	return o + Vector3(cos(a), 0, sin(a)) * 2.6

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
		hud.prompt("E", "Speak" if sit < 0.5 else "Listen")
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
	if sit >= 0.5 or activity == "sleep":
		return _pool_line("sleep")
	if _intro_i < INTRO.size():
		_intro_i += 1
		return INTRO[_intro_i - 1]
	var key := activity
	if activity == "tend" and _hour() >= 19.0:
		key = "tend_night"
	if not LINES.has(key):
		key = "watch"
	return _pool_line(key)

func _pool_line(key: String) -> String:
	var pool: Array = LINES[key]
	var i := int(_line_i.get(key, 0))
	_line_i[key] = i + 1
	return pool[i % pool.size()]

## The doze: knees drawn up, back to the wall, head down on the knees; the body sinks onto
## the floor as she sits.
func _pose_sit() -> void:
	if crumple == null:
		return
	var e := sit * sit * (3.0 - 2.0 * sit)
	crumple.active = e > 0.001
	crumple.hip = 1.85 * e
	crumple.knee = 2.15 * e
	crumple.spine = 0.55 * e
	crumple.arm = 0.75 * e
	crumple.elbow = 1.1 * e
	crumple.head_turn = 0.25 * e
	model.transform = _model_rest.translated(Vector3.DOWN * (_hip_h - 0.14) * e)

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
