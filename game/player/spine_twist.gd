class_name SpineTwist
extends SkeletonModifier3D
## Adds a yaw twist about the body's up axis, spread over the three spine bones, on top of
## whatever the animation posed. Lets an attack wind the chest into a swing.

const BONES := ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]
const SHARE := [0.25, 0.35, 0.40]

var twist := 0.0             # radians, positive turns the chest toward the hero's left
var up: Node3D               # node whose +Y is the twist axis (the player's Body)

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or absf(twist) < 1e-4:
		return
	var axis_world := up.global_basis.y if up != null else Vector3.UP
	var axis_skel := (skel.global_basis.orthonormalized().inverse() * axis_world).normalized()
	for i in BONES.size():
		var b := skel.find_bone(BONES[i])
		if b < 0:
			continue
		var parent := skel.get_bone_parent(b)
		var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var local_axis := (pb.inverse() * axis_skel).normalized()
		var q := Quaternion(local_axis, twist * float(SHARE[i]))
		skel.set_bone_pose_rotation(b, q * skel.get_bone_pose_rotation(b))
