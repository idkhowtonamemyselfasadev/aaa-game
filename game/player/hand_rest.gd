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

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or weight <= 0.001:
		return
	for side in ["Left", "Right"]:
		_pose_hand(skel, side, weight, hold)

func _y(skel: Skeleton3D, b: int) -> Vector3:
	return skel.get_bone_global_pose(b).basis.y.normalized()

func _pose_hand(skel: Skeleton3D, side: String, w: float, h: float) -> void:
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
		_turn(skel, b, fan_axis, (float(FAN[f]) * fan_k - ang) * w)
	# 3. the curl, joint by joint: each bone turned so its bend off the bone before is the target
	for f in FINGERS:
		var prev := dir
		for j in 3:
			var b := skel.find_bone("%s%s%d" % [pre, f, j + 1])
			if b < 0:
				break
			var want := lerpf(float(RELAX[f][j]), float(HOLD[f][j]), h)
			var cur := prev.signed_angle_to(_y(skel, b), hinge)
			_turn(skel, b, hinge, (want - cur) * w)
			prev = _y(skel, b)
	# 4. the thumb: its root swung in toward the palm, the joints a little curled
	var t1 := skel.find_bone(pre + "Thumb1")
	if t1 >= 0:
		_turn(skel, t1, across.cross(palm).normalized(), lerpf(THUMB_SWING, THUMB_HOLD_SWING, h) * w)
		var t2 := skel.find_bone(pre + "Thumb2")
		var tl := _y(skel, t1)
		var th := tl.cross(palm).normalized()
		for j in 3:
			var b := skel.find_bone("%sThumb%d" % [pre, j + 1])
			if b >= 0:
				_turn(skel, b, th, lerpf(float(THUMB_CURL[j]), float(THUMB_HOLD_CURL[j]), h) * w)
		if t2 < 0:
			return

## Rotates bone b about a skeleton-space axis through its joint (the axis taken into the
## parent's frame, as Crumple._bend does).
func _turn(skel: Skeleton3D, b: int, axis_skel: Vector3, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))
