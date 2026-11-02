class_name LegTuck
extends SkeletonModifier3D
## Bends both legs on top of whatever the animation posed: the thighs swing forward about the
## body's side axis (hip flexion) and the shins fold back (knee flexion). Drives a crouch that
## really bends the knees, and the knees-up tuck of a body in the air.

const LEGS := [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg"], ["mixamorig_RightUpLeg", "mixamorig_RightLeg"]]

var hip := 0.0               # radians the thighs swing forward
var knee := 0.0              # radians the shins fold back from the thigh line
var side: Node3D             # node whose +X is the bend axis and +Z is forward (the Body)

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or (absf(hip) < 1e-4 and absf(knee) < 1e-4):
		return
	var axis_world := side.global_basis.x if side != null else Vector3.RIGHT
	var axis_skel := (skel.global_basis.orthonormalized().inverse() * axis_world).normalized()
	for leg in LEGS:
		# rotating "down" about +X by +a swings it toward -Z, so forward is -a
		_bend(skel, leg[0], axis_skel, -hip)
		_bend(skel, leg[1], axis_skel, knee)

func _bend(skel: Skeleton3D, bone: String, axis_skel: Vector3, angle: float) -> void:
	var b := skel.find_bone(bone)
	if b < 0 or absf(angle) < 1e-4:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))
