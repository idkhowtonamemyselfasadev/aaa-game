class_name HandRest
extends SkeletonModifier3D
## The hero's fingers, posed on top of the clip. The Mixamo clips leave the hands splayed and
## hooked (tips bent back, the fingers fanned ~40 deg apart): at rest they read as claws. Here
## each finger is first taken back to its straight rest, then fanned in close and curled the way
## a relaxed hand hangs (a little at the index, more toward the pinky; the middle joint most).
## With the staff drawn the curl closes toward a grip round the shaft. Off (eased) whenever
## another pose owns the hands (climbing holds, the glider bar, a fist in Crumple).

var weight := 1.0            # 0..1: how much of this pose is on (eased by Player)
var hold := 0.0              # 0..1: the relaxed curl closed toward a grip on the staff
var fan_k := 1.0             # (bots) scale on the fan; 0 leaves the spread as the rest pose has it
## 0..1 per side: the hand clenched into a closed fist with nothing in it (the knight's roar fist).
## A grip on a haft leaves a hollow; this closes it: the fingers folded right in, the tips on the
## palm, the thumb wrapped across the index and middle fingers' middle joints.
var clench_l := 0.0
var clench_r := 0.0
## (11-09 23:00) 0..1: on a grip, the thumb's root swung so its tip comes round the haft onto the
## folded index's middle joint (opposed, a power grip). The fixed swing + curl left the foes'
## thumbs out beside the haft like a thumbs-up (tip 2.5-3.3 index-lengths off the index, 6-11 cm
## off the shaft axis). Foes set 1; the hero's grip is tuned through Crumple and stays at 0.
var thumb_aim := 0.0
const THUMB_AIM_MAX := 1.2    # rad per step: no wild flip when the clip throws the hand about
const THUMB_AIM_PALM := 0.35   # index-lengths: the aim point lifted off the middle joint, outside the fist
var thumb_tip_gap := [0.0, 0.0]   # (bots) right, left: tip to the index's middle joint, index-lengths, last pose

# radians per finger joint, knuckle to tip: + folds toward the palm
const RELAX := {
	"Index": [0.35, 0.55, 0.30],
	"Middle": [0.45, 0.65, 0.34],
	"Ring": [0.55, 0.70, 0.34],
	"Pinky": [0.62, 0.95, 0.30],   # (the rig's pinky has 2 bones: the 2nd takes both outer joints)
}
const HOLD := {
	"Index": [1.05, 1.15, 0.65],
	"Middle": [1.15, 1.2, 0.7],
	"Ring": [1.2, 1.2, 0.7],
	"Pinky": [1.25, 1.55, 0.65],
}
# radians off the hand's length (+ toward the index side): the fingers lie close, a slight fan
const FAN := {"Index": 0.10, "Middle": 0.0, "Ring": -0.09, "Pinky": -0.20}
const THUMB_SWING := 0.0     # on top of the clip's thumb at rest (already tucked in)
const THUMB_CURL := [0.0, 0.1, 0.1]
const THUMB_HOLD_SWING := -1.1
const THUMB_HOLD_CURL := [0.4, 0.5, 0.45]
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
# the clenched fist: knuckles at ~85 deg, middle joints folded right over, tips tucked onto the palm
const FIST := {
	"Index": [1.40, 1.55, 0.95],
	"Middle": [1.50, 1.60, 0.95],
	"Ring": [1.55, 1.60, 0.95],
	"Pinky": [1.60, 1.95, 0.85],
}
const FIST_FAN := {"Index": 0.03, "Middle": 0.0, "Ring": -0.03, "Pinky": -0.07}
const THUMB_FIST_SWING := 1.2     # the thumb's root rolled about the knuckle line, across the fingers
const THUMB_FIST_CURL := [0.6, 0.6, 0.6]

## The closed fist's centre (world): the mean of the index, middle and ring joints and tips, the
## hollow a haft runs through when the fingers wrap it (hero and foes share the rig).
static func fist_center(skel: Skeleton3D, side: String) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for f in ["Index", "Middle", "Ring"]:
		var last := -1
		for j in 3:
			var b := skel.find_bone("mixamorig_%sHand%s%d" % [side, f, j + 1])
			if b < 0:
				break
			sum += skel.get_bone_global_pose(b).origin
			n += 1
			last = b
		if last >= 0:
			var tb := skel.get_bone_global_pose(last)
			sum += tb.origin + tb.basis.y.normalized() * 2.0
			n += 1
	return skel.global_transform * (sum / maxf(n, 1))

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or weight <= 0.001:
		return
	for side in ["Left", "Right"]:
		_pose_hand(skel, side, weight, hold, clench_l if side == "Left" else clench_r)

func _y(skel: Skeleton3D, b: int) -> Vector3:
	return skel.get_bone_global_pose(b).basis.y.normalized()

func _pose_hand(skel: Skeleton3D, side: String, w: float, h: float, c := 0.0) -> void:
	c = clampf(c, 0.0, 1.0)
	var pre := "mixamorig_%sHand" % side
	var hb := skel.find_bone(pre)
	var mid := skel.find_bone(pre + "Middle1")
	var idx := skel.find_bone(pre + "Index1")
	var pin := skel.find_bone(pre + "Pinky1")
	if hb < 0 or mid < 0 or idx < 0 or pin < 0:
		return
	# 1. every finger bone back toward its straight rest (the clip's hook taken out); the thumb
	# keeps the clip's pose, tucked beside the index (its T rest juts straight out of the hand)
	for f in FINGERS:
		for j in 3:
			var b := skel.find_bone("%s%s%d" % [pre, f, j + 1])
			if b >= 0:
				var rr := skel.get_bone_rest(b).basis.get_rotation_quaternion()
				skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b).slerp(rr, w))
	var o := skel.get_bone_global_pose(hb).origin
	var dir := (skel.get_bone_global_pose(mid).origin - o).normalized()
	var across := skel.get_bone_global_pose(idx).origin - skel.get_bone_global_pose(pin).origin
	across = (across - dir * across.dot(dir)).normalized()
	var palm := across.cross(dir) * (1.0 if side == "Right" else -1.0)
	var hinge := dir.cross(palm).normalized()     # + about it folds a finger into the palm
	var fan_axis := dir.cross(across).normalized() # + about it turns a finger toward the index side
	# 2. the fingers drawn in close, a slight fan
	for f in FINGERS:
		var b := skel.find_bone("%s%s1" % [pre, f])
		if b < 0:
			continue
		var a := _y(skel, b)
		var ang := atan2(a.dot(across), a.dot(dir))
		_turn(skel, b, fan_axis, (lerpf(float(FAN[f]), float(FIST_FAN[f]), c) * fan_k - ang) * w)
	# 3. the curl, joint by joint: each bone turned so its bend off the bone before is the target
	for f in FINGERS:
		var prev := dir
		for j in 3:
			var b := skel.find_bone("%s%s%d" % [pre, f, j + 1])
			if b < 0:
				break
			var want := lerpf(lerpf(float(RELAX[f][j]), float(HOLD[f][j]), h), float(FIST[f][j]), c)
			# (11-06) both bones projected onto the hinge's plane first: the fan sets the first bone
			# off the hand's length ACROSS the hinge, and a plain signed angle then took that 0.1 rad
			# as fold with a sign from rounding noise (the knight's index flipped 0.2 rad tick to tick)
			var cur := _on_plane(prev, hinge).signed_angle_to(_on_plane(_y(skel, b), hinge), hinge)
			_turn(skel, b, hinge, (want - cur) * w)
			prev = _y(skel, b)
	# 4. the thumb: its root swung in toward the palm, the joints a little curled
	var t1 := skel.find_bone(pre + "Thumb1")
	if t1 >= 0:
		# (11-07) the fist's thumb: the grip's swing eased out and the root rolled about the knuckle
		# line instead, down across the front of the folded index and middle (swept on the knight's
		# roar fist: tip 1.23 -> 0.67 index-lengths from their middle joints; mirrored for the right)
		_turn(skel, t1, across.cross(palm).normalized(), lerpf(THUMB_SWING, THUMB_HOLD_SWING, h) * w * (1.0 - c))
		_turn(skel, t1, across * (1.0 if side == "Left" else -1.0), THUMB_FIST_SWING * c * w)
		var t2 := skel.find_bone(pre + "Thumb2")
		var tl := _y(skel, t1)
		var th := tl.cross(palm).normalized()
		for j in 3:
			var b := skel.find_bone("%sThumb%d" % [pre, j + 1])
			if b >= 0:
				_turn(skel, b, th, lerpf(lerpf(float(THUMB_CURL[j]), float(THUMB_HOLD_CURL[j]), h),
					float(THUMB_FIST_CURL[j]), c) * w)
		if t2 < 0:
			return
		var ak := thumb_aim * h * (1.0 - c) * w
		if ak > 0.001:
			for it in 3:
				_aim_thumb(skel, pre, t1, t2, palm, ak)
		var ti := skel.find_bone(pre + "Index1")
		var t2i := skel.find_bone(pre + "Index2")
		if ti >= 0 and t2i >= 0:
			var i2 := skel.get_bone_global_pose(t2i).origin
			thumb_tip_gap[0 if side == "Right" else 1] = _thumb_tip(skel, pre, t1, t2).distance_to(i2) / maxf(skel.get_bone_global_pose(ti).origin.distance_to(i2), 1e-4)

## The thumb's tip (skeleton space). The foes' left thumb is rigged with two bones (the second
## carries both phalanges), the right with three plus an end.
func _thumb_tip(skel: Skeleton3D, pre: String, t1: int, t2: int) -> Vector3:
	var t3 := skel.find_bone(pre + "Thumb3")
	var t4 := skel.find_bone(pre + "Thumb4")
	if t4 >= 0:
		return skel.get_bone_global_pose(t4).origin
	if t3 >= 0:
		var p3 := skel.get_bone_global_pose(t3).origin
		return p3 + _y(skel, t3) * p3.distance_to(skel.get_bone_global_pose(t2).origin)
	var p2 := skel.get_bone_global_pose(t2).origin
	return p2 + _y(skel, t2) * p2.distance_to(skel.get_bone_global_pose(t1).origin) * 1.3

## One step of the opposed thumb: the root (Thumb1) turned the shortest way so the tip heads for
## the index's middle joint, lifted a little off it on the back of the folded finger.
func _aim_thumb(skel: Skeleton3D, pre: String, t1: int, t2: int, palm: Vector3, k: float) -> void:
	var i1 := skel.find_bone(pre + "Index1")
	var i2 := skel.find_bone(pre + "Index2")
	var m2 := skel.find_bone(pre + "Middle2")
	if i1 < 0 or i2 < 0:
		return
	var p2 := skel.get_bone_global_pose(i2).origin
	var il := p2.distance_to(skel.get_bone_global_pose(i1).origin)
	var tgt := p2
	if m2 >= 0:
		tgt = p2.lerp(skel.get_bone_global_pose(m2).origin, 0.3)
	tgt -= palm * il * THUMB_AIM_PALM
	# the root takes the swing, the second bone half of what is left (a curl round the haft)
	for pair in [[t1, 1.0], [t2, 0.5]]:
		var root := skel.get_bone_global_pose(pair[0]).origin
		var a := _thumb_tip(skel, pre, t1, t2) - root
		var b := tgt - root
		var ax := a.cross(b)
		if ax.length() < 1e-6:
			continue
		_turn(skel, pair[0], ax.normalized(), minf(a.angle_to(b), THUMB_AIM_MAX) * k * float(pair[1]))

func _on_plane(v: Vector3, n: Vector3) -> Vector3:
	return v - n * v.dot(n)

## Rotates bone b about a skeleton-space axis through its joint (the axis taken into the
## parent's frame, as Crumple._bend does).
func _turn(skel: Skeleton3D, b: int, axis_skel: Vector3, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))
