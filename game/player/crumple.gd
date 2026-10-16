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
var frame := Basis()         # the skeleton's rest orientation in body space (set by Player)

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
		_bend(skel, "mixamorig_%sUpLeg" % side, x, -hip - pelvis)
		_bend(skel, "mixamorig_%sLeg" % side, x, knee)
		var bh := back_hand if side == "Right" else 0.0
		var ts := toss if side == "Right" else 0.0
		# a hand to the back: the upper arm swings behind the hip, the forearm folds across;
		# a toss over the shoulder: the arm goes up past the ear, the forearm drops behind
		_bend(skel, "mixamorig_%sArm" % side, x, -lerpf(lerpf(arm, -1.0, bh), toss_arm, ts))
		_bend(skel, "mixamorig_%sForeArm" % side, x, -lerpf(lerpf(elbow, 1.7, bh), toss_elbow, ts))
		if ts > 0.0:
			_bend(skel, "mixamorig_%sArm" % side, fwd, toss_in * ts)
	_bend(skel, "mixamorig_Spine", x, spine * 0.3)
	_bend(skel, "mixamorig_Spine1", x, spine * 0.35)
	_bend(skel, "mixamorig_Spine2", x, spine * 0.35)
	_bend(skel, "mixamorig_Neck", x, -neck)
	_bend(skel, "mixamorig_Head", up, head_turn)

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
