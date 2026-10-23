class_name Crumple
extends SkeletonModifier3D
## The hero's death fall, layered on top of whatever the animation posed: knees fold, the
## hips and spine curl, the arms go limp and the head turns to one side. Every bend is a
## rotation about the body's right axis (the sagittal plane), so the joints compose cleanly;
## Player tilts the whole model about the knees on top of this.

var knee := 0.0              # radians, positive folds the shin back under the thigh
var hip := 0.0               # radians, positive brings the thigh forward
var spine := 0.0             # radians, positive curls the chest forward (spread over 3 bones)
var arm := 0.0               # radians, positive swings the upper arms forward
var elbow := 0.0             # radians, positive bends the forearms
var neck := 0.0              # radians, positive lifts the head back (an old stoop looks up)
var head_turn := 0.0         # radians about the neck, so the face does not plant in the dirt
var pelvis := 0.0            # radians, positive tips the pelvis (and all above it) forward
							 # at the hip joints; the thighs are held where `hip` puts them
var back_hand := 0.0         # 0..1: the right hand goes round to the small of the back
var toss := 0.0              # 0..1: the right hand reaches up over the shoulder into a back basket
var toss_arm := 3.8          # the upper arm raised past the vertical, elbow up by the ear
var toss_elbow := 1.4        # the forearm laid back over the shoulder
var toss_in := -1.1          # the raised arm drawn in across toward the head (about body forward)
var flick := 0.0             # 0..1: the right arm taken over by flick_arm/flick_elbow (a toss)
var flick_arm := 0.0
var flick_elbow := 0.0
var flick_out := 0.0         # radians: the flicked arm swung out to the right about the body's up axis
var grip := 0.0              # 0..1: the right hand's fingers close into a fist (round a bail or a helve)
var grip_fold := 0.0         # (bots) the closed hand as posed: the middle finger's first bone . the palm's normal
var grip_thumb := 0.0        # (bots) the thumb's second bone . the palm's normal (folded over the fingers)
var grip_gap := 0.0          # (bots) m from the thumb's last joint (its tip if rigged) to the index's middle joint
var grip_tip := Vector3.ZERO # (bots) the thumb's last bone in the hand's frame: (along the hand, index-ward, palm-ward)
var grip_turn := 1.0         # (bots) and its second bone . the hand's length (below 0: folded back to the wrist)
var clasp := 0.0             # radians: both upper arms drawn in to the midline (two hands on a helve)
var stride := 0.0            # radians: climbing reach, + raises the left arm and right leg, - the other pair
var frame := Basis()         # the skeleton's rest orientation in body space (set by Player)
var plant := 0.0             # 0..1: both wrists reach for hand_target (holds on a climbing face)
var hand_target := [Vector3.ZERO, Vector3.ZERO]   # world wrist targets, left then right
var hand_wall := Vector3.FORWARD # world: the face's outward normal; the palms turn to it
var hand_curl := 0.4         # the fingers half close over the stone they hold
var shoulder := [Vector3.ZERO, Vector3.ZERO]      # world shoulder joints as posed, before the reach
var hand_err := [0.0, 0.0]   # (bots) m from each wrist to its target after the reach

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	# axes are given in body space (the body faces +Z: rotating about +X tips +Y toward +Z)
	var to_skel := frame.inverse()
	var x := (to_skel * Vector3.RIGHT).normalized()
	var up := (to_skel * Vector3.UP).normalized()
	var fwd := (to_skel * Vector3.BACK).normalized()
	_bend(skel, "mixamorig_Hips", x, pelvis)
	for side in ["Left", "Right"]:
		var sg := 1.0 if side == "Left" else -1.0
		_bend(skel, "mixamorig_%sUpLeg" % side, x, -(hip - stride * sg * 1.1) - pelvis)
		_bend(skel, "mixamorig_%sLeg" % side, x, knee - stride * sg * 1.3)
		var bh := back_hand if side == "Right" else 0.0
		var ts := toss if side == "Right" else 0.0
		# a hand to the back: the upper arm swings behind the hip, the forearm folds across;
		# a toss over the shoulder: the arm goes up past the ear, the forearm drops behind
		if clasp != 0.0:
			_bend(skel, "mixamorig_%sArm" % side, fwd, clasp * (1.0 if side == "Right" else -1.0))
		_bend(skel, "mixamorig_%sArm" % side, x, -lerpf(lerpf(arm + stride * sg, -1.0, bh), toss_arm, ts))
		_bend(skel, "mixamorig_%sForeArm" % side, x, -lerpf(lerpf(elbow, 1.7, bh), toss_elbow, ts))
		if ts > 0.0:
			_bend(skel, "mixamorig_%sArm" % side, fwd, toss_in * ts)
		if side == "Right" and flick > 0.0:
			# on top of the pose: the difference to the flick's arm and elbow
			_bend(skel, "mixamorig_RightArm", x, -(flick_arm - arm) * flick)
			_bend(skel, "mixamorig_RightForeArm", x, -(flick_elbow - elbow) * flick)
			if flick_out != 0.0:
				_bend(skel, "mixamorig_RightArm", up, -flick_out * flick)
	if grip > 0.0:
		_grip(skel, "Right", grip)
	_bend(skel, "mixamorig_Spine", x, spine * 0.3)
	_bend(skel, "mixamorig_Spine1", x, spine * 0.35)
	_bend(skel, "mixamorig_Spine2", x, spine * 0.35)
	_bend(skel, "mixamorig_Neck", x, -neck)
	_bend(skel, "mixamorig_Head", up, head_turn)
	var sides := ["Left", "Right"]
	for i in 2:
		var sb := skel.find_bone("mixamorig_%sArm" % sides[i])
		if sb >= 0:
			shoulder[i] = skel.global_transform * skel.get_bone_global_pose(sb).origin
	if plant > 0.0:
		# last of all, after the spine has moved the shoulders: the hands go to their holds
		for i in 2:
			_reach(skel, sides[i], hand_target[i], plant)
			_grip(skel, sides[i], hand_curl * plant)

const GRIP_CURL := [1.25, 1.2, 0.8]   # radians per finger joint, knuckle to tip, at a full fist
const THUMB_CURL := [0.55, 0.6, 0.5]
const THUMB_SWING := -1.5    # radians: the thumb's root swung in across the palm (opposition)
const THUMB_WRAP := -0.35    # radians per bone: the thumb's tip turned across the fingers, pinky-ward

## Closes a hand: each finger folds toward the palm about its knuckle hinge. The hinge is found
## from the hand's own bones (finger direction and the pinky-to-index line), so it holds
## whatever the arm is doing; the thumb only half closes, across the fingers.
func _grip(skel: Skeleton3D, side: String, g: float) -> void:
	var hb := skel.find_bone("mixamorig_%sHand" % side)
	var mid := skel.find_bone("mixamorig_%sHandMiddle1" % side)
	var idx := skel.find_bone("mixamorig_%sHandIndex1" % side)
	var pin := skel.find_bone("mixamorig_%sHandPinky1" % side)
	if hb < 0 or mid < 0 or idx < 0 or pin < 0:
		return
	var h := skel.get_bone_global_pose(hb).origin
	var dir := (skel.get_bone_global_pose(mid).origin - h).normalized()
	var across := skel.get_bone_global_pose(idx).origin - skel.get_bone_global_pose(pin).origin
	across = (across - dir * across.dot(dir)).normalized()
	# the palm faces across x dir for a right hand (index on the thumb side), the other way for a left
	var palm := across.cross(dir) * (1.0 if side == "Right" else -1.0)
	var hinge := dir.cross(palm).normalized()
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		for j in 3:
			_bend(skel, "mixamorig_%sHand%s%d" % [side, f, j + 1], hinge, GRIP_CURL[j] * g)
	# the thumb folds over the fingers about its own hinge (the thumb's line x the palm's
	# normal), not the fingers' one: on theirs it stuck out sideways like a thumbs-up
	var t1 := skel.find_bone("mixamorig_%sHandThumb1" % side)
	var t2 := skel.find_bone("mixamorig_%sHandThumb2" % side)
	var t3 := skel.find_bone("mixamorig_%sHandThumb3" % side)
	if t1 >= 0 and t2 >= 0 and t3 >= 0:
		# first swing its root in across the palm about the hand's length, so the thumb lies
		# along the curled index instead of hooking out on the back-of-hand side
		_bend(skel, "mixamorig_%sHandThumb1" % side, across.cross(palm).normalized(), THUMB_SWING * g)
		var tl := (skel.get_bone_global_pose(t2).origin - skel.get_bone_global_pose(t1).origin).normalized()
		var th := tl.cross(palm).normalized()
		for j in 3:
			_bend(skel, "mixamorig_%sHandThumb%d" % [side, j + 1], th, THUMB_CURL[j] * g)
		# then turn its last two bones about the hand's length so the tip lies across the
		# curled fingers toward the pinky; left as it was, it pointed straight out of the fist
		for j in [1, 2]:
			_bend(skel, "mixamorig_%sHandThumb%d" % [side, j + 1], dir, THUMB_WRAP * g)
		var tip_dir := skel.get_bone_global_pose(t3).basis.y.normalized()
		grip_tip = Vector3(tip_dir.dot(dir), tip_dir.dot(across), tip_dir.dot(palm))
		grip_thumb = (skel.get_bone_global_pose(t3).origin - skel.get_bone_global_pose(t2).origin).normalized().dot(palm)
		var t4 := skel.find_bone("mixamorig_%sHandThumb4" % side)
		var i2 := skel.find_bone("mixamorig_%sHandIndex2" % side)
		if i2 >= 0:
			var tip := skel.get_bone_global_pose(t4 if t4 >= 0 else t3).origin
			grip_gap = tip.distance_to(skel.get_bone_global_pose(i2).origin) * skel.global_basis.get_scale().x
	# (bots) the middle finger as posed: its first bone into the palm, its second turned back
	var m2 := skel.find_bone("mixamorig_%sHandMiddle2" % side)
	var m3 := skel.find_bone("mixamorig_%sHandMiddle3" % side)
	if m2 >= 0 and m3 >= 0:
		var a1 := skel.get_bone_global_pose(mid).origin
		var a2 := skel.get_bone_global_pose(m2).origin
		var a3 := skel.get_bone_global_pose(m3).origin
		grip_fold = (a2 - a1).normalized().dot(palm)
		grip_turn = (a3 - a2).normalized().dot(dir)

## Two-bone reach: the upper arm and forearm turn so the wrist lands on `target` (world), the
## elbow bowed out, down and off the face like a climber's; then the hand turns so the fingers
## point up the face and the palm lies on it. `w` blends from the posed wrist to the target.
func _reach(skel: Skeleton3D, side: String, target: Vector3, w: float) -> void:
	var ua := skel.find_bone("mixamorig_%sArm" % side)
	var fa := skel.find_bone("mixamorig_%sForeArm" % side)
	var hd := skel.find_bone("mixamorig_%sHand" % side)
	var ch := skel.find_bone("mixamorig_Spine2")
	var mid := skel.find_bone("mixamorig_%sHandMiddle1" % side)
	if ua < 0 or fa < 0 or hd < 0 or ch < 0:
		return
	var inv := skel.global_transform.affine_inverse()
	var up := (inv.basis * Vector3.UP).normalized()
	var wall := (inv.basis * hand_wall).normalized()
	var s := skel.get_bone_global_pose(ua).origin
	var e := skel.get_bone_global_pose(fa).origin
	var h := skel.get_bone_global_pose(hd).origin
	var a := s.distance_to(e)
	var b := e.distance_to(h)
	var t := h.lerp(inv * target, w)
	var d := t - s
	var dl := clampf(d.length(), absf(a - b) + 1e-3, (a + b) * 0.995)
	var dn := d.normalized()
	var out := s - skel.get_bone_global_pose(ch).origin
	out = (out - up * out.dot(up)).normalized()
	var pole := out * 0.8 - up * 0.6 + wall * 0.35
	pole = (pole - dn * pole.dot(dn)).normalized()
	var d1 := (a * a - b * b + dl * dl) / (2.0 * dl)
	var e_new := s + dn * d1 + pole * sqrt(maxf(a * a - d1 * d1, 0.0))
	_swing(skel, ua, e - s, e_new - s)
	e = skel.get_bone_global_pose(fa).origin
	h = skel.get_bone_global_pose(hd).origin
	_swing(skel, fa, h - e, t - e)
	h = skel.get_bone_global_pose(hd).origin
	hand_err[0 if side == "Left" else 1] = h.distance_to(inv * target) * skel.global_basis.get_scale().x
	if mid < 0 or w < 0.5:
		return
	# fingers up the face, tipped a little into it so they hook over the stone above
	var want := (up - wall * up.dot(wall)).normalized() - wall * 0.25
	_swing(skel, hd, skel.get_bone_global_pose(mid).origin - h, want)
	var idx := skel.find_bone("mixamorig_%sHandIndex1" % side)
	var pin := skel.find_bone("mixamorig_%sHandPinky1" % side)
	if idx < 0 or pin < 0:
		return
	var dir := (skel.get_bone_global_pose(mid).origin - h).normalized()
	var across := skel.get_bone_global_pose(idx).origin - skel.get_bone_global_pose(pin).origin
	across = (across - dir * across.dot(dir)).normalized()
	var palm := across.cross(dir) * (1.0 if side == "Right" else -1.0)
	var flat := -wall - dir * (-wall).dot(dir)
	palm = palm - dir * palm.dot(dir)
	if flat.length() > 1e-3 and palm.length() > 1e-3:
		_swing(skel, hd, palm, flat)

## Turns a bone (skeleton-space rotation, pivoting at its joint) so `from` points along `to`.
func _swing(skel: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	var ax := from.cross(to)
	if ax.length() < 1e-6:
		return
	_bend(skel, skel.get_bone_name(b), ax.normalized(), from.angle_to(to))

## Rotates a bone about an axis given in skeleton space, pivoting at its own joint.
func _bend(skel: Skeleton3D, bone_name: String, axis_skel: Vector3, angle: float) -> void:
	if absf(angle) < 1e-4:
		return
	var b := skel.find_bone(bone_name)
	if b < 0:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))
