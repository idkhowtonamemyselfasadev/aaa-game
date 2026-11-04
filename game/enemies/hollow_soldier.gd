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
const STRIDE_BUILD := 1.06     # the model's scale along the stride (model.scale.z) against the hero's 1.0
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
const KINDLE_TEMPO := 1.3      # a Kindler's flame: winds up and strikes this much faster
const KINDLE_DMG := 1.25       # ... and hits this much harder
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
var sweep_reach := SWEEP_REACH   # hero centre within this when the blade passes (a shorter weapon cuts less)
var _thrusts_in_row := 0
var _arc_prev := 0.0
var t := 0.0
var health := HEALTH_MAX
## Tuning a heavier Hollow (the Ashen Knight) changes these instead of the consts above.
var health_max := HEALTH_MAX
var poise_max := POISE
var tempo := 1.0               # time scale of the whole brain: a faster phase winds up sooner
var damage_mul := 1.0
var unblockable := false       # strikes the hero's heavy cannot deflect
var glint_col := Color(1.0, 0.82, 0.6)
var kindled := 0.0             # s left burning from a Kindler's chant (faster, harder, white-hot)
var kindle_count := 0          # bots: times it was kindled
var _kindle_boost := false     # damage_mul carries the kindle factor
var _kindle_glow := 0.0        # 0..1 eased in and out
var _kindle_sparks: CPUParticles3D
## Variants (the shield warden) hold a different guard while idle/stalking and can kick the
## body back from the hips (a blocked blow); both default to the soldier's.
var guard_pose: Array = GUARD
var lean_kick := 0.0
var notice := NOTICE           # wakes when the hero comes this near (an archer sees farther)
var give_up := GIVE_UP
var engage_delay := 0.25      # s inside ENGAGE before it winds up (a warden holds its ward longer)
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
var _chest_bone := -1
var _chest_fwd := Vector3.FORWARD
var _model_rest: Transform3D
var _mats: Array[ShaderMaterial] = []
var soak: Soak
var _wield: Node3D
var _grip_r: Node3D
var _grip_l: Node3D
var _ik: TwoBoneIK3D
var _twist: SpineTwist
var _lead_twist: SpineTwist            # head and chest lead a turn: yawed toward where the body is turning
var turn_lead := 0.0             # radians of that lead (head ~ all of it, chest ~ a third)
var lead_peak := 0.0             # bots: largest |turn_lead| since reset
var _turn_gap := 0.0             # yaw still to turn this tick (set by _turn_to in IDLE/STALK)
var _ember_light: OmniLight3D
var _glint: MeshInstance3D
var _ash: CPUParticles3D
var rags: HollowRags
## Uniform size of the whole body (1 = a soldier). A boss grows by raising it: the model,
## glaive, collision capsule, hurt capsule, reach, stride and ember light all scale with it.
## Reach checks are made in the body's own (scaled) frame, so they grow on their own.
var size_scale := 1.0
## Bots: a world velocity that overrides the brain's footwork (the gait is measured with it).
var bot_move := Vector3.ZERO
var bot_cadence_k := 1.0
var bot_face := Vector3.ZERO     # bots: IDLE turns on the spot toward this (world dir) when set
var turn_shuffle := 0.0          # 0..1 stepping round on the spot while the body turns
var shuffle_peak := 0.0          # bots: highest turn_shuffle since reset
var _prev_yaw := 0.0
var _col_cap: CapsuleShape3D
var _col: CollisionShape3D
var _ember_range := 2.6

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
	_col = col
	_col_cap = cap
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
	_cut_rags(rags)
	add_child(rags)
	rags.build(skel, body)
	rags.set_param("hemp", 1.0)  # coarse sacking: drape folds, slubs, darns (rag.gdshader)
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

## Sets the body's size (see size_scale). Called every frame while a boss grows.
func set_size_scale(s: float) -> void:
	size_scale = s
	if body != null:
		body.scale = Vector3.ONE * s
	if _col_cap != null:
		_col_cap.radius = 0.36 * s
		_col_cap.height = 1.85 * s
		_col.position.y = 0.925 * s
	if _ember_light != null:
		_ember_light.omni_range = _ember_range * s

func plant(terrain: Terrain) -> void:
	var p := global_position
	global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.05, p.z)
	_home = global_position

## The hero died and woke at a rest point: a living soldier is back at its post at full
## health, at ease, as if the fight never happened.
func return_to_post() -> void:
	if state == DEAD:
		return
	douse()
	global_position = _home
	velocity = Vector3.ZERO
	health = health_max
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

## Subclasses change the cut of the rags here, before they are built.
func _cut_rags(_r: HollowRags) -> void:
	pass

## World -> rest-pose map of the chest bone (Spine2), for the skin shader's chest band: a
## point rigid with the chest goes back to where it sits standing at rest, so the band stays
## on the sternum through a crouch or lunge and never lights a head dropped to that height.
func _chest_unpose() -> Projection:
	if skel == null:
		return Projection.IDENTITY
	if _chest_bone < 0:
		_chest_bone = skel.find_bone("mixamorig_Spine2")
		if _chest_bone < 0:
			return Projection.IDENTITY
	var now := skel.global_transform * skel.get_bone_global_pose(_chest_bone)
	# (11-03 19:30) the rest frame is taken through the model's REST transform, not its current
	# one: the crouch's sink and lean live in model.transform, so measuring "rest" through it
	# dropped and tilted the band with the body
	var skel_in_model := model.global_transform.affine_inverse() * skel.global_transform
	var rest := (model.get_parent() as Node3D).global_transform * _model_rest * skel_in_model \
			* skel.get_bone_global_rest(_chest_bone)
	var unpose := rest * now.affine_inverse()
	# the chest's facing as posed: the band only lights skin that faces this way, so points the
	# unpose swings into the band from behind (nape, lower back of a crouch) stay dark
	_chest_fwd = (unpose.basis.inverse() * body.global_basis.z).normalized()
	return Projection(unpose)

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
	# the lead yaws the upper chest, neck and head; it runs before the arm IK so the hands
	# still close on the spear from the turned shoulders
	_lead_twist = SpineTwist.new()
	_lead_twist.name = "TurnLead"
	_lead_twist.up = body
	_lead_twist.bones = LEAD_BONES
	_lead_twist.share = LEAD_SHARE
	skel.add_child(_lead_twist)
	skel.move_child(_lead_twist, _ik.get_index())
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
	var s := size_scale
	return [global_position + Vector3.UP * 0.3 * s, global_position + Vector3.UP * 1.65 * s, 0.34 * s]

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
	if not armoured or poise >= poise_max:
		poise = 0.0
		staggers += 1
		_knock = d.normalized() * (1.6 + 1.4 * power) / sqrt(size_scale)   # a giant barely rocks back
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
	if kindled > 0.0:
		kindled = maxf(kindled - delta, 0.0)
		if kindled <= 0.0:
			douse()
	_kindle_glow = move_toward(_kindle_glow, 1.0 if kindled > 0.0 else 0.0, delta * 2.0)
	t += delta * tempo * (KINDLE_TEMPO if kindled > 0.0 else 1.0)
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
	_turn_gap = 0.0
	var sink := 0.0
	match state:
		IDLE:
			_pose = guard_pose
			ember = 0.8 + 0.2 * sin(t * 1.7)
			var back := _home - global_position
			back.y = 0.0
			if back.length() > 0.6:
				move = back.normalized() * STALK_SPEED * 0.7
				_turn_to(back, delta, 4.0)
			elif bot_face != Vector3.ZERO:
				_turn_to(bot_face, delta, 5.0)
			if dist < notice:
				_enter(STALK)
		STALK:
			_pose = guard_pose
			ember = 1.0 + 0.15 * sin(t * 4.0)
			_turn_to(to, delta, 5.0)
			if dist > give_up or (global_position - _home).length() > give_up:
				_enter(IDLE)
			else:
				move = _stalk(to, dist)

		WINDUP, STRIKE, RECOVER when move_kind > SWEEP_MOVE:
			# a variant's own move (the warden's shield bash): it poses itself and hands back
			# [move, lean, sink, ember]
			var r: Array = _special_tick(delta, to, dist)
			move = r[0]
			lean = r[1]
			sink = r[2]
			ember = r[3]
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
			move = body.global_basis.z * (SWEEP_STEP / SWEEP_T) * 2.0 * (1.0 - u) * clampf((dist - (1.15 + 0.45 * (size_scale - 1.0))) / 0.5, 0.0, 1.0)
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
			_pose = _lerp_pose(sweep_pose(lerpf(SWEEP_TO, GUARD[0], f)), guard_pose, f)
			lean = 0.1 * (1.0 - smoothstep(0.2, 0.9, u))
			sink = 0.14 * (1.0 - u)
			ember = 1.4 - 0.4 * u
			if u >= 1.0:
				_enter(STALK)
		WINDUP:
			var u := clampf(t / WINDUP_T, 0.0, 1.0)
			_turn_to(to, delta, 3.0 * (1.0 - u))   # tracks early, commits late
			_pose = _lerp_pose(guard_pose, DRAWN, minf(u * 1.6, 1.0))
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
			_pose = _lerp_pose(THRUST, guard_pose, smoothstep(0.35, 1.0, u))
			lean = 0.16 * (1.0 - smoothstep(0.2, 0.9, u))
			sink = 0.09 * (1.0 - u)
			ember = 1.4 - 0.4 * u
			if u >= 1.0:
				_enter(STALK)
		STAGGER:
			var u := clampf(t / _stagger_len, 0.0, 1.0)
			_update_glint(0.0)
			_pose = _lerp_pose(_from, [30.0, -18.0, Vector3(0.15, 1.0, 0.55), 18.0], minf(u * 3.0, 1.0)) if u < 0.5 else _lerp_pose([30.0, -18.0, Vector3(0.15, 1.0, 0.55), 18.0], guard_pose, (u - 0.5) * 2.0)
			lean = -0.22 * _recoil * sin(PI * minf(u * 1.4, 1.0))
			sink = 0.05
			move = _knock * (1.0 - u) * (1.0 - u) * 2.2
			ember = 1.6
			if u >= 1.0:
				_enter(STALK)
		DEAD:
			_die_tick(delta)
			return
	if bot_move != Vector3.ZERO:
		move = bot_move
		body.rotation.y = atan2(bot_move.x, bot_move.z)
	_update_turn_lead(delta)
	_place(_pose)
	if state == STRIKE and move_kind == SWEEP_MOVE and not _resolved:
		_sweep_contact()
	lean_kick = move_toward(lean_kick, 0.0, delta * 1.2)
	_lean(lean - lean_kick, sink)
	max_ember = maxf(max_ember, ember)
	ember *= 1.0 + 0.9 * _kindle_glow
	_set_skin("ember", ember)
	_set_skin("root_pos", global_position)
	_set_skin("root_fwd", body.global_basis.z.normalized())
	_set_skin("chest_unpose", _chest_unpose())
	_set_skin("chest_fwd", _chest_fwd)
	_ember_light.light_energy = 0.3 * ember
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if anim_tree:
		# a bigger body covers more ground per stride: the clips play at the scaled speed
		var hs := Vector2(velocity.x, velocity.z).length() / size_scale
		if state == STRIKE or state == STAGGER:
			hs = minf(hs, 0.8)      # the lunge is a planted thrust, not a run
		# a big body's natural cadence is slower (pendulum legs: ~1/sqrt(size)), so below a full
		# walk it keeps that cadence and shortens the stride instead of shuffling quick little steps
		var goal := gait_blend(hs)
		if goal < Player.ANIM_WALK_SPEED:
			goal = minf(hs / (Player.WALK_STRIDE_SPEED * STRIDE_BUILD * natural_cadence()), 1.0) * Player.ANIM_WALK_SPEED
		# turning on the spot: the feet step round (short walk steps at the body's own cadence)
		# instead of the whole figure spinning on two still, sliding soles
		_update_turn_shuffle(delta, hs)
		goal = maxf(goal, turn_shuffle * Player.ANIM_WALK_SPEED * TURN_STEP_REACH)
		_blend = lerpf(_blend, goal, 1.0 - exp(-(14.0 if turn_shuffle > 0.05 else 8.0) * delta))
		anim_tree.set("parameters/move/blend_position", _blend)
		# cadence from the stride the clip mix covers (the hero's calibration, bot `foestride`):
		# the old hs / 1.9 (clamped 0.7-1.4) let the planted foot ride forward up to 4 m/s on the giant
		var ts := clampf(hs / clip_stride_speed(), 0.3, 1.8) * bot_cadence_k if hs > 0.05 else 1.0
		if turn_shuffle > 0.02 and hs * size_scale < TURN_STILL:
			ts = lerpf(ts, TURN_STEP_CADENCE * natural_cadence(), minf(turn_shuffle * 3.0, 1.0))
		anim_tree.set("parameters/speed/scale", ts)

const TURN_STEP_REACH := 0.5     # of the walk's reach: short steps round, not a stride
const TURN_STEP_CADENCE := 1.3   # x the body's natural cadence: quick little steps
const TURN_STILL := 0.3          # m/s (any size): below this a turn is on the spot
const TURN_FROM := 0.8           # rad/s of yaw where the stepping starts
const TURN_FULL := 2.5           # rad/s more for full steps
const TURN_STEP_RATE := 4.0      # rad/s cap of a turn on the spot at 1x cadence

const LEAD_BONES := ["mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head"]
const LEAD_SHARE := [0.12, 0.18, 0.30, 0.40]   # the head turns furthest, the chest a little
const LEAD_K := 0.7              # lead per radian still to turn
const LEAD_MAX := 0.85           # rad (~49 deg at the head, ~15 deg at the chest)
const LEAD_RATE := 12.0          # 1/s at 1x cadence: the eyes go first, quicker than the feet
const LEAD_SETTLE := 6.0         # 1/s back to square once the body has caught up

## The head and chest lead a turn: they swing toward where the body is turning before the
## feet have stepped it round, then settle back square as the body catches up. A big body
## looks round slower (its own cadence), never snapping its head.
func _update_turn_lead(delta: float) -> void:
	var goal := clampf(_turn_gap * LEAD_K, -LEAD_MAX, LEAD_MAX) if state in [IDLE, STALK] else 0.0
	var rate := (LEAD_RATE if absf(goal) > absf(turn_lead) else LEAD_SETTLE) * natural_cadence()
	turn_lead = lerpf(turn_lead, goal, 1.0 - exp(-rate * delta))
	lead_peak = maxf(lead_peak, absf(turn_lead))
	if _lead_twist != null:
		_lead_twist.twist = turn_lead
		_lead_twist.influence = _twist.influence if _twist != null else 1.0

## Standing and turning (IDLE/STALK, not posed by an attack): ramps turn_shuffle from the yaw rate.
func _update_turn_shuffle(delta: float, hs: float) -> void:
	var yaw := body.rotation.y
	var rate := absf(angle_difference(_prev_yaw, yaw)) / maxf(delta, 1e-4)
	_prev_yaw = yaw
	var standing := hs * size_scale < TURN_STILL and is_on_floor() and state in [IDLE, STALK]
	# measured against the body's own cadence: the giant's slow turn is still a full step round
	var sh := clampf((rate / natural_cadence() - TURN_FROM) / TURN_FULL, 0.0, 1.0) if standing else 0.0
	# rises quick (the first step goes as the turn starts), settles over the last step
	turn_shuffle = move_toward(turn_shuffle, sh, delta * (8.0 if sh > turn_shuffle else 2.5))
	shuffle_peak = maxf(shuffle_peak, turn_shuffle)

## Blend position for a ground speed (per unit size): the walk point held up to WALK_TOP, then
## a short band to the run point, so a quick stalk is never an unsynced walk/run mix.
static func gait_blend(v: float) -> float:
	if v <= Player.ANIM_WALK_SPEED:
		return minf(v, Player.ANIM_WALK_SPEED)
	if v <= Player.WALK_TOP:
		return Player.ANIM_WALK_SPEED
	return lerpf(Player.ANIM_WALK_SPEED, Player.ANIM_RUN_SPEED, smoothstep(Player.WALK_TOP, Player.JOG_FROM, v))

## The clip rate a body of this size walks at: a soldier 1x, the phase-3 giant ~0.47x.
func natural_cadence() -> float:
	return 1.0 / sqrt(maxf(size_scale, 1.0))

## m/s (per unit size) the planted foot travels back at 1x cadence for the clip mix as it is now.
## The model stands STRIDE_BUILD x the hero's along the stride.
func clip_stride_speed() -> float:
	var w := clampf((_blend - Player.ANIM_WALK_SPEED) / (Player.ANIM_RUN_SPEED - Player.ANIM_WALK_SPEED), 0.0, 1.0)
	var under := clampf(_blend / Player.ANIM_WALK_SPEED, 0.05, 1.0)   # idle -> walk: the stride shrinks
	return lerpf(Player.WALK_STRIDE_SPEED * under, Player.RUN_STRIDE_SPEED, w) * STRIDE_BUILD

## STALK's footwork once the hero is in range: close in to ENGAGE, then wind up. Variants that
## keep their distance (the archer) override it; returns the move velocity.
func _stalk(to: Vector3, dist: float) -> Vector3:
	var engage := ENGAGE * size_scale
	if dist > engage:
		# close in, slowing as the gap shrinks so it does not overrun; a bigger body strides
		# slower but longer (sqrt: heavier steps, more ground)
		return to.normalized() * STALK_SPEED * sqrt(size_scale) * clampf((dist - engage) / (1.5 * size_scale) + 0.35, 0.35, 1.0)
	if t > engage_delay and _facing(to) > 0.85:
		_begin_attack(dist)
	return Vector3.ZERO

func _begin_attack(dist: float) -> void:
	windups += 1
	_from = _pose
	move_kind = _choose(dist)
	_enter(WINDUP)


## Variants override this to run a move of their own (move_kind > SWEEP_MOVE) through
## WINDUP/STRIKE/RECOVER; it sets _pose and returns [move, lean, sink, ember].
func _special_tick(_delta: float, _to: Vector3, _dist: float) -> Array:
	_enter(STALK)
	return [Vector3.ZERO, 0.0, 0.0, 1.0]

func _enter(s: int) -> void:
	state = s
	t = 0.0

func _facing(to: Vector3) -> float:
	if to.length() < 1e-3:
		return 1.0
	return body.global_basis.z.normalized().dot(to.normalized())

func _turn_to(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 1e-3 or rate <= 0.0:
		return
	var want := lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))
	var hs := Vector2(velocity.x, velocity.z).length()
	if state in [IDLE, STALK]:
		_turn_gap = angle_difference(body.rotation.y, atan2(dir.x, dir.z))
	if state in [IDLE, STALK] and hs < TURN_STILL:
		# on the spot the body only comes round as fast as its feet can step it round: a soldier
		# ~230 deg/s, the phase-3 giant under half that (heavy, but it still keeps a circling hero)
		var cap := TURN_STEP_RATE * natural_cadence() * delta
		want = body.rotation.y + clampf(angle_difference(body.rotation.y, want), -cap, cap)
	body.rotation.y = want

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
		k = SWEEP_MOVE if dist < SWEEP_CLOSE * size_scale or _thrusts_in_row >= 2 else THRUST_MOVE
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
	return Vector2(l.x, l.z).length() < sweep_reach + 0.4 and b > SWEEP_FROM and b < SWEEP_TO and absf(l.y) < 1.2

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
	var in_reach := Vector2(l.x, l.z).length() < sweep_reach and absf(l.y) < 1.2
	var dodging := _player.dodge_t >= 0.0 and _player.dodge_t <= Player.DODGE_TIME
	if not in_reach and not (_aimed and dodging):
		return
	_resolved = true
	var r := _player.receive_attack(self, SWEEP_DAMAGE * damage_mul, true, unblockable)   # the sweep throws the hero down
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
		r = _player.receive_attack(self, DAMAGE * damage_mul, false, unblockable)
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
	((_glint.mesh as QuadMesh).material as StandardMaterial3D).albedo_color = Color(glint_col.r, glint_col.g, glint_col.b, a)

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
var _spear_scale := Vector3.ONE   # the dropped weapon keeps its size (the giant's glaive is scaled up)

func _die(dir: Vector3) -> void:
	douse()
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
		_spear_scale = spear.global_basis.get_scale()
	if spear.get_parent() != _wield:
		# the spear topples flat onto the ground
		var ground := global_position.y + 0.025
		spear.global_position.y = maxf(spear.global_position.y - delta * 3.0, ground)
		var rot := spear.global_basis.orthonormalized().slerp(_spear_rest, minf(delta * 5.0, 1.0))
		spear.global_basis = rot.scaled_local(_spear_scale)
	_set_skin("ember", 1.6 * (1.0 - u))
	_set_skin("dissolve", smoothstep(0.35, 1.0, u) * 1.02)
	_ember_light.light_energy = 0.6 * (1.0 - u)
	if anim_tree:
		anim_tree.set("parameters/speed/scale", maxf(1.0 - u * 3.0, 0.0))
	if u >= 1.0 and _ash.emitting:
		_ash.emitting = false
	if t > 5.0:
		queue_free()

## A Hollow Kindler's chant caught: for `secs` it burns white-hot, sparks streaming off it,
## and winds up KINDLE_TEMPO faster and hits KINDLE_DMG harder.
func kindle(secs: float) -> void:
	if state == DEAD:
		return
	if not _kindle_boost:
		_kindle_boost = true
		damage_mul *= KINDLE_DMG
	kindled = maxf(kindled, secs)
	kindle_count += 1
	if _kindle_sparks == null:
		_kindle_sparks = CPUParticles3D.new()
		_kindle_sparks.name = "KindleSparks"
		_kindle_sparks.amount = 40
		_kindle_sparks.lifetime = 0.9
		_kindle_sparks.local_coords = false
		_kindle_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_kindle_sparks.emission_box_extents = Vector3(0.25, 0.45, 0.2)
		_kindle_sparks.position = Vector3(0, 1.15, 0.05)
		_kindle_sparks.direction = Vector3.UP
		_kindle_sparks.spread = 25.0
		_kindle_sparks.initial_velocity_min = 0.6
		_kindle_sparks.initial_velocity_max = 1.6
		_kindle_sparks.gravity = Vector3(0, 0.8, 0)
		_kindle_sparks.scale_amount_min = 0.4
		_kindle_sparks.scale_amount_max = 1.0
		var q := QuadMesh.new()
		q.size = Vector2(0.035, 0.035)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		q.material = m
		_kindle_sparks.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.85, 0.55, 1.0))
		g.set_color(1, Color(0.8, 0.2, 0.02, 0.0))
		_kindle_sparks.color_ramp = g
		body.add_child(_kindle_sparks)
	_kindle_sparks.emitting = true

## The flame goes out (time up, or the Kindler that lit it died).
func douse() -> void:
	if _kindle_boost:
		_kindle_boost = false
		damage_mul /= KINDLE_DMG
	kindled = 0.0
	if _kindle_sparks != null:
		_kindle_sparks.emitting = false

func is_dead() -> bool:
	return state == DEAD
