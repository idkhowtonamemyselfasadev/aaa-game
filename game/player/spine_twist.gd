class_name SpineTwist
extends SkeletonModifier3D
## Adds a yaw twist about the body's up axis, spread over the three spine bones, on top of
## whatever the animation posed. Lets an attack wind the chest into a swing.
##
## (16:30 11-08) `square`: with the staff held in both fists at guard a runner can't pump the
## arms, but the run clip turns the shoulder line up to ~55 deg each stride (clavicles and
## chest), which drove the right shoulder joint 0.3 m forward onto the guard staff (the right
## fist slid 0.12 m off the shaft). With square > 0 this modifier reads the shoulder line from
## the pose as it stands this tick (no lag), eases the clavicles toward rest by `clav_hold`, and
## adds the yaw that turns the shoulder line back toward `square_ref` (its heading at guard)
## times `square`. `last_yaw` = the line's heading before the counter (read-out).

const BONES := ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]
const SHARE := [0.25, 0.35, 0.40]
const CLAVS := ["mixamorig_RightShoulder", "mixamorig_LeftShoulder"]
const ARMS := ["mixamorig_RightArm", "mixamorig_LeftArm"]

var bones: Array = BONES     # a turn lead uses the chest, neck and head instead
var share: Array = SHARE
var twist := 0.0             # radians, positive turns the chest toward the hero's left
var up: Node3D               # node whose +Y is the twist axis (the player's Body)
var square := 0.0            # 0..1 share of the shoulder line's turn away from square_ref cancelled
var square_ref := 0.0        # the shoulder line's heading (body space, rad) to hold
var square_max := 0.9        # cap on the counter-twist, rad
var clav_hold := 0.0         # 0..1 clavicles eased toward their rest rotation
var last_yaw := 0.0
var last_counter := 0.0

func _shoulder_yaw(skel: Skeleton3D) -> float:
	var r := skel.find_bone(ARMS[0])
	var l := skel.find_bone(ARMS[1])
	if r < 0 or l < 0 or up == null:
		return square_ref
	var d := skel.get_bone_global_pose(r).origin - skel.get_bone_global_pose(l).origin
	d = up.global_basis.orthonormalized().inverse() * (skel.global_basis * d)
	return atan2(d.z, -d.x)

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	var tw := twist
	last_counter = 0.0
	if square > 0.001 and skel.get_bone_count() > 0 and bones == BONES:
		if clav_hold > 0.001:
			for c in CLAVS:
				var cb := skel.find_bone(c)
				if cb >= 0:
					var rest := skel.get_bone_rest(cb).basis.get_rotation_quaternion()
					skel.set_bone_pose_rotation(cb, skel.get_bone_pose_rotation(cb).slerp(rest, clav_hold))
		last_yaw = _shoulder_yaw(skel)
		last_counter = clampf(-wrapf(last_yaw - square_ref, -PI, PI) * square, -square_max, square_max)
		tw += last_counter
	if absf(tw) < 1e-4:
		return
	var axis_world := up.global_basis.y if up != null else Vector3.UP
	var axis_skel := (skel.global_basis.orthonormalized().inverse() * axis_world).normalized()
	for i in bones.size():
		var b := skel.find_bone(bones[i])
		if b < 0:
			continue
		var parent := skel.get_bone_parent(b)
		var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var local_axis := (pb.inverse() * axis_skel).normalized()
		var q := Quaternion(local_axis, tw * float(share[i]))
		skel.set_bone_pose_rotation(b, q * skel.get_bone_pose_rotation(b))
