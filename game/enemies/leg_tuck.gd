class_name LegTuck
extends SkeletonModifier3D
## Bends both legs on top of whatever the animation posed: the thighs swing forward about the
## body's side axis (hip flexion) and the shins fold back (knee flexion). Drives a crouch that
## really bends the knees, and the knees-up tuck of a body in the air.

const LEGS := [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg"], ["mixamorig_RightUpLeg", "mixamorig_RightLeg"]]

var hip := 0.0               # radians the thighs swing forward
var knee := 0.0              # radians the shins fold back from the thigh line
var lift_hip := 0.0          # one leg only (lift_leg): the stomp's knee raised high
var lift_knee := 0.0
var lift_leg := 1            # index into LEGS (1 = right)
var side: Node3D             # node whose +X is the bend axis and +Z is forward (the Body)
## WEIGHT SHIFT (the stomp's one-legged stand): 0..1. The hips slide sideways over the
## standing boot and the pelvis hikes on the lifted side (the hip it hangs from comes up),
## the spine leans back the other way over the standing leg; both boots stay where the clip
## and the ground IK put them (each leg re-solved to its ankle), so the shift never skates a
## foot. Runs before the arm IK (the knight moves this modifier up the chain) so the fists
## stay on the glaive.
var shift := 0.0
const SHIFT_K := 0.8         # share of the hips-to-standing-ankle lateral gap closed at shift 1
const HIKE := 0.14           # rad the pelvis rolls up on the lifted side at shift 1
const SPINE_BACK := 1.25     # x HIKE the lower spine rolls back (net trunk lean over the standing leg)
var shifted := 0.0           # (bots) skeleton units the hips moved sideways this tick
var dropped := 0.0           # (bots) skeleton units the hips came down so the standing leg reaches
var short := 0.0             # (bots) skeleton units a re-solved leg could not reach its boot this tick
## PLANTED BOOTS: 0..1. Each boot is put back where the clip (and the ground IK) stands it
## with the whole-model lean undone across the turf (`model` vs `model_up`), the legs
## re-solved to it, so a move that leans or sinks the model from the hips (the stomp's lean
## back and drive down) does not swing the feet across the turf with it. The lifted leg's
## knee-up bend goes on top, so the stamped boot comes down on its own spot. It lets go with
## no pop: as the lean runs out the correction is the identity. It is worked out here, from
## the model as it stands this tick (the owner's lean may run after the skeleton).
var pin := 0.0
var model: Node3D             # the leaned model (owner)
var model_up := Transform3D()  # the model's local transform with no lean or sink (owner)
var floor_fn: Callable         # world ground height under a point (owner)
var floor_of: Node3D           # the node whose origin is the floor the clip stands on (owner)
var _held_h: Array = [null, null]   # [standing, lifted]: each boot's height over the turf, held while planted

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	shifted = 0.0
	short = 0.0
	dropped = 0.0
	if pin < 1e-4:
		_held_h = [null, null]
	if skel == null or (absf(hip) < 1e-4 and absf(knee) < 1e-4 and absf(lift_hip) < 1e-4 and absf(lift_knee) < 1e-4 \
			and shift < 1e-4 and pin < 1e-4):
		return
	var axis_world := side.global_basis.x if side != null else Vector3.RIGHT
	var axis_skel := (skel.global_basis.orthonormalized().inverse() * axis_world).normalized()
	if shift >= 1e-4 or pin >= 1e-4:
		_shift_weight(skel, axis_skel)
	for i in LEGS.size():
		var leg: Array = LEGS[i]
		var lh := lift_hip if i == lift_leg else 0.0
		var lk := lift_knee if i == lift_leg else 0.0
		# rotating "down" about +X by +a swings it toward -Z, so forward is -a
		_bend(skel, leg[0], axis_skel, -(hip + lh))
		_bend(skel, leg[1], axis_skel, knee + lk)

func _bend(skel: Skeleton3D, bone: String, axis_skel: Vector3, angle: float) -> void:
	var b := skel.find_bone(bone)
	if b < 0 or absf(angle) < 1e-4:
		return
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))

## The hips over the standing boot (see `shift`): slide + hike, spine rolled back, then both
## legs re-solved so the ankles (and the soles' orientation) stay exactly where they were.
func _shift_weight(skel: Skeleton3D, axis_skel: Vector3) -> void:
	var hb := skel.find_bone("mixamorig_Hips")
	var sp := skel.find_bone("mixamorig_Spine")
	if hb < 0:
		return
	var inv := skel.global_basis.orthonormalized().inverse()
	var up := (inv * Vector3.UP).normalized()
	var fwd := (inv * (side.global_basis.z if side != null else Vector3.BACK)).normalized()
	var stand: Array = LEGS[1 - lift_leg]
	var lifted: Array = LEGS[lift_leg]
	var bones := []
	var feet := []
	for leg in [stand, lifted]:
		var ul := skel.find_bone(leg[0])
		var lg := skel.find_bone(leg[1])
		var ft := skel.find_bone(str(leg[0]).replace("UpLeg", "Foot"))
		if ul < 0 or lg < 0 or ft < 0:
			return
		bones.append([ul, lg, ft])
		feet.append(skel.get_bone_global_pose(ft))
	# the planted boots: the clip's spot with the model's lean and sink taken back out
	if pin >= 1e-4:
		var xf := skel.global_transform
		var unlean := Transform3D()
		if model != null and model.is_inside_tree():
			var par := model.get_parent() as Node3D
			var pg := par.global_transform if par != null else Transform3D()
			unlean = (pg * model_up) * model.global_transform.affine_inverse()
		var c := xf.affine_inverse() * unlean * xf
		for j in 2:
			var cur: Transform3D = feet[j]
			# the spot on the turf is held, at the upright clip's height over the ground under it
			# (the owner keeps its ground IK out of it meanwhile, or the boot is lifted twice);
			# the sole keeps the clip's turn
			var w := xf * (c * cur.origin)
			if floor_fn.is_valid() and floor_of != null:
				# the boot's height over the turf only ever comes down while planted: a stomp
				# begun mid-stride lets the stepping boot land, but the clip's own idle sway
				# (~1 cm per size, upward) does not lift a standing boot off the turf
				var h := w.y - floor_of.global_position.y
				_held_h[j] = h if _held_h[j] == null else minf(float(_held_h[j]), h)
				w.y = float(floor_fn.call(w)) + float(_held_h[j])
			feet[j] = Transform3D(cur.basis, cur.origin.lerp(xf.affine_inverse() * w, pin))
	var hips := skel.get_bone_global_pose(hb)
	# sideways only (along the body's side axis): the gap from the hips to the standing ankle
	var lat := axis_skel - up * axis_skel.dot(up)
	lat = lat.normalized()
	var gap := ((feet[0] as Transform3D).origin - hips.origin).dot(lat)
	var d := lat * gap * SHIFT_K * shift
	# the hike: the roll about the forward axis that lifts the hanging leg's hip joint
	var r := skel.get_bone_global_pose(bones[1][0]).origin - hips.origin
	var sgn := signf(fwd.cross(r).dot(up))
	if sgn == 0.0:
		sgn = 1.0
	var a := sgn * HIKE * shift
	var parent := skel.get_bone_parent(hb)
	var pg := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	skel.set_bone_pose_position(hb, skel.get_bone_pose_position(hb) + pg.affine_inverse().basis * d)
	_bend_axis(skel, hb, fwd, a)
	if sp >= 0:
		_bend_axis(skel, sp, fwd, -a * SPINE_BACK)
	shifted = d.length()
	# a standing leg that can no longer reach its boot (the hike and the rise onto it lift its
	# hip joint) lets the hips down by just enough, rather than the boot leaving the turf
	var sb: Array = bones[0]
	var hs := skel.get_bone_global_pose(sb[0]).origin
	var reach := (hs.distance_to(skel.get_bone_global_pose(sb[1]).origin) \
			+ skel.get_bone_global_pose(sb[1]).origin.distance_to(skel.get_bone_global_pose(sb[2]).origin)) * 0.99
	var v := (feet[0] as Transform3D).origin - hs
	if v.length() > reach:
		var h := -v.dot(up)
		var disc := h * h - v.length_squared() + reach * reach
		if disc >= 0.0:
			var dz := h - sqrt(disc)
			skel.set_bone_pose_position(hb, skel.get_bone_pose_position(hb) - pg.affine_inverse().basis * (up * dz))
			dropped = dz
	for i in 2:
		var b: Array = bones[i]
		_leg_to(skel, b[0], b[1], b[2], (feet[i] as Transform3D).origin, (feet[i] as Transform3D).basis, fwd)

func _bend_axis(skel: Skeleton3D, b: int, axis_skel: Vector3, angle: float) -> void:
	var parent := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local_axis := (pb.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(b, Quaternion(local_axis, angle) * skel.get_bone_pose_rotation(b))

func _swing(skel: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	var ax := from.cross(to)
	if ax.length() < 1e-6:
		return
	_bend_axis(skel, b, ax.normalized(), from.angle_to(to))

## Two-bone IK (as StrideWarp's): the ankle to `t` (skeleton space), the knee kept in its
## bend plane, the foot's skeleton-space orientation kept as `keep`.
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
