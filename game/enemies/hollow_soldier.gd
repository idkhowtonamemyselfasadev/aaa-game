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
## (11-10 12:00) was [16, 4, (0.10, 1.12, 0.80), 6]: the left grip wanted 0.69 m from its shoulder
## (reach 0.45), so the reach clamp pulled it 0.24 m in and the shaft really lay 35 deg off the
## pose's direction (yaw 41, pitch 30 from the right fist) and every lerp into the guard bent
## through the clamp on its way. Re-solved offline (scratch python replica of `_place`): the same
## right fist, the shaft where the old guard visibly held it (3 deg off), both grips inside their
## reach, axis 0 deg off the pose. GUARD_OLD=1 env: the before.
const GUARD := [43.2, 32.8, Vector3(0.334, 1.488, 0.53), 6.0]
const GUARD_OLD := [16.0, 4.0, Vector3(0.10, 1.12, 0.80), 6.0]
## the sweep's blade bearing at the guard (the old guard's yaw: the cut's arc and timing unchanged)
const SWEEP_HOME := 16.0
const SWEEP_FROM_BLEND := 2.0   # 1 / the share of the sweep wind-up spent turning out of the guard
const DRAWN := [6.0, 9.0, Vector3(-0.05, 1.24, 0.30), -32.0]
## (11-10 14:00) THRUST (the old pose; env THRUST_OLD=1): the front (left) grip wants 0.98 m from its shoulder
## (reach 0.45), the clamp pulls it 0.53 m in and the real shaft at full extension points up and
## across the chest, 102 deg off the line of the thrust (bot `foereach`). THRUST_SOLVED (python
## replica of `_place`): arms out to 0.58, rear fist at the right hip 0.3 m from its shoulder, the
## shaft angled 18 deg across a bladed chest so the blade drives in on the centre line, both grips
## inside reach, axis 0 deg off. LIVE since 18:00 11-10: its one-tick fist slip (the rear forearm
## swinging round the far side of the shaft, a ~166 deg roll wanted) was the lunge's lean folding the
## arm shut, now carried by `_lean_grips`. THRUST_TRY=a,b,x,y,z,tw,sl,r tries a pose.
const THRUST := [2.0, 1.0, Vector3(0.02, 1.20, 1.15), 22.0]
const THRUST_SOLVED := [18.0, 1.0, Vector3(0.02, 1.22, 0.82), -20.0, -0.1, 0.58]
const FOE_PIVOT_SINK := 14.0     # skeleton cm the hips may settle onto a ball-pivot leg (hero 8)
const FOE_BALL_HEEL_MAX := 24.0  # deg a foe's heel may rise onto the ball to keep it on its spot
var thrust_pose: Array = _try_thrust()
const WINDUP_LEAN := -0.13
var THRUST_UNLEANED := OS.get_environment("THRUST_UNLEANED") == "1"
var THRUST_LEAN_POP := OS.get_environment("THRUST_LEAN_POP") == "1"
static func _try_thrust() -> Array:
	if not OS.has_environment("THRUST_TRY"):
		return THRUST if OS.get_environment("THRUST_OLD") == "1" else THRUST_SOLVED
	var v := OS.get_environment("THRUST_TRY").split_floats(",")
	return [v[0], v[1], Vector3(v[2], v[3], v[4]), v[5], v[6], v[7]]

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
var _turn_sh := 0.0                # the shuffle the turn rate wants this tick
## 11-06: the turn ends in the hero's two settle steps (StrideWarp.pivot_settle) into the idle
## stance. FOE_PIVOT_HOVER: the before (the turn ended in the shuffle clip's stance and both boots
## slid back to the idle stance on the release)
static var FOE_PIVOT_HOVER := OS.has_environment("FOE_PIVOT_HOVER")
## Pivot foot (the hero's StrideWarp, contact lock and stride warp off): in a turn on the spot
## the inside foot stays planted and the body swings round over it; the outside foot steps.
var stride_warp: StrideWarp
## The stagger at the joints (the hero's `_flinch_layer`, on a Crumple before the arm IK): the
## hips thrown back off the blow, the chest caving round it, the head whipping, a side blow
## twisting the chest, the knees giving; the shove walked off in backward steps.
var crumple: Crumple
var hand_rest: HandRest      # the fingers: a grip while the hands hold the weapon, open as it slips
## (11-06) the fists round the haft: the arm IK lands the WRIST on the grip point, so the shaft ran
## beside the closed fingers; each tick the posed fist's centre is measured against the shaft's
## axis and the wrist target moved (Wield space) so the haft sits inside the curl
var fist_fit_on := true          # (bots / archer) off: the wrist on the grip point (env FOE_WRISTGRIP)
var _fist_off: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   # right, left: Wield-space wrist shift
var fist_gap: Array[float] = [0.0, 0.0]
var _feed_gain := float(OS.get_environment("FOE_FEEDGAIN")) if OS.has_environment("FOE_FEEDGAIN") else 0.6
var fist_shift: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   # (11-10) the wrist shift _place applied (Wield space)
var _roll_frame := false          # (11-10) _fist_off is in the spear's frame (GripRoll holding)
var grip_roll: GripRoll           # (11-10) null with FOE_GRIPLAG or on the archer   # (bots) right, left: fist centre to the shaft axis, m per size, last fit
const FIST_GAIN := 0.6           # of the measured gap taken out each tick
var _aim: FistAim
var _aim_tgt := [null, null]
var _aim_ik := [null, null]
var _aim_bone := [-1, -1]
var _aim_gap: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   # world: the fist's gap off the axis before the second pass
var _aim_gap_ok := [false, false]
const FIST_AIM_K := 0.6          # of the gap the second pass moves the wrist (the IK turns the hand as the wrist moves: the fist moves ~1.4x; 1.0 rings)
const FIST_AIM_FIT_GAIN := 0.45
const FIST_MAX := 0.22           # m (Wield space) the wrist may move off its grip point (the knight's needs ~0.16)
var reel_on := true              # (bots) off: the old rigid lean of the whole model about the hips
var _reel_dir := Vector3.ZERO    # world: the way the blow drove the body (flat, unit)
var _reel_posed := false
var _reel_yaw := 0.0             # rad: the hips and legs turned to back off along a shove from a side
const REEL_YAW_MAX := 1.1        # rad: the rest of a side shove is taken by the chest counter-twist
var reel_head_peak := 0.0        # (bots) largest neck whip of the last stagger (rad, + head back)
var reel_chest_peak := 0.0       # (bots) largest spine + pelvis of the last stagger (rad, + forward)
var reel_lock_on := true         # (bots) off: no contact lock in a stagger, as before 11-05 14:30
var reel_release_on := true      # (bots) off: a lifting stance boot lets go of its pin in ~3 ticks, as before 11-05 18:30
var reel_lateral_on := true      # (bots) off: the lock holds the boot only along the legs, as before 11-05 15:30
var reel_pivot_on := true        # (bots) off: the legs' reel turn spins about the root, as before 11-05 13:30
var reel_pivot_shift := 0.0      # (bots) m the body was carried round the planted boot by the reel's leg turn
var reel_twist_peak := 0.0       # (bots) largest chest twist of the last stagger (rad, + to the left)
var pivot_shift := Vector3.ZERO  # bots: net m the body has been swung round planted feet
const PIVOT_REACH := 0.11        # m per unit size: the most the body's middle orbits off the pivot foot
var _col_cap: CapsuleShape3D
var _col: CollisionShape3D
var _ember_range := 2.6

func _ready() -> void:
	if OS.has_environment("GUARD_OLD") and guard_pose == GUARD:
		guard_pose = GUARD_OLD
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
	_pose = guard_pose
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
	if skel != null:
		stride_warp = StrideWarp.new()
		stride_warp.name = "StrideWarp"
		skel.add_child(stride_warp)
		skel.move_child(stride_warp, 0)        # first modifier: on the clip's own legs
		stride_warp.frame = (body.global_basis.inverse() * skel.global_basis).orthonormalized()
		stride_warp.ground_body = self
		# (11-12 02:00) the turn on the spot spins on the ball with the heel up, like the hero's; the
		# foes' clips rise onto the stepping leg, so the hips may sink deeper and the heel rise higher
		# to keep the ball on its spot. FOEBALL_OLD: the before (ankle pin, 8 cm sink)
		stride_warp.ball_pivot = not OS.has_environment("FOEBALL_OLD")
		if stride_warp.ball_pivot:
			stride_warp.pivot_sink_max = FOE_PIVOT_SINK
			stride_warp.ball_heel_max_deg = FOE_BALL_HEEL_MAX
		if OS.has_environment("FOE_SINK"):
			stride_warp.pivot_sink_max = float(OS.get_environment("FOE_SINK"))
		if OS.has_environment("FOE_HEEL"):
			stride_warp.ball_heel_max_deg = float(OS.get_environment("FOE_HEEL"))
		# modifiers once per physics tick on the AnimationTree's physics pose (the hero's 17:30
		# switch): on idle frames they ran 0 or 2 times a tick, so the contact lock was flaky
		if OS.get_environment("FOE_IDLEMOD") == "":
			skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS

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
	# the hit reaction at the joints (`_reel_layer`); before the arm IK, so the hands stay
	# closed on the spear while the chest caves and twists under them
	crumple = Crumple.new()
	crumple.name = "Reel"
	skel.add_child(crumple)
	skel.move_child(crumple, _ik.get_index())
	crumple.frame = (body.global_basis.inverse() * skel.global_basis).orthonormalized()
	crumple.active = false
	# (11-06) the fingers closed round the haft (the hero's HandRest: the clip leaves them splayed
	# and hooked like claws over the shaft); the rig is the hero's, so the same bones and angles
	if OS.get_environment("FOE_CLAWHANDS") == "":   # env FOE_CLAWHANDS: the before
		hand_rest = HandRest.new()
		hand_rest.name = "HandRest"
		hand_rest.hold = 1.0
		hand_rest.thumb_aim = 0.0 if OS.has_environment("FOE_THUMBOUT") else 1.0
		skel.add_child(hand_rest)
		# (11-10) the hero's GripRoll on the foes' hands: each hand held in the spear's frame and
		# only rolled about the shaft, and the arm re-solved on the same tick so the closed fist
		# sits on the haft (the late fit alone let a fist ride 9 cm off it on a thrust's first
		# ticks, the hand turning with the clip's forearm); env FOE_GRIPLAG: the before
		if not OS.has_environment("FOE_GRIPLAG") and fist_fit_on:
			grip_roll = GripRoll.new()
			grip_roll.name = "GripRoll"
			grip_roll.staff = spear
			# (02:00 11-10) the foes' wrists may bend 80 deg for the feed (the hero's 75): at 75 the
			# knight's left fist rode 3.2 cm off the glaive for a tick of the sweep (its feed was cut
			# to 2/3); at 80 no hand-tick passes 2 cm (bot foegrip). env FOE_BEND75: the before
			if not OS.has_environment("BEND_LIMIT") and not OS.has_environment("FOE_BEND75"):
				grip_roll.bend_limit = deg_to_rad(80.0)
			# (15:00 11-10) the roll damped (a quarter of the wanted roll a tick, faded out with the
			# forearm along the haft): taken whole it rang +-0.6 rad a tick through the feed for up
			# to 40 ticks, the hand flapping on the haft (bot foegrip `roll chatter`). Env
			# FOE_ROLLRING=1: the before.
			if not OS.has_environment("FOE_ROLLRING"):
				if not OS.has_environment("ROLL_GAIN"):
					grip_roll.roll_gain = 0.25
				if not OS.has_environment("ROLL_FPFADE"):
					grip_roll.fp_fade = true
			skel.add_child(grip_roll)
			skel.move_child(grip_roll, _ik.get_index() + 1)
		if OS.get_environment("FOE_WRISTGRIP") == "":
			skel.skeleton_updated.connect(_fit_fists)
			if fist_fit_on and not OS.has_environment("FOE_NOAIM"):
				_setup_fist_aim(pole_r, pole_l)
	_place(guard_pose)

## (11-10 01:00) the second arm pass for when GripRoll is NOT holding (the knight's reveal and
## roar): FistAim (after HandRest) sets the targets, one TwoBoneIK3D per side so each can fade on
## its own (the knight's freed left hand). With GripRoll on it stands aside (weight 0).
func _setup_fist_aim(pole_r: Node3D, pole_l: Node3D) -> void:
	_aim = FistAim.new()
	_aim.name = "FistAim"
	_aim.foe = self
	skel.add_child(_aim)
	var poles := [pole_r, pole_l]
	var sides := ["Right", "Left"]
	for i in 2:
		var tgt := Node3D.new()
		tgt.name = "FistAimTarget%s" % sides[i]
		tgt.top_level = true
		_wield.add_child(tgt)
		_aim_tgt[i] = tgt
		var ik := TwoBoneIK3D.new()
		ik.name = "FistAimIK%s" % sides[i]
		skel.add_child(ik)
		ik.setting_count = 1
		ik.set_root_bone_name(0, "mixamorig_%sArm" % sides[i])
		ik.set_middle_bone_name(0, "mixamorig_%sForeArm" % sides[i])
		ik.set_end_bone_name(0, "mixamorig_%sHand" % sides[i])
		ik.set_target_node(0, ik.get_path_to(tgt))
		ik.set_pole_node(0, ik.get_path_to(poles[i]))
		ik.influence = 0.0
		ik.active = false
		_aim_ik[i] = ik
		_aim_bone[i] = skel.find_bone("mixamorig_%sHand" % sides[i])

## Variants: 0..1 how much the same-tick fit may pull this side's fist onto the haft (0 while
## the hand is off it).
func _fist_aim_weight(_side: int) -> float:
	return 1.0

## FistAim's step, mid-update: the posed fist's gap across the haft's axis (world), handed to
## the cross-tick fit, and the second-pass wrist target moved by minus that gap.
func _aim_fists() -> void:
	if spear == null or _aim_ik[0] == null:
		return
	var on := fist_fit_on and state != DEAD and _ik != null and _ik.influence > 0.5
	var o := spear.global_position
	var ax := spear.global_basis.y.normalized()
	var s := maxf(size_scale, 0.01)
	var sides := ["Right", "Left"]
	for i in 2:
		var ik: TwoBoneIK3D = _aim_ik[i]
		var f := fist_center(sides[i])
		var gap := f - (o + ax * ax.dot(f - o))
		_aim_gap[i] = gap
		# only where GripRoll is not wanted (it holds the hands in every attack; the knight opts out
		# through its reveal and roar): the two fighting over a wrist broke foegrip and the stomp
		var gr_off := grip_roll == null or not _grip_roll_wanted()
		var w := (_fist_aim_weight(i) * (1.0 - smoothstep(0.12, 0.25, gap.length() / s))) if (on and gr_off) else 0.0
		var wr := skel.global_transform * skel.get_bone_global_pose(_aim_bone[i]).origin
		(_aim_tgt[i] as Node3D).global_position = wr - gap * FIST_AIM_K
		ik.influence = w * _ik.influence
		ik.active = ik.influence > 0.001   # an idle pass off entirely (at influence 0 it still re-solved the arm)
		_aim_gap_ok[i] = ik.influence > 0.01

## The closed fist's centre (world): the mean of the index, middle and ring joints and tips, the
## hollow the haft runs through when the fingers wrap it.
func fist_center(side: String) -> Vector3:
	return HandRest.fist_center(skel, side)

## After the modifiers: each fist's centre to the shaft's axis, and the wrist target moved by a
## share of that gap for the next tick (the IK keeps the hand's turn, so the gap closes in a
## few ticks and follows the poses as the hand rolls round the shaft).
func _fit_fists() -> void:
	if spear == null or _wield == null or hand_rest == null:
		return
	var on := fist_fit_on and state != DEAD and _ik != null and _ik.influence > 0.5
	# (11-10) GripRoll's feed puts the fists on the axis the same tick. Fitting the gap left
	# AFTER it would only fight it (the hero's rule), but with no fit the IK aims each wrist
	# ~15 cm per size off the fist's line, and a tick where the feed's wrist-bend limit refuses
	# the shift popped the fist that far off the haft. So the fit learns, slowly, from the gap
	# the feed found BEFORE it moved the wrist, kept in the SPEAR's frame (GripRoll holds the
	# hand in that frame, so the shift is near constant there); the feed trims the rest.
	# (Tried: the same in the body frame at gain 0.3-0.6: it ran to FIST_MAX, the roll chattered.)
	var feed := grip_roll != null and grip_roll.feed_on and _roll_frame
	var o := spear.global_position
	var ax := spear.global_basis.y.normalized()
	var inv := _wield.global_basis.inverse()
	var s := maxf(size_scale, 0.01)
	var sides := ["Right", "Left"]
	for i in 2:
		var f := fist_center(sides[i])
		var p := o + ax * ax.dot(f - o)
		fist_gap[i] = f.distance_to(p) / s
		var aim_ok: bool = _aim_gap_ok[i]
		_aim_gap_ok[i] = false
		if on and not feed and _aim_ik[0] != null and (grip_roll == null or not _grip_roll_wanted()) and _fist_aim_weight(i) < 0.99:
			# (11-10 01:00) a hand the variant has let go of (the knight's roar fling): no fit
			# chasing a haft it is nowhere near (it pinned the wrist ~0.2 m off its fling target)
			_fist_off[i] = Vector3.ZERO
		elif on and feed:
			var gap: Vector3 = grip_roll.last_err[i]
			_fist_off[i] = (_fist_off[i] - spear.global_basis.inverse() * gap * _feed_gain).limit_length(FIST_MAX)
		elif on:
			var g := FIST_GAIN
			if aim_ok:
				# the second pass already put the fist on the axis: learn from the gap it saw,
				# at a lower gain (0.6 on top of the pass rang at the knight x4.6 sweep end)
				p = f - _aim_gap[i]
				g = FIST_AIM_FIT_GAIN
			var off: Vector3 = _fist_off[i] - inv * (f - p) * g
			_fist_off[i] = off.limit_length(FIST_MAX)
		else:
			_fist_off[i] = _fist_off[i].lerp(Vector3.ZERO, 0.1)

## (05:00 11-11) read-outs of the last `_place` (bots): how far past its reach each grip was
## asked (m, R/L) and how far the clamp then bent the shaft off the pose's direction (deg)
var clamp_over := [0.0, 0.0]
var axis_off := 0.0
## The shoulders the reach clamp measures from, in the Wield's space: [left, right, leaned]. The
## default is the hero's body model turned with the chest (`leaned` false: `_place` tips them with
## the grips). A variant may return the skeleton's real shoulders (already leaned: true).
## (11-11) reach slide (variants opt in): the shift `_place` gave the hold point this tick (read-out)
var slid := Vector3.ZERO
const REACH_SLIDE_MARGIN := 0.02
const REACH_SLIDE_MAX := 0.45
func _reach_slide_on() -> bool:
	return false

## (11-11 20:00) the reach clamp eases in over its last SOFTCLAMP_K metres for the plain soldiers'
## sweep. The front (left) grip runs up to 0.16 m past the sweep's reach through the first two thirds of
## the cut; the hard clamp bent the shaft up to 11 deg (leading the blade) and, as the bend unwound
## between bearing +47 and +65, it stopped dead the tick the grip came back inside reach: the blade's
## turn went 6.7 -> 6.6 -> 7.1 -> 6.2 deg/tick, a hitch in the follow-through. A soft clamp (same reach,
## C1 at the knee) lets the bend fade out. The slide (`_reach_slide_on`) was tried first: it straightens
## the shaft but pulls the blade 0.16 m in, folds the right arm (0.14 m shoulder-to-wrist, bot foefold)
## and moves the blade's arrival out of the parry window. Env SOFTCLAMP_OLD=1: the hard clamp.
const SOFTCLAMP_K := 0.08
static var SOFTCLAMP_OLD := OS.get_environment("SOFTCLAMP_OLD") == "1"
func _soft_clamp_k() -> float:
	# (foes that slide their grips inside reach, the knight, never reach the clamp's knee: left hard)
	if SOFTCLAMP_OLD or _reach_slide_on() or move_kind != SWEEP_MOVE or not state in [WINDUP, STRIKE, RECOVER]:
		return 0.0
	return float(OS.get_environment("SOFTCLAMP_K")) if OS.has_environment("SOFTCLAMP_K") else SOFTCLAMP_K

## w limited to `reach`; with k > 0 the length eases toward reach over its last k metres instead of
## stopping at it (exponential knee, continuous slope)
static func _clamp_reach(w: Vector3, reach: float, k: float) -> Vector3:
	var n := w.length()
	if k <= 0.0:
		return w.limit_length(reach)
	var knee := reach - k
	if n <= knee or n < 1e-6:
		return w
	return w * ((knee + k * (1.0 - exp(-(n - knee) / k))) / n)

func _shoulders(tw: float) -> Array:
	return [SHOULDER.rotated(Vector3.UP, tw), Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z).rotated(Vector3.UP, tw), false]

func _place(pose: Array) -> void:
	var d := StaffCombat.dir_of(pose[0], pose[1])
	var c: Vector3 = pose[2]
	var tw := deg_to_rad(pose[3])
	var sh: Array = _shoulders(tw)
	var sl: Vector3 = sh[0]
	var sr: Vector3 = sh[1]
	if absf(_place_lean) > 0.0005:
		var hip := Vector3(0, 0.95, 0)
		var lb := Basis(Vector3.RIGHT, _place_lean)
		c = hip + lb * (c - hip)
		if not sh[2]:
			sl = hip + lb * (sl - hip)
			sr = hip + lb * (sr - hip)
	var slide: float = pose[4] if pose.size() > 4 else 0.0
	var reach: float = pose[5] if pose.size() > 5 else ARM_REACH
	slid = Vector3.ZERO
	if _reach_slide_on():
		# (11-11) slide both grips together along the pose's own line back inside reach of the
		# shoulders before the clamp has to bend the shaft: the body brings its hands to where
		# its arms can hold the glaive, the glaive keeps the pose's direction
		var room := reach - REACH_SLIDE_MARGIN
		for _i in 24:
			var g := Vector3.ZERO
			for pr in [[c + slid + d * (HAND_R + slide), sr], [c + slid + d * (HAND_L + slide), sl]]:
				var w: Vector3 = pr[0] - pr[1]
				var n := w.length()
				if n > room:
					g -= (n - room) * w / n
			if g.length() < 0.0005:
				break
			slid = (slid + g * 0.5).limit_length(REACH_SLIDE_MAX)
		c += slid
	var wr := c + d * (HAND_R + slide) - sr
	var wl := c + d * (HAND_L + slide) - sl
	clamp_over = [maxf(wr.length() - reach, 0.0), maxf(wl.length() - reach, 0.0)]
	var sk := _soft_clamp_k()
	var hr := sr + _clamp_reach(wr, reach, sk)
	var hl := sl + _clamp_reach(wl, reach, sk)
	var axis := hl - hr
	if axis.length() < 0.15:
		axis = d * 0.15
	var d2 := axis.normalized()
	axis_off = rad_to_deg(d.angle_to(d2))
	spear.transform = Transform3D(Basis(Quaternion(Vector3.UP, d2)), hr - d2 * (HAND_R + slide))
	var fb := spear.basis if _roll_frame else Basis.IDENTITY
	fist_shift = [fb * _fist_off[0], fb * _fist_off[1]]
	_grip_r.position = hr + fist_shift[0]
	_grip_l.position = hl + fist_shift[1]
	if _twist != null:
		_twist.twist = tw

## (18:00 11-10) the thrust's grips ride the body's lean. `_lean` tips the model from the hips but
## the spear lives in the Wield's unleaned space: in the lunge (lean -0.13 -> +0.16) the shoulders
## swung ~0.15 m forward over the rear fist, the right arm folded to 0.12 m shoulder-to-wrist, the
## elbow flipped across the shaft and the fist left the haft (THRUST_SOLVED, bot `foegrip`). The
## grip positions and the shoulders the reach is measured from are now turned about the hips with
## the lean (`_place_lean`; the shaft's direction kept, so the blade still drives level).
## Env THRUST_UNLEANED=1: the before.
var _place_lean := 0.0
## the share of this tick's model lean the grips are carried by (variants add their own moves)
func _grip_lean(lean: float) -> float:
	return lean - lean_kick if _thrust_leaned() else 0.0

func _thrust_leaned() -> bool:
	return move_kind == THRUST_MOVE and state in [WINDUP, STRIKE, RECOVER] and not THRUST_UNLEANED

## (11-10) a pose eased once along a quadratic arc through `m` (the hewer's raise, the knight's
## leap heave and slam): a straight lerp between far-apart poses drags a grip through the body.
static func _lin_pose(a: Array, b: Array, f: float) -> Array:
	return [lerpf(a[0], b[0], f), lerpf(a[1], b[1], f), (a[2] as Vector3).lerp(b[2], f), lerpf(a[3], b[3], f),
		lerpf(a[4] if a.size() > 4 else 0.0, b[4] if b.size() > 4 else 0.0, f),
		lerpf(a[5] if a.size() > 5 else ARM_REACH, b[5] if b.size() > 5 else ARM_REACH, f)]
static func _arc_pose(a: Array, m: Array, b: Array, r: float) -> Array:
	var f := r * r * (3.0 - 2.0 * r)
	return _lin_pose(_lin_pose(a, m, f), _lin_pose(m, b, f), f)

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

## (11-11) the sweep pose this foe actually swings (the knight re-solves it against its real shoulders)
func _sweep_pose(a: float) -> Array:
	return sweep_pose(a)

## Lean the whole model from the hips (back = negative), pivoting so the feet stay put.
var lean_last := 0.0   # (bots) the hip lean set last tick
func _lean(rad: float, sink: float) -> void:
	lean_last = rad
	var hip := Vector3(0, 0.95, 0)
	var tr := Transform3D(Basis(Vector3.RIGHT, rad), Vector3.ZERO)
	tr = Transform3D(Basis(), hip) * tr * Transform3D(Basis(), -hip)
	model.transform = Transform3D(Basis(Vector3.UP, _reel_yaw), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -sink, 0)) * tr * _model_rest

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
		_reel_dir = d.normalized()
		_reel_posed = false
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
	_reel_dir = _knock.normalized() if _knock.length() > 1e-3 else -body.global_basis.z.normalized()
	_reel_posed = false
	state = STAGGER
	t = 0.0

# --- brain ---

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_parent().get_node_or_null("Player") as Player
	if hand_rest != null and _ik != null:
		hand_rest.hold = _ik.influence
	if grip_roll != null:
		var want := _ik.influence if (fist_fit_on and state != DEAD and spear.get_parent() == _wield and _grip_roll_wanted()) else 0.0
		grip_roll.weight = want if want >= grip_roll.weight else move_toward(grip_roll.weight, want, delta * 8.0)
		# the wrist shift lives in the spear's frame while GripRoll holds the hands, in the body's
		# without it: carried across on the switch so the wrist target does not jump
		var on_now := grip_roll.weight > 0.5
		if on_now != _roll_frame:
			for i in 2:
				_fist_off[i] = (spear.basis.inverse() * _fist_off[i]) if on_now else (spear.basis * _fist_off[i])
			_roll_frame = on_now
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
			var a := lerpf(SWEEP_HOME, SWEEP_FROM, smoothstep(0.0, 0.62, u)) + sin(t * 47.0) * 1.5 * smoothstep(0.6, 0.9, u)
			# (11-10 12:00) the turn out of the (re-solved, high) guard into the low coil takes half the
			# wind-up (was a quarter: from the real guard the left wrist's GripRoll roll hit its cap for
			# a tick, fist 0.06 m off; 2.5-3.0 do too, see PROGRESS.md). Env SWEEP_FROMK: tuning.
			var fk := float(OS.get_environment("SWEEP_FROMK")) if OS.has_environment("SWEEP_FROMK") else SWEEP_FROM_BLEND
			_pose = _lerp_pose(_from, _sweep_pose(a), minf(u * fk, 1.0))
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
			var a := lerpf(SWEEP_FROM, SWEEP_TO, sweep_cut_f(u))
			_pose = _sweep_pose(a)
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
			_pose = _lerp_pose(_sweep_pose(lerpf(SWEEP_TO, SWEEP_HOME, f)), guard_pose, f)
			lean = 0.1 * (1.0 - smoothstep(0.2, 0.9, u))
			sink = 0.14 * (1.0 - u)
			ember = 1.4 - 0.4 * u
			if u >= 1.0:
				_enter(STALK)
		WINDUP:
			var u := clampf(t / WINDUP_T, 0.0, 1.0)
			_turn_to(to, delta, 3.0 * (1.0 - u))   # tracks early, commits late
			_pose = _lerp_pose(guard_pose, DRAWN, minf(u * 1.6, 1.0))
			lean = WINDUP_LEAN * smoothstep(0.0, 0.6, u)
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
			_pose = _lerp_pose(DRAWN, thrust_pose, minf(u * 2.2, 1.0))
			# (18:00 11-10) from the wind-up's lean back into the lunge (was 0 -> 0.16: the whole
			# body popped 0.13 rad forward on the first strike tick)
			lean = 0.16 * smoothstep(0.0, 0.4, u) if THRUST_LEAN_POP else lerpf(WINDUP_LEAN, 0.16, smoothstep(0.0, 0.4, u))
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
			_pose = _lerp_pose(thrust_pose, guard_pose, smoothstep(0.35, 1.0, u))
			lean = 0.16 * (1.0 - smoothstep(0.2, 0.9, u))
			sink = 0.09 * (1.0 - u)
			ember = 1.4 - 0.4 * u
			if u >= 1.0:
				_enter(STALK)
		STAGGER:
			var u := clampf(t / _stagger_len, 0.0, 1.0)
			_update_glint(0.0)
			_pose = _lerp_pose(_from, [30.0, -18.0, Vector3(0.15, 1.0, 0.55), 18.0], minf(u * 3.0, 1.0)) if u < 0.5 else _lerp_pose([30.0, -18.0, Vector3(0.15, 1.0, 0.55), 18.0], guard_pose, (u - 0.5) * 2.0)
			# with the joint reaction the trunk is thrown back at the hips, not the whole model
			# tipped about them (that swung the planted feet ~0.2 m)
			lean = (0.0 if _reel_layer_on() else -0.22) * _recoil * sin(PI * minf(u * 1.4, 1.0))
			sink = 0.05
			move = _knock * (1.0 - u) * (1.0 - u) * 2.2   # steered along the legs after `_reel_layer` turns them
			if not reel_pivot_on:
				move = _reel_steer(move)              # (bots) the old order: last tick's leg yaw
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
	_reel_layer()
	if state == STAGGER and bot_move == Vector3.ZERO:
		move = _reel_steer(move) if reel_pivot_on else move      # this tick's leg yaw: a tick late, the shove ran 15 deg off the stepping legs
	_place_lean = _grip_lean(lean)
	_place(_pose)
	_place_lean = 0.0
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
	var y_pre := global_position.y
	var floor_pre := is_on_floor()
	_step_climb(delta)
	var pay := _carry_payback(delta)
	move_and_slide()
	if pay < 1.0:
		velocity.x /= pay
		velocity.z /= pay
	_ease_carry(delta)
	if floor_pre and velocity.y < 0.5 and state != DEAD:
		var excess := StepUp.lip_excess(self, global_position.y - y_pre, delta, size_scale)
		var pd0 := global_position
		excess -= StepUp.step_down(self, y_pre, delta, STEP_H * size_scale, size_scale)
		# (11-13 04:00) the step down slides the round bottom off the tread edge (a few cm past the
		# pace in one tick): the visible body is held back by that slide, as the hero's is, so the
		# planted boot is not dragged over the edge. FOEDOWNCARRY_OLD=1 = before
		if not _foe_carry_old and not _foe_down_carry_old and not _foe_nohold:
			var cd := global_position - pd0
			cd.y = 0.0
			if cd.length() > 0.001:
				_step_carry -= cd
				_carry_p1 = global_position
				down_carry_max = maxf(down_carry_max, cd.length())
				body.position.x = _step_carry.x
				body.position.z = _step_carry.z
		if excess != 0.0:
			_step_dip = clampf(_step_dip - excess, -(STEP_H + 0.05) * size_scale, (STEP_H + 0.05) * size_scale)
			body.position.y = _step_dip
	_floor_dip_to_feet()
	_update_ground_feet(delta)
	if anim_tree:
		# a bigger body covers more ground per stride: the clips play at the scaled speed
		var hs := Vector2(velocity.x, velocity.z).length() / size_scale
		if state == STRIKE or state == STAGGER:
			hs = minf(hs, 0.8)      # the lunge is a planted thrust, not a run
		if _legs_still():
			hs = 0.0                # carried with the legs set (a leap's flight): no run stride
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
		if _reel_posed:
			# shoved by the blow: the walk played backwards at the shove's own pace, so the feet
			# take stagger steps back under the body instead of skating forward strides
			var hv := Vector3(velocity.x, 0.0, velocity.z)
			_blend = lerpf(_blend, Player.ANIM_WALK_SPEED, 1.0 - exp(-25.0 * delta))
			anim_tree.set("parameters/move/blend_position", _blend)
			var fs := maxf(hv.length() / size_scale / clip_stride_speed(), 0.35)
			var legs_fwd := body.global_basis.orthonormalized() * Vector3(sin(_reel_yaw), 0.0, cos(_reel_yaw))
			if hv.dot(legs_fwd) > 0.3 * hv.length():
				fs = -fs                       # driven from behind: stumbling forward, the walk runs on
			ts = -fs
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
## Foot IK on uneven ground (StrideWarp ground feet), scaled with the body: each boot on its
## own ground on the ring's slope, the hips settled for the lower one; off in the air and dead.
## Step-up (StepUp, shared with the hero): a riser up to STEP_H x size is climbed; the body
## is let down by the lift and eases up through it. `steps_up` counts them (bots).
const STEP_H := 0.38
var steps_up := 0
var _step_dip := 0.0
## (11-13 00:00) The foes stepped up without the carry onto the tread, so a stalk's slide left the
## round bottom on the riser's edge and it settled back off it every tick: a soldier or the knight
## walking slower than the probe never climbed a stair at all (bot `foestep`: 370 lifts, 0 m up).
## Now carried like the hero, and the visible body is held back by the carry and let go as the root
## lags its pace (`_ease_carry`), so the hips keep the stalk's pace. FOECARRY_OLD=1 = before.
var _step_carry := Vector3.ZERO      # visible body off the root, across the ground (m, world axes)
var _carry_p1 := Vector3.ZERO
var _carry_sp := 0.0
static var _foe_carry_old := OS.has_environment("FOECARRY_OLD")
static var _stepwhy := OS.has_environment("STEPWHY")   # debug: print why a moving foe did not step
static var _foe_nohold := OS.has_environment("FOECARRY_NOHOLD")   # bots: carried, not held back
var carry_max := 0.0                 # bots: the largest hold-back so far (m)
var down_carry_max := 0.0            # bots: the largest slide off a tread edge held back (m)
static var _foe_down_carry_old := OS.has_environment("FOEDOWNCARRY_OLD")
## (11-13 04:00) The ground IK stands the boots on the VISIBLE body's floor, as the hero's does:
## held up over a step down (or let down after a step up) the foe's boots were measured from the
## root and hung 13 cm off the tread (or sank into it). FOEFLOORDIP_OLD=1 = before
static var _foe_floor_dip_old := OS.has_environment("FOEFLOORDIP_OLD")

func _floor_dip_to_feet() -> void:
	if stride_warp != null and not _foe_floor_dip_old:
		stride_warp.floor_dip = _step_dip

func _step_climb(delta: float) -> void:
	var p0 := global_position
	var lift := StepUp.try(self, delta, STEP_H * size_scale, not _foe_carry_old, true, size_scale) if state != DEAD else 0.0
	if _stepwhy and lift <= 0.0 and Vector2(velocity.x, velocity.z).length() > 0.1:
		print("STEPWHY %s %s y %.3f" % [name, StepUp.why, global_position.y])
	_carry_p1 = global_position
	_carry_sp = Vector2(velocity.x, velocity.z).length()
	if lift > 0.0:
		steps_up += 1
		if not _foe_carry_old:
			var c := global_position - p0
			c.y = 0.0
			_step_carry -= c
			carry_max = maxf(carry_max, _step_carry.length())
	if _step_dip != 0.0 or lift > 0.0:
		_step_dip = StepUp.ease_dip(_step_dip, Vector2(velocity.x, velocity.z).length(), delta, size_scale)
		body.position.y = _step_dip

## (11-13 03:00) The carry onto a tread is ground the root covers for free (0.22 m a step for a
## soldier on a 0.45 m tread: up a stair it went ~2x its stalk), so the hold-back the body owed it
## piled up step on step (0.46 m behind the capsule on the test stair). Once the root stands
## square on the tread it pays the carry back: it slides at half pace until the hold-back is gone,
## and the body, let go by the root's lag, keeps walking at its own pace. FOEPAYBACK_OLD=1 = before.
## Returns the factor the horizontal velocity was scaled by (restored after the slide).
const PAYBACK := 0.5
static var _foe_payback_old := OS.has_environment("FOEPAYBACK_OLD")

func _carry_payback(delta: float) -> float:
	if _foe_payback_old or _step_carry == Vector3.ZERO or state == DEAD or not is_on_floor():
		return 1.0
	if get_floor_normal().y < 0.95:
		return 1.0                       # still riding the tread's edge: keep the full slide
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp < 0.05:
		return 1.0
	var owed := _step_carry.length()
	var f := 1.0 - minf(owed / (sp * delta), PAYBACK)
	velocity.x *= f
	velocity.z *= f
	return f

## The hold-back goes as the root falls behind the pace it was asked for, and at least at a quarter
## of the pace (never lingers); dead or staggered off its feet it goes at once.
func _ease_carry(delta: float) -> void:
	if _step_carry == Vector3.ZERO:
		return
	if state == DEAD or _foe_nohold:
		_step_carry = Vector3.ZERO
	else:
		var moved := global_position - _carry_p1
		moved.y = 0.0
		var nominal := _carry_sp * delta
		var lag := maxf(nominal - moved.length(), 0.0)
		var go := maxf(lag, maxf(0.25 * nominal, 0.15 * sqrt(size_scale) * delta))
		var m := _step_carry.length()
		_step_carry = Vector3.ZERO if m <= go else _step_carry * ((m - go) / m)
	body.position.x = _step_carry.x
	body.position.z = _step_carry.z

## Another modifier stands the boots on the ground itself this tick (the knight's stomp):
## the ground IK stays out of it, or the two lift the boot twice.
## The body is carried without the legs walking (a giant's leap): the locomotion clip stands.
func _legs_still() -> bool:
	return false

func _feet_planted() -> bool:
	return false

func _update_ground_feet(delta: float) -> void:
	if stride_warp == null:
		return
	stride_warp.ground_scale = size_scale
	var w := 1.0 if is_on_floor() and state != DEAD else 0.0
	stride_warp.ground_w = move_toward(stride_warp.ground_w, w, delta * (8.0 if w > stride_warp.ground_w else 12.0))
	if _feet_planted():
		stride_warp.ground_w = 0.0
	# staggered: the stance boot is pinned where it struck (the hero's contact lock), so the
	# shove's backward stagger steps plant instead of skating while the walk's cadence and the
	# shove's pace disagree (the 4x backward walk lifted its stance foot before the shove slowed)
	var lk := 1.0 if reel_lock_on and _reel_posed and is_on_floor() else 0.0
	stride_warp.lock = move_toward(stride_warp.lock, lk, delta * (30.0 if lk > stride_warp.lock else 8.0))
	stride_warp.lock_lateral = reel_lateral_on
	stride_warp.release_speed = 60.0 if reel_release_on else 0.0   # ~1 cm a tick at 60 Hz

func _update_turn_shuffle(delta: float, hs: float) -> void:
	var yaw := body.rotation.y
	var rate := absf(angle_difference(_prev_yaw, yaw)) / maxf(delta, 1e-4)
	_prev_yaw = yaw
	var standing := hs * size_scale < TURN_STILL and is_on_floor() and state in [IDLE, STALK]
	# measured against the body's own cadence: the giant's slow turn is still a full step round
	var sh := clampf((rate / natural_cadence() - TURN_FROM) / TURN_FULL, 0.0, 1.0) if standing else 0.0
	# rises quick (the first step goes as the turn starts), settles over the last step
	_turn_sh = sh
	turn_shuffle = move_toward(turn_shuffle, sh, delta * (8.0 if sh > turn_shuffle else 2.5))
	shuffle_peak = maxf(shuffle_peak, turn_shuffle)
	_update_pivot_foot(delta, standing)

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

## (11-10) Variants that take a hand off the haft (the knight's roar) return false while they do:
## the late body-frame fit then holds the one hand that is left.
func _grip_roll_wanted() -> bool:
	return true

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

## Variants whose own choreography owns the body in a STAGGER (the knight's crown reel and
## surge) return true, and the hit reaction stands aside.
func _reel_owned() -> bool:
	return false

func _reel_layer_on() -> bool:
	return reel_on and crumple != null and state == STAGGER and _reel_dir != Vector3.ZERO and not _reel_owned()

func _clear_reel() -> void:
	if crumple == null:
		return
	for k in ["pelvis", "spine", "neck", "head_turn", "chest_twist", "knee", "hip", "ground"]:
		crumple.set(k, 0.0)
	crumple.active = false
	_reel_posed = false
	_reel_yaw = 0.0

## The stagger at the joints, layered on the clip: struck from ahead the hips are thrown back
## while the chest rounds over the blow and the head snaps forward (0.025 s behind the chest,
## the whiplash), then everything rebounds a little past rest; from behind the trunk pitches
## forward and the head is flung back; from a side the chest twists off the struck shoulder.
## The knees give and the hips are kept over the lower foot. A giant rocks less (size^-0.35).
func _reel_layer() -> void:
	if not _reel_layer_on():
		if _reel_posed:
			_clear_reel()
		if state != STAGGER:
			_reel_dir = Vector3.ZERO
		return
	if not _reel_posed:
		reel_head_peak = 0.0
		reel_chest_peak = 0.0
		reel_twist_peak = 0.0
	_reel_posed = true
	var L := _stagger_len
	var a := _reel_hit(t, L)
	var h := _reel_hit(t - 0.025, L)
	var r := sin(PI * clampf((t - 0.3 * L) / (0.5 * L), 0.0, 1.0))
	var e := smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.8 * L, L, t))
	var k := minf(_recoil, 1.5) * pow(size_scale, -0.35)
	var push := body.global_basis.inverse() * _reel_dir   # body faces +Z, +X is its left
	push.y = 0.0
	if push.length() > 1e-3:
		push = push.normalized()
	var front := maxf(-push.z, 0.0)
	var rear := maxf(push.z, 0.0)
	var side := push.x
	crumple.active = true
	crumple.pelvis = ((-0.3 * front + 0.24 * rear) * a + (0.07 * front - 0.05 * rear) * r) * k
	crumple.spine = ((0.18 * front + 0.1 * rear) * a - 0.06 * front * r) * k
	crumple.neck = ((-0.3 * front + 0.36 * rear) * h + (0.13 * front - 0.1 * rear) * r) * k
	# a shove from a side: the hips and legs swing round so the stagger steps back along it (a
	# body shoved sideways turns and stumbles; walking backward square-on its feet would skate
	# across the turf), the chest and head counter-turned to keep the hero in front
	var back := atan2(-push.x, -push.z)
	var fore := atan2(push.x, push.z)
	var goal := clampf(back if absf(back) <= absf(fore) else fore, -REEL_YAW_MAX, REEL_YAW_MAX)
	var yaw := goal * smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.7 * L, L, t))
	_reel_pivot(yaw - _reel_yaw)
	_reel_yaw = yaw
	var twist := (-0.34 * side * a + 0.07 * side * r) * k
	crumple.chest_twist = twist - 0.55 * _reel_yaw
	crumple.head_turn = (-0.4 * side * h + 0.1 * side * r) * k - 0.35 * _reel_yaw
	crumple.knee = 0.2 * a * minf(k, 1.0)
	crumple.hip = 0.1 * a * minf(k, 1.0)
	crumple.ground = e
	if absf(crumple.neck) > absf(reel_head_peak):
		reel_head_peak = crumple.neck
	if absf(crumple.spine + crumple.pelvis) > absf(reel_chest_peak):
		reel_chest_peak = crumple.spine + crumple.pelvis
	if absf(twist) > absf(reel_twist_peak):
		reel_twist_peak = twist                # the blow's own twist, not the counter to the legs' turn

## The legs swing round into a side shove (and back out of it) on the planted foot, not about the
## root between the feet (that skated the standing boot ~2.5 cm a tick through the turn): the
## body is carried round the lower boot by the turn step d, as `_pivot_orbit` does for a turn.
func _reel_pivot(d: float) -> void:
	if absf(d) < 1e-5 or skel == null or not reel_pivot_on:
		return
	var feet := []
	for b in ["mixamorig_LeftFoot", "mixamorig_RightFoot"]:
		var i := skel.find_bone(b)
		if i < 0:
			return
		feet.append(skel.global_transform * skel.get_bone_global_pose(i).origin)
	var f: Vector3 = feet[0] if feet[0].y < feet[1].y else feet[1]
	var r := Vector3(f.x - global_position.x, 0.0, f.z - global_position.z)
	if r.length() > 0.6 * size_scale:
		return
	var orbit := r - r.rotated(Vector3.UP, d)
	if orbit.length() > 1e-5 and orbit.length() < 0.2 * size_scale:
		var before := global_position
		move_and_collide(orbit)
		reel_pivot_shift += (global_position - before).length()

## The shove carried along the line the legs back off on (they are turned by `_reel_yaw`): a body
## shoved from a side turns and stumbles back over its own feet rather than sliding across them.
func _reel_steer(v: Vector3) -> Vector3:
	if not _reel_posed or absf(_reel_yaw) < 1e-3 or v.length() < 1e-4:
		return v
	var b := body.global_basis.orthonormalized()
	var legs := b * Vector3(sin(_reel_yaw), 0.0, cos(_reel_yaw))
	var flat := Vector3(v.x, 0.0, v.z)
	var dir := -legs if flat.dot(legs) < 0.0 else legs
	return dir * flat.length() + Vector3(0.0, v.y, 0.0)

## Impact envelope at time t (s) of a stagger L s long: snaps in over 0.06 s, gives back by 0.6 L.
static func _reel_hit(t: float, L: float) -> float:
	if t < 0.0:
		return 0.0
	return sin(minf(t / 0.06, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.06, 0.6 * L, t))

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
		var d := clampf(angle_difference(body.rotation.y, want), -cap, cap)
		_pivot_orbit(d)
		want = body.rotation.y + d
	body.rotation.y = want

## Swings the body round the planted pivot foot by the yaw step d (the hero's Player._step_capped):
## about the pin's sideways offset only, so a 120 deg turn moves a soldier ~0.2 m, not a stroll.
func _pivot_orbit(d: float) -> void:
	if stride_warp == null:
		return
	if stride_warp.pivot <= 0.0 and absf(d) > 1e-4:
		stride_warp.pivot_side = 0 if d > 0.0 else 1   # turning left (yaw up): plant the left foot
	if stride_warp.pivot_pin == null or stride_warp.pivot <= 0.0:
		return
	var side := body.global_basis.x
	side = Vector3(side.x, 0.0, side.z).normalized()
	var reach := PIVOT_REACH * size_scale
	var off := clampf((stride_warp.pivot_pin - global_position).dot(side), -reach, reach)
	var r := -side * off
	var orbit := (r.rotated(Vector3.UP, d) - r) * stride_warp.pivot
	if orbit.length() > 1e-5 and orbit.length() < 0.2 * size_scale:
		var before := global_position
		move_and_collide(orbit)
		pivot_shift += global_position - before

## The pivot foot is planted while the feet step round on the spot, and let go once square.
func _update_pivot_foot(delta: float, standing: bool) -> void:
	if stride_warp == null:
		return
	var want := stride_warp.pivot_want(1.0 if standing and turn_shuffle > 0.05 else 0.0, standing, delta)
	# squared up (the body no longer turning): the turn step comes down and the feet close the stance
	if FOE_PIVOT_HOVER or not standing or stride_warp.pivot <= 0.0 or _turn_sh > 0.3:
		stride_warp.pivot_settle = false
	elif standing and _turn_sh <= 0.0:
		stride_warp.pivot_settle = true
	stride_warp.stance_idle = standing and turn_shuffle <= 0.0 and Vector2(velocity.x, velocity.z).length() < 0.05 * size_scale
	var rate := (10.0 if want > stride_warp.pivot else 5.0) * natural_cadence()
	stride_warp.pivot = move_toward(stride_warp.pivot, want, delta * rate)

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
# (11-11 19:00) the cut's path over its u: the blade leaves the held coil accelerating over the first
# SWEEP_CUT_RAMP of the cut (linear speed ramp), reaches the same peak speed as before (2x the mean) and
# eases out into the follow-through. The old curve (1 - (1-u)^2, env SWEEPCUT_OLD=1) started at full speed:
# 1 -> 16.7 deg in one tick off the trembling coil, a visible pop.
const SWEEP_CUT_RAMP := 0.14
static var SWEEPCUT_OLD := OS.get_environment("SWEEPCUT_OLD") == "1"

static func sweep_cut_f(u: float) -> float:
	if SWEEPCUT_OLD:
		return 1.0 - (1.0 - u) * (1.0 - u)
	if u < SWEEP_CUT_RAMP:
		return u * u / SWEEP_CUT_RAMP
	return 1.0 - (1.0 - u) * (1.0 - u) / (1.0 - SWEEP_CUT_RAMP)

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
