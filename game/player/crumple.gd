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
var frame := Basis()         # the skeleton's rest orientation in body space (set by Player)

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	# axes are given in body space (the body faces +Z: rotating about +X tips +Y toward +Z)
	var to_skel := frame.inverse()
	var x := (to_skel * Vector3.RIGHT).normalized()
	var up := (to_skel * Vector3.UP).normalized()
	for side in ["Left", "Right"]:
		_bend(skel, "mixamorig_%sUpLeg" % side, x, -hip)
		_bend(skel, "mixamorig_%sLeg" % side, x, knee)
		_bend(skel, "mixamorig_%sArm" % side, x, -arm)
		_bend(skel, "mixamorig_%sForeArm" % side, x, -elbow)
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
