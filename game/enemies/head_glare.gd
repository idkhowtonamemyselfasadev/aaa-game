class_name HeadGlare
extends SkeletonModifier3D
## Turns the neck and head about the body's up axis so the face keeps on a target while the
## chest twists away under it (the knight's reveal coil: the chest winds round to its right, the
## helm stays on the hero). Measures where the head really faces after everything before it in
## the stack, so it only adds the yaw still missing, clamped to what a neck can turn.

const BONES := ["mixamorig_Neck", "mixamorig_Head"]
const SHARE := [0.45, 0.55]

var weight := 0.0            # 0..1 how much of the missing yaw is taken up
var target := Vector3.ZERO   # world point the face turns onto
var side: Node3D             # node whose +Y is the twist axis and +Z is forward (the Body)
var max_yaw := 1.1           # rad the neck and head may add on top of the chest
var last_err := 0.0          # (bots) yaw left between the face and the target before the turn

## The head's facing in world space: the body's forward carried by how far the head bone has
## turned from its rest (the rig faces body +Z at rest).
static func head_forward(skel: Skeleton3D, body: Node3D) -> Vector3:
	var b := skel.find_bone("mixamorig_Head")
	if b < 0:
		return body.global_basis.z
	var r := skel.get_bone_global_pose(b).basis.orthonormalized() \
		* skel.get_bone_global_rest(b).basis.orthonormalized().inverse()
	var sk := skel.global_basis.orthonormalized()
	return sk * (r * (sk.inverse() * body.global_basis.z.normalized()))

## Signed yaw (rad, + toward body +X) from the face to `at`, flat on the body's up plane.
static func yaw_to(skel: Skeleton3D, body: Node3D, at: Vector3) -> float:
	var up := body.global_basis.y.normalized()
	var f := head_forward(skel, body)
	var hb := skel.find_bone("mixamorig_Head")
	var hp := skel.global_transform * skel.get_bone_global_pose(hb).origin if hb >= 0 else body.global_position
	var t := at - hp
	f -= up * f.dot(up)
	t -= up * t.dot(up)
	if f.length() < 1e-4 or t.length() < 1e-4:
		return 0.0
	return f.normalized().signed_angle_to(t.normalized(), up)

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or side == null or weight < 1e-3:
		last_err = 0.0
		return
	last_err = yaw_to(skel, side, target)
	var a := clampf(last_err, -max_yaw, max_yaw) * weight
	if absf(a) < 1e-4:
		return
	var axis_skel := (skel.global_basis.orthonormalized().inverse() * side.global_basis.y).normalized()
	for i in BONES.size():
		var b := skel.find_bone(BONES[i])
		if b < 0:
			continue
		var parent := skel.get_bone_parent(b)
		var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var local_axis := (pb.inverse() * axis_skel).normalized()
		skel.set_bone_pose_rotation(b, Quaternion(local_axis, a * float(SHARE[i])) * skel.get_bone_pose_rotation(b))
