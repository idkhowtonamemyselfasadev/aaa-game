class_name StaffCombat
extends Node
## Ward-stance light string. The staff's path is authored in body space as keyed poses
## (direction yaw/pitch + grip-centre position + spine twist); both hands are solved onto the
## shaft with two-bone IK and the torso twists into each swing, so the arms, chest and staff
## move as one over whatever the legs are doing in the locomotion blend.
## Attack: sweep -> backhand -> overhead slam -> spinning sweep. Idle 5 s -> staff slung back.
## Heavy (hold): the staff rises overhead and charges through three tiers; release brings it
## down in a planted smash. The first PARRY_WINDOW of the raise deflects an incoming blow.

signal swing_started(step: int)
signal hit_landed(target: Node, point: Vector3, power: float)
signal parried(attacker: Node)
signal charge_tier(tier: int)
signal slammed(at: Vector3, power: float)

enum { SHEATHED, DRAWING, READY, ATTACKING, SHEATHING, CHARGING, DROPPED }

const DRAW_TIME := 0.22
const SHEATHE_AFTER := 5.0
const HAND_R := -0.45        # metres along the staff from its centre (toward the butt)
const HAND_L := -0.10
const SHOULDER := Vector3(0.21, 1.48, -0.06)   # body space, left shoulder (mirror for right)
const REACH := 0.43          # shoulder-to-wrist reach used for the grips (arm is 0.47 m)
const TRAIL_LIFE := 0.14
# per hit of the string: stamina cost, impact power (scales hit-stop, shake, knockback, VFX)
const COST := [9.0, 9.0, 14.0, 12.0]
const POWER := [1.0, 1.0, 1.6, 1.25]
const HITSTOP := 0.065       # seconds of freeze per unit of power

# Heavy: hold time at which each tier is reached, stamina cost and power per tier.
const PARRY_WINDOW := 0.25
const PARRY_HITSTOP := 0.13
const RAISE_TIME := 0.18     # guard -> overhead
const MIN_CHARGE := 0.16     # a tap still raises the staff before it comes down
const CHARGE_TIERS := [0.0, 0.5, 1.1]
const CHARGE_MAX := 2.6      # held this long, it comes down by itself
const HEAVY_COST := [16.0, 22.0, 28.0]
const HEAVY_POWER := [1.8, 2.4, 3.2]
const SLAM_AT := 0.40        # normalised time the smash meets the ground
# Raised overhead, tip back over the shoulders, chest turned a little away.
const RAISED := [3.0, 137.0, Vector3(-0.20, 1.70, -0.04), -15.0]
const HEAVY := { "dur": 0.84, "hit": [0.22, 0.54], "lunge": 4.0, "lunge_at": 0.0, "spin": 0.0, "keys": [
	[0.00, 3.0, 137.0, Vector3(-0.20, 1.70, -0.04), -15.0],
	[0.12, 3.0, 143.0, Vector3(-0.15, 1.70, 0.03), 9.0],
	[0.40, 4.0, -40.0, Vector3(-0.21, 1.23, 0.61), -55.0, -0.26],
	[0.70, 2.0, -38.0, Vector3(-0.14, 1.35, 0.30), -3.0],
	[0.86, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],
	[1.00, 45.0, -12.0, Vector3(0.08, 1.15, 0.36), -24.0, -0.03]]}

# Guard: a diagonal mid guard -- rear hand low at the right flank, front hand at the belt,
# tip forward-left and down at knee-to-hip height (was held at shoulder height like a yoke).  [yaw°, pitch°, P, twist°]
const GUARD := [45.0, -12.0, Vector3(0.08, 1.15, 0.36), -24.0, -0.03]
# Chest-high pass the arms ease through on the way back down to GUARD, so the shaft swings
# out in front of the body instead of cutting through the chest (tools/pose_check.py).
const CHAMBER := [35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03]

# Each attack: duration (s), strike window (t0, t1 normalised), lunge m/s during the strike,
# body spin (rad over the clip), keys [t, yaw°, pitch°, P, twist°, grip slide m (optional)].
# Body space: +Z forward, +X is the hero's left, so yaw -90 points out to the right.
const STRING := [
	{ "dur": 0.62, "hit": [0.30, 0.55], "lunge": 2.5, "spin": 0.0, "keys": [
		[0.00, 45.0, -12.0, Vector3(0.08, 1.15, 0.36), -24.0, -0.03],
		[0.10, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],    # chamber: staff up to the chest
		[0.28, -131.0, 10.0, Vector3(-0.13, 1.57, 0.08), 24.0, 0.11],
		[0.52, 95.0, -6.0, Vector3(0.31, 1.47, 0.24), 37.0],
		[1.00, 41.0, -12.0, Vector3(0.07, 1.28, 0.35), 4.0, -0.03]]},
	{ "dur": 0.58, "hit": [0.25, 0.52], "lunge": 2.0, "spin": 0.0, "keys": [
		[0.00, 41.0, -12.0, Vector3(0.07, 1.28, 0.35), 4.0, -0.03],
		[0.24, 118.0, 8.0, Vector3(0.13, 1.52, 0.14), 37.0],
		[0.50, -100.0, 0.0, Vector3(-0.34, 1.51, 0.07), -46.0],
		[1.00, -16.0, -12.0, Vector3(0.08, 1.34, 0.50), -13.0, -0.03]]},
	{ "dur": 0.80, "hit": [0.42, 0.62], "lunge": 3.5, "spin": 0.0, "keys": [
		[0.00, -16.0, -12.0, Vector3(0.08, 1.34, 0.50), -13.0, -0.03],
		[0.38, -20.0, 106.0, Vector3(0.15, 1.98, 0.09), -14.0],
		[0.60, -4.0, -28.0, Vector3(0.13, 1.28, 0.56), -21.0, -0.05],
		[1.00, 9.0, -23.0, Vector3(0.27, 1.33, 0.52), -15.0, -0.06]]},
	{ "dur": 0.85, "hit": [0.25, 0.75], "lunge": 2.0, "spin": TAU, "keys": [
		[0.00, 9.0, -23.0, Vector3(0.27, 1.33, 0.52), -15.0, -0.06],
		[0.20, -95.0, 2.0, Vector3(-0.32, 1.42, 0.12), -38.0],
		[0.30, -95.0, 2.0, Vector3(-0.62, 1.43, 0.09), -38.0, -0.30],    # staff runs out through the hands
		[0.75, -98.0, 4.0, Vector3(-0.64, 1.57, 0.13), -34.0, -0.30],
		[0.86, -98.0, 4.0, Vector3(-0.30, 1.55, 0.18), -34.0, 0.04],
		[0.94, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],
		[1.00, 45.0, -12.0, Vector3(0.08, 1.15, 0.36), -24.0, -0.03]]},
]

var player: Player
var staff: Staff
var skel: Skeleton3D
var state := SHEATHED
var step := -1
var t := 0.0                 # seconds into the current attack / transition
var idle_t := 0.0
var queued := false
var hit_active := false
var dip := 0.0                 # rad the swing plane tips forward-down onto a low foe (a hound)
const LOW_DIP := 0.55          # full tip toward a low target in front
var spin_delta := 0.0        # body yaw the current attack added this frame
var _spin_applied := 0.0     # last frame's spin_delta, which the body turned by this frame
var swings := 0              # attacks started (bots read this)
var last_grip_error := 0.0   # metres, hand bone to IK target after the last IK pass
var hitstop := 0.0           # remaining freeze after a connecting hit
var hits := 0                # hits landed (bots read this)
var _hit_this_swing: Array = []
var _atk: Dictionary = {}    # the attack in progress (a STRING entry or HEAVY)
var _power := 1.0
var heavy_held := false      # the player sets this every tick from the heavy button
var _heavy_queued := false
var charge_t := 0.0          # seconds into the current charge
var tier := 0                # charge tier reached (0..2)
var heavies := 0             # heavy smashes released (bots read this)
var parries := 0             # blows deflected (bots read this)
var last_power := 0.0        # power of the last hit that landed (bots read this)
var _slammed := false
var _raise_from: Array = GUARD
var _prev_u := -1.0          # normalised swing time at the last contact test
const RECOVER_TIME := 0.26
var _recover := 0.0          # remaining blend from a cancelled swing back to guard
var _from_pose: Array = GUARD
var _recover_keys: Array = []  # the path picked by _begin_recover (keys [t] + pose)

var _back_slot: Node3D
var _back_xform: Transform3D
var _wield: Node3D
var _from_xform: Transform3D
var _target_r: Node3D
var _target_l: Node3D
var _ik: TwoBoneIK3D
var _twist: SpineTwist
var _blend := 0.0            # IK/twist influence, eased in on draw
var _spun := 0.0
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array = []   # [age, tip, mid]

func setup(p: Player, s: Staff, sk: Skeleton3D) -> void:
	player = p
	staff = s
	skel = sk
	_back_slot = staff.get_parent()
	_back_xform = staff.transform
	_wield = Node3D.new()
	_wield.name = "Wield"
	player.body.add_child(_wield)
	_target_r = _marker("GripR")
	_target_l = _marker("GripL")
	var pole_r := _marker("PoleR")
	var pole_l := _marker("PoleL")
	# elbows bend down and out, away from the shaft
	pole_r.position = Vector3(-0.75, 0.7, -0.35)
	pole_l.position = Vector3(0.75, 0.7, -0.35)

	_twist = SpineTwist.new()
	_twist.name = "SpineTwist"
	skel.add_child(_twist)
	_twist.up = player.body
	_ik = TwoBoneIK3D.new()
	_ik.name = "ArmIK"
	skel.add_child(_ik)
	_ik.setting_count = 2
	var arms := [["Right", _target_r, pole_r], ["Left", _target_l, pole_l]]
	for i in 2:
		var side: String = arms[i][0]
		_ik.set_root_bone_name(i, "mixamorig_%sArm" % side)
		_ik.set_middle_bone_name(i, "mixamorig_%sForeArm" % side)
		_ik.set_end_bone_name(i, "mixamorig_%sHand" % side)
		_ik.set_target_node(i, _ik.get_path_to(arms[i][1]))
		_ik.set_pole_node(i, _ik.get_path_to(arms[i][2]))
	_set_influence(0.0)
	# the modified pose only exists right after the modifiers ran; sample the grip there
	_ik.modification_processed.connect(func(): last_grip_error = _measure_grip())

	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.name = "SwingTrail"
	_trail.top_level = true
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/swing_trail.gdshader")
	_trail.material_override = mat
	player.add_child(_trail)

func _marker(n: String) -> Node3D:
	var m := Node3D.new()
	m.name = n
	_wield.add_child(m)
	return m

func _set_influence(v: float) -> void:
	_blend = v
	_ik.influence = v
	_ik.active = v > 0.001
	_twist.influence = v
	_twist.active = v > 0.001

func is_drawn() -> bool:
	return state != SHEATHED

func is_attacking() -> bool:
	return state == ATTACKING

func is_charging() -> bool:
	return state == CHARGING

func current_attack() -> Dictionary:
	return _atk

## The released heavy is committed from the moment it starts down until the strike has passed:
## a blow landing then is taken without breaking the swing.
func has_hyper_armour() -> bool:
	return state == ATTACKING and _atk == HEAVY and t / float(_atk["dur"]) < float(_atk["hit"][1])

## Heavy pressed: start raising the staff (drawing it first if slung). During a light swing
## it cuts in once the strike has passed, otherwise it waits for the swing to finish.
func heavy() -> void:
	match state:
		SHEATHED, SHEATHING:
			_begin_draw()
			_heavy_queued = true
			queued = false
		DRAWING:
			_heavy_queued = true
			queued = false
		READY:
			_start_charge()
		ATTACKING:
			if _atk == HEAVY:
				return
			var u := t / float(_atk["dur"])
			if u > float(_atk["hit"][1]):
				_from_pose = _pose_at(_atk["keys"], clampf(u, 0.0, 1.0))
				_start_charge(_from_pose)
			else:
				_heavy_queued = true
				queued = false

func _start_charge(from: Array = []) -> void:
	if player.stamina <= 0.0:
		return
	if from.size() > 0:
		_raise_from = from
	elif _recover > 0.0 and _recover_keys.size() > 1:
		# raise from where the ease back to guard has got to, not from where it began
		_raise_from = _pose_at(_recover_keys, 1.0 - _recover / RECOVER_TIME)
		_raise_from[0] = wrapf(_raise_from[0], -180.0, 180.0)
	else:
		_raise_from = GUARD
	_recover = 0.0
	state = CHARGING
	step = -1
	charge_t = 0.0
	tier = 0
	t = 0.0
	queued = false
	_heavy_queued = false
	hit_active = false
	idle_t = 0.0

## True while a blow landing now would be deflected: the opening of the heavy's raise.
func can_parry() -> bool:
	return state == CHARGING and charge_t <= PARRY_WINDOW and hitstop <= 0.0

## Enemies' blows ask this first. A deflect freezes both fighters, throws sparks off the
## shaft, staggers the attacker and banks a free charge tier.
func try_parry(attacker: Node) -> bool:
	if not can_parry():
		return false
	parries += 1
	hitstop = PARRY_HITSTOP
	var to := player.body.global_basis.z
	if attacker is Node3D:
		to = (attacker as Node3D).global_position - player.global_position
	to.y = 0.0
	to = to.normalized() if to.length() > 1e-3 else player.body.global_basis.z
	var spark := staff.global_transform * Vector3(0, Staff.LENGTH * 0.18, 0)
	spark = spark.lerp(player.global_position + Vector3.UP * 1.5 + to * 0.45, 0.5)
	ImpactFX.spawn(player.get_parent(), spark, to.cross(Vector3.UP), "metal", 1.6)
	player.add_shake(0.42)
	charge_t = maxf(charge_t, float(CHARGE_TIERS[1]))
	_set_tier(1)
	if attacker.has_method("parried"):
		attacker.parried(to, PARRY_HITSTOP)
	parried.emit(attacker)
	return true

func _set_tier(n: int) -> void:
	if n <= tier:
		return
	tier = n
	# a cold glint off the ferrule marks each tier
	ImpactFX.spawn(player.get_parent(), tip_position(), Vector3.UP, "metal", 0.35 + 0.2 * n)
	player.add_shake(0.06 * n)
	charge_tier.emit(n)

func _release() -> void:
	var cost: float = HEAVY_COST[tier]
	player.stamina = maxf(player.stamina - cost, 0.0)
	_atk = HEAVY
	_power = HEAVY_POWER[tier]
	_hit_this_swing.clear()
	_prev_u = -1.0
	_slammed = false
	step = -1
	t = 0.0
	_spun = 0.0
	queued = false
	idle_t = 0.0
	state = ATTACKING
	swings += 1
	heavies += 1
	swing_started.emit(-1)

## Light attack pressed: draw if needed, start or queue the next hit of the string.
func light() -> void:
	match state:
		SHEATHED, SHEATHING:
			_begin_draw()
			queued = true
		DRAWING:
			queued = true
		READY:
			_start(0)
		ATTACKING:
			if t / float(_atk["dur"]) > 0.35 and not _heavy_queued:
				queued = true

## A dodge breaks off whatever swing is in progress; the arms ease back to guard from the
## pose they were in instead of snapping.
func cancel_to_guard() -> void:
	_heavy_queued = false
	if state == CHARGING:
		_from_pose = _charge_pose()
	elif state == ATTACKING:
		_from_pose = _pose_at(_atk["keys"], clampf(t / float(_atk["dur"]), 0.0, 1.0))
	else:
		return
	_begin_recover()
	state = READY
	step = -1
	queued = false
	idle_t = 0.0
	hit_active = false
	_prev_u = -1.0

## The hero has fallen: the arms let go and a drawn staff drops and topples flat into the
## grass beside the body (a slung one stays on the back).
var _drop_rest := Basis()
var _drop_v := 0.0

func drop() -> void:
	cancel_to_guard()
	_heavy_queued = false
	queued = false
	hitstop = 0.0
	_set_influence(0.0)
	_twist.twist = 0.0
	if staff.get_parent() == _back_slot:
		staff.transform = _back_xform
		state = SHEATHED
		return
	staff.reparent(player.get_parent(), true)
	var flat := Vector3(staff.global_basis.y.x, 0.0, staff.global_basis.y.z)
	if flat.length() < 0.1:
		flat = player.body.global_basis.x
	_drop_rest = Basis(Quaternion(Vector3.UP, flat.normalized()))
	_drop_v = 0.0
	state = DROPPED

## Back on the hero's back after a rest.
func restore() -> void:
	staff.reparent(_back_slot, false)
	staff.transform = _back_xform
	_set_influence(0.0)
	_twist.twist = 0.0
	state = SHEATHED
	step = -1
	queued = false
	_heavy_queued = false
	hitstop = 0.0
	_recover = 0.0

func _begin_draw() -> void:
	staff.reparent(_wield, true)
	_from_xform = staff.transform
	state = DRAWING
	t = 0.0

func _start(i: int) -> void:
	if player.stamina <= 0.0:
		# winded: the string breaks off, back to guard
		state = READY
		step = -1
		queued = false
		idle_t = 0.0
		return
	player.stamina = maxf(player.stamina - float(COST[i]), 0.0)
	_atk = STRING[i]
	_power = POWER[i]
	_hit_this_swing.clear()
	_prev_u = -1.0
	step = i
	t = 0.0
	_spun = 0.0
	queued = false
	idle_t = 0.0
	state = ATTACKING
	swings += 1
	swing_started.emit(i)

## Body-space pose of the current attack at normalised time u.
func _pose_at(keys: Array, u: float) -> Array:
	return _pose_at_static(keys, u)

static func dir_of(yaw_deg: float, pitch_deg: float) -> Vector3:
	var y := deg_to_rad(yaw_deg)
	var p := deg_to_rad(pitch_deg)
	return Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))

func physics_step(delta: float) -> void:
	_spin_applied = spin_delta
	spin_delta = 0.0
	if hitstop > 0.0:
		# frozen in the contact: pose, IK and twist hold; only the trail keeps fading
		hitstop -= delta
		_age_trail(delta)
		return
	hit_active = false
	var pose: Array = GUARD
	match state:
		SHEATHED:
			_age_trail(delta)
			return
		DROPPED:
			# falls under gravity to rest on the ground, tipping flat as it goes
			var ground := player.global_position.y + 0.03
			_drop_v += 9.8 * delta
			staff.global_position.y = maxf(staff.global_position.y - _drop_v * delta, ground)
			staff.global_basis = staff.global_basis.slerp(_drop_rest, minf(delta * 4.0, 1.0))
			_age_trail(delta)
			return
		DRAWING:
			t += delta
			var f := clampf(t / DRAW_TIME, 0.0, 1.0)
			staff.transform = _from_xform.interpolate_with(_place_hands(GUARD), f)
			_set_influence(f)
			if f >= 1.0:
				state = READY
				idle_t = 0.0
				if _heavy_queued:
					_start_charge()
				elif queued:
					_start(0)
			_age_trail(delta)
			return
		READY:
			if _recover > 0.0:
				_recover = maxf(_recover - delta, 0.0)
				pose = _pose_at(_recover_keys, 1.0 - _recover / RECOVER_TIME)
				if _recover <= 0.0:
					pose = GUARD   # drop any +-360 yaw the path wrapped through
			idle_t += delta
			if idle_t > SHEATHE_AFTER:
				staff.reparent(_back_slot, true)
				_from_xform = staff.transform
				state = SHEATHING
				t = 0.0
		CHARGING:
			charge_t += delta
			idle_t = 0.0
			pose = _charge_pose()
			for n in range(CHARGE_TIERS.size() - 1, 0, -1):
				if charge_t >= float(CHARGE_TIERS[n]):
					_set_tier(n)
					break
			if (not heavy_held and charge_t >= MIN_CHARGE) or charge_t >= CHARGE_MAX:
				_release()
				pose = _pose_at(_atk["keys"], 0.0)
		ATTACKING:
			var atk: Dictionary = _atk
			var dur: float = atk["dur"]
			t += delta
			var u := clampf(t / dur, 0.0, 1.0)
			pose = _pose_at(atk["keys"], u)
			var hw: Array = atk["hit"]
			hit_active = u >= float(hw[0]) and u <= float(hw[1])
			var spin: float = atk["spin"]
			if spin != 0.0:
				var target := spin * smoothstep(0.15, 0.8, u)
				spin_delta = target - _spun
				_spun = target
			if atk == HEAVY and not _slammed and u >= SLAM_AT:
				_slammed = true
				_ground_slam()
			if u >= 1.0:
				if _heavy_queued:
					_start_charge(pose)
				elif queued:
					_start((step + 1) % STRING.size())
				else:
					# the string ends: settle from the follow-through down into the low guard
					_from_pose = _pose_at(_atk["keys"], 1.0)
					_begin_recover()
					state = READY
					idle_t = 0.0
					step = -1
		SHEATHING:
			t += delta
			var f := clampf(t / DRAW_TIME, 0.0, 1.0)
			staff.transform = _from_xform.interpolate_with(_back_xform, f)
			_set_influence(1.0 - f)
			_place_hands(GUARD)
			if f >= 1.0:
				staff.transform = _back_xform
				_set_influence(0.0)
				state = SHEATHED
			_age_trail(delta)
			return
	var want_dip := LOW_DIP if is_attacking() and _low_target_ahead() else 0.0
	dip = lerpf(dip, want_dip, 1.0 - exp(-12.0 * delta))
	staff.transform = _place_hands(pose)
	_twist.twist = deg_to_rad(pose[3])
	if hit_active:
		_detect_hits(t / float(_atk["dur"]))
	else:
		_prev_u = -1.0
	_update_trail(delta)

# --- contact: the whole shaft is swept between ticks against each hittable's capsule ---

func _detect_hits(u: float) -> void:
	var atk: Dictionary = _atk
	var u0 := _prev_u if _prev_u >= 0.0 else u
	_prev_u = u
	# re-evaluate the authored arc at ~4 ms sub-steps: at low frame rates one tick can sweep
	# the staff through 90°+, and a straight line between the two poses would cut inside it.
	# A spinning attack also turns the body (by last frame's spin_delta, applied before this
	# step), so the sub-steps turn it back too, or the shaft tunnels past a target.
	var n := clampi(int(ceil((u - u0) * float(atk["dur"]) / 0.004)), 1, 24)
	if _spin_applied != 0.0:
		n = maxi(n, clampi(int(ceil(absf(_spin_applied) / 0.05)), 1, 24))
	var segs: Array = []
	var bx := player.body.global_transform
	for k in n + 1:
		var f := float(k) / n
		var bk := Transform3D(bx.basis.rotated(Vector3.UP, -_spin_applied * (1.0 - f)), bx.origin)
		var xf := bk * _staff_xform(_pose_at(atk["keys"], lerpf(u0, u, f)))
		segs.append([xf * Vector3(0, -Staff.LENGTH * 0.5, 0), xf * Vector3(0, Staff.LENGTH * 0.5, 0)])
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if target in _hit_this_swing or not target.has_method("hurt_capsule"):
			continue
		var cap: Array = target.hurt_capsule()
		if (cap[0] as Vector3).distance_to(player.global_position) > 4.0:
			continue
		for k in segs.size():
			var a: Vector3 = segs[k][0]
			var b: Vector3 = segs[k][1]
			var pts := Geometry3D.get_closest_points_between_segments(a, b, cap[0], cap[1])
			if pts[0].distance_to(pts[1]) <= float(cap[2]) + 0.03:
				var prev_tip: Vector3 = segs[maxi(k - 1, 0)][1]
				var swing := b - prev_tip
				if swing.length() < 1e-4:
					swing = (b - a).cross(Vector3.UP)
				var out := pts[0] - pts[1]
				out.y = 0.0
				var point := pts[1] + (out.normalized() * float(cap[2]) if out.length() > 1e-4 else Vector3.ZERO)
				_land_hit(target, point, swing.normalized())
				break

## Nearest hittable's centre within `dist` and `half_angle` (rad) of the facing, or INF.
func magnet_target(dist: float, half_angle: float) -> Vector3:
	var face := player.body.global_basis.z
	var best := Vector3.INF
	var best_d := dist
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if not target.has_method("hurt_capsule"):
			continue
		var c: Vector3 = target.hurt_capsule()[0]
		var to := c - player.global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and d > 0.05 and face.angle_to(to) < half_angle:
			best = c
			best_d = d
	return best

## True when a hittable stands within lunge-stopping range ahead of the hero.
func target_in_reach(dist: float) -> bool:
	var bx := player.body.global_transform
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if not target.has_method("hurt_capsule"):
			continue
		var c: Vector3 = target.hurt_capsule()[0]
		var l := bx.affine_inverse() * c
		if l.z > 0.0 and Vector2(l.x, l.z).length() < dist + float(target.hurt_capsule()[2]):
			return true
	return false

func _land_hit(target: Node, point: Vector3, swing: Vector3) -> void:
	var power: float = _power
	_hit_this_swing.append(target)
	hits += 1
	last_power = power
	hitstop = HITSTOP * power
	target.take_hit(point, swing, power, hitstop)
	var kind: String = target.get("impact_kind") if target.get("impact_kind") != null else "wood"
	ImpactFX.spawn(player.get_parent(), point, swing, kind, power)
	player.add_shake(0.32 * power)
	hit_landed.emit(target, point, power)

## Staff overhead, easing up from wherever the arms were; a tremble grows with the charge.
func _charge_pose() -> Array:
	var f := clampf(charge_t / RAISE_TIME, 0.0, 1.0)
	var k: Array = [[0.0] + _raise_from, [1.0] + RAISED]
	var pose := _pose_at(k, f)
	var shake := 0.6 + 1.2 * float(tier)
	pose[0] += sin(charge_t * 47.0) * shake * f
	pose[1] += sin(charge_t * 39.0 + 1.3) * shake * 0.6 * f + 4.0 * float(tier) * f
	return pose

## The smash meets the ground ahead: a burst of soil and grit, and the camera feels it.
func _ground_slam() -> void:
	var tip := tip_position()
	var at := Vector3(tip.x, player.global_position.y + 0.05, tip.z)
	ImpactFX.spawn(player.get_parent(), at, Vector3.DOWN, "stone", 0.8 + 0.35 * float(tier))
	player.add_shake(0.18 + 0.1 * float(tier))
	slammed.emit(at, 0.8 + 0.35 * float(tier))

## Puts both grips on the authored staff line, pulls each into its shoulder's reach (the
## shoulders turn with the spine twist), then lays the staff through the two grips.
## Returns the staff's body-space transform.
func _place_hands(pose: Array) -> Transform3D:
	var r := _solve(pose)
	_target_r.position = r[1]
	_target_l.position = r[2]
	return r[0]

func _staff_xform(pose: Array) -> Transform3D:
	return _solve(pose)[0]

## [staff body-space transform, right grip, left grip] for a pose.
func _solve(pose: Array) -> Array:
	var d := dir_of(pose[0], pose[1])
	var p: Vector3 = pose[2]
	if dip > 0.001:
		# tip the whole swing forward and down about the chest so it meets a low foe
		var rb := Basis(Vector3.RIGHT, dip)
		var piv := Vector3(0, 1.3, 0)
		d = rb * d
		p = piv + rb * (p - piv)
	var tw := deg_to_rad(pose[3])
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var sr := Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z).rotated(Vector3.UP, tw)
	# optional 5th element slides both grips along the shaft (negative = toward the butt,
	# the long grip of an overhead strike; P stays the staff's centre)
	var slide: float = pose[4] if pose.size() > 4 else 0.0
	var hr := _clamp_reach(p + d * (HAND_R + slide), sr)
	var hl := _clamp_reach(p + d * (HAND_L + slide), sl)
	var axis := hl - hr
	if axis.length() < 0.12:
		axis = d * 0.12
	var d2 := axis.normalized()
	var b := Basis(Quaternion(Vector3.UP, d2)) if d2.y > -0.99 else Basis(Vector3.RIGHT, PI)
	return [Transform3D(b, hr - d2 * (HAND_R + slide)), hr, hl]

## Starts the ease from `_from_pose` back down to GUARD. A straight blend from a pose with the
## shaft out to the side swings the butt through the chest (a dodge out of string swing 2
## did), so it scores a few candidate paths -- turning the shaft either way round, with or
## without dipping/lifting the tip or pushing the hands out first -- by their worst torso
## clearance and takes the clearest (tools/pose_check.py's model; checked offline: worst
## clearance over every cancel point 0.63 torso radii, was 0.01).
func _begin_recover() -> void:
	_recover = RECOVER_TIME
	_recover_keys = best_recover_path(_from_pose)

static func best_recover_path(from: Array) -> Array:
	var f: Array = from.duplicate()
	if f.size() < 5:
		f.append(0.0)
	var best: Array = []
	var best_gap := -1.0
	for wrap in [0.0, -360.0, 360.0]:
		var ch: Array = CHAMBER.duplicate()
		ch[0] += wrap
		var gu: Array = GUARD.duplicate()
		gu[0] += wrap
		for via in ["", "fwd", -55.0, -30.0, 30.0, 55.0]:
			var keys: Array = [[0.0] + f]
			var fp: Vector3 = f[2]
			if via is String and via == "fwd":
				keys.append([0.3, f[0], f[1], Vector3(fp.x * 0.5, fp.y, maxf(fp.z, 0.55)), f[3], 0.0])
			elif not via is String:
				keys.append([0.3, lerpf(f[0], ch[0], 0.4), via, Vector3(fp.x * 0.5, 1.35, maxf(fp.z, 0.45)), f[3], 0.0])
			keys.append([0.62] + ch)
			keys.append([1.0] + gu)
			var g := path_clearance(keys)
			if g > best_gap + 0.01:   # ties keep the earlier (plainer) path
				best_gap = g
				best = keys
	return best

## Worst torso clearance (torso radii, 1.0 = touching) along a key path, 24 samples.
static func path_clearance(keys: Array) -> float:
	var worst := 9.0
	for j in range(1, 25):
		var pz: Array = _pose_at_static(keys, j / 24.0)
		worst = minf(worst, torso_clearance(pz))
	return worst

static func _pose_at_static(keys: Array, u: float) -> Array:
	var k := 0
	while k < keys.size() - 2 and u > float(keys[k + 1][0]):
		k += 1
	var a: Array = keys[k]
	var b: Array = keys[k + 1]
	var f := clampf((u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var sa: float = a[5] if a.size() > 5 else 0.0
	var sb: float = b[5] if b.size() > 5 else 0.0
	return [lerpf(a[1], b[1], f), lerpf(a[2], b[2], f), (a[3] as Vector3).lerp(b[3], f), lerpf(a[4], b[4], f), lerpf(sa, sb, f)]

## The staff's clearance from the chest/head for one pose, body space, no dip (same model
## as tools/pose_check.py: chest ellipse 0.17 x 0.12 m for y 0.9-1.5, head ellipsoid above).
static func torso_clearance(pose: Array) -> float:
	var d := dir_of(pose[0], pose[1])
	var p: Vector3 = pose[2]
	var tw := deg_to_rad(pose[3])
	var slide: float = pose[4] if pose.size() > 4 else 0.0
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var sr := Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z).rotated(Vector3.UP, tw)
	var hr := _clamp_reach(p + d * (HAND_R + slide), sr)
	var hl := _clamp_reach(p + d * (HAND_L + slide), sl)
	var ax := hl - hr
	var a := ax.normalized() if ax.length() > 1e-4 else d
	var c := hr - a * (HAND_R + slide)
	var e0 := c - a * 0.93
	var e1 := c + a * 0.93
	var best := 9.0
	for i in 41:
		var x := e0.lerp(e1, i / 40.0)
		if x.y >= 0.9 and x.y <= 1.5:
			best = minf(best, Vector2(x.x / 0.17, (x.z + 0.02) / 0.12).length())
		elif x.y > 1.5 and x.y <= 1.8:
			best = minf(best, Vector3(x.x / 0.11, (x.z - 0.01) / 0.12, (x.y - 1.66) / 0.14).length())
	return best

static func _clamp_reach(h: Vector3, shoulder: Vector3) -> Vector3:
	var v := h - shoulder
	return shoulder + v.limit_length(REACH)

## Grip error in metres (hand bone origin to its IK target), for bots.
func grip_error() -> float:
	return last_grip_error

func _measure_grip() -> float:
	var e := 0.0
	for side in [["Right", _target_r], ["Left", _target_l]]:
		var b := skel.find_bone("mixamorig_%sHand" % side[0])
		var hp := skel.global_transform * skel.get_bone_global_pose(b).origin
		e = maxf(e, hp.distance_to((side[1] as Node3D).global_position))
	return e

## A living low foe (one that sets `low_target`, e.g. a Briar Hound) close in front.
func _low_target_ahead() -> bool:
	var face := player.body.global_basis.z
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if target.get("low_target") != true:
			continue
		var to: Vector3 = (target as Node3D).global_position - player.global_position
		to.y = 0.0
		if to.length() < 3.4 and face.angle_to(to) < 1.3:
			return true
	return false

func tip_position() -> Vector3:
	return staff.global_transform * Vector3(0, Staff.LENGTH * 0.5, 0)

# --- swing trail: a ribbon between the tip and the upper shaft, fading with age ---

func _update_trail(delta: float) -> void:
	if hit_active:
		var mid := staff.global_transform * Vector3(0, Staff.LENGTH * 0.12, 0)
		_trail_pts.push_front([0.0, tip_position(), mid])
	_age_trail(delta)

func _age_trail(delta: float) -> void:
	for p in _trail_pts:
		p[0] += delta
	while _trail_pts.size() > 0 and float(_trail_pts.back()[0]) > TRAIL_LIFE:
		_trail_pts.pop_back()
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _trail_pts:
		var a := 1.0 - float(p[0]) / TRAIL_LIFE
		_trail_mesh.surface_set_color(Color(1, 1, 1, a))
		_trail_mesh.surface_set_uv(Vector2(1.0 - a, 0.0))
		_trail_mesh.surface_add_vertex(p[1])
		_trail_mesh.surface_set_color(Color(1, 1, 1, a))
		_trail_mesh.surface_set_uv(Vector2(1.0 - a, 1.0))
		_trail_mesh.surface_add_vertex(p[2])
	_trail_mesh.surface_end()
