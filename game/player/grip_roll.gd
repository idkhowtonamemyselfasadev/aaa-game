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
## the feed-forward never bends a wrist past this (a real wrist flexes ~70-80 deg): on the few
## ticks of the authored string where a fist exactly on the shaft would need more, it moves only
## 2/3 or 1/3 of the way, or not at all (bots: env BEND_LIMIT, deg)
## bisection steps for the feed's share under bend_limit (env SHARE_STEPS; 0 = all or nothing)
var share_steps := int(OS.get_environment("SHARE_STEPS")) if OS.has_environment("SHARE_STEPS") else 6
var bend_limit := deg_to_rad(float(OS.get_environment("BEND_LIMIT")) if OS.has_environment("BEND_LIMIT") else 75.0)

var _sides := []             # per hand: {hand, fore, grip (hand-local across-palm axis), sign, hs, init}
var last_roll := [0.0, 0.0]  # (bots) rad rolled about the shaft this tick, right / left
## (11-06) feed-forward: the roll turns the closed fist about the wrist, and the fist fit in
## StaffCombat only moves the wrist target a tick later, so in a fast strike a fist rode up to
## 11 cm off the shaft for a tick. The fist's offset from the wrist (hand frame, measured after
## every modifier last tick: the curl is steady in a grip) is turned with this tick's hand, its
## gap to the shaft's axis found, and the arm re-solved (shoulder kept, elbow kept in its bend
## plane) so the wrist moves by that gap this same tick (as far as bend_limit allows); the late
## fit is then off. Env HERO_GRIPLAG: the before.
var feed_on := true
var _fist_local := [null, null]   # per hand: fist centre - wrist, in the hand's frame (skeleton space)
var last_feed := [0.0, 0.0]       # (bots) m the wrist was moved this tick, right / left

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
		_sides.append({"arm": skel.find_bone("mixamorig_%sArm" % side), "side": side, "hand": hb, "fore": fb, "grip": g, "sign": 1.0, "hs": Basis(), "init": false, "tilt": Quaternion.IDENTITY})

	if OS.has_environment("HERO_GRIPLAG"):
		feed_on = false
	skel.skeleton_updated.connect(_capture_fists)

## After every modifier: each closed fist's centre from its wrist, in the hand's frame.
func _capture_fists() -> void:
	var skel := get_skeleton()
	if skel == null or weight <= 0.001:
		for i in 2:
			_fist_local[i] = null
		return
	var inv := skel.global_transform.affine_inverse()
	for i in _sides.size():
		var s = _sides[i]
		if s == null:
			continue
		var hg := skel.get_bone_global_pose(s["hand"])
		var f := inv * HandRest.fist_center(skel, s["side"])
		_fist_local[i] = hg.basis.orthonormalized().inverse() * (f - hg.origin)

## The hand's turn for the forearm as it now is: the roll about the shaft that brings the hand's
## line closest to the forearm's (capped a tick once started), then the tilt toward the forearm
## past BEND_OK, eased from last tick's. Returns [hand rotation (weighted), tilt, roll, bend].
func _solve_hand(skel: Skeleton3D, s: Dictionary, H0: Basis, H_ik: Basis, a: Vector3, tprev: Quaternion) -> Array:
	var hb: int = s["hand"]
	var f := (skel.get_bone_global_pose(hb).origin - skel.get_bone_global_pose(s["fore"]).origin).normalized()
	var yp := H0.y - a * H0.y.dot(a)
	var fp := f - a * f.dot(a)
	var th := 0.0
	if yp.length() > 1e-4 and fp.length() > 1e-4:
		th = yp.normalized().signed_angle_to(fp.normalized(), a)
		if s["init"]:
			th = clampf(th, -roll_max, roll_max)
	var Hr := (Basis(a, th) * H0).orthonormalized()
	var bend := Hr.y.angle_to(f)
	var tq := Quaternion.IDENTITY
	var tax := Hr.y.cross(f)
	if bend > BEND_OK and tax.length() > 1e-5:
		tq = Quaternion(tax.normalized(), minf(bend - BEND_OK, TILT_MAX))
	# eased in and out over a few ticks (kept in the staff's frame, so it rides the swing)
	tq = tprev.slerp(tq, TILT_EASE) if s.has("tilt_on") else tq
	var H := (Basis(tq) * Hr).orthonormalized()
	var Hq := H_ik.get_rotation_quaternion().slerp(H.get_rotation_quaternion(), weight)
	return [Hq, tq, th, Basis(Hq).y.angle_to(f)]

## Moves the wrist (hand bone origin) by `move` (skeleton space): the upper arm and forearm are
## turned so the elbow stays in its current bend plane and both bones keep their lengths.
func _shift_wrist(skel: Skeleton3D, s: Dictionary, move: Vector3) -> void:
	var ab: int = s["arm"]
	var fb: int = s["fore"]
	var hb: int = s["hand"]
	if ab < 0:
		return
	var A := skel.get_bone_global_pose(ab).origin
	var B := skel.get_bone_global_pose(fb).origin
	var C := skel.get_bone_global_pose(hb).origin
	var l1 := A.distance_to(B)
	var l2 := B.distance_to(C)
	var T := C + move
	var at := T - A
	var d := clampf(at.length(), absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
	if at.length() < 1e-6:
		return
	var dir := at.normalized()
	T = A + dir * d
	# the bend direction: the elbow's offset from the shoulder-wrist line now
	var ac := (C - A).normalized()
	var pole := (B - A) - ac * (B - A).dot(ac)
	pole = pole - dir * pole.dot(dir)
	if pole.length() < 1e-6:
		return
	pole = pole.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var B2 := A + dir * (l1 * ca) + pole * (l1 * sqrt(1.0 - ca * ca))
	_aim_bone(skel, ab, B - A, B2 - A)
	var B3 := skel.get_bone_global_pose(fb).origin
	var C3 := skel.get_bone_global_pose(hb).origin
	_aim_bone(skel, fb, C3 - B3, T - B3)

## Turns a bone (globally, shortest arc) so its child offset `from` points along `to`.
func _aim_bone(skel: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	var ax := from.cross(to)
	if ax.length() < 1e-9:
		return
	var R := Basis(ax.normalized(), from.angle_to(to))
	var g := skel.get_bone_global_pose(b).basis
	var par := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(par).basis if par >= 0 else Basis()
	var ng := (R * g.orthonormalized()).orthonormalized()
	skel.set_bone_pose_rotation(b, (pb.orthonormalized().inverse() * ng).get_rotation_quaternion())

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
		# the roll and tilt for the IK'd forearm, then (feed-forward) the arm re-solved so the fist,
		# turned as that hand, sits on the shaft. The hand is NOT re-solved on the moved forearm
		# (the roll would chase the forearm and the fist leave the shaft again); the shift is only
		# checked against the wrist it leaves.
		var tprev: Quaternion = S.get_rotation_quaternion() * (s["tilt"] as Quaternion) * S.get_rotation_quaternion().inverse()
		var sol := _solve_hand(skel, s, H0, H_ik, a, tprev)
		last_feed[i] = 0.0
		if feed_on and _fist_local[i] != null:
			# the largest share of the shift (1, 2/3, 1/3) whose wrist stays within BEND_LIMIT;
			# else none: the fist rides off the shaft that tick rather than a wrist bent back
			var ab: int = s["arm"]
			var keep := [skel.get_bone_pose_rotation(ab), skel.get_bone_pose_rotation(fb)]
			var inv := skel.global_transform.affine_inverse()
			var o := inv * staff.global_position
			var ax_s := (inv.basis * staff.global_basis.y).normalized()
			var Hy := Basis(sol[0] as Quaternion).y
			var P: Vector3 = skel.get_bone_global_pose(hb).origin + Basis(sol[0] as Quaternion) * (_fist_local[i] as Vector3)
			var e := P - (o + ax_s * ax_s.dot(P - o))
			# (15:00 11-06) the share is found by bisection (was the steps 1, 2/3, 1/3, none: a
			# fist jumped 4.5 -> 9 cm off the shaft between ticks where the next step down failed)
			var lim := maxf(bend_limit, float(sol[3]))
			var lo := 0.0
			var hi := 1.0
			var lo_bend := float(sol[3])
			var k := 1.0
			for it in maxi(share_steps, 0) + 1:
				_shift_wrist(skel, s, -e * weight * k)
				var f2 := (skel.get_bone_global_pose(hb).origin - skel.get_bone_global_pose(fb).origin).normalized()
				var bend2 := Hy.angle_to(f2)
				if OS.has_environment("GRIP_DBG"):
					print("  k %.2f bend %.0f" % [k, rad_to_deg(bend2)])
				skel.set_bone_pose_rotation(ab, keep[0])
				skel.set_bone_pose_rotation(fb, keep[1])
				if bend2 <= lim:
					lo = k
					lo_bend = bend2
					if it == 0:
						break
				else:
					hi = k
				k = (lo + hi) * 0.5
			if lo > 0.0:
				_shift_wrist(skel, s, -e * weight * lo)
				sol[3] = lo_bend
				last_feed[i] = (skel.global_transform.basis * e).length() * weight * lo
		var Hq: Quaternion = sol[0]
		var tq: Quaternion = sol[1]
		var th: float = sol[2]
		if OS.has_environment("GRIP_DBG"):
			print("GRIP %d roll %.2f bend %.0f feed %.3f w %.2f" % [i, th, rad_to_deg(sol[3]), last_feed[i], weight])
		s["tilt"] = S.get_rotation_quaternion().inverse() * tq * S.get_rotation_quaternion()
		s["tilt_on"] = true
		last_roll[i] = th
		s["hs"] = (S.inverse() * (Basis(a, th) * H0).orthonormalized()).orthonormalized()
		s["init"] = true
		# half the hand's twist about the forearm goes to the forearm (turned about its own length)
		var Fb := skel.get_bone_global_pose(fb).basis.orthonormalized()   # re-read: the feed may have turned it
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
