class_name HollowSoldier
extends CharacterBody3D
## Hollow Soldier, spear variant: a body of cracked ash-stone with an ember burning in the
## chest. Stands its ground until the hero comes near, then stalks in with the spear levelled
## and thrusts. Every thrust is telegraphed: the soldier draws the spear back and leans away,
## the chest ember flares and a glint runs to the blade point; then a fast lunging thrust
## (perfect-dodge it on the glint), then a long recovery — the punish window.
## Second move, the sweep: when the hero crowds inside the spear point (or after two thrusts in
## a row) it slides its grip back, winds the spear low round to its right with the chest turned
## away, then cuts a wide flat arc right-to-left with a long stride. Strafing does not escape
## it; a dodge on the glint, a parry or an early backstep does.
## Implements the staff's hittable contract (hurt_capsule / take_hit) and strikes through
## Player.receive_attack. Poise: during the wind-up and thrust only a poise break staggers it.

enum { IDLE, STALK, WINDUP, STRIKE, RECOVER, STAGGER, DEAD }
enum { THRUST_MOVE, SWEEP_MOVE }

const HEALTH_MAX := 90.0
const NOTICE := 12.0
const GIVE_UP := 22.0
const ENGAGE := 2.7            # starts the wind-up inside this distance
const REACH := 3.1             # thrust connects within this (body-space forward)
const STALK_SPEED := 2.1
const WINDUP_T := 0.78
const STRIKE_T := 0.24
const STRIKE_AT := 0.35        # normalised strike time the blow resolves
const RECOVER_T := 0.95
const STAGGER_T := 0.5
const PARRIED_T := 1.3         # knocked off balance by a deflect: the big punish window
const LUNGE := 1.1             # metres the thrust carries the body
const DAMAGE := 22.0
const POISE := 30.0
const DMG_PER_POWER := 13.0
const GRAVITY := 22.0
const SWEEP_CLOSE := 2.1      # closer than this the point is useless: sweep instead
const SWEEP_WINDUP_T := 0.95
const SWEEP_T := 0.36
const SWEEP_RECOVER_T := 1.15
const SWEEP_FROM := -115.0     # arc start (soldier's right, behind) and end (left), degrees
const SWEEP_TO := 95.0
const SWEEP_REACH := 2.6       # hero centre within this of the soldier when the blade passes
const SWEEP_STEP := 1.3        # metres the cut's stride carries the body
const SWEEP_DAMAGE := 26.0
const SWEEP_SLIDE := -0.22     # grip slid toward the butt for the long cut
const SWEEP_ARM := 0.6
const HAND_R := -0.78          # metres from the spear centre toward the butt
const HAND_L := -0.36
const SHOULDER := Vector3(0.21, 1.48, -0.06)
const ARM_REACH := 0.45

# spear poses in body space (+Z forward, +X the soldier's left): [yaw°, pitch°, centre, twist°]
const GUARD := [16.0, 4.0, Vector3(0.10, 1.12, 0.80), 6.0]
const DRAWN := [6.0, 9.0, Vector3(-0.05, 1.24, 0.30), -32.0]
const THRUST := [2.0, 1.0, Vector3(0.02, 1.20, 1.15), 22.0]

signal struck(result: String)
signal died

var state := IDLE
var move_kind := THRUST_MOVE
var force_move := -1           # bots/shots: pin the next attack (-1 = choose)
var sweeps := 0
var _thrusts_in_row := 0
var _arc_prev := 0.0
var t := 0.0
var health := HEALTH_MAX
var poise := 0.0
var parried_count := 0
var _stagger_len := STAGGER_T
var _recoil := 1.0
var impact_kind := "stone"
var windups := 0
var strikes := 0
var staggers := 0
var hits_taken := 0
var last_result := ""
var max_ember := 0.0
var _freeze := 0.0
var _flash := 0.0
var _resolved := false
var _aimed := false
var _knock := Vector3.ZERO
var _player: Player
var _home := Vector3.ZERO
var _blend := 0.0
var _pose: Array = GUARD
var _from: Array = GUARD

var body: Node3D
var model: Node3D
var spear: HollowSpear
var anim_tree: AnimationTree
var skel: Skeleton3D
var _model_rest: Transform3D
var _mats: Array[ShaderMaterial] = []
var soak: Soak
var _wield: Node3D
var _grip_r: Node3D
var _grip_l: Node3D
var _ik: TwoBoneIK3D
var _twist: SpineTwist
var _ember_light: OmniLight3D
var _glint: MeshInstance3D
var _ash: CPUParticles3D
var rags: HollowRags

func _ready() -> void:
	add_to_group("hittable")
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = 0.9
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.85
	col.shape = cap
	col.position.y = 0.925
	add_child(col)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	model = (preload("res://player/models/vanguard.glb") as PackedScene).instantiate()
	model.name = "Model"
	model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	# a touch taller and broader than the hero: heavier, slower, reads as a threat at range
	model.scale = Vector3(1.06, 1.08, 1.06)
	body.add_child(model)
	_model_rest = model.transform
	_skin()
	_setup_animation()
	_setup_spear()
	# grey hemp rags over the old armour; they flare and burn away with the skin
	rags = HollowRags.new()
	rags.name = "Rags"
	add_child(rags)
	rags.build(skel, body)
	_mats.append_array(rags.mats)
	soak = Soak.new()          # the rain darkens the ash skin, rags and spear shaft
	soak.name = "Soak"
	add_child(soak)
	_ember_light = OmniLight3D.new()
	_ember_light.light_color = Color(1.0, 0.45, 0.15)
	_ember_light.omni_range = 2.6
	_ember_light.light_energy = 0.5
	_ember_light.position = Vector3(0, 1.25, 0.55)
	# the ember lights the ground, the spear and whoever stands in front, not its own skin
	_ember_light.light_cull_mask = 0xFFFFF & ~2
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 2
	body.add_child(_ember_light)
	_home = global_position

func plant(terrain: Terrain) -> void:
	var p := global_position
	global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.05, p.z)
	_home = global_position

## The hero died and woke at a rest point: a living soldier is back at its post at full
## health, at ease, as if the fight never happened.
func return_to_post() -> void:
	if state == DEAD:
		return
	global_position = _home
	velocity = Vector3.ZERO
	health = HEALTH_MAX
	poise = 0.0
	_pose = GUARD
	_update_glint(0.0)
	_enter(IDLE)

func face(point: Vector3) -> void:
	var d := point - global_position
	body.rotation.y = atan2(d.x, d.z)

# --- look ---

func _skin() -> void:
	var shader := preload("res://shaders/hollow.gdshader")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s) as BaseMaterial3D
			var mat := ShaderMaterial.new()
			mat.shader = shader
			if src != null:
				mat.set_shader_parameter("albedo_tex", src.albedo_texture)
				mat.set_shader_parameter("normal_tex", src.normal_texture)
			m.set_surface_override_material(s, mat)
			_mats.append(mat)

func _set_skin(param: String, v: Variant) -> void:
	for m in _mats:
		m.set_shader_parameter(param, v)

func _setup_animation() -> void:
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if ap == null:
		return
	for a in ["Idle", "Walk", "Run"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var space := AnimationNodeBlendSpace1D.new()
	space.max_space = Player.ANIM_RUN_SPEED
	for pt in [["Idle", 0.0], ["Walk", Player.ANIM_WALK_SPEED], ["Run", Player.ANIM_RUN_SPEED]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = pt[0]
		space.add_blend_point(clip, pt[1])
	var root := AnimationNodeBlendTree.new()
	root.add_node("move", space, Vector2(0, 0))
	root.add_node("speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	root.connect_node("speed", 0, "move")
	root.connect_node("output", 0, "speed")
	anim_tree = AnimationTree.new()
	model.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(ap)
	anim_tree.tree_root = root
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true

## Spear in a body-space Wield node; both hands IK onto its grips, the chest twists with it.
func _setup_spear() -> void:
	_wield = Node3D.new()
	_wield.name = "Wield"
	body.add_child(_wield)
	spear = HollowSpear.new()
	spear.name = "Spear"
	_wield.add_child(spear)
	_grip_r = Node3D.new()
	_grip_l = Node3D.new()
	var pole_r := Node3D.new()
	var pole_l := Node3D.new()
	pole_r.position = Vector3(-0.8, 0.6, -0.4)
	pole_l.position = Vector3(0.8, 0.7, -0.2)
	for n in [_grip_r, _grip_l, pole_r, pole_l]:
		_wield.add_child(n)
	if skel == null:
		return
	_twist = SpineTwist.new()
	skel.add_child(_twist)
	_twist.up = body
	_ik = TwoBoneIK3D.new()
	skel.add_child(_ik)
	_ik.setting_count = 2
	var arms := [["Right", _grip_r, pole_r], ["Left", _grip_l, pole_l]]
	for i in 2:
		var side: String = arms[i][0]
		_ik.set_root_bone_name(i, "mixamorig_%sArm" % side)
		_ik.set_middle_bone_name(i, "mixamorig_%sForeArm" % side)
		_ik.set_end_bone_name(i, "mixamorig_%sHand" % side)
		_ik.set_target_node(i, _ik.get_path_to(arms[i][1]))
		_ik.set_pole_node(i, _ik.get_path_to(arms[i][2]))
	_ik.influence = 1.0
	_twist.influence = 1.0
	_place(GUARD)

func _place(pose: Array) -> void:
	var d := StaffCombat.dir_of(pose[0], pose[1])
	var c: Vector3 = pose[2]
	var tw := deg_to_rad(pose[3])
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var sr := Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z).rotated(Vector3.UP, tw)
	var slide: float = pose[4] if pose.size() > 4 else 0.0
	var reach: float = pose[5] if pose.size() > 5 else ARM_REACH
	var hr := sr + (c + d * (HAND_R + slide) - sr).limit_length(reach)
	var hl := sl + (c + d * (HAND_L + slide) - sl).limit_length(reach)
	var axis := hl - hr
	if axis.length() < 0.15:
		axis = d * 0.15
	var d2 := axis.normalized()
	spear.transform = Transform3D(Basis(Quaternion(Vector3.UP, d2)), hr - d2 * (HAND_R + slide))
	_grip_r.position = hr
	_grip_l.position = hl
	if _twist != null:
		_twist.twist = tw

static func _lerp_pose(a: Array, b: Array, f: float) -> Array:
	f = f * f * (3.0 - 2.0 * f)
	var sa: float = a[4] if a.size() > 4 else 0.0
	var sb: float = b[4] if b.size() > 4 else 0.0
	var ra: float = a[5] if a.size() > 5 else ARM_REACH
	var rb: float = b[5] if b.size() > 5 else ARM_REACH
	return [lerpf(a[0], b[0], f), lerpf(a[1], b[1], f), (a[2] as Vector3).lerp(b[2], f), lerpf(a[3], b[3], f), lerpf(sa, sb, f), lerpf(ra, rb, f)]

## The sweep's spear pose for blade bearing a (degrees, + = soldier's left): the butt hand
## stays planted at the belly as the pivot, the front hand swings out with the blade, the
## chest turns a third of the way with it. Tuned offline for <11 deg axis error at 0.6 m reach.
static func sweep_pose(a: float) -> Array:
	var mid := Vector3(0, 1.25, 0.2) + StaffCombat.dir_of(a, 0.0) * 0.2
	var d := StaffCombat.dir_of(a, -4.0)
	var c := mid - d * ((HAND_R + HAND_L) * 0.5 + SWEEP_SLIDE)
	return [a, -4.0, c, a * 0.3, SWEEP_SLIDE, SWEEP_ARM]

## Lean the whole model from the hips (back = negative), pivoting so the feet stay put.
func _lean(rad: float, sink: float) -> void:
	var hip := Vector3(0, 0.95, 0)
	var tr := Transform3D(Basis(Vector3.RIGHT, rad), Vector3.ZERO)
	tr = Transform3D(Basis(), hip) * tr * Transform3D(Basis(), -hip)
	model.transform = Transform3D(Basis(), Vector3(0, -sink, 0)) * tr * _model_rest

# --- hittable contract ---

func hurt_capsule() -> Array:
	return [global_position + Vector3.UP * 0.3, global_position + Vector3.UP * 1.65, 0.34]

func take_hit(_point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	hits_taken += 1
	_freeze = hitstop
	health -= DMG_PER_POWER * power
	poise += DMG_PER_POWER * power
	_flash = 1.0
	_set_skin("hit_flash", _flash)
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 1e-3:
		d = -body.global_basis.z
	if health <= 0.0:
		_die(d.normalized())
		return
	var armoured := (state == WINDUP and t > WINDUP_T * 0.35) or state == STRIKE
	if not armoured or poise >= POISE:
		poise = 0.0
		staggers += 1
		_knock = d.normalized() * (1.6 + 1.4 * power)
		_from = _pose
		_stagger_len = STAGGER_T
		_recoil = 1.0
		state = STAGGER
		t = 0.0

## The hero's heavy deflected the thrust: the spear is batted aside, the soldier reels back
## and stays open for PARRIED_T, whatever its poise.
func parried(dir: Vector3, hitstop: float) -> void:
	if state == DEAD:
		return
	parried_count += 1
	staggers += 1
	poise = 0.0
	_freeze = hitstop
	_flash = 0.6
	_set_skin("hit_flash", _flash)
	_update_glint(0.0)
	_knock = Vector3(dir.x, 0, dir.z).normalized() * 1.5
	_from = _pose
	_stagger_len = PARRIED_T
	_recoil = 1.8
	state = STAGGER
	t = 0.0

# --- brain ---

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_parent().get_node_or_null("Player") as Player
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_set_skin("hit_flash", _flash)
	if _freeze > 0.0:
		_freeze -= delta
		if anim_tree:
			anim_tree.set("parameters/speed/scale", 0.0)
		return
	t += delta
	poise = maxf(poise - 8.0 * delta, 0.0)
	var to := Vector3.ZERO
	var dist := INF
	if _player != null:
		to = _player.global_position - global_position
		to.y = 0.0
		dist = to.length()
		if _player.is_dead():
			dist = INF                         # a fallen hero is no longer a threat: back to its post
	var move := Vector3.ZERO
	var ember := 1.0
	var lean := 0.0
	var sink := 0.0
	match state:
		IDLE:
			_pose = GUARD
			ember = 0.8 + 0.2 * sin(t * 1.7)
			var back := _home - global_position
			back.y = 0.0
			if back.length() > 0.6:
				move = back.normalized() * STALK_SPEED * 0.7
				_turn_to(back, delta, 4.0)
			if dist < NOTICE:
				_enter(STALK)
		STALK:
			_pose = GUARD
			ember = 1.0 + 0.15 * sin(t * 4.0)
			_turn_to(to, delta, 5.0)
			if dist > GIVE_UP or (global_position - _home).length() > GIVE_UP:
				_enter(IDLE)
			elif dist > ENGAGE:
				# close in, slowing as the gap shrinks so it does not overrun
				move = to.normalized() * STALK_SPEED * clampf((dist - ENGAGE) / 1.5 + 0.35, 0.35, 1.0)
			elif t > 0.25 and _facing(to) > 0.85:
				windups += 1
				_from = _pose
				move_kind = _choose(dist)
				_enter(WINDUP)
		WINDUP when move_kind == SWEEP_MOVE:
			var u := clampf(t / SWEEP_WINDUP_T, 0.0, 1.0)
			# the coiled sweep keeps tracking almost to the release: it is built to catch a strafe
			_turn_to(to, delta, 6.0 * (1.0 - u * u * u))
			# swing round low to the right, chest turned away, then a held, trembling coil
			var a := lerpf(GUARD[0], SWEEP_FROM, smoothstep(0.0, 0.62, u)) + sin(t * 47.0) * 1.5 * smoothstep(0.6, 0.9, u)
			_pose = _lerp_pose(_from, sweep_pose(a), minf(u * 4.0, 1.0))
			lean = -0.06 * smoothstep(0.0, 0.6, u)
			sink = 0.14 * smoothstep(0.0, 0.6, u)
			ember = 1.0 + 3.2 * smoothstep(0.15, 0.85, u)
			_update_glint(smoothstep(0.55, 0.8, u) * (1.0 - smoothstep(0.92, 1.0, u)))
			if u >= 1.0:
				_resolved = false
				_aimed = _in_arc()
				_arc_prev = _blade_bearing()
				sweeps += 1
				strikes += 1
				_enter(STRIKE)
		STRIKE when move_kind == SWEEP_MOVE:
			var u := clampf(t / SWEEP_T, 0.0, 1.0)
			_update_glint(0.0)
			var a := lerpf(SWEEP_FROM, SWEEP_TO, 1.0 - (1.0 - u) * (1.0 - u))
			_pose = sweep_pose(a)
			lean = 0.1 * smoothstep(0.0, 0.5, u)
			sink = 0.14
			ember = 4.2 - 1.5 * u
			# the stride closes the gap but stops short of walking into the hero
			move = body.global_basis.z * (SWEEP_STEP / SWEEP_T) * 2.0 * (1.0 - u) * clampf((dist - 1.15) / 0.5, 0.0, 1.0)
			if u >= 1.0:
				if not _resolved:
					_resolved = true
					last_result = "miss"
					struck.emit("miss")
				_from = _pose
				_enter(RECOVER)
		RECOVER when move_kind == SWEEP_MOVE:
			var u := clampf(t / SWEEP_RECOVER_T, 0.0, 1.0)
			var f := smoothstep(0.35, 1.0, u)
			_pose = _lerp_pose(sweep_pose(lerpf(SWEEP_TO, GUARD[0], f)), GUARD, f)
			lean = 0.1 * (1.0 - smoothstep(0.2, 0.9, u))
			sink = 0.14 * (1.0 - u)
			ember = 1.4 - 0.4 * u
			if u >= 1.0:
				_enter(STALK)
		WINDUP:
			var u := clampf(t / WINDUP_T, 0.0, 1.0)
			_turn_to(to, delta, 3.0 * (1.0 - u))   # tracks early, commits late
			_pose = _lerp_pose(GUARD, DRAWN, minf(u * 1.6, 1.0))
			lean = -0.13 * smoothstep(0.0, 0.6, u)
			sink = 0.07 * smoothstep(0.0, 0.6, u)
			ember = 1.0 + 3.2 * smoothstep(0.15, 0.85, u)
			_update_glint(smoothstep(0.55, 0.8, u) * (1.0 - smoothstep(0.92, 1.0, u)))
			if u >= 1.0:
				_resolved = false
				_aimed = _in_cone()
				strikes += 1
				_thrusts_in_row += 1
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / STRIKE_T, 0.0, 1.0)
			_update_glint(0.0)
			_pose = _lerp_pose(DRAWN, THRUST, minf(u * 2.2, 1.0))
			lean = 0.16 * smoothstep(0.0, 0.4, u)
			sink = 0.09
			ember = 4.2 - 1.5 * u
			# speed falls off linearly; integrates to LUNGE over the thrust
			move = body.global_basis.z * (LUNGE / STRIKE_T) * 2.0 * (1.0 - u)
			if not _resolved and u >= STRIKE_AT:
				_resolved = true
				_resolve_strike()
			if u >= 1.0:
				_from = _pose
				_enter(RECOVER)
		RECOVER:
			var u := clampf(t / RECOVER_T, 0.0, 1.0)
			_pose = _lerp_pose(THRUST, GUARD, smoothstep(0.35, 1.0, u))
			lean = 0.16 * (1.0 - smoothstep(0.2, 0.9, u))
			sink = 0.09 * (1.0 - u)
			ember = 1.4 - 0.4 * u
			if u >= 1.0:
				_enter(STALK)
		STAGGER:
			var u := clampf(t / _stagger_len, 0.0, 1.0)
			_update_glint(0.0)
			_pose = _lerp_pose(_from, [30.0, -18.0, Vector3(0.15, 1.0, 0.55), 18.0], minf(u * 3.0, 1.0)) if u < 0.5 else _lerp_pose([30.0, -18.0, Vector3(0.15, 1.0, 0.55), 18.0], GUARD, (u - 0.5) * 2.0)
			lean = -0.22 * _recoil * sin(PI * minf(u * 1.4, 1.0))
			sink = 0.05
			move = _knock * (1.0 - u) * (1.0 - u) * 2.2
			ember = 1.6
			if u >= 1.0:
				_enter(STALK)
		DEAD:
			_die_tick(delta)
			return
	_place(_pose)
	if state == STRIKE and move_kind == SWEEP_MOVE and not _resolved:
		_sweep_contact()
	_lean(lean, sink)
	max_ember = maxf(max_ember, ember)
	_set_skin("ember", ember)
	_set_skin("root_pos", global_position)
	_set_skin("root_fwd", body.global_basis.z)
	_ember_light.light_energy = 0.3 * ember
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if anim_tree:
		var hs := Vector2(velocity.x, velocity.z).length()
		if state == STRIKE or state == STAGGER:
			hs = minf(hs, 0.8)      # the lunge is a planted thrust, not a run
		_blend = lerpf(_blend, minf(hs, Player.ANIM_RUN_SPEED), 1.0 - exp(-8.0 * delta))
		anim_tree.set("parameters/move/blend_position", _blend)
		anim_tree.set("parameters/speed/scale", clampf(hs / Player.ANIM_WALK_SPEED, 0.7, 1.4) if hs > 0.2 else 1.0)

func _enter(s: int) -> void:
	state = s
	t = 0.0

func _facing(to: Vector3) -> float:
	if to.length() < 1e-3:
		return 1.0
	return body.global_basis.z.dot(to.normalized())

func _turn_to(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 1e-3 or rate <= 0.0:
		return
	body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))

func _in_cone() -> bool:
	if _player == null:
		return false
	var l := body.global_transform.affine_inverse() * _player.global_position
	return l.z > 0.0 and l.z < REACH + 0.4 and absf(l.x) < 0.75 and absf(l.y) < 1.2

## Thrust when the hero stands off at spear length; sweep when they crowd inside the point
## or after two thrusts in a row (so the soldier can't be read by distance alone).
func _choose(dist: float) -> int:
	var k := force_move
	if k < 0:
		k = SWEEP_MOVE if dist < SWEEP_CLOSE or _thrusts_in_row >= 2 else THRUST_MOVE
	if k == SWEEP_MOVE:
		_thrusts_in_row = 0
	return k

func _hero_local() -> Vector3:
	return body.global_transform.affine_inverse() * _player.global_position

## Bearing (degrees, + = soldier's left) of the blade, from the spear as actually placed.
func _blade_bearing() -> float:
	var tip := body.global_transform.affine_inverse() * spear.to_global(spear.tip_local())
	return rad_to_deg(atan2(tip.x, tip.z))

func _in_arc() -> bool:
	if _player == null:
		return false
	var l := _hero_local()
	var b := rad_to_deg(atan2(l.x, l.z))
	return Vector2(l.x, l.z).length() < SWEEP_REACH + 0.4 and b > SWEEP_FROM and b < SWEEP_TO and absf(l.y) < 1.2

## The cut lands when the blade's bearing passes the hero's and the hero is inside its reach;
## a hero who was in the arc as it launched and is mid-dodge gets the dodge verdict instead.
func _sweep_contact() -> void:
	if _player == null:
		return
	var now := _blade_bearing()
	var l := _hero_local()
	var b := rad_to_deg(atan2(l.x, l.z))
	# the blade has reached or swept past the hero's bearing (the hero may move against it)
	var passed := b > SWEEP_FROM - 10.0 and b <= now
	_arc_prev = now
	if not passed:
		return
	var in_reach := Vector2(l.x, l.z).length() < SWEEP_REACH and absf(l.y) < 1.2
	var dodging := _player.dodge_t >= 0.0 and _player.dodge_t <= Player.DODGE_TIME
	if not in_reach and not (_aimed and dodging):
		return
	_resolved = true
	var r := _player.receive_attack(self, SWEEP_DAMAGE)
	if r == "hit":
		var side := body.global_basis.x
		ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 1.0, side, "stone", 0.8)
	last_result = r
	struck.emit(r)

## The thrust lands on anything standing in a narrow cone ahead within reach.
func _resolve_strike() -> void:
	if _player == null:
		return
	var r := "miss"
	# a hero who was in the thrust's line as it launched is "caught" even if a dodge has
	# already carried them out of it: receive_attack decides perfect / dodged / hit
	if _aimed or _in_cone():
		r = _player.receive_attack(self, DAMAGE)
		if r == "hit":
			ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 1.15, body.global_basis.z, "stone", 0.7)
	last_result = r
	struck.emit(r)

# --- the glint: a hard star of light that runs up the blade before the thrust ---

func _update_glint(a: float) -> void:
	if _glint == null:
		if a <= 0.0:
			return
		_glint = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.55, 0.55)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = false
		m.albedo_texture = _star_texture()
		m.albedo_color = Color(1.0, 0.8, 0.55)
		q.material = m
		_glint.mesh = q
		_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spear.add_child(_glint)
	_glint.visible = a > 0.01
	var along := HollowSpear.LENGTH * 0.5 - HollowSpear.BLADE * (1.0 - a) * 0.6 - 0.04
	_glint.position = Vector3(0, along, 0)
	_glint.scale = Vector3.ONE * (0.4 + 0.9 * a)
	((_glint.mesh as QuadMesh).material as StandardMaterial3D).albedo_color = Color(1.0, 0.82, 0.6, a)

static var _star: ImageTexture

static func _star_texture() -> ImageTexture:
	if _star != null:
		return _star
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var core := exp(-p.length_squared() * 40.0)
			var rays := exp(-absf(p.x) * 60.0) * exp(-absf(p.y) * 3.5) + exp(-absf(p.y) * 60.0) * exp(-absf(p.x) * 3.5)
			var v := clampf(core + rays * 0.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	_star = ImageTexture.create_from_image(img)
	return _star

# --- death: the ember gutters, the body folds forward and crumbles into ash ---

var _fall_dir := Vector3.ZERO
var _spear_rest := Basis()

func _die(dir: Vector3) -> void:
	state = DEAD
	t = 0.0
	_fall_dir = dir
	remove_from_group("hittable")
	collision_layer = 0
	_update_glint(0.0)
	_ash = CPUParticles3D.new()
	_ash.amount = 160
	_ash.lifetime = 2.6
	_ash.explosiveness = 0.15
	_ash.local_coords = false
	_ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ash.emission_box_extents = Vector3(0.3, 0.8, 0.25)
	_ash.position = Vector3(0, 0.9, 0)
	_ash.direction = Vector3(0, 1, 0)
	_ash.spread = 60.0
	_ash.initial_velocity_min = 0.3
	_ash.initial_velocity_max = 1.2
	_ash.gravity = Vector3(dir.x * 0.6, 0.35, dir.z * 0.6)
	_ash.damping_min = 0.5
	_ash.damping_max = 1.2
	_ash.angular_velocity_min = -300.0
	_ash.angular_velocity_max = 300.0
	_ash.scale_amount_min = 0.4
	_ash.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true       # the ash ramp is authored in sRGB
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.08)
	m.emission_energy_multiplier = 0.6
	q.material = m
	_ash.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.45, 0.2, 1.0))
	g.set_color(1, Color(0.25, 0.24, 0.23, 0.0))
	g.add_point(0.25, Color(0.35, 0.33, 0.31, 0.9))
	_ash.color_ramp = g
	body.add_child(_ash)
	_ash.emitting = true
	died.emit()

func _die_tick(delta: float) -> void:
	var u := clampf(t / 2.4, 0.0, 1.0)
	# knees give: sink and pitch forward along the killing blow, spear slips from the hands
	var f := smoothstep(0.0, 0.45, u)
	var local_dir := body.global_basis.inverse() * _fall_dir
	var pitch := 0.9 * f * signf(local_dir.z + 0.001)
	_lean(pitch, 0.55 * f)
	_ik.influence = maxf(1.0 - f * 2.0, 0.0)
	_twist.influence = _ik.influence
	if spear.get_parent() == _wield and u > 0.1:
		spear.reparent(get_parent(), true)
		var flat := Vector3(spear.global_basis.y.x, 0, spear.global_basis.y.z)
		if flat.length() < 0.1:
			flat = _fall_dir
		_spear_rest = Basis(Quaternion(Vector3.UP, flat.normalized()))
	if spear.get_parent() != _wield:
		# the spear topples flat onto the ground
		var ground := global_position.y + 0.025
		spear.global_position.y = maxf(spear.global_position.y - delta * 3.0, ground)
		spear.global_basis = spear.global_basis.slerp(_spear_rest, minf(delta * 5.0, 1.0))
	_set_skin("ember", 1.6 * (1.0 - u))
	_set_skin("dissolve", smoothstep(0.35, 1.0, u) * 1.02)
	_ember_light.light_energy = 0.6 * (1.0 - u)
	if anim_tree:
		anim_tree.set("parameters/speed/scale", maxf(1.0 - u * 3.0, 0.0))
	if u >= 1.0 and _ash.emitting:
		_ash.emitting = false
	if t > 5.0:
		queue_free()

func is_dead() -> bool:
	return state == DEAD
