class_name StrideWarp
extends SkeletonModifier3D
## Stride warping: lengthens the run clip's stride so the planted foot holds still on the turf
## at running pace instead of the clip being played faster and faster (a scurry). Each leg's
## swing about the hip (the hip-to-ankle line's pitch off plumb, in the body's sagittal plane)
## is scaled by `k`; the foot is turned back by the same amount so the sole keeps the clip's
## angle, and the hips are lowered by what the longer reach lifts the lower (weight-bearing)
## foot, so it stays on the ground. Runs first, on the clip's own pose, before the Crumple poses.

var k := 1.0                 # stride length x the clip's (1 = the clip as authored)
var frame := Basis()         # the skeleton's rest orientation in body space (set by Player)
var drop := 0.0              # (bots) m the hips were lowered this tick (skeleton units x scale)
## Contact lock: the foot that touches down is pinned where it struck (in the world, along the
## body's line) until its heel lifts, so a fast cadence cannot carry it on through the strike.
var lock := 0.0              # 0..1 how much of the contact lock is on (Player: grounded, striding)
const LOCK_H := 1.5          # skeleton units (cm) over the stance level that count as on the turf
const LOCK_MAX := 16.0       # skeleton units (cm): a bigger error lets go (a turn, a teleport)
var _ground := 0.0           # the stance level: the lowest the lower ankle has been lately (cm)
var _ground_set := false
var _h_prev := [0.0, 0.0]    # each ankle's height last tick (cm): a falling foot is caught early
const LOCK_H_FALL := 4.0     # cm over the stance level: a foot coming down is pinned this early
var _pin := [null, null]     # world pin per foot (Vector3) or null
var _pin_w := [0.0, 0.0]     # each pin's weight, fading out once the heel lifts
var corrected := 0.0         # (bots) largest correction this tick (m, skeleton units)

func _process_modification_with_delta(_delta: float) -> void:
	drop = 0.0
	corrected = 0.0
	var skel := get_skeleton()
	if skel == null:
		return
	if absf(k - 1.0) >= 1e-3:
		_warp_stride(skel)
	_lock_feet(skel, _delta)

func _warp_stride(skel: Skeleton3D) -> void:
	var to_skel := frame.inverse()
	var x := (to_skel * Vector3.RIGHT).normalized()
	var up := (to_skel * Vector3.UP).normalized()
	var fwd := (to_skel * Vector3.BACK).normalized()
	var lift := [0.0, 0.0]
	var low := [0.0, 0.0]
	var sides := ["Left", "Right"]
	for i in 2:
		var hb := skel.find_bone("mixamorig_%sUpLeg" % sides[i])
		var fb := skel.find_bone("mixamorig_%sFoot" % sides[i])
		if hb < 0 or fb < 0:
			return
		var d := skel.get_bone_global_pose(fb).origin - skel.get_bone_global_pose(hb).origin
		var a := atan2(d.dot(fwd), -d.dot(up))           # + the foot ahead of the hip
		var r := Vector2(d.dot(fwd), d.dot(up)).length()
		var da := (k - 1.0) * a
		_bend(skel, hb, x, -da)                          # the thigh swings further, ahead or behind
		_bend(skel, fb, x, da)                           # the sole keeps the clip's pitch
		lift[i] = r * (cos(a) - cos(a + da))             # the longer reach lifts the foot this much
		low[i] = skel.get_bone_global_pose(fb).origin.dot(up)
	# the lower foot is the one on the ground: the hips come down by what lifted it
	var g: float = lift[0] if low[0] < low[1] else lift[1]
	if g <= 0.0:
		return
	var hips := skel.find_bone("mixamorig_Hips")
	if hips < 0:
		return
	var parent := skel.get_bone_parent(hips)
	var pb := skel.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	skel.set_bone_pose_position(hips, skel.get_bone_pose_position(hips) - pb.inverse() * (up * g))
	drop = g * skel.global_basis.get_scale().x

func _lock_feet(skel: Skeleton3D, delta: float) -> void:
	if lock <= 0.0:
		_pin = [null, null]
		_pin_w = [0.0, 0.0]
		_ground_set = false
		return
	var to_skel := frame.inverse()
	var x := (to_skel * Vector3.RIGHT).normalized()
	var up := (to_skel * Vector3.UP).normalized()
	var fwd := (to_skel * Vector3.BACK).normalized()
	var xf := skel.global_transform
	var inv := xf.affine_inverse()
	var hb := [skel.find_bone("mixamorig_LeftUpLeg"), skel.find_bone("mixamorig_RightUpLeg")]
	var fb := [skel.find_bone("mixamorig_LeftFoot"), skel.find_bone("mixamorig_RightFoot")]
	if hb.has(-1) or fb.has(-1):
		return
	var h := [0.0, 0.0]
	for i in 2:
		h[i] = skel.get_bone_global_pose(fb[i]).origin.dot(up)
	var g_now: float = minf(h[0], h[1])
	if not _ground_set or g_now < _ground:
		_ground = g_now
		_ground_set = true
	else:
		_ground = move_toward(_ground, g_now, delta * 4.0)   # creeps up 4 cm/s (a slope, a crouch)
	var h_last: Array = _h_prev.duplicate()
	_h_prev = h.duplicate()
	for i in 2:
		var falling: bool = float(h[i]) < float(h_last[i]) - 0.05
		var down: bool = h[i] < _ground + (LOCK_H_FALL if falling else LOCK_H)
		var foot: Vector3 = skel.get_bone_global_pose(fb[i]).origin
		if down and _pin[i] == null:
			_pin[i] = xf * foot                          # the strike: pin it where it lands
			_pin_w[i] = 1.0
		elif down:
			_pin_w[i] = 1.0                              # back on the turf (a wobble at the strike)
		elif not down and _pin[i] != null:
			_pin_w[i] = move_toward(_pin_w[i], 0.0, delta * 18.0)   # heel up: let go over a few ticks
			if _pin_w[i] <= 0.0:
				_pin[i] = null
		if _pin[i] == null:
			continue
		# the pin's error along the body's line, in skeleton space
		var e: float = ((inv * (_pin[i] as Vector3)) - foot).dot(fwd)
		if absf(e) > LOCK_MAX * 2.0:
			_pin[i] = null                               # a teleport, a snap turn: let go at once
			_pin_w[i] = 0.0
			continue
		if absf(e) > LOCK_MAX:
			# held too far from the clip's foot: drag the pin along (a slow slide, never a snap)
			e = signf(e) * LOCK_MAX
			_pin[i] = xf * (foot + fwd * e)
		var d: Vector3 = foot - skel.get_bone_global_pose(hb[i]).origin
		var r := maxf(-d.dot(up), 30.0)
		var a := atan2(d.dot(fwd), -d.dot(up))
		var da := atan2(d.dot(fwd) + e * float(_pin_w[i]) * lock, r) - a
		_bend(skel, hb[i], x, -da)                       # swing the thigh to put the foot back on its pin
		_bend(skel, fb[i], x, da)                        # the sole keeps its pitch
		corrected = maxf(corrected, absf(e * float(_pin_w[i]) * lock))

func _bend(skel: Skeleton3D, b: int, axis_skel: Vector3, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))
