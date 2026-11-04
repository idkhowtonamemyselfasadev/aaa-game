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

func _process_modification_with_delta(_delta: float) -> void:
	drop = 0.0
	var skel := get_skeleton()
	if skel == null or absf(k - 1.0) < 1e-3:
		return
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

func _bend(skel: Skeleton3D, b: int, axis_skel: Vector3, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))
