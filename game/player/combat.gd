class_name StaffCombat
extends Node
## Ward-stance light string. The staff's path is authored in body space as keyed poses
## (direction yaw/pitch + grip-centre position + spine twist); both hands are solved onto the
## shaft with two-bone IK and the torso twists into each swing, so the arms, chest and staff
## move as one over whatever the legs are doing in the locomotion blend.
## Attack: sweep -> backhand -> overhead slam -> spinning sweep. Idle 5 s -> staff slung back.

signal swing_started(step: int)
signal hit_landed(target: Node, point: Vector3, power: float)

enum { SHEATHED, DRAWING, READY, ATTACKING, SHEATHING }

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

# Guard: staff low across the body, tip forward-left.  [yaw°, pitch°, P, twist°]
const GUARD := [28.0, -14.0, Vector3(0.02, 1.0, 0.55), 0.0]

# Each attack: duration (s), strike window (t0, t1 normalised), lunge m/s during the strike,
# body spin (rad over the clip), keys [t, yaw°, pitch°, P, twist°].
# Body space: +Z forward, +X is the hero's left, so yaw -90 points out to the right.
const STRING := [
	{ "dur": 0.62, "hit": [0.30, 0.55], "lunge": 2.5, "spin": 0.0, "keys": [
		[0.00, 28.0, -14.0, Vector3(0.02, 1.00, 0.55), 0.0],
		[0.28, -125.0, 4.0, Vector3(-0.30, 1.22, 0.22), -38.0],
		[0.52, 95.0, -6.0, Vector3(0.28, 1.12, 0.40), 34.0],
		[1.00, 40.0, -12.0, Vector3(0.08, 1.05, 0.52), 8.0]]},
	{ "dur": 0.58, "hit": [0.25, 0.52], "lunge": 2.0, "spin": 0.0, "keys": [
		[0.00, 40.0, -12.0, Vector3(0.08, 1.05, 0.52), 8.0],
		[0.24, 118.0, 8.0, Vector3(0.30, 1.25, 0.25), 36.0],
		[0.50, -100.0, 2.0, Vector3(-0.28, 1.18, 0.42), -34.0],
		[1.00, -20.0, -10.0, Vector3(-0.05, 1.05, 0.55), -6.0]]},
	{ "dur": 0.80, "hit": [0.42, 0.62], "lunge": 3.5, "spin": 0.0, "keys": [
		[0.00, -20.0, -10.0, Vector3(-0.05, 1.05, 0.55), -6.0],
		[0.38, 0.0, 128.0, Vector3(0.00, 2.00, 0.00), -12.0],
		[0.60, 0.0, -28.0, Vector3(0.00, 1.05, 0.62), 6.0],
		[1.00, 10.0, -22.0, Vector3(0.00, 1.02, 0.58), 0.0]]},
	{ "dur": 0.85, "hit": [0.25, 0.75], "lunge": 2.0, "spin": TAU, "keys": [
		[0.00, 10.0, -22.0, Vector3(0.00, 1.02, 0.58), 0.0],
		[0.20, -95.0, 2.0, Vector3(-0.28, 1.18, 0.30), -30.0],
		[0.75, -95.0, 0.0, Vector3(-0.28, 1.15, 0.32), -30.0],
		[1.00, 28.0, -14.0, Vector3(0.02, 1.00, 0.55), 0.0]]},
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
var spin_delta := 0.0        # body yaw the current attack added this frame
var swings := 0              # attacks started (bots read this)
var last_grip_error := 0.0   # metres, hand bone to IK target after the last IK pass
var hitstop := 0.0           # remaining freeze after a connecting hit
var hits := 0                # hits landed (bots read this)
var _hit_this_swing: Array = []
var _prev_u := -1.0          # normalised swing time at the last contact test
const RECOVER_TIME := 0.16
var _recover := 0.0          # remaining blend from a cancelled swing back to guard
var _from_pose: Array = GUARD

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
			if t / float(STRING[step]["dur"]) > 0.35:
				queued = true

## A dodge breaks off whatever swing is in progress; the arms ease back to guard from the
## pose they were in instead of snapping.
func cancel_to_guard() -> void:
	if state != ATTACKING:
		return
	_from_pose = _pose_at(STRING[step]["keys"], clampf(t / float(STRING[step]["dur"]), 0.0, 1.0))
	_recover = RECOVER_TIME
	state = READY
	step = -1
	queued = false
	idle_t = 0.0
	hit_active = false
	_prev_u = -1.0

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
	var k := 0
	while k < keys.size() - 2 and u > float(keys[k + 1][0]):
		k += 1
	var a: Array = keys[k]
	var b: Array = keys[k + 1]
	var f := clampf((u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	return [lerpf(a[1], b[1], f), lerpf(a[2], b[2], f), (a[3] as Vector3).lerp(b[3], f), lerpf(a[4], b[4], f)]

static func dir_of(yaw_deg: float, pitch_deg: float) -> Vector3:
	var y := deg_to_rad(yaw_deg)
	var p := deg_to_rad(pitch_deg)
	return Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))

func physics_step(delta: float) -> void:
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
		DRAWING:
			t += delta
			var f := clampf(t / DRAW_TIME, 0.0, 1.0)
			staff.transform = _from_xform.interpolate_with(_place_hands(GUARD), f)
			_set_influence(f)
			if f >= 1.0:
				state = READY
				idle_t = 0.0
				if queued:
					_start(0)
			_age_trail(delta)
			return
		READY:
			if _recover > 0.0:
				_recover = maxf(_recover - delta, 0.0)
				var k: Array = [[0.0] + _from_pose, [1.0] + GUARD]
				pose = _pose_at(k, 1.0 - _recover / RECOVER_TIME)
			idle_t += delta
			if idle_t > SHEATHE_AFTER:
				staff.reparent(_back_slot, true)
				_from_xform = staff.transform
				state = SHEATHING
				t = 0.0
		ATTACKING:
			var atk: Dictionary = STRING[step]
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
			if u >= 1.0:
				if queued:
					_start((step + 1) % STRING.size())
				else:
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
	staff.transform = _place_hands(pose)
	_twist.twist = deg_to_rad(pose[3])
	if hit_active:
		_detect_hits(t / float(STRING[step]["dur"]))
	else:
		_prev_u = -1.0
	_update_trail(delta)

# --- contact: the whole shaft is swept between ticks against each hittable's capsule ---

func _detect_hits(u: float) -> void:
	var atk: Dictionary = STRING[step]
	var u0 := _prev_u if _prev_u >= 0.0 else u
	_prev_u = u
	# re-evaluate the authored arc at ~4 ms sub-steps: at low frame rates one tick can sweep
	# the staff through 90°+, and a straight line between the two poses would cut inside it
	var n := clampi(int(ceil((u - u0) * float(atk["dur"]) / 0.004)), 1, 24)
	var segs: Array = []
	var bx := player.body.global_transform
	for k in n + 1:
		var xf := bx * _staff_xform(_pose_at(atk["keys"], lerpf(u0, u, float(k) / n)))
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
	var power: float = POWER[step]
	_hit_this_swing.append(target)
	hits += 1
	hitstop = HITSTOP * power
	target.take_hit(point, swing, power, hitstop)
	var kind: String = target.get("impact_kind") if target.get("impact_kind") != null else "wood"
	ImpactFX.spawn(player.get_parent(), point, swing, kind, power)
	player.add_shake(0.32 * power)
	hit_landed.emit(target, point, power)

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
	var tw := deg_to_rad(pose[3])
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var sr := Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z).rotated(Vector3.UP, tw)
	var hr := _clamp_reach(p + d * HAND_R, sr)
	var hl := _clamp_reach(p + d * HAND_L, sl)
	var axis := hl - hr
	if axis.length() < 0.12:
		axis = d * 0.12
	var d2 := axis.normalized()
	var b := Basis(Quaternion(Vector3.UP, d2)) if d2.y > -0.99 else Basis(Vector3.RIGHT, PI)
	return [Transform3D(b, hr - d2 * HAND_R), hr, hl]

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
