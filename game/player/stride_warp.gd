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
## Pivot foot: in a turn on the spot the inside foot stays planted where it stood (two-bone IK on
## that leg, the sole keeping the clip's angle so it spins on its ball) while Player swings the
## body round over it; the outside foot steps the turn from the clip.
var pivot := 0.0             # 0..1 weight (Player)
var pivot_side := 0          # 0 the left foot, 1 the right foot
var pivot_pin = null         # world ankle pin (Vector3) while pivoting, else null
var pivot_ankle := Vector3.ZERO  # (bots) world pivot ankle as posed this tick
var pivot_other := Vector3.ZERO  # (bots) world other ankle as posed this tick
var pivot_sink := 0.0            # (bots) skeleton units the hips settled onto the pivot leg this tick
const PIVOT_SINK_MAX := 8.0      # skeleton units (cm)
var pivot_short := 0.0           # (bots) skeleton units the leg could not reach to the pin this tick
## Ground feet (foot IK on slopes, steps, stones): the clip is authored on flat ground at the
## body's floor level. Each tick a ray finds the real ground under each ankle; the hips settle
## by what the lower foot needs to reach its ground, each leg is bent (two-bone IK, knee in the
## clip's plane) to put its foot on its own ground, and a planted sole is tilted onto the slope.
var ground_w := 0.0              # 0..1 weight (owner: grounded and on its feet)
var ground_body: Node3D = null   # the owner: its origin is the floor the clip stands on; excluded from rays
var ground_scale := 1.0          # the owner's body size (a growing boss): limits and snaps scale with it
var ground_off := [0.0, 0.0]     # world m each foot's ground sits above (+) or below the floor, eased
var ground_n := [Vector3.UP, Vector3.UP]   # each foot's ground normal, eased
var ground_drop := 0.0           # (bots) world m the hips settled for the lower foot this tick
var ground_anim := [0.0, 0.0]    # (bots) world m each ankle sat over the floor in the clip this tick
var ground_sole := [0.0, 0.0]    # (bots) world m each ankle sits over the ground under it after the IK
const GROUND_MAX := 0.42         # m (x the owner's scale): a bigger step is not a slope, leave it
const GROUND_RATE := 45.0        # 1/s: the feet follow the ground under them this fast (a kerb in ~3 ticks)
const GROUND_SNAP := 0.035       # m (x scale) a tick: less than this is the slope, followed at once
const GROUND_HIPS_RATE := 10.0   # 1/s: the hips settle slower than the feet (no bob on a rough slope)
const GROUND_TILT_MAX := 0.6     # rad: a sole tilts at most this far onto the slope
var _ground_t := -1.0
var _drop := 0.0               # world m, the hips' settle, eased
var _ground_pf := -1
var toe_lift := [0.0, 0.0]        # (bots) world m each foot was lifted so its toes clear a rising edge
const TOE_TIP := 0.55            # the toe tip ray sits this far past the ball (x the ankle-to-ball reach)
const TOE_TOL := 0.006           # m (x scale): a rise smaller than this under the toes is the slope's own curve
var _gxz := [Vector3.ZERO, Vector3.ZERO]   # each ankle's world x/z last tick (the slope's own rise under a moving foot)
var _gy := [0.0, 0.0]            # each foot's ground height in the world, eased (a planted foot's is fixed)

func _process_modification_with_delta(_delta: float) -> void:
	drop = 0.0
	corrected = 0.0
	var skel := get_skeleton()
	if skel == null:
		return
	if absf(k - 1.0) >= 1e-3:
		_warp_stride(skel)
	_lock_feet(skel, _delta)
	_pivot_leg(skel)
	_ground_feet(skel, _delta)

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

func _pivot_leg(skel: Skeleton3D) -> void:
	if pivot <= 0.0:
		pivot_pin = null
		return
	var sides := ["Left", "Right"]
	var ul := skel.find_bone("mixamorig_%sUpLeg" % sides[pivot_side])
	var lg := skel.find_bone("mixamorig_%sLeg" % sides[pivot_side])
	var ft := skel.find_bone("mixamorig_%sFoot" % sides[pivot_side])
	var of := skel.find_bone("mixamorig_%sFoot" % sides[1 - pivot_side])
	if ul < 0 or lg < 0 or ft < 0 or of < 0:
		return
	var xf := skel.global_transform
	var inv := xf.affine_inverse()
	var up := (frame.inverse() * Vector3.UP).normalized()
	var fwd := (frame.inverse() * Vector3.BACK).normalized()
	if pivot_pin == null:
		# plant it where it stands, at the stance level (the lower ankle), not mid-lift
		var f0 := skel.get_bone_global_pose(ft).origin
		var lo := minf(f0.dot(up), skel.get_bone_global_pose(of).origin.dot(up))
		pivot_pin = xf * (f0 - up * (f0.dot(up) - lo))
	var keep := skel.get_bone_global_pose(ft).basis
	var s := skel.get_bone_global_pose(ul).origin
	# a clip that rises onto the stepping leg would pull the planted foot off its pin: the hips
	# settle onto the pivot leg instead, by just what it needs to reach (capped, a few cm)
	var reach_l := (s.distance_to(skel.get_bone_global_pose(lg).origin) + skel.get_bone_global_pose(lg).origin.distance_to(skel.get_bone_global_pose(ft).origin)) * 0.99
	var tp: Vector3 = skel.get_bone_global_pose(ft).origin.lerp(inv * (pivot_pin as Vector3), pivot)
	var dd := tp - s
	pivot_sink = 0.0
	if dd.length() > reach_l:
		var du := dd.dot(up)
		var h := -du - sqrt(maxf(du * du - dd.length_squared() + reach_l * reach_l, 0.0))
		h = clampf(h, 0.0, PIVOT_SINK_MAX)
		var hips := skel.find_bone("mixamorig_Hips")
		if hips >= 0 and h > 0.0:
			var hp := skel.get_bone_parent(hips)
			var pbh := skel.get_bone_global_pose(hp).basis if hp >= 0 else Basis()
			skel.set_bone_pose_position(hips, skel.get_bone_pose_position(hips) - pbh.inverse() * (up * h))
			pivot_sink = h
			s = skel.get_bone_global_pose(ul).origin
	var k := skel.get_bone_global_pose(lg).origin
	var f := skel.get_bone_global_pose(ft).origin
	var a := s.distance_to(k)
	var b := k.distance_to(f)
	var t := f.lerp(inv * (pivot_pin as Vector3), pivot)
	var d := t - s
	var dl := clampf(d.length(), absf(a - b) + 1e-3, (a + b) * 0.995)
	pivot_short = d.length() - dl
	var dn := d.normalized()
	# the knee keeps the clip's bend plane (forward over the toes)
	var pole := (k - s) - dn * (k - s).dot(dn)
	if pole.length() < 1e-3:
		pole = fwd - dn * fwd.dot(dn)
	pole = pole.normalized()
	var d1 := (a * a - b * b + dl * dl) / (2.0 * dl)
	var k_new := s + dn * d1 + pole * sqrt(maxf(a * a - d1 * d1, 0.0))
	_swing(skel, ul, k - s, k_new - s)
	k = skel.get_bone_global_pose(lg).origin
	f = skel.get_bone_global_pose(ft).origin
	_swing(skel, lg, f - k, t - k)
	# the sole keeps the clip's angle: it spins on the ball with the body, it does not tip
	var pb := skel.get_bone_global_pose(lg).basis.orthonormalized()
	skel.set_bone_pose_rotation(ft, (pb.inverse() * keep.orthonormalized()).get_rotation_quaternion())
	pivot_ankle = xf * skel.get_bone_global_pose(ft).origin
	pivot_other = xf * skel.get_bone_global_pose(of).origin

func _swing(skel: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	var ax := from.cross(to)
	if ax.length() < 1e-6:
		return
	_bend(skel, b, ax.normalized(), from.angle_to(to))

## Two-bone IK on one leg: the ankle to `t` (skeleton space), the knee kept in the clip's bend
## plane, the foot's skeleton-space orientation kept as `keep`.
func _leg_to(skel: Skeleton3D, ul: int, lg: int, ft: int, t: Vector3, keep: Basis, fwd: Vector3) -> void:
	var s := skel.get_bone_global_pose(ul).origin
	var k := skel.get_bone_global_pose(lg).origin
	var f := skel.get_bone_global_pose(ft).origin
	var a := s.distance_to(k)
	var b := k.distance_to(f)
	var d := t - s
	var dl := clampf(d.length(), absf(a - b) + 1e-3, (a + b) * 0.995)
	var dn := d.normalized()
	var pole := (k - s) - dn * (k - s).dot(dn)
	if pole.length() < 1e-3:
		pole = fwd - dn * fwd.dot(dn)
	pole = pole.normalized()
	var d1 := (a * a - b * b + dl * dl) / (2.0 * dl)
	var k_new := s + dn * d1 + pole * sqrt(maxf(a * a - d1 * d1, 0.0))
	_swing(skel, ul, k - s, k_new - s)
	k = skel.get_bone_global_pose(lg).origin
	f = skel.get_bone_global_pose(ft).origin
	_swing(skel, lg, f - k, s + dn * dl - k)
	var pb := skel.get_bone_global_pose(lg).basis.orthonormalized()
	skel.set_bone_pose_rotation(ft, (pb.inverse() * keep.orthonormalized()).get_rotation_quaternion())

func _ground_feet(skel: Skeleton3D, delta: float) -> void:
	ground_drop = 0.0
	if ground_body == null or not ground_body.is_inside_tree():
		return
	var xf := skel.global_transform
	var inv := xf.affine_inverse()
	var sc: float = ground_scale
	var floor_y: float = ground_body.global_position.y
	var sides := ["Left", "Right"]
	var ul := [0, 0]
	var lg := [0, 0]
	var ft := [0, 0]
	var tb := [-1, -1]
	for i in 2:
		tb[i] = skel.find_bone("mixamorig_%sToeBase" % sides[i])
		ul[i] = skel.find_bone("mixamorig_%sUpLeg" % sides[i])
		lg[i] = skel.find_bone("mixamorig_%sLeg" % sides[i])
		ft[i] = skel.find_bone("mixamorig_%sFoot" % sides[i])
		if ul[i] < 0 or lg[i] < 0 or ft[i] < 0:
			return
	# the ground under each ankle (a fresh landing eases in from the floor, no pop)
	# eased once per physics tick (the clip is posed on physics ticks; the modifier's own delta
	# is the render frame's and may come several times a tick, or not at all)
	var pf := Engine.get_physics_frames()
	var dt := 0.0 if pf == _ground_pf else 1.0 / float(Engine.physics_ticks_per_second)
	if _ground_t < 0.0:
		dt = 1.0
	_ground_pf = pf
	_ground_t = 0.0
	var space := ground_body.get_world_3d().direct_space_state
	var excl: Array[RID] = []
	if ground_body is CollisionObject3D:
		excl.append((ground_body as CollisionObject3D).get_rid())
	var lim := GROUND_MAX * sc
	var anim_h := [0.0, 0.0]
	for i in 2:
		var a: Vector3 = xf * skel.get_bone_global_pose(ft[i]).origin
		anim_h[i] = a.y - floor_y
		var q := PhysicsRayQueryParameters3D.create(Vector3(a.x, floor_y + lim + 0.3 * sc, a.z), Vector3(a.x, floor_y - lim - 0.3 * sc, a.z), 1, excl)
		var hit := space.intersect_ray(q)
		var gy := floor_y
		var n := Vector3.UP
		if not hit.is_empty():
			gy = (hit.position as Vector3).y
			n = hit.normal as Vector3
			if n.y < 0.5:
				n = Vector3.UP                  # a wall face, not a footing
		# toe rays: the ball of the foot and the toe tip ahead of it. Where the ground under them
		# rises above the slope the ankle stands on (a stair edge, a kerb, a root, a stone), the
		# foot is lifted onto it so the toes never dip into it: the ball takes the weight on the
		# step, the heel hangs over the lower ground, as a foot does on a stair edge.
		toe_lift[i] = 0.0
		if tb[i] >= 0:
			var ball: Vector3 = xf * skel.get_bone_global_pose(tb[i]).origin
			var reach := Vector3(ball.x - a.x, 0.0, ball.z - a.z)
			for tp in [ball, ball + reach * TOE_TIP]:
				var tq := PhysicsRayQueryParameters3D.create(Vector3(tp.x, floor_y + lim + 0.3 * sc, tp.z), Vector3(tp.x, floor_y - lim - 0.3 * sc, tp.z), 1, excl)
				var th := space.intersect_ray(tq)
				if th.is_empty():
					continue
				var tn := th.normal as Vector3
				if tn.y < 0.5:
					continue                    # the riser's face: the tread's own ray decides
				# where the ankle's slope would put the ground under this toe point
				var dxz := Vector3(tp.x - a.x, 0.0, tp.z - a.z)
				var plane_y := gy - (n.x * dxz.x + n.z * dxz.z) / maxf(n.y, 0.5)
				var excess := (th.position as Vector3).y - plane_y - TOE_TOL * sc
				toe_lift[i] = maxf(float(toe_lift[i]), excess)
			gy += minf(float(toe_lift[i]), lim)
		# eased in the WORLD: the ground under a planted foot does not move as the body climbs
		# a slope's small change per tick is followed exactly; a jump (a kerb, a stone) is eased
		var r := 1.0 - exp(-GROUND_RATE * dt)
		var jump := gy - float(_gy[i])
		# what the slope alone gives for how far this foot moved since last tick: a swinging foot
		# crosses a hillside fast and its ground rises with it, that is followed at once; only the
		# rest (a kerb, a stone, a stair edge) is eased
		var gn: Vector3 = ground_n[i]
		var mv: Vector3 = Vector3(a.x, 0.0, a.z) - (_gxz[i] as Vector3)
		var slope_rise := -(gn.x * mv.x + gn.z * mv.z) / maxf(gn.y, 0.5)
		if mv.length() > 0.5 * sc:
			slope_rise = 0.0                    # a teleport, not a stride
		_gxz[i] = Vector3(a.x, 0.0, a.z)
		_gy[i] = gy if absf(jump - slope_rise) <= GROUND_SNAP * sc and dt > 0.0 and dt < 1.0 else lerpf(float(_gy[i]), gy, r)
		ground_off[i] = clampf(float(_gy[i]) - floor_y, -lim, lim)
		ground_n[i] = (ground_n[i] as Vector3).lerp(n, r).normalized()
	ground_anim = anim_h.duplicate()
	var w := clampf(ground_w, 0.0, 1.0)
	if w <= 0.0:
		_drop = 0.0
		for i in 2:
			ground_sole[i] = anim_h[i] - float(ground_off[i])
		return
	var up_s: Vector3 = inv.basis * Vector3.UP                # 1 world m up, in skeleton units
	var fwd := (frame.inverse() * Vector3.BACK).normalized()
	# the hips settle by what the lower ground needs (the clip's floor is the body's origin)
	var want := maxf(0.0, -minf(float(ground_off[0]), float(ground_off[1]))) * w
	_drop = lerpf(_drop, want, 1.0 - exp(-GROUND_HIPS_RATE * dt)) if want < _drop else want   # down at once, up eased
	var drop := _drop
	var hips := skel.find_bone("mixamorig_Hips")
	if hips >= 0 and drop > 0.0:
		var hp := skel.get_bone_parent(hips)
		var pbh := skel.get_bone_global_pose(hp).basis if hp >= 0 else Basis()
		skel.set_bone_pose_position(hips, skel.get_bone_pose_position(hips) - pbh.inverse() * (up_s * drop))
	ground_drop = drop
	for i in 2:
		# each foot keeps its height over ITS ground: up by its offset plus what the hips gave
		var lift := float(ground_off[i]) * w + drop
		var keep := skel.get_bone_global_pose(ft[i]).basis
		# a planted sole lies on the slope; a foot swinging high keeps the clip's angle
		var plant := clampf(1.0 - (float(anim_h[i]) / sc - 0.12) / 0.14, 0.0, 1.0) * w
		var n: Vector3 = ground_n[i]
		var tilt := Vector3.UP.angle_to(n)
		if plant > 0.0 and tilt > 1e-3:
			var ax_w := Vector3.UP.cross(n).normalized()
			var ax_s := (inv.basis * ax_w).normalized()
			keep = Basis(ax_s, minf(tilt, GROUND_TILT_MAX) * plant) * keep
		if absf(lift) < 1e-4 and plant <= 0.0:
			continue
		var t := skel.get_bone_global_pose(ft[i]).origin + up_s * lift
		_leg_to(skel, ul[i], lg[i], ft[i], t, keep, fwd)
	for i in 2:
		ground_sole[i] = (xf * skel.get_bone_global_pose(ft[i]).origin).y - floor_y - float(ground_off[i])
