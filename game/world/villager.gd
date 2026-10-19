class_name Villager
extends CharacterBody3D
## Edda, the cottager in the limewashed house on the green: Harrowmere's first villager (the
## hero's rig and Hesper's garb builder, cut as a working woman: a linen coif, a madder-washed
## kirtle to the ankles, no basket). She keeps a day by the clock and the weather:
##   06:00 opens the door and stands on the step looking out over the green
##   06:30 draws water at the butt by the door corner (stoops to dip the pail, straightens)
##   08:00 works the woodpile at the lean-to's open end (stoops for split logs, stacks them)
##   12:00 sits on the bench under the window to eat
##   13:00 back to the butt, then the woodpile through the afternoon
##   18:50 walks out to the lantern post on the green with a taper and lights the lantern
##   19:40 sits out on the bench in the last of the light
##   20:40 goes in for the night (the windows stay lit until bedtime)
## Under a rain front she breaks off and goes indoors until it eases (the lantern round
## excepted: it still gets lit). Indoors she is not drawn. When the hero comes near she stops,
## turns to face him and watches him while he stays close.

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
var visits := {}                 # activity -> times she reached its spot (bots)
var goings_in := 0               # times she went in at the door (bots)
var warps := 0
var stuck_t := 0.0

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
var taper: MeshInstance3D
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
	# a bleached linen coif, a brown wool shawl, a kirtle of madder washed out to rust, a
	# leather girdle, linen wraps
	garb.palette = {
		"hood": [Color(0.10, 0.092, 0.078), Color(0.46, 0.43, 0.37), 0.35],
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
		_build_taper()
		var hb := skel.find_bone("mixamorig_Hips")
		if hb >= 0:
			_hip_h = (skel.global_transform * skel.get_bone_global_rest(hb).origin).y - global_position.y

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
	weather = w.get("weather")
	player = w.get_node_or_null("Player")
	terrain = w.get_node("Terrain")
	home = w.get("white_cottage")
	lantern = w.get("lantern_post")
	_rng.seed = 4242
	var hd := WhiteCottage.W_DEP * 0.5
	var fy := home.global_rotation.y         # the door side's facing (local +z)
	_spots["door_in"] = [home.to_global(Vector3(-0.3, 0, hd - 0.9)), fy]
	_spots["door"] = [home.to_global(Vector3(-0.3, 0, hd + 1.0)), fy]
	var bt := WhiteCottage.BUTT_AT
	_spots["water"] = [home.to_global(Vector3(bt.x + 0.1, 0, bt.y + 0.62)), fy + PI]
	var bk := WhiteCottage.BLOCK_AT
	_spots["wood"] = [home.to_global(Vector3(bk.x - 0.7, 0, bk.y + 0.1)), fy + PI * 0.5]
	# round the front of the water butt to and from the woodpile
	_spots["round"] = [home.to_global(Vector3(3.7, 0, bt.y + 1.0)), fy]
	_seat = home.bench_seat
	_spots["eat"] = [home.to_global(Vector3(WhiteCottage.BENCH_X + 0.1, 0, hd + 0.75)), fy]
	_spots["evening"] = _spots["eat"]
	if lantern != null:
		var lc := lantern.lantern_center()
		var out := Vector3(lc.x - lantern.global_position.x, 0, lc.z - lantern.global_position.z).normalized()
		var st := lc + out * 0.45
		_spots["lamp"] = [st, atan2(-out.x, -out.z)]
		lantern.lighter = self
	activity = ""
	var a := _activity_for(at_hour)
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
	if h < 8.0:
		return "water"
	if h < 12.0:
		return "wood"
	if h < 13.0:
		return "eat"
	if h < 14.0:
		return "water"
	if h < 18.83:
		return "wood"
	if h < 19.67:
		return "lamp"
	return "evening"

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
	# going in: up to the step, and in at the door (the door leaf is shut geometry)
	if to.distance_to(_spots["door_in"][0]) < 0.1:
		to = _spots["door"][0]
	var wd: Vector3 = _spots["wood"][0]
	var here := global_position
	if (Vector2(here.x - wd.x, here.z - wd.z).length() < 1.0) != (to.distance_to(wd) < 1.0):
		path.append(_spots["round"][0])
	path.append(to)
	state = WALK
	stuck_t = 0.0

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var h := _hour()
	var want := _activity_for(h)
	var raining := weather != null and weather.rain > RAIN_IN
	if raining and want != "in" and want != "lamp":
		want = "shelter"
	elif activity == "shelter" and weather != null and weather.rain > RAIN_IN * 0.5 and want != "lamp":
		want = "shelter"
	if want == "wake" or want == "water":
		if h < 13.0:
			lantern_lit = false
	if want != activity:
		_begin(want)
	_update_notice()
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
			var sp := HURRY_SPEED if activity == "shelter" else WALK_SPEED
			v = d.normalized() * sp
			goal_yaw = atan2(d.x, d.z)
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
	_update_light(delta)
	_pose()
	_update_animation(delta)
	var pg = player.get("garb") if player != null else null
	if garb.fill != null and pg != null and pg.fill != null:
		garb.fill.light_energy = pg.fill.light_energy
		garb.fill.light_color = pg.fill.light_color

func _begin(a: String) -> void:
	activity = a
	_light_t = -1.0
	var to: Vector3 = _spots[_spot_name(a)][0]
	if a == "in" or a == "shelter":
		if state == IN:
			return
	_route(to)

func _arrive() -> void:
	state = STAND
	visits[activity] = visits.get(activity, 0) + 1
	goal_yaw = _spots[_spot_name(activity)][1]
	if activity == "in" or activity == "shelter":
		state = IN
		goings_in += 1
		_show(false)
	elif activity == "eat" or activity == "evening":
		state = SIT
	elif activity == "lamp":
		_light_t = 0.0 if not lantern_lit else -1.0
	_stoop_t = _rng.randf_range(1.0, 2.5)

## Stops and turns to the hero when he comes close (not while sat or mid-stoop).
func _update_notice() -> void:
	noticing = false
	if player == null or state == IN or stoop > 0.1 or reach > 0.1 or state == SIT:
		return
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() < NOTICE:
		noticing = true
		goal_yaw = atan2(d.x, d.z)

## At the butt and the woodpile: bend down, hold, straighten, a pause, again.
func _update_work(delta: float) -> void:
	var working := state == STAND and (activity == "water" or activity == "wood") and not noticing
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
	else:
		stoops += 1
		_stoop_t = _rng.randf_range(2.5, 5.0) if activity == "wood" else _rng.randf_range(4.0, 8.0)

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
	crumple.flick = r
	crumple.flick_arm = 2.75
	crumple.flick_elbow = 0.35
	# bent knees lower the hips; sat, the hips come down onto the seat
	var bob := _hip_h * (1.0 - cos(0.75 * p * 0.5)) * 0.5 + 0.06 * p
	var down := lerpf(bob, _hip_h - SEAT_H - 0.05, s)
	model.transform = _model_rest.translated(Vector3.DOWN * down)

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
