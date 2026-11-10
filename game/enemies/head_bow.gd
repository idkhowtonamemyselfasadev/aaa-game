class_name HeadBow
extends SkeletonModifier3D
## Bows the head and neck forward (and the upper chest a little with them) and rolls them to
## the side, on top of whatever the animation posed. Drives a stunned reel: the head knocked
## down onto the chest, lolling, then shaken off.

const BONES := ["mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head"]
const BOW_SHARE := [0.2, 0.45, 0.35]
const ROLL_SHARE := [0.15, 0.4, 0.45]

var bow := 0.0               # radians the head drops forward (negative lifts it)
var roll := 0.0              # radians the head lolls toward the body's right (+X side drops)
var side: Node3D             # node whose +X is the bow axis and +Z is forward (the Body)
## (11-10) where the head bone and the left hand ended up, world space, as last posed (read here,
## after the arm IK and the bow: outside the modifier pass the skeleton hands back the clip's pose)
var head_world := Vector3.INF
var hand_l_world := Vector3.INF
var _hb := -2
var _lh := -2

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if absf(bow) < 1e-4 and absf(roll) < 1e-4:
		_record(skel)
		return
	var inv := skel.global_basis.orthonormalized().inverse()
	var bx := side.global_basis.x if side != null else Vector3.RIGHT
	var bz := side.global_basis.z if side != null else Vector3.BACK
	var ax := (inv * bx).normalized()
	var az := (inv * bz).normalized()
	for i in BONES.size():
		var b := skel.find_bone(BONES[i])
		if b < 0:
			continue
		var parent := skel.get_bone_parent(b)
		var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var pinv := pb.inverse()
		# rotating "up" about +X by +a tips it toward +Z: forward is +a; about +Z by +a it tips
		# toward -X, so the head drops to the body's right with -a
		var q := Quaternion((pinv * ax).normalized(), bow * float(BOW_SHARE[i])) \
			* Quaternion((pinv * az).normalized(), -roll * float(ROLL_SHARE[i]))
		skel.set_bone_pose_rotation(b, q * skel.get_bone_pose_rotation(b))

	_record(skel)

func _record(skel: Skeleton3D) -> void:
	if _hb == -2:
		_hb = skel.find_bone("mixamorig_Head")
		_lh = skel.find_bone("mixamorig_LeftHand")
	if _hb >= 0:
		head_world = skel.global_transform * skel.get_bone_global_pose(_hb).origin
	if _lh >= 0:
		hand_l_world = skel.global_transform * skel.get_bone_global_pose(_lh).origin
