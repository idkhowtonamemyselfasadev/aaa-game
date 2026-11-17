class_name StanceWiden
extends SkeletonModifier3D
## A wider, heavier base for a giant (03:00 11-17). The shared Idle clip stands the boots on one
## line, the left a long pace ahead of the right and only 0.16 m per size apart sideways (0.35 x
## the shoulder width): a fencer's line, not the planted stance of something that weighs tons.
## This runs FIRST on the clip's own legs (before StrideWarp, the ground IK and the plants), so
## everything after it treats the wider pose as the clip: each ankle is moved straight out along
## the body's side axis at its own height, the leg re-solved to it (knee kept in its bend plane,
## the sole's turn kept), so nothing downstream skates. Full at a standstill, a share of it in the
## walk (a giant walks a little wide-tracked, not straddling), eased with the locomotion blend.

const LEGS := [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot"],
		["mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot"]]
var out := 0.12              # m per size each ankle moves out at a standstill (x2 on the gap)
var walk_share := 0.45       # share of it kept at the walk clip's pace and above
var walk_blend := 1.9        # the locomotion blend position of the walk clip (Player.ANIM_WALK_SPEED)
var foe: Node               # the owner (HollowSoldier): its locomotion blend and size_scale
var side: Node3D             # node whose +X is the side axis and +Z forward (the Body)
var applied := 0.0           # (bots) m per size the last tick moved each ankle out
var short := 0.0             # (bots) skeleton units a leg could not reach its widened spot

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	applied = 0.0
	short = 0.0
	if skel == null or out <= 0.0:
		return
	# keyed to the locomotion blend, which StrideWarp's stop/start settle steps and plants already
	# follow (keyed to the ground pace instead, the base eased out under boots planted at a stop or a
	# landing: 0.054 / 0.069 m per size skate, bots `foestop`, `knightplant`)
	var blend: float = foe._blend if foe != null else 0.0
	var size: float = foe.size_scale if foe != null else 1.0
	var k := lerpf(1.0, walk_share, smoothstep(0.0, walk_blend, absf(blend)))
	var amt := out * k
	var inv := skel.global_basis.orthonormalized().inverse()
	var wx := side.global_basis.x if side != null else Vector3.RIGHT
	wx = Vector3(wx.x, 0.0, wx.z).normalized()
	var lat := (inv * wx).normalized()
	# world metres -> skeleton units along it
	var per := (skel.global_basis.inverse() * wx).length()
	var fwd := (inv * (side.global_basis.z if side != null else Vector3.BACK)).normalized()
	var hb := skel.find_bone("mixamorig_Hips")
	if hb < 0:
		return
	var hips := skel.get_bone_global_pose(hb).origin
	for leg in LEGS:
		var ul := skel.find_bone(leg[0])
		var lg := skel.find_bone(leg[1])
		var ft := skel.find_bone(leg[2])
		if ul < 0 or lg < 0 or ft < 0:
			return
		var fp := skel.get_bone_global_pose(ft)
		# out = away from the body's centre line, on this leg's own side
		var sgn := signf((skel.get_bone_global_pose(ul).origin - hips).dot(lat))
		if sgn == 0.0:
			continue
		_leg_to(skel, ul, lg, ft, fp.origin + lat * sgn * amt * size * per, fp.basis, fwd)
	applied = amt

## Two-bone IK (LegTuck's): the ankle to `t` (skeleton space), the knee kept in its bend plane,
## the foot's skeleton-space orientation kept as `keep`.
func _leg_to(skel: Skeleton3D, ul: int, lg: int, ft: int, t: Vector3, keep: Basis, fwd: Vector3) -> void:
	var s := skel.get_bone_global_pose(ul).origin
	var k := skel.get_bone_global_pose(lg).origin
	var f := skel.get_bone_global_pose(ft).origin
	var a := s.distance_to(k)
	var b := k.distance_to(f)
	var d := t - s
	var dl := clampf(d.length(), absf(a - b) + 1e-3, (a + b) * 0.995)
	short = maxf(short, d.length() - dl)
	var dn := d.normalized()
	var pole := (k - s) - dn * (k - s).dot(dn)
	if pole.length() < 1e-3:
		pole = fwd - dn * fwd.dot(dn)
	pole = pole.normalized()
	var d1 := (a * a - b * b + dl * dl) / (2.0 * dl)
	var k_new := s + dn * d1 + pole * sqrt(maxf(a * a - d1 * d1, 0.0))
	_swing(skel, ul, k - s, k_new - s)
	k = skel.get_bone_global_pose(lg).origin
	f = skel.get_bone_global_pose(ft).origin
	_swing(skel, lg, f - k, s + dn * dl - k)
	var pb := skel.get_bone_global_pose(lg).basis.orthonormalized()
	skel.set_bone_pose_rotation(ft, (pb.inverse() * keep.orthonormalized()).get_rotation_quaternion())

func _swing(skel: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	var ax := from.cross(to)
	if ax.length() < 1e-6:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * ax.normalized()).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, from.angle_to(to)) * skel.get_bone_pose_rotation(b))
