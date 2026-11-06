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
var lock_max := LOCK_MAX     # skeleton units: along the line, a pin held further off is dragged
## Lateral lock: the pin also holds the foot across the body's line (the hip abducts/adducts to
## put it back), not only along it. Foes in a stagger: their backward walk carries the stance
## boot sideways ~1 cm a tick while the body is shoved straight back.
var lock_lateral := false
## Gentle release (opt-in): as the heel lifts, the pin fades so the shown boot moves at most
## release_speed (skeleton units per second, 0 = off) toward the clip foot, but always lets go
## within ~1/RELEASE_MIN_RATE s. Foes in a stagger hold pins ~9 cm off their clip feet.
var release_speed := 0.0
const RELEASE_MIN_RATE := 5.0
var lateral_corrected := 0.0 # (bots) largest sideways correction this tick (m, skeleton units)
var _ground := 0.0           # the stance level: the lowest the lower ankle has been lately (cm)
var _ground_set := false
var _h_prev := [0.0, 0.0]    # each ankle's height last tick (cm): a falling foot is caught early
const LOCK_H_FALL := 4.0     # cm over the stance level: a foot coming down is pinned this early
## Strike approach: a foot coming down fast (a sprint) is eased onto the point where it will
## strike over its last few cm of descent: that point is predicted from the clip foot's own
## world motion and fall rate, and the pin's weight grows from 0 to 1 as the foot comes down,
## so the boot arrives slowing instead of still swinging and then stopping dead in one tick.
var strike_ease := false
var strike_by_time := OS.get_environment("STRIKE_HEIGHTONLY") == ""   # the approach weight also grows with the ticks left (env: the before)
const APPROACH_H := 10.0     # cm over the stance level where the approach begins
const APPROACH_END_H := 6.0  # cm: at a sprint the approach is fully held by here (a foot can drop the last 5 cm in one tick)
var approach_fast := 0.0     # 0..1 (Player: 0 at a run, 1 at a sprint): how much the approach ends early
const APPROACH_TICKS := 3.0  # the prediction looks at most this many ticks ahead
const STRIKE_DECEL := 0.5    # the clip foot slows to the strike: it covers this much of its straight run
var _approach := [false, false]
var _c_prev = [null, null]   # each clip ankle's world position last tick (before any correction)
var strike_eased := 0.0      # (bots) largest approach weight this tick
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
	strike_eased = 0.0
	lateral_corrected = 0.0
	var skel := get_skeleton()
	if skel == null:
		return
	if absf(k - 1.0) >= 1e-3:
		_warp_stride(skel)
	_lock_feet(skel, _delta)
	_pivot_leg(skel, _delta)
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
		_approach = [false, false]
		_c_prev = [null, null]
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
		var c_world: Vector3 = xf * foot
		var c_last = _c_prev[i]
		_c_prev[i] = c_world
		if strike_ease and not down and falling and h[i] < _ground + APPROACH_H \
				and (_pin[i] == null or _approach[i]) and c_last != null:
			var dh: float = float(h_last[i]) - float(h[i])
			# predict the strike: where the clip foot will be when it reaches the turf (it is
			# slowing as it comes down: half the straight-line run), refined each tick
			var n := clampf((float(h[i]) - _ground - LOCK_H * 0.5) / maxf(dh, 0.5), 0.0, APPROACH_TICKS)
			var v: Vector3 = c_world - (c_last as Vector3)
			v.y = 0.0
			var pred: Vector3 = c_world + v * n * STRIKE_DECEL
			var w_end := lerpf(LOCK_H, APPROACH_END_H, approach_fast) if strike_by_time else LOCK_H
			var w := clampf((_ground + APPROACH_H - float(h[i])) / (APPROACH_H - w_end), 0.0, 1.0)
			if strike_by_time:
				# weigh by the ticks left to the strike too: a fast foot covers the last cm in one
				# tick, so a height ramp alone leaves it half-held on the tick before it lands
				w = maxf(w, clampf(1.0 - (n - 0.5) / (APPROACH_TICKS - 0.5), 0.0, 1.0))
			var w_prev: float = float(_pin_w[i]) if _approach[i] else 0.0
			# refine the predicted point less as the pin takes hold: moving a held pin moves the boot
			var refine := 0.5 * (1.0 - w_prev * w_prev) if strike_by_time else 0.5
			_pin[i] = pred if not _approach[i] or _pin[i] == null else (_pin[i] as Vector3).lerp(pred, refine)
			_approach[i] = true
			_pin_w[i] = w * w * (3.0 - 2.0 * w)
			strike_eased = maxf(strike_eased, _pin_w[i])
		elif _approach[i] and not down and strike_by_time and float(h[i]) <= float(h_last[i]) + 0.05 \
				and h[i] < _ground + APPROACH_H:
			pass                                         # hovering over the strike: hold the eased pin
		elif _approach[i] and not down and strike_by_time:
			_approach[i] = false                         # it rose again (a skip, a hop): let the pin fade
			_pin_w[i] = move_toward(_pin_w[i], 0.0, delta * 18.0)
			if _pin_w[i] <= 0.0:
				_pin[i] = null
				continue
		elif _approach[i] and not down:
			_approach[i] = false                         # it rose again (a skip, a hop): drop it
			_pin[i] = null
			_pin_w[i] = 0.0
			continue
		elif down and _approach[i]:
			_approach[i] = false                         # the strike: the eased pin becomes the stance pin
			_pin_w[i] = 1.0
		elif down and _pin[i] == null:
			_pin[i] = xf * foot                          # the strike: pin it where it lands
			_pin_w[i] = 1.0
		elif down:
			if float(_pin_w[i]) < 1.0:
				# back on the turf while the old pin was letting go: re-pin where the foot is
				# shown now (between the clip and the fading pin), not back on the stale pin,
				# which may be 10+ cm off by now (a one-tick pop at a stop's hand-off)
				_pin[i] = c_world.lerp(_pin[i] as Vector3, float(_pin_w[i]) * lock)
			_pin_w[i] = 1.0                              # back on the turf (a wobble at the strike)
		elif not down and _pin[i] != null:
			var rate := delta * 18.0                     # heel up: let go over a few ticks
			if release_speed > 0.0:
				# a pin held far from the clip's foot (a shove outrunning the steps) would throw
				# the boot that whole error in ~3 ticks: let go no faster than release_speed
				var ev: Vector3 = (inv * (_pin[i] as Vector3)) - foot
				var err := absf(ev.dot(fwd)) if not lock_lateral else Vector2(ev.dot(fwd), ev.dot(x)).length()
				if err * lock > 1e-3:
					rate = clampf(release_speed * delta / (err * lock), delta * RELEASE_MIN_RATE, rate)
			_pin_w[i] = move_toward(_pin_w[i], 0.0, rate)
			if _pin_w[i] <= 0.0:
				_pin[i] = null
		if _pin[i] == null:
			continue
		# the pin's error along the body's line, in skeleton space
		var e: float = ((inv * (_pin[i] as Vector3)) - foot).dot(fwd)
		if absf(e) > LOCK_MAX * 2.0:
			_pin[i] = null                               # a teleport, a snap turn: let go at once
			_pin_w[i] = 0.0
			_approach[i] = false
			continue
		if absf(e) > lock_max:
			# held too far from the clip's foot: drag the pin along (a slow slide, never a snap)
			e = signf(e) * lock_max
			_pin[i] = xf * (foot + fwd * e)
		var d: Vector3 = foot - skel.get_bone_global_pose(hb[i]).origin
		var r := maxf(-d.dot(up), 30.0)
		var a := atan2(d.dot(fwd), -d.dot(up))
		var da := atan2(d.dot(fwd) + e * float(_pin_w[i]) * lock, r) - a
		_bend(skel, hb[i], x, -da)                       # swing the thigh to put the foot back on its pin
		_bend(skel, fb[i], x, da)                        # the sole keeps its pitch
		corrected = maxf(corrected, absf(e * float(_pin_w[i]) * lock))
		if lock_lateral:
			_lock_across(skel, i, hb[i], fb[i], x, up, inv)

## The sideways half of the contact lock: the leg swings out or in at the hip (about the line
## from the hip to the foot's own forward) so the pinned boot stays where it struck across the
## body's line too; the sole is turned back by the same rotation so it keeps its angle.
func _lock_across(skel: Skeleton3D, i: int, hb: int, fb: int, x: Vector3, up: Vector3, inv: Transform3D) -> void:
	var foot := skel.get_bone_global_pose(fb).origin
	var el: float = ((inv * (_pin[i] as Vector3)) - foot).dot(x)
	if absf(el) > LOCK_MAX * 2.0:
		return                                           # not this foot's pin any more: leave it
	if absf(el) > LOCK_MAX:
		# held too far across: drag the pin along with the clip's foot (a slow slide, never the
		# 16 cm pop of letting go once the error passes twice the cap)
		el = signf(el) * LOCK_MAX
		var pin: Vector3 = inv * (_pin[i] as Vector3)
		_pin[i] = inv.affine_inverse() * (pin - x * (pin - foot).dot(x) + x * el)
	el *= float(_pin_w[i]) * lock
	if absf(el) < 1e-3:
		return
	var d := foot - skel.get_bone_global_pose(hb).origin
	if -d.dot(up) < 20.0:
		return                                           # a leg folded up: no abduction to speak of
	var target := d + x * el
	var axis := d.cross(target)
	if axis.length() < 1e-6:
		return
	axis = axis.normalized()
	var ang := d.angle_to(target)
	_bend(skel, hb, axis, ang)                           # the thigh swings out or in
	_bend(skel, fb, axis, -ang)                          # the sole keeps its angle
	lateral_corrected = maxf(lateral_corrected, absf(el))

func _bend(skel: Skeleton3D, b: int, axis_skel: Vector3, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))

static var PIVOT_FREE_SINKS := OS.has_environment("PIVOT_FREE_SINKS")
## The turn step's arc (11-06): the clip's free foot only flicks up ~4 cm for 3 ticks and then
## drops ~4 cm under its standing height while it is still travelling round. While the pivot
## holds, the free boot is lifted by how fast it travels over the turf (eased: it rises quickly,
## comes down over ~0.15 s and sets down flat), and never goes below the stance level.
## PIVOT_NO_ARC: the before.
static var PIVOT_NO_ARC := OS.has_environment("PIVOT_NO_ARC")
const STEP_LIFT_K := 0.030       # s: lift = the free foot's travel speed x this (skeleton units)
const STEP_LIFT_MAX := 6.5       # skeleton units (cm): a turn step clears the turf by at most this
const STEP_RISE := 30.0          # 1/s: the lift eases up to its target this fast
const STEP_FALL := 24.0          # skeleton units/s: the boot comes down at most this fast
const STEP_SPEED_RATE := 20.0    # 1/s: the travel speed is smoothed (a one-tick jump is not a step)
const STEP_SPEED_DECAY := 6.0    # 1/s: ...and let down this slowly
static var PIVOT_ARC_DIP := OS.has_environment("PIVOT_ARC_DIP")
var step_lift := 0.0             # (bots) skeleton units the free boot is lifted this tick
var _arc_prev = null             # the free ankle's world position last tick (the clip's, before the arc)
var _arc_speed := 0.0            # skeleton units/s, smoothed
var _arc_lift := 0.0
const STEP_SAG := 9.0            # skeleton units/s: the arc's top sags this fast while the foot travels
const STEP_HOLD_FRAC := 0.15     # the foot counts as travelling while its speed is above this x the step's peak
var _arc_top := 0.0              # the boot's height over the stance level the arc holds (skeleton units)
var _arc_peak := 0.0             # the step's peak travel speed
var _arc_falling := false        # the arc has passed its top
var _arc_floor := 0.0            # the stance level when the pivot planted (skeleton space, the clip's)

func _pivot_leg(skel: Skeleton3D, delta: float = 1.0 / 60.0) -> void:
	step_lift = 0.0
	if pivot <= 0.0:
		pivot_pin = null
		_arc_prev = null
		_arc_speed = 0.0
		_arc_lift = 0.0
		_arc_top = 0.0
		_arc_peak = 0.0
		_arc_falling = false
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
		_arc_floor = lo
	var keep := skel.get_bone_global_pose(ft).basis
	var s := skel.get_bone_global_pose(ul).origin
	# a clip that rises onto the stepping leg would pull the planted foot off its pin: the hips
	# settle onto the pivot leg instead, by just what it needs to reach (capped, a few cm)
	var reach_l := (s.distance_to(skel.get_bone_global_pose(lg).origin) + skel.get_bone_global_pose(lg).origin.distance_to(skel.get_bone_global_pose(ft).origin)) * 0.99
	var tp: Vector3 = skel.get_bone_global_pose(ft).origin.lerp(inv * (pivot_pin as Vector3), pivot)
	var dd := tp - s
	pivot_sink = 0.0
	# the free foot as the clip steps it, before the hips settle: it keeps that place after
	var of_clip := skel.get_bone_global_pose(of).origin
	var of_keep := skel.get_bone_global_pose(of).basis
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
	# the hips settled onto the pivot leg carry the stepping leg down with them: without this
	# its boot sank up to 7.5 cm into the turf through the step (11-06, bot `foeturn` on the
	# final pose: off the turf 3 ticks of a turn, then under it). The free leg bends to keep its
	# boot where the clip steps it. PIVOT_FREE_SINKS: the before
	var of_t := of_clip
	if not PIVOT_NO_ARC and delta > 0.0:
		var wnow := xf * of_clip
		if _arc_prev != null:
			var dv: Vector3 = inv.basis * (wnow - (_arc_prev as Vector3))
			var v := (dv - up * dv.dot(up)).length() / delta
			# the speed rises fast but is let down slowly, so a lull mid-step (the clip's foot slows as
			# the body catches up) does not set the boot down and lift it again (11-06: a 2-4 cm dip
			# mid-arc). PIVOT_ARC_DIP: the before
			var rate := STEP_SPEED_RATE if (v > _arc_speed or PIVOT_ARC_DIP) else STEP_SPEED_DECAY
			_arc_speed = lerpf(_arc_speed, v, 1.0 - exp(-rate * delta))
		_arc_prev = wnow
		var want := minf(_arc_speed * STEP_LIFT_K, STEP_LIFT_MAX)
		if want > _arc_lift:
			_arc_lift = lerpf(_arc_lift, want, 1.0 - exp(-STEP_RISE * delta))
		else:
			_arc_lift = maxf(want, _arc_lift - STEP_FALL * delta)
		# the stance level in the clip's space: _ground_feet adds each foot's own ground after this,
		# so the pinned ankle's height (which carries the pivot foot's ground) would set the free boot
		# into a rise in the turf (11-06: -4 cm at size 4.6). PIVOT_ARC_DIP: the before
		var floor_h := (inv * (pivot_pin as Vector3)).dot(up) if PIVOT_ARC_DIP else _arc_floor
		var hgt := of_t.dot(up)
		var top := maxf(hgt, floor_h + _arc_lift)
		if not PIVOT_ARC_DIP:
			# one arc: the boot's height over the stance level only sags slowly while the foot still
			# travels round, and comes down at STEP_FALL once it has (11-06: the knights' clip foot fell
			# 6.6 -> 3.3 cm mid-step and rose to 4.1 again, the lift too small at their slow cadence)
			_arc_peak = maxf(_arc_peak, _arc_speed)
			var travelling := _arc_speed > STEP_HOLD_FRAC * _arc_peak
			# once the arc is coming down, the lift no longer pushes it back up (the knight's body
			# swings round a second time and its travel speed rose again: a second hump); only the
			# clip's own foot can
			var cand := maxf(hgt - floor_h, 0.0) if _arc_falling else (top - floor_h)
			var nt := maxf(cand, _arc_top - (STEP_SAG if travelling else STEP_FALL) * delta)
			if nt < _arc_top - 1e-4:
				_arc_falling = true
			_arc_top = nt
			top = floor_h + _arc_top
		var raise := (top - hgt) * pivot
		of_t += up * raise
		step_lift = _arc_lift * pivot
	if (pivot_sink > 0.0 and not PIVOT_FREE_SINKS) or of_t != of_clip:
		var oul := skel.find_bone("mixamorig_%sUpLeg" % sides[1 - pivot_side])
		var olg := skel.find_bone("mixamorig_%sLeg" % sides[1 - pivot_side])
		if oul >= 0 and olg >= 0:
			_leg_to(skel, oul, olg, of, of_t, of_keep, fwd)
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
