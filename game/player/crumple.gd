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
var flick_across := 0.0      # radians: the flicked upper arm rolled about the body's forward axis, so a
							 # forearm folded up before the face is laid across it (a shielding arm)
var probe := PackedStringArray() # (bots) bones whose skeleton-space origins are recorded after the bends
var probed := {}             # (bots) bone name -> its skeleton-space origin as posed by this modifier
var grip := 0.0              # 0..1: the right hand's fingers close into a fist (round a bail or a helve)
var grip_fold := 0.0         # (bots) the closed hand as posed: the middle finger's first bone . the palm's normal
var grip_thumb := 0.0        # (bots) the thumb's second bone . the palm's normal (folded over the fingers)
var grip_gap := 0.0          # (bots) m from the thumb's last joint (its tip if rigged) to the index's middle joint
var grip_tip := Vector3.ZERO # (bots) the thumb's last bone in the hand's frame: (along the hand, index-ward, palm-ward)
var grip_turn := 1.0         # (bots) and its second bone . the hand's length (below 0: folded back to the wrist)
var clasp := 0.0             # radians: both upper arms drawn in to the midline (two hands on a helve)
var chest_twist := 0.0       # radians about the body's up, spread over the spine (+ turns the chest to the left)
var arm_sweep := 0.0         # radians: both upper arms swung round the body's up (+ to the left), a fling across
var square := 0.0            # 0..1: turn the hips and chest square to the body (undo a guard stance's
							 # twist), so a body tipped onto its back lies flat instead of rolled on one side
var arm_aim := 0.0           # 0..1: likewise hang both arms straight at the sides before arm/elbow bend
var leg_aim := 0.0           # 0..1: first hang both legs straight and plumb (the body's down, a touch apart),
							 # whatever stance the clip had, so hip/knee/stride bend from an even start
var ankle := 0.0             # radians, positive points the toes down (a push-off, a reach for the
							 # ground); negative lifts them
var sole_flat := 0.0         # 0..1: the feet turned back by what the hip/knee/stride bends tipped
							 # them, so a folded leg keeps its sole flat on the ground
var stride := 0.0            # radians: climbing reach, + raises the left arm and right leg, - the other pair
var hip_lr := Vector2.ZERO   # radians on top of hip, per leg (x left, y right): one thigh ahead, one behind
var knee_lr := Vector2.ZERO  # likewise on top of knee (a braced front leg, a folded back one)
var ankle_lr := Vector2.ZERO # likewise on top of ankle, after sole_flat (- toes up on a heel strike,
							 # + toes down: a back heel lifted onto the ball of the foot)
var arm_lr := Vector2.ZERO   # likewise on top of arm (a counter-swing)
var ground := 0.0            # 0..1: after the leg bends, the hips are moved up or down so the lower
							 # ankle sits at its rest height (a posed stance stays on the turf)
var settle := 0              # after `ground`: 1 the left leg, 2 the right one is bent down at the knee
							 # (two-bone, in its own plane) until its ankle is settle_lift over its rest
							 # height: a back foot reaching the turf on the ball of the foot
var settle_lift := 0.06      # m
var ground_toe := 0          # with `ground`: 1 the left, 2 the right foot's toes (not the lower ankle)
							 # are what is set on the turf: a drive foot pushing off its toes, heel up
var clip_ahead := 0.0        # (read) m the right foot stands ahead of the left in the clip's own pose,
							 # before any bend here: which stride phase the run clip is in
var ground_drop := 0.0       # (bots) m the hips stand below their rest height once grounded
var frame := Basis()         # the skeleton's rest orientation in body space (set by Player)
var plant := 0.0             # 0..1: both wrists reach for hand_target (holds on a climbing face)
var hand_target := [Vector3.ZERO, Vector3.ZERO]   # world wrist targets, left then right
var hand_wall := Vector3.FORWARD # world: the face's outward normal; the palms turn to it
var hand_curl := 0.4         # the fingers half close over the stone they hold
var shoulder := [Vector3.ZERO, Vector3.ZERO]      # world shoulder joints as posed, before the reach
var hand_err := [0.0, 0.0]   # (bots) m from each wrist to its target after the reach
var foot_plant := 0.0        # 0..1: both ankles reach for foot_target (toe holds on the face)
var foot_target := [Vector3.ZERO, Vector3.ZERO]   # world ankle targets, left then right
var hip_joint := [Vector3.ZERO, Vector3.ZERO]     # world hip joints as posed, before the reach
var foot_err := [0.0, 0.0]   # (bots) m from each ankle to its target after the reach
var hip_shift := Vector3.ZERO # world m: the hips (and all above) moved this way before the limb reaches,
							 # the spine bent back so the chest stays near centre (weight over a standing foot)
var hip_roll := 0.0          # rad: the pelvis rolls about the facing so one hip hikes (+ = the left hip up,
							 # a climber's stepping side), the spine rolled back so the shoulders stay level

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	# axes are given in body space (the body faces +Z: rotating about +X tips +Y toward +Z)
	var to_skel := frame.inverse()
	var x := (to_skel * Vector3.RIGHT).normalized()
	var up := (to_skel * Vector3.UP).normalized()
	var fwd := (to_skel * Vector3.BACK).normalized()
	var clf := skel.find_bone("mixamorig_LeftFoot")
	var crf := skel.find_bone("mixamorig_RightFoot")
	if clf >= 0 and crf >= 0:
		clip_ahead = (skel.get_bone_global_pose(crf).origin - skel.get_bone_global_pose(clf).origin).dot(fwd) \
			* skel.global_basis.get_scale().x
	if square > 0.0:
		_square(skel, "mixamorig_Hips", "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", x, up)
		_square(skel, "mixamorig_Spine2", "mixamorig_LeftArm", "mixamorig_RightArm", x, up)
	_bend(skel, "mixamorig_Hips", x, pelvis)
	for side in ["Left", "Right"]:
		var sg := 1.0 if side == "Left" else -1.0
		if leg_aim > 0.0:
			_hang_leg(skel, side, (-up + x * sg * 0.1).normalized())
		var li := 0 if side == "Left" else 1
		var th := hip - stride * sg * 1.1 + hip_lr[li]
		var kn := knee - stride * sg * 1.3 + knee_lr[li]
		_bend(skel, "mixamorig_%sUpLeg" % side, x, -th - pelvis)
		_bend(skel, "mixamorig_%sLeg" % side, x, kn)
		_bend(skel, "mixamorig_%sFoot" % side, x, ankle + ankle_lr[li] - sole_flat * (kn - th))
		if arm_aim > 0.0:
			_hang(skel, "mixamorig_%sArm" % side, "mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side,
				(-up + x * sg * 0.3).normalized(), arm_aim)
		var bh := back_hand if side == "Right" else 0.0
		var ts := toss if side == "Right" else 0.0
		# a hand to the back: the upper arm swings behind the hip, the forearm folds across;
		# a toss over the shoulder: the arm goes up past the ear, the forearm drops behind
		if clasp != 0.0:
			_bend(skel, "mixamorig_%sArm" % side, fwd, clasp * (1.0 if side == "Right" else -1.0))
		if arm_sweep != 0.0:
			_bend(skel, "mixamorig_%sArm" % side, up, arm_sweep)
		_bend(skel, "mixamorig_%sArm" % side, x, -lerpf(lerpf(arm + stride * sg + arm_lr[0 if side == "Left" else 1], -1.0, bh), toss_arm, ts))
		_bend(skel, "mixamorig_%sForeArm" % side, x, -lerpf(lerpf(elbow, 1.7, bh), toss_elbow, ts))
		if ts > 0.0:
			_bend(skel, "mixamorig_%sArm" % side, fwd, toss_in * ts)
		if side == "Right" and flick > 0.0:
			# on top of the pose: the difference to the flick's arm and elbow
			_bend(skel, "mixamorig_RightArm", x, -(flick_arm - arm) * flick)
			_bend(skel, "mixamorig_RightForeArm", x, -(flick_elbow - elbow) * flick)
			if flick_out != 0.0:
				_bend(skel, "mixamorig_RightArm", up, -flick_out * flick)
			if flick_across != 0.0:
				_bend(skel, "mixamorig_RightArm", fwd, flick_across * flick)
	if grip > 0.0:
		_grip(skel, "Right", grip)
	_bend(skel, "mixamorig_Spine", x, spine * 0.3)
	_bend(skel, "mixamorig_Spine1", x, spine * 0.35)
	_bend(skel, "mixamorig_Spine2", x, spine * 0.35)
	if chest_twist != 0.0:
		_bend(skel, "mixamorig_Spine", up, chest_twist * 0.25)
		_bend(skel, "mixamorig_Spine1", up, chest_twist * 0.35)
		_bend(skel, "mixamorig_Spine2", up, chest_twist * 0.4)
	_bend(skel, "mixamorig_Neck", x, -neck)
	_bend(skel, "mixamorig_Head", up, head_turn)
	if hip_shift != Vector3.ZERO:
		_shift_hips(skel, up)
	if hip_roll != 0.0:
		_roll_hips(skel, fwd)
	if ground > 0.0:
		_ground(skel, up)
		if settle > 0:
			_settle_leg(skel, "Left" if settle == 1 else "Right", up)
	var sides := ["Left", "Right"]
	for i in 2:
		var sb := skel.find_bone("mixamorig_%sArm" % sides[i])
		if sb >= 0:
			shoulder[i] = skel.global_transform * skel.get_bone_global_pose(sb).origin
	for i in 2:
		var hb := skel.find_bone("mixamorig_%sUpLeg" % sides[i])
		if hb >= 0:
			hip_joint[i] = skel.global_transform * skel.get_bone_global_pose(hb).origin
	if foot_plant > 0.0:
		for i in 2:
			_reach_leg(skel, sides[i], foot_target[i], foot_plant)
	if plant > 0.0:
		# last of all, after the spine has moved the shoulders: the hands go to their holds
		for i in 2:
			_reach(skel, sides[i], hand_target[i], plant)
			_grip(skel, sides[i], hand_curl * plant)
	for n in probe:
		var pb := skel.find_bone(n)
		if pb >= 0:
			probed[n] = skel.get_bone_global_pose(pb).origin

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

## Two-bone leg reach: the thigh and shin turn so the ankle lands on `target` (world), the
## knee bowed into the face and a little out like a climber's frog; then the foot turns so the
## toes dig into the face, a touch downward, standing on the stone's edge.
func _reach_leg(skel: Skeleton3D, side: String, target: Vector3, w: float) -> void:
	var ul := skel.find_bone("mixamorig_%sUpLeg" % side)
	var lg := skel.find_bone("mixamorig_%sLeg" % side)
	var ft := skel.find_bone("mixamorig_%sFoot" % side)
	var hp := skel.find_bone("mixamorig_Hips")
	var toe := skel.find_bone("mixamorig_%sToeBase" % side)
	if ul < 0 or lg < 0 or ft < 0 or hp < 0:
		return
	var inv := skel.global_transform.affine_inverse()
	var up := (inv.basis * Vector3.UP).normalized()
	var wall := (inv.basis * hand_wall).normalized()
	var s := skel.get_bone_global_pose(ul).origin
	var k := skel.get_bone_global_pose(lg).origin
	var f := skel.get_bone_global_pose(ft).origin
	var a := s.distance_to(k)
	var b := k.distance_to(f)
	var t := f.lerp(inv * target, w)
	var d := t - s
	var dl := clampf(d.length(), absf(a - b) + 1e-3, (a + b) * 0.995)
	var dn := d.normalized()
	var out := s - skel.get_bone_global_pose(hp).origin
	out = (out - up * out.dot(up) - wall * out.dot(wall)).normalized()
	var pole := -wall * 0.75 + out * 0.55 + up * 0.15
	pole = (pole - dn * pole.dot(dn)).normalized()
	var d1 := (a * a - b * b + dl * dl) / (2.0 * dl)
	var k_new := s + dn * d1 + pole * sqrt(maxf(a * a - d1 * d1, 0.0))
	_swing(skel, ul, k - s, k_new - s)
	k = skel.get_bone_global_pose(lg).origin
	f = skel.get_bone_global_pose(ft).origin
	_swing(skel, lg, f - k, t - k)
	f = skel.get_bone_global_pose(ft).origin
	foot_err[0 if side == "Left" else 1] = f.distance_to(inv * target) * skel.global_basis.get_scale().x
	if toe < 0 or w < 0.5:
		return
	# toes into the face, tipped down onto the stone's edge
	var want := (-wall * 0.85 - up * 0.5).normalized()
	_swing(skel, ft, skel.get_bone_global_pose(toe).origin - f, want)

## Swings the thigh, then the shin, toward `down` (skeleton space) by leg_aim: a straight leg
## hanging from the hip.
func _hang_leg(skel: Skeleton3D, side: String, down: Vector3) -> void:
	_hang(skel, "mixamorig_%sUpLeg" % side, "mixamorig_%sLeg" % side, "mixamorig_%sFoot" % side, down, leg_aim)

## The same for any two-bone limb (upper, lower, end joint) by weight w.
func _hang(skel: Skeleton3D, upper: String, lower: String, end: String, down: Vector3, w: float) -> void:
	var ul := skel.find_bone(upper)
	var lg := skel.find_bone(lower)
	var ft := skel.find_bone(end)
	if ul < 0 or lg < 0 or ft < 0:
		return
	var th := skel.get_bone_global_pose(lg).origin - skel.get_bone_global_pose(ul).origin
	_swing(skel, ul, th, th.normalized().slerp(down, w))
	var sh := skel.get_bone_global_pose(ft).origin - skel.get_bone_global_pose(lg).origin
	_swing(skel, lg, sh, sh.normalized().slerp(down, w))

## Turns a bone (skeleton-space rotation, pivoting at its joint) so `from` points along `to`.
func _swing(skel: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	var ax := from.cross(to)
	if ax.length() < 1e-6:
		return
	_bend(skel, skel.get_bone_name(b), ax.normalized(), from.angle_to(to))

## Moves the root (the hips, and all above and below them) along up so the lower of the two
## ankles stands at its rest height: the stance's legs decide how low the body sits.
func _ground(skel: Skeleton3D, up: Vector3) -> void:
	var hb := skel.find_bone("mixamorig_Hips")
	var lf := skel.find_bone("mixamorig_LeftFoot")
	var rf := skel.find_bone("mixamorig_RightFoot")
	if hb < 0 or lf < 0 or rf < 0 or skel.get_bone_parent(hb) >= 0:
		return
	var rest := minf(skel.get_bone_global_rest(lf).origin.dot(up), skel.get_bone_global_rest(rf).origin.dot(up))
	var low := minf(skel.get_bone_global_pose(lf).origin.dot(up), skel.get_bone_global_pose(rf).origin.dot(up))
	if ground_toe > 0:
		var tb := skel.find_bone("mixamorig_%sToeBase" % ("Left" if ground_toe == 1 else "Right"))
		var tl := skel.find_bone("mixamorig_LeftToeBase")
		var tr := skel.find_bone("mixamorig_RightToeBase")
		if tb >= 0 and tl >= 0 and tr >= 0:
			# the rig's two rest toes do not stand level: the lower one is the turf
			rest = minf(skel.get_bone_global_rest(tl).origin.dot(up), skel.get_bone_global_rest(tr).origin.dot(up))
			low = skel.get_bone_global_pose(tb).origin.dot(up)
			# the other foot never goes into the turf: while it is still the lower, it is the contact
			var ot := tr if ground_toe == 1 else tl
			var of := rf if ground_toe == 1 else lf
			var rest_a := minf(skel.get_bone_global_rest(lf).origin.dot(up), skel.get_bone_global_rest(rf).origin.dot(up))
			low = minf(low, skel.get_bone_global_pose(ot).origin.dot(up) + 0.0)
			low = minf(low, skel.get_bone_global_pose(of).origin.dot(up) - (rest_a - rest))
	var d := (rest - low) * ground
	skel.set_bone_pose_position(hb, skel.get_bone_pose_position(hb) + up * d)
	ground_drop = (skel.get_bone_global_rest(hb).origin.dot(up) - skel.get_bone_global_pose(hb).origin.dot(up)) \
		* skel.global_basis.get_scale().x

## Two-bone: the thigh and shin turn, keeping the knee's bend plane, so the ankle comes straight
## down to settle_lift over its rest height (by `ground`); the foot keeps its posed angle.
func _settle_leg(skel: Skeleton3D, side: String, up: Vector3) -> void:
	var ul := skel.find_bone("mixamorig_%sUpLeg" % side)
	var lg := skel.find_bone("mixamorig_%sLeg" % side)
	var ft := skel.find_bone("mixamorig_%sFoot" % side)
	var toe := skel.find_bone("mixamorig_%sToeBase" % side)
	if ul < 0 or lg < 0 or ft < 0 or toe < 0:
		return
	var sc := skel.global_basis.get_scale().x
	var s := skel.get_bone_global_pose(ul).origin
	var k := skel.get_bone_global_pose(lg).origin
	var f := skel.get_bone_global_pose(ft).origin
	var want := skel.get_bone_global_rest(ft).origin.dot(up) + settle_lift / maxf(sc, 1e-6)
	var over := (f.dot(up) - want) * ground
	# the toes are what reach the turf: bring the foot down until they touch (not past the rest
	# height of the ankle), however far the posed angle points them
	var tl := skel.find_bone("mixamorig_LeftToeBase")
	var tr := skel.find_bone("mixamorig_RightToeBase")
	if tl >= 0 and tr >= 0:
		var rest_t := minf(skel.get_bone_global_rest(tl).origin.dot(up), skel.get_bone_global_rest(tr).origin.dot(up))
		var toe_over := skel.get_bone_global_pose(toe).origin.dot(up) - rest_t
		over = minf(toe_over, f.dot(up) - skel.get_bone_global_rest(ft).origin.dot(up)) * ground
	if over <= 0.0:
		return
	var toe_dir := skel.get_bone_global_pose(toe).origin - f
	var a := s.distance_to(k)
	var b := k.distance_to(f)
	var t := f - up * over
	var d := t - s
	var reach := (a + b) * 0.985
	if d.length() > reach:
		# out of reach from the hip: the foot comes in under the body at that height (a shorter
		# stance), rather than hanging in the air short of the turf
		var dv := d.dot(up)
		var dh := d - up * dv
		var hl := sqrt(maxf(reach * reach - dv * dv, 0.0))
		if dh.length() > 1e-5:
			t = s + up * dv + dh.normalized() * hl
			d = t - s
	var dl := clampf(d.length(), absf(a - b) + 1e-3, (a + b) * 0.995)
	var dn := d.normalized()
	var pole := (k - s) - dn * (k - s).dot(dn)
	if pole.length() < 1e-5:
		return
	pole = pole.normalized()
	var d1 := (a * a - b * b + dl * dl) / (2.0 * dl)
	var k_new := s + dn * d1 + pole * sqrt(maxf(a * a - d1 * d1, 0.0))
	_swing(skel, ul, k - s, k_new - s)
	k = skel.get_bone_global_pose(lg).origin
	f = skel.get_bone_global_pose(ft).origin
	_swing(skel, lg, f - k, t - k)
	f = skel.get_bone_global_pose(ft).origin
	_swing(skel, ft, skel.get_bone_global_pose(toe).origin - f, toe_dir)

## Moves the hips by hip_shift (world) and bends the spine back the other way, so the pelvis
## sways out over a standing foot while the shoulders stay nearly over the holds (an S through
## the trunk, like a climber's weight shift). The limb reaches run after this.
func _shift_hips(skel: Skeleton3D, up: Vector3) -> void:
	var hb := skel.find_bone("mixamorig_Hips")
	if hb < 0 or skel.get_bone_parent(hb) >= 0:
		return
	var d := skel.global_transform.affine_inverse().basis * hip_shift
	skel.set_bone_pose_position(hb, skel.get_bone_pose_position(hb) + d)
	var m := hip_shift.length()
	var k := d.normalized().cross(up)
	if k.length() < 1e-4:
		return
	k = k.normalized()
	# ~1.7 rad per metre of shift, spread up the spine: the top leans back toward the middle
	_bend(skel, "mixamorig_Spine", k, m * 0.6)
	_bend(skel, "mixamorig_Spine1", k, m * 0.6)
	_bend(skel, "mixamorig_Spine2", k, m * 0.5)

## Rolls the pelvis about the facing by hip_roll so the stepping side's hip hikes up, and rolls
## the spine back the other way, mostly low down, so the chest and shoulders stay level over the
## holds. The limb reaches run after this and keep hands and feet on their stones.
func _roll_hips(skel: Skeleton3D, fwd: Vector3) -> void:
	var a := hip_roll * ROLL_SIGN
	_bend(skel, "mixamorig_Hips", fwd, a)
	_bend(skel, "mixamorig_Spine", fwd, -a * 0.5)
	_bend(skel, "mixamorig_Spine1", fwd, -a * 0.32)
	_bend(skel, "mixamorig_Spine2", fwd, -a * 0.18)

const ROLL_SIGN := 1.0

## Rotates a bone about an axis given in skeleton space, pivoting at its own joint.
## Turns a bone about the body's up so the line from its right child joint to its left one
## lies along the body's right axis (by `square`).
func _square(skel: Skeleton3D, bone_name: String, left: String, right: String, x: Vector3, up: Vector3) -> void:
	var l := skel.find_bone(left)
	var r := skel.find_bone(right)
	if l < 0 or r < 0:
		return
	var line := skel.get_bone_global_pose(l).origin - skel.get_bone_global_pose(r).origin
	var flat := line - up * line.dot(up)
	if flat.length() < 1e-4:
		return
	_bend(skel, bone_name, up, atan2(flat.cross(x).dot(up), flat.dot(x)) * square)

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
