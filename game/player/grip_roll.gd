class_name GripRoll
extends SkeletonModifier3D
## (11-06) The hero's hands on the drawn staff, after the arm IK. The IK lands each wrist on its
## grip point but leaves the hand turned as the clip has it, and in a fast light strike the clip's
## hand rides a rolling forearm: the right hand turned 110 then 177 deg in two ticks and the fist
## left the shaft. Here each hand is held in the STAFF's frame from tick to tick (it turns with
## the shaft) and may only ROLL ABOUT THE SHAFT'S AXIS, by as much as keeps its line closest to
## the forearm's (the shaft turning in loose fists, never a wrist bent back), capped per tick.
## Half the hand's twist about the forearm is then handed to the forearm bone (it turns about
## its own length, so the IK'd wrist stays put), the way a real forearm carries the roll.

var staff: Node3D            # the drawn staff (its basis.y is the shaft)
var weight := 0.0            # 0..1, eased by StaffCombat (on only with the staff in both hands)
var roll_max := 0.6        # rad a tick the hand may roll about the shaft (~34 deg; bots: env ROLL_MAX)
## when the forearm runs nearly along the shaft no roll squares the hand to it: the fist then
## holds the shaft obliquely (a real grip does: the haft lies slanted across the palm), the hand
## turned toward the forearm's line by up to TILT_MAX once the bend passes BEND_OK
const BEND_OK := deg_to_rad(45.0)
const TILT_MAX := deg_to_rad(40.0)
const TILT_EASE := 0.4
const FOREARM_SHARE := 0.5   # of the hand's twist about the forearm carried by the forearm

var _sides := []             # per hand: {hand, fore, grip (hand-local across-palm axis), sign, hs, init}
var last_roll := [0.0, 0.0]  # (bots) rad rolled about the shaft this tick, right / left

func _ready() -> void:
	if OS.has_environment("ROLL_MAX"):
		roll_max = float(OS.get_environment("ROLL_MAX"))
	var skel := get_skeleton()
	if skel == null:
		return
	for side in ["Right", "Left"]:
		var hb := skel.find_bone("mixamorig_%sHand" % side)
		var fb := skel.find_bone("mixamorig_%sForeArm" % side)
		var ib := skel.find_bone("mixamorig_%sHandIndex1" % side)
		var pb := skel.find_bone("mixamorig_%sHandPinky1" % side)
		if hb < 0 or fb < 0 or ib < 0 or pb < 0:
			_sides.append(null)
			continue
		# the line a haft runs through a closed fist: across the palm, pinky to index knuckle
		var g := (skel.get_bone_rest(ib).origin - skel.get_bone_rest(pb).origin).normalized()
		_sides.append({"hand": hb, "fore": fb, "grip": g, "sign": 1.0, "hs": Basis(), "init": false, "tilt": Quaternion.IDENTITY})

func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or staff == null or not is_instance_valid(staff):
		return
	if weight <= 0.001:
		for s in _sides:
			if s != null:
				s["init"] = false
				s.erase("tilt_on")
				s["tilt"] = Quaternion.IDENTITY
		return
	var sb := skel.global_basis.orthonormalized()
	var S := (sb.inverse() * staff.global_basis.orthonormalized()).orthonormalized()
	var a := S.y.normalized()
	for i in _sides.size():
		var s = _sides[i]
		if s == null:
			continue
		var hb: int = s["hand"]
		var fb: int = s["fore"]
		var hg := skel.get_bone_global_pose(hb)
		var fg := skel.get_bone_global_pose(fb)
		var H_ik := hg.basis.orthonormalized()
		var g: Vector3 = s["grip"]
		var H0: Basis
		if not s["init"]:
			s["sign"] = 1.0 if (H_ik * g).dot(a) >= 0.0 else -1.0
			H0 = H_ik
		else:
			H0 = (S * (s["hs"] as Basis)).orthonormalized()
		# the across-palm line laid along the shaft (shortest turn: a correction of drift on later ticks)
		var want: Vector3 = a * float(s["sign"])
		var cur := (H0 * g).normalized()
		var ax := cur.cross(want)
		if ax.length() > 1e-6:
			H0 = Basis(ax.normalized(), cur.angle_to(want)) * H0
		# roll about the shaft so the hand's line comes closest to the forearm's
		var f := (hg.origin - fg.origin).normalized()
		var yp := H0.y - a * H0.y.dot(a)
		var fp := f - a * f.dot(a)
		var th := 0.0
		if yp.length() > 1e-4 and fp.length() > 1e-4:
			th = yp.normalized().signed_angle_to(fp.normalized(), a)
			if s["init"]:
				th = clampf(th, -roll_max, roll_max)
		last_roll[i] = th
		if OS.has_environment("GRIP_DBG"):
			var Hd := Basis(a, th) * H0
			print("GRIP %d roll %.2f fa %.0f bend %.0f w %.2f" % [i, th, rad_to_deg(f.angle_to(a)), rad_to_deg(f.angle_to(Hd.y)), weight])
		var H := (Basis(a, th) * H0).orthonormalized()
		s["hs"] = (S.inverse() * H).orthonormalized()
		s["init"] = true
		var bend := H.y.angle_to(f)
		var tq := Quaternion.IDENTITY
		var tax := H.y.cross(f)
		if bend > BEND_OK and tax.length() > 1e-5:
			tq = Quaternion(tax.normalized(), minf(bend - BEND_OK, TILT_MAX))
		# eased in and out over a few ticks (kept in the staff's frame, so it rides the swing)
		var tprev: Quaternion = S.get_rotation_quaternion() * (s["tilt"] as Quaternion) * S.get_rotation_quaternion().inverse()
		tq = tprev.slerp(tq, TILT_EASE) if s.has("tilt_on") else tq
		s["tilt"] = S.get_rotation_quaternion().inverse() * tq * S.get_rotation_quaternion()
		s["tilt_on"] = true
		H = (Basis(tq) * H).orthonormalized()
		var Hq := H_ik.get_rotation_quaternion().slerp(H.get_rotation_quaternion(), weight)
		# half the hand's twist about the forearm goes to the forearm (turned about its own length)
		var Fb := fg.basis.orthonormalized()
		var L := (Fb.inverse() * Basis(Hq)).get_rotation_quaternion()
		var tw := Quaternion(0.0, L.y, 0.0, L.w)
		if tw.length() > 1e-6:
			tw = tw.normalized()
			var ang := 2.0 * atan2(tw.y, tw.w)
			var ft := ang * FOREARM_SHARE
			var fpar := skel.get_bone_parent(fb)
			var pbas := skel.get_bone_global_pose(fpar).basis.orthonormalized() if fpar >= 0 else Basis()
			var fl := (pbas.inverse() * Fb.y).normalized()
			skel.set_bone_pose_rotation(fb, Quaternion(fl, ft) * skel.get_bone_pose_rotation(fb))
		var Fn := skel.get_bone_global_pose(fb).basis.orthonormalized()
		skel.set_bone_pose_rotation(hb, (Fn.inverse() * Basis(Hq)).get_rotation_quaternion())
