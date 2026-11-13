class_name HollowRags
extends Node
## The Hollow Soldier's rags: a deep hood, a shoulder mantle, a knotted sash and a front and
## back tabard of grey, ash-stiff hemp over the old armour. Every piece is built in body space
## (metres, +Z forward, feet at 0) and hung on a skeleton bone, so it rides the animation.
## The tabards swing out of the way of the thighs; the hems trail the body's motion.
## Hemp bandages bind the thighs, shins, feet and forearms over the old armour.

const BONE_HEAD := "mixamorig_Head"
const BONE_CHEST := "mixamorig_Spine2"
const BONE_HIPS := "mixamorig_Hips"

var mats: Array[ShaderMaterial] = []
var _skel: Skeleton3D
## How far (m) the wraps sit in from the base body's widest point: a wearer whose plates sink
## in (hero.gdshader plate_inset) gets wraps that hug the slimmer limb, not the old armour
var wrap_inset := 0.0
var _body: Node3D
var _hips_rest := Transform3D()
var _front: Node3D
var _back: Node3D
var _legs: Array[PackedInt32Array] = []
var _hips := -1
var _swing_f := 0.0
var _swing_b := 0.0
var wraps := 0          # bandage wraps on thighs, shins, feet and forearms, for the bots
var peak_swing := 0.0   # largest tabard swing so far (rad), for the bots
var _last_pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _trail := Vector3.ZERO
var layer := 2           # render layer of the pieces (the soldier's ember light skips layer 2)
var tint: Array = []
var swing_slack := 0.0   # leg angle (rad) the panels clear before the thigh pushes them
## 0..1: how far the panels hang to gravity instead of riding the pelvis's tilt (a wearer who
## bends at the waist). With it, on a deep stoop the front panel lies along the thighs and
## folds down over the knees, and the back panel folds where it meets the ground.
var hang := 0.0
var fold_front := Vector2(1000.0, 0.0)   # (distance down the panel, angle) of its knee fold
var fold_back := Vector2(1000.0, 0.0)
var fold_front2 := Vector2(1000.0, 0.0)  # where the front panel meets the ground and pools
var tip := 0.0                           # the pelvis's forward tilt (rad), for the bots
## A climber on a face: the legs are read as posed after the skeleton's modifiers (the climb
## pose bends them past the clip), a knee drawn up drags the hems toward its side, and the
## front panel swings out only as far as the face lets it (`wall_n`/`wall_p`: the face's
## outward normal and a point on it, world; zero = no face).
var posed_legs := false
var stream := 0.0                        # 0..1 airflow past the body (gliding): the hems stream back and lift
var flap := 0.0                          # 0..1 how hard the cloth works in that airflow
## 0..1 how hard the wearer is coming down through the air (stream x fall speed): the air
## pushes up under the cloth, both panels flare out and the hems lift (a leap's descent)
var fall := 0.0
## Vertical speed (m/s) the wearer's model moves at on top of the body node (a leap's arc the
## model rides while the body stays on the ground), added to the body's own
var air_y := 0.0
var rise := 0.0                          # 0..1 the same going up: the hems are dragged down a little
var peak_lift := 0.0                     # highest hem lift so far (m, sway y), for the bots
var peak_back := 0.0                     # widest back-panel swing in the air (rad), for the bots
var wall_n := Vector3.ZERO
var wall_p := Vector3.ZERO
var lateral := 0.0                       # the knee drag (m, body +X = the wearer's left), for the bots
## (11-08) In the air with the legs posed (a leap's tuck, the jump attack's fold) the front panel
## lies along the higher thigh and folds down over its knee instead of standing out as a flat
## board at the 0.7 rad cap, and the back panel swings back clear of the heels. `knee_fold`
## turns it on (the hero); `tuck_lie` is how far it lies (0..1), `tuck_gap` the panel line's
## worst clearance over the knee's top this tuck (m, < 0 = the knee through the cloth), and
## `tuck_heel` the back hem's worst clearance behind the heels (m), for the bots.
var knee_fold := false
var tuck_lie := 0.0
var tuck_gap := 9.0
var tuck_heel := 9.0
var tuck_lie_peak := 0.0
var tuck_aim := 0.0
var tuck_k := 0.0
## (11-08 g2) The knee fold rolls round an arc this long (m, local panel units) instead of a
## 7 cm crease: eased toward TUCK_ROUND in the tuck and back to 0 (the old crease) once the
## panels hang again. `tuck_shin` is the bent cloth's worst gap off the higher shin (m), for
## the bots. `KNEEROUND_OFF=1` keeps the hard crease.
const TUCK_ROUND := 0.15
const KNEEROUND_OFF_ENV := "KNEEROUND_OFF"
var fold_round := 0.0
var tuck_shin := 9.0
const TUCK_LIE0 := 0.62                  # thigh angle off the pelvis (rad) the panel starts to lie on it
const TUCK_LIE1 := 0.95                  # ... and lies along it fully
const TUCK_PAD := 0.075                  # m, the cloth over the thigh's top (thigh radius + wool)
const TUCK_SWING_MAX := 1.75             # rad, the most the front panel lies out along a thigh
## Cut of the rags, set before build(): the harrier runs light in a fitted coif, no mantle,
## and a short kilt-length tabard; everyone else wears the deep cowl and long panels.
var cowl := true
## (11-13 22:00) the cowl's side profile: how far (m) the front of the dome rolls down over the
## brow, and how much (of r) the back of the crown rounds in; HOODSIDE_OLD=1 = both 0 (before)
static var HOOD_BROW_ROLL := 0.0 if OS.get_environment("HOODSIDE_OLD") == "1" else float(OS.get_environment("HOOD_ROLL") if OS.get_environment("HOOD_ROLL") != "" else "0.05")
static var HOOD_BACK_ROUND := 0.0 if OS.get_environment("HOODSIDE_OLD") == "1" else float(OS.get_environment("HOOD_BACKR") if OS.get_environment("HOOD_BACKR") != "" else "0.12")
## (11-13 22:00) the cowl's hemp: 0..1 how far its folds break into sharp ridges, and the depth
## (of r) of its few deep irregular folds; HOODFOLD_OLD=1 = both 0 (before)
static var HOOD_STIFF := 0.0 if OS.get_environment("HOODFOLD_OLD") == "1" else 0.5
static var HOOD_DEEP := 0.0 if OS.get_environment("HOODFOLD_OLD") == "1" else float(OS.get_environment("HOOD_DEEP") if OS.get_environment("HOOD_DEEP") != "" else "0.15")
## (11-13 23:00) the side panel read flat and evenly lit: the fold hollows are now darkened by a
## baked cavity term (COLOR.r -> rag.gdshader fold_ao) and two or three stiff horizontal creases
## sag across each side, where a hood pushed back off the head has crumpled. HOODAO_OLD=1 = before.
static var HOOD_AO := 0.0 if OS.get_environment("HOODAO_OLD") == "1" else float(OS.get_environment("HOOD_AO") if OS.get_environment("HOOD_AO") != "" else "0.9")
static var HOOD_CAV := float(OS.get_environment("HOOD_CAV") if OS.get_environment("HOOD_CAV") != "" else "0.003")
static var HOOD_CREASE := 0.0 if OS.get_environment("HOODAO_OLD") == "1" else float(OS.get_environment("HOOD_CREASE") if OS.get_environment("HOOD_CREASE") != "" else "0.05")
const COIF_TURNS := 5.0                  # turns of strip wound round the harrier's coif
const COIF_KNOT := 0.05                  # how proud the tie-off knot stands off the coif (m)
const COIF_KNOT_V := 0.3                 # its height on the coif (0 crown .. 1 throat)
const TAIL_LEN := 0.44                   # the coif's knotted tails, nape to tip (m)
var mantle := true
var hem := 1.0                           # tabard length scale
var front_clear := INF                   # the front hem's gap to the face (m), for the bots     # [cloth_dark, cloth_light, soot] for the next pieces; empty = grey hemp

func build(skel: Skeleton3D, body: Node3D) -> void:
	_skel = skel
	_body = body
	var head := _attach(BONE_HEAD)
	var chest := _attach(BONE_CHEST)
	var hips := _attach(BONE_HIPS)
	_hips = skel.find_bone(BONE_HIPS)
	_hips_rest = _rest_in_body(_hips)
	for side in ["Left", "Right"]:
		_legs.append(PackedInt32Array([skel.find_bone("mixamorig_%sUpLeg" % side),
				skel.find_bone("mixamorig_%sLeg" % side), skel.find_bone("mixamorig_%sFoot" % side)]))
	if cowl:
		# the cowl drapes in gathered folds that deepen from the crown to the shoulders, and
		# its brim (the edges round the face) is torn and frayed like the mantle's front
		var h_seed := 0.0 + mats.size() * 3.7     # the seed _piece gives its material
		var h_n := hood_folds(h_seed)
		var hp := _piece(_cowl(h_seed, h_n), 0.0, 0.10, 0.0, 1.2)
		var hm := hp.material_override as ShaderMaterial
		hm.set_shader_parameter("pleats", h_n)
		hm.set_shader_parameter("side_tear", 0.035)
		hm.set_shader_parameter("crown_fade", 0.32)
		hm.set_shader_parameter("fold_ao", HOOD_AO)
		head.add_child(hp)
	else:
		# a fitted hemp coif bound round the old helm, the visor left bare, two knotted
		# tails hanging down the nape
		var coif := _piece(_coif(), 0.0, 0.06, 0.0, 1.0)
		# wound on in strips round the helm like the bandages: overlapping turns, each lip a
		# little proud of the last (the shader's wrap bands), wound unevenly by hand
		var cm := coif.material_override as ShaderMaterial
		cm.set_shader_parameter("wrap_turns", COIF_TURNS)
		cm.set_shader_parameter("wrap_jitter", 1.0)
		cm.set_shader_parameter("seed", 0.0)          # the mesh's laps use the same warp (_wrap_s)
		cm.set_shader_parameter("tongues", 10.0)
		head.add_child(coif)
		for side in [-1.0, 1.0]:
			head.add_child(_piece(_tail(side), 0.0, 0.25, 3.0 + side, 0.15))
		# the strip's last turn left loose: its end tucked under at the temple and hanging
		# free past the left cheek-guard
		head.add_child(_piece(_loose_end(), 0.0, 0.3, 7.0, 0.3))
		# (18:00 11-03) the neck bound in the same hemp: the crouch pitches the head far
		# forward and bared the ash neck between coif and collar, where the tell burned like
		# a bald skull from behind
		_wrap("mixamorig_Neck", "mixamorig_Head", -0.1, 1.05, 0.01, 4.0)
	if mantle:
		var m_seed := 0.35 + mats.size() * 3.7     # the seed _piece gives its material
		var m_n := mantle_folds(m_seed)
		var mp := _piece(_mantle(m_seed, m_n), 0.35, 0.22, 0.35, 1.0)
		var mm := mp.material_override as ShaderMaterial
		mm.set_shader_parameter("pleats", m_n)
		mm.set_shader_parameter("side_tear", 0.03)
		chest.add_child(mp)
	hips.add_child(_piece(_sash(), 0.0, 0.0, 0.0, 0.25))
	_front = _panel(hips, Vector3(0, 1.20, 0.215), 0.30, lerpf(0.30, 0.40, hem), 0.68 * hem, 0.9, 1.0)
	_back = _panel(hips, Vector3(0, 1.21, -0.205), 0.32, lerpf(0.32, 0.42, hem), 0.76 * hem, -0.9, 2.0)
	# bandage wraps bound over the old greaves and vambraces, fitted to the armour underneath
	for side in ["Left", "Right"]:
		_wrap("mixamorig_%sLeg" % side, "mixamorig_%sFoot" % side, 0.14, 0.93, 0.01, 8.0)
		_wrap("mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side, 0.22, 0.97, 0.008, 6.0)
		# thigh bindings hide the Vanguard's plated thighs; foot wraps bind the boots like
		# old field puttees, ankle to the ball of the foot
		_wrap("mixamorig_%sUpLeg" % side, "mixamorig_%sLeg" % side, 0.16, 0.90, 0.012, 9.0)
		_wrap("mixamorig_%sFoot" % side, "mixamorig_%sToeBase" % side, 0.0, 0.92, 0.008, 4.0)
	_last_pos = body.global_position

func _attach(bone: String) -> Node3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	_skel.add_child(att)
	# the offset makes the children's local space the body space at rest
	var off := Node3D.new()
	off.transform = _rest_in_body(_skel.find_bone(bone)).affine_inverse()
	att.add_child(off)
	return off

func _rest_in_body(bone: int) -> Transform3D:
	return _body.global_transform.affine_inverse() * _skel.global_transform \
			* _skel.get_bone_global_rest(bone)

func _piece(mesh: ArrayMesh, holes: float, tear: float, sd: float, aspect: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/rag.gdshader")
	mat.set_shader_parameter("holes", holes)
	mat.set_shader_parameter("tear", tear)
	mat.set_shader_parameter("seed", sd + mats.size() * 3.7)
	mat.set_shader_parameter("aspect", aspect)
	mat.set_shader_parameter("tongues", 6.0 + 10.0 * tear / 0.2)
	mat.set_shader_parameter("time_offset", randf() * 10.0)
	if not tint.is_empty():
		mat.set_shader_parameter("cloth_dark", tint[0])
		mat.set_shader_parameter("cloth_light", tint[1])
		mat.set_shader_parameter("soot_amt", tint[2])
		mat.set_shader_parameter("ember", 0.0)
	mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = layer
	return mi

## A tabard panel hung from a pivot at its top edge; the pivot swings about body X.
func _panel(parent: Node3D, top: Vector3, w0: float, w1: float, length: float, bow: float,
		sd: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = top
	parent.add_child(pivot)
	var dir := signf(bow)
	# the material's seed (_piece adds mats.size() * 3.7): the shader's fold shading and the
	# side tears run off the same phase as the pleats baked here
	var mseed := sd + mats.size() * 3.7
	var n_pl := pleat_count(mseed)
	var mesh := _grid(func(u: float, v: float) -> Vector3:
		# a hand-cut, uneven hem: one side hangs longer, the edge dips and rises (never past
		# `length`, so the knee/ground clearances computed from it still hold)
		var cut := 1.0 - 0.07 * (0.5 + 0.5 * sin(u * PI * 1.3 + mseed)) \
				- 0.03 * (0.5 + 0.5 * sin(u * 9.0 + mseed * 2.0))
		var vv := v * cut
		var x := (u - 0.5) * lerpf(w0, w1, vv)
		# ragged side edges: the outer columns bite in and bulge out, more toward the hem
		var e := pow(absf(u - 0.5) * 2.0, 6.0) * vv
		x *= 1.0 + e * (0.07 * sin(v * 17.0 + mseed) + 0.04 * sin(v * 41.0 + mseed * 3.0))
		var s := x / 0.2
		# wraps round the hips at the top, hangs flatter lower down
		var z := -dir * (0.06 * (1.0 - vv * 0.6)) * s * s
		z += dir * 0.025 * vv
		# real pleats: gathered at the sash, opening and deepening toward the hem, crowns
		# broad and rounded, valleys narrower (matches rag.gdshader's pleat profile)
		var ph := pleat_phase(u, v, n_pl, mseed)
		var fh := sin(ph * TAU) + 0.35 * sin(ph * TAU * 2.0 + 1.3)
		# each pleat hangs a different depth (slow swell across the panel), and the folds fan
		# out and soften lower down, so it never reads as corrugated
		var amp := 0.55 + 0.45 * sin(ph * TAU * 0.37 + mseed * 2.3) * sin(ph * 1.1 + mseed)
		z += dir * lerpf(0.003, 0.015, smoothstep(0.0, 0.8, vv)) * fh * amp
		return Vector3(x * dir, -vv * length, z), 40, 22)
	var piece := _piece(mesh, 0.25, 0.18, sd, length / w1)
	var pm := piece.material_override as ShaderMaterial
	pm.set_shader_parameter("pleats", n_pl)
	pm.set_shader_parameter("side_tear", 0.035)
	pivot.add_child(piece)
	pivot.set_meta("len", length)
	pivot.set_meta("w1", w1)
	pivot.set_meta("pleats", n_pl)
	return pivot

## How many pleats a tabard panel hangs in (4..5.5 across), from its material seed; the shader
## uses the same count (uniform `pleats`).
static func pleat_count(mseed: float) -> float:
	return 4.0 + 1.5 * fposmod(sin(mseed * 12.9898) * 43758.5453, 1.0)

## The pleats' phase across a panel: wandering a little down the hang so they are not ruled
## lines. Must match rag.gdshader's `pleat_phase()`.
static func pleat_phase(u: float, v: float, n: float, mseed: float) -> float:
	return u * n + 0.22 * sin(v * 2.3 + mseed * 1.7) + 0.12 * sin(u * 7.0 + v * 1.1 + mseed)

## Binds the base body's shins in tight: every skinned vertex carried by `bone` (the shin) between
## t 0..1.1 of bone -> `tip` is pulled toward the bone axis by `k` (1 = untouched), faded in below
## the knee and by its skin weight on the shin, so the knee and the foot keep their shape. Run it
## before `_wrap()`, which then fits a slimmer binding over the slimmer leg (a real puttee is
## wound tight and gathers the trouser in; fitted over the old greave and baggy trouser hem the
## hero's read as a 22 cm-deep tube side-on). Each mesh gets its own copy; returns verts moved.
const _KEEP_FLAGS := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS \
		| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) \
		| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) \
		| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
func _slim_leg(bone: String, tip: String, k: float) -> int:
	var a := _rest_in_body(_skel.find_bone(bone)).origin
	var axis := _rest_in_body(_skel.find_bone(tip)).origin - a
	var d := axis.normalized()
	return _reshape(bone, func(pb: Vector3, w: float) -> Vector3:
		var p := pb - a
		var along := p.dot(d)
		var t := along / axis.length()
		var band := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(1.0, 1.12, t))
		var f := lerpf(1.0, k, band * smoothstep(0.0, 0.6, w))
		if f >= 0.999:
			return pb
		return a + d * along + (p - d * along) * f)

## The ankle's share of the slim: the base body's greave ends in a lip skinned to the foot that
## stood 8-10 cm in front of the ankle 0-4 cm above the joint, where the slimmed shin is 5-6 cm,
## so a grey plate rim peeked out between the shin binding's end and the boot (ankle lens, 09:15
## 11-12). Every vert carried by `foot` above the ankle joint is pulled toward the shin's axis
## (run on below the ankle) horizontally by `k`, faded in over 1..3.5 cm above the joint and by
## its foot weight, so the instep and the sole keep their shape. Returns verts moved.
func _slim_ankle(leg: String, foot: String, k: float) -> int:
	var knee := _rest_in_body(_skel.find_bone(leg)).origin
	var ank := _rest_in_body(_skel.find_bone(foot)).origin
	var d := (ank - knee).normalized()
	return _reshape(foot, func(pb: Vector3, w: float) -> Vector3:
		var h := pb.y - ank.y
		var f := lerpf(1.0, k, smoothstep(0.01, 0.035, h) * smoothstep(0.2, 0.6, w))
		if f >= 0.999:
			return pb
		# the point on the shin axis at this height
		var c := ank + d * ((pb.y - ank.y) / d.y)
		var q := pb - c
		q.y = 0.0
		return pb - q * (1.0 - f))

## Moves the base body's verts carried by `bone`: `fn(body_pos, weight) -> body_pos` per vert with
## any weight on that bone. Each mesh gets its own copy (custom-format + 8-weight flags kept).
func _reshape(bone: String, fn: Callable) -> int:
	var bi := _skel.find_bone(bone)
	var moved := 0
	for mi in _body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null or not (m.mesh is ArrayMesh):
			continue
		var bind := -1
		for j in m.skin.get_bind_count():
			var bb := m.skin.get_bind_bone(j)
			if bb < 0:
				bb = _skel.find_bone(m.skin.get_bind_name(j))
			if bb == bi:
				bind = j
		if bind < 0:
			continue
		var to_body := _rest_in_body(bi) * m.skin.get_bind_pose(bind)
		var from_body := to_body.affine_inverse()
		var src := m.mesh as ArrayMesh
		var dst := ArrayMesh.new()
		dst.blend_shape_mode = src.blend_shape_mode
		for bsi in src.get_blend_shape_count():
			dst.add_blend_shape(src.get_blend_shape_name(bsi))
		var hit := 0
		for s in src.get_surface_count():
			var arr := src.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if not verts.is_empty() and not bones.is_empty():
				var per := bones.size() / verts.size()
				for v in verts.size():
					var w := 0.0
					for j in per:
						if bones[v * per + j] == bind:
							w += wts[v * per + j]
					if w <= 0.0:
						continue
					var pb := to_body * verts[v]
					var nb: Vector3 = fn.call(pb, w)
					if nb.is_equal_approx(pb):
						continue
					verts[v] = from_body * nb
					hit += 1
				arr[Mesh.ARRAY_VERTEX] = verts
			dst.add_surface_from_arrays(src.surface_get_primitive_type(s), arr,
					src.surface_get_blend_shape_arrays(s), {},
					src.surface_get_format(s) & _KEEP_FLAGS)
			dst.surface_set_material(s, src.surface_get_material(s))
			dst.surface_set_name(s, src.surface_get_name(s))
		if hit > 0:
			m.mesh = dst
			moved += hit
	return moved

## A bandage tube wound round the bone from `bone` towards `tip` (t0..t1 of that segment), its
## radius fitted per height and angle to the skinned armour underneath so nothing pokes through.
func _wrap(bone: String, tip: String, t0: float, t1: float, pad: float, turns: float) -> void:
	var bi := _skel.find_bone(bone)
	var a := _rest_in_body(bi).origin
	var b := _rest_in_body(_skel.find_bone(tip)).origin
	var axis := b - a
	var d := axis.normalized()
	var e1 := (Vector3(0, 0, 1) - d * d.z).normalized()  # body forward off the axis
	var e2 := d.cross(e1)
	const NA := 16
	const NH := 10
	var rad := PackedFloat32Array()
	rad.resize(NA * NH)
	rad.fill(0.0)
	for mi in _body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null or m.mesh == null:
			continue
		var bind := -1
		for k in m.skin.get_bind_count():
			var bb := m.skin.get_bind_bone(k)
			if bb < 0:
				bb = _skel.find_bone(m.skin.get_bind_name(k))
			if bb == bi:
				bind = k
		if bind < 0:
			continue
		var to_body := _rest_in_body(bi) * m.skin.get_bind_pose(bind)
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			for v in verts.size():
				var w := 0.0
				for k in per:
					if bones[v * per + k] == bind:
						w += wts[v * per + k]
				if w < 0.25:
					continue
				var p := to_body * verts[v] - a
				var t := p.dot(d) / axis.length()
				if t < t0 - 0.05 or t > t1 + 0.05:
					continue
				var q := p - d * p.dot(d)
				var ang := fposmod(atan2(q.dot(e2), q.dot(e1)), TAU)
				var ia := int(ang / TAU * NA) % NA
				var ih := clampi(int((t - t0) / (t1 - t0) * NH), 0, NH - 1)
				rad[ih * NA + ia] = maxf(rad[ih * NA + ia], q.length())
	# fill empty cells, then smooth so the wrap is a tight but soft shell over the armour
	var floor_r := 0.035
	for i in rad.size():
		floor_r = maxf(floor_r, rad[i] * 0.42)
	for pass_i in 2:
		var out := rad.duplicate()
		for ih in NH:
			for ia in NA:
				var m := rad[ih * NA + ia]
				for o in [-1, 1]:
					m = maxf(m, rad[ih * NA + (ia + o + NA) % NA] * 0.9)
					m = maxf(m, rad[clampi(ih + o, 0, NH - 1) * NA + ia] * 0.94)
				out[ih * NA + ia] = maxf(m, floor_r)
		rad = out
	if OS.get_environment("WRAP_DBG") != "" and bone.contains("Leg") and not bone.contains("Up"):
		var line := "WRAP %s len %.3f floor %.3f |" % [bone, axis.length(), floor_r]
		for ih in NH:
			var f := rad[ih * NA]          # front (body forward)
			var bk := rad[ih * NA + NA / 2]  # back (calf)
			var sd := rad[ih * NA + NA / 4]
			line += " %.2f:%.3f/%.3f/%.3f" % [lerpf(t0, t1, (ih + 0.5) / NH), f, sd, bk]
		print(line)
	var mesh := _grid(func(u: float, v: float) -> Vector3:
		var ang := u * TAU
		var fa := u * NA - 0.5
		var fh := clampf(v * NH - 0.5, 0.0, NH - 1.0)
		var ia0 := int(floor(fa))
		var ih0 := int(floor(fh))
		var ih1 := mini(ih0 + 1, NH - 1)
		var r00 := rad[ih0 * NA + (ia0 + NA) % NA]
		var r01 := rad[ih0 * NA + (ia0 + 1 + NA) % NA]
		var r10 := rad[ih1 * NA + (ia0 + NA) % NA]
		var r11 := rad[ih1 * NA + (ia0 + 1 + NA) % NA]
		var fx: float = fa - floor(fa)
		var fy: float = fh - floor(fh)
		var r := maxf(lerpf(lerpf(r00, r01, fx), lerpf(r10, r11, fx), fy) - wrap_inset, floor_r) + pad
		# each turn of the bandage overlaps the last: a slight step at the leading edge
		r += 0.004 * fposmod(v * turns + u, 1.0)
		var t := lerpf(t0, t1, v)
		return a + axis * t + (e1 * cos(ang) + e2 * sin(ang)) * r, 24, 28)
	var piece := _piece(mesh, 0.0, 0.05, 5.0 + mats.size(), (t1 - t0) * axis.length() / 0.4)
	var mat := piece.material_override as ShaderMaterial
	mat.set_shader_parameter("wrap_turns", turns)
	mat.set_shader_parameter("tongues", 10.0)
	_attach(bone).add_child(piece)
	wraps += 1

## The deep cowl: a dome over the crown that opens round the face and flares out over the
## shoulders. It hangs in gathered drape folds (`pleat_phase()` over `n` folds across the hood,
## which rag.gdshader shades through uniform `pleats` = n): barely a ripple on the crown where
## the cloth is stretched over the skull, deepening toward the hem where it falls free, and
## pressed shallow at the back of the neck. The brim round the face rolls over into a thick
## lip that sags a little over the brow, and the hem is cut unevenly by hand.
func _cowl(mseed: float, n: float) -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		# open at the front: the face sits in the dark of the cowl, which closes at the throat
		var gap := 0.22 + 0.42 * smoothstep(0.12, 0.4, v) - 0.5 * smoothstep(0.72, 1.0, v)
		var a := lerpf(gap, TAU - gap, u)
		# a hand-cut hem: never more than ~2 cm short, so it still tucks under the mantle collar
		var cut := 1.0 - 0.035 * (0.5 + 0.5 * sin(a * 2.7 + mseed)) \
				- 0.02 * (0.5 + 0.5 * sin(a * 9.0 + mseed * 1.9))
		var vv := v * lerpf(1.0, cut, smoothstep(0.5, 1.0, v))
		# (11-13 21:00) not a bucket: from above and behind the old profile (a shallow dome, full
		# width straight down to a shelf at vv 0.7, then a 45 % skirt) read as a straight-sided
		# pail with a flat lid. Now a round dome as tall as it is wide sits snug on the skull, and
		# from there the cloth widens steadily all the way to the shoulders, a bell, not a pail
		var dome := sqrt(clampf(1.0 - pow(1.0 - minf(vv / 0.42, 1.0), 2.0), 0.0, 1.0))
		var bk := maxf(-cos(a), 0.0)
		var r := dome * (0.86 + 0.59 * pow(smoothstep(0.22, 1.0, vv), 1.3))
		# the back's slack: below the occiput the hood sags out a little under its own weight
		r += 0.05 * bk * bk * exp(-pow((vv - 0.62) / 0.14, 2.0))
		r *= 1.0 + 0.03 * sin(a * 7.0) * vv
		if n > 0.0:
			# drape folds, each its own depth, biased outward so no valley sinks onto the head
			var ph := pleat_phase(u, v, n, mseed)
			var fh := sin(ph * TAU) + 0.35 * sin(ph * TAU * 2.0 + 1.3)
			var swell := 0.55 + 0.45 * sin(ph * TAU * 0.41 + mseed * 2.3) * sin(ph * 0.9 + mseed)
			var amp := lerpf(0.003, 0.085, smoothstep(0.15, 0.95, vv)) * swell
			# pressed flat where the cowl lies on the back of the neck
			amp *= 1.0 - 0.45 * smoothstep(0.2, 0.9, vv) * pow(maxf(-cos(a), 0.0), 2.0)
			# (11-13 22:00) ash-stiff hemp does not ripple like silk: the folds break into sharp
			# ridges between rounder hollows, and three or four deep irregular folds (a crush
			# where the hood lay on the shoulder, a fold kinked by the mantle collar) break the
			# bell's even run of pleats at uneven places round it
			if HOOD_STIFF > 0.0:
				var sharp := 2.0 * (1.0 - absf(sin(ph * PI))) - 1.0
				fh = lerpf(fh, 1.3 * sharp, HOOD_STIFF)
			r += amp * (0.5 * fh + 0.55)
			if HOOD_STIFF > 0.0:
				var deep := 0.0
				for k in 4:
					var fk := float(k)
					var ca := 1.1 + fk * 1.33 + 0.5 * sin(mseed * (2.1 + fk) + fk * 4.7)
					var cw := 0.07 + 0.04 * (0.5 + 0.5 * sin(mseed * 3.3 + fk * 2.9))
					var cd := 0.6 + 0.4 * sin(mseed * 1.3 + fk * 5.1)
					# the fold leans as it falls, as cloth draped off a round shoulder does
					var dk: float = wrapf(a - ca - (0.18 + 0.1 * fk) * (vv - 0.5), -PI, PI)
					# a stiff ridge thrown out, a deep hollow tucked under it on one side
					deep += cd * (exp(-dk * dk / (cw * cw)) - 0.8 * exp(-pow(dk + 1.4 * cw, 2.0) / (0.6 * cw * cw)))
				r += HOOD_DEEP * deep * smoothstep(0.22, 0.8, vv) * (1.0 - 0.6 * pow(maxf(-cos(a), 0.0), 3.0))
			if HOOD_CREASE > 0.0:
				# stiff horizontal creases sagging across the sides: each a sharp ridge with the
				# hollow under it, bowing down toward the middle of the side, fading to the front
				# (the brim) and the back (pressed on the neck); seeded per hood
				var side := pow(absf(sin(a)), 2.0)
				var hc := 0.0
				for k in 3:
					var fk := float(k)
					var sgn := signf(sin(a))
					var c0 := 0.42 + 0.13 * fk + 0.03 * sin(mseed * (1.7 + fk) + sgn * 2.1)
					# the crease sags in the middle of the side and wanders round it
					var cv := c0 + 0.035 * absf(sin(a)) + 0.012 * sin(a * 5.0 + mseed + fk * 2.3)
					var dv := vv - cv
					var cwid := 0.018 + 0.006 * fk
					var ck := (0.8 - 0.2 * fk) * (0.7 + 0.3 * sin(mseed * 2.9 + fk * 3.1 + sgn))
					hc += ck * (exp(-dv * dv / (cwid * cwid)) - 0.9 * exp(-pow(dv - 1.6 * cwid, 2.0) / (0.8 * cwid * cwid)))
				r += HOOD_CREASE * hc * side
			# the brim: a rolled lip of doubled cloth round the face opening
			var lip := 1.0 - smoothstep(0.0, 0.07, minf(u, 1.0 - u))
			r += 0.06 * lip * dome
		# the crown is not a dome: the cloth gathers into a slumped peak pulled back over the
		# skull, the tip drooping behind, with a couple of creases running down from it
		var pk := 1.0 - smoothstep(0.0, 0.34, vv)
		var back := maxf(-cos(a), 0.0)
		# (11-13 21:00: 0.22 left a flat ledge on top seen from behind; a softer droop)
		r *= 1.0 + 0.08 * pk * pk * back * smoothstep(0.02, 0.1, vv)
		# a centre seam runs over the crown down the back: two panels sewn edge to edge stand a
		# little proud along it, breaking the dome's smooth top
		var sda := wrapf(a - PI, -PI, PI)
		r += 0.075 * exp(-sda * sda / 0.006) * (1.0 - smoothstep(0.35, 0.75, vv)) * smoothstep(0.0, 0.05, vv)
		var crease := 0.0
		for c in [[PI - 0.85 + 0.2 * sin(mseed), 1.0], [PI + 0.7 + 0.15 * cos(mseed * 1.7), 0.8],
				[0.9 * PI + 0.3 * sin(mseed * 2.3), 0.6]]:
			var da: float = wrapf(a - float(c[0]) - 0.25 * vv, -PI, PI)
			# a sharp ridge with a shallow hollow beside it, strongest just below the peak
			crease += float(c[1]) * (exp(-da * da / 0.012) - 0.45 * exp(-pow(da - 0.16, 2.0) / 0.02))
		r += 0.05 * crease * smoothstep(0.04, 0.14, vv) * (1.0 - smoothstep(0.32, 0.55, vv))
		var cz := -0.045 - 0.06 * pow(1.0 - vv, 3.0) - 0.045 * pk * pk
		# the brim sags forward over the brow where the cloth has nothing under it
		var brow := (1.0 - smoothstep(0.0, 0.18, minf(u, 1.0 - u))) * smoothstep(0.05, 0.2, vv) \
				* (1.0 - smoothstep(0.3, 0.55, vv))
		# (11-13 21:00) the crown sits 4 cm lower, on the skull instead of a peak above it
		var y := 2.09 - vv * 0.43 - 0.04 * (1.0 - smoothstep(0.0, 0.45, vv)) - 0.012 * brow - 0.025 * pk * pk * pk + 0.012 * pk * (1.0 - pk) * 4.0 * (1.0 - back)
		# (11-13 22:00) a head's curve side-on, not a sloped lid: the old profile ran nearly level
		# from the crown back to a hard corner over the brow and dropped straight down the face
		# panel. Now the front of the dome rolls down over the brow (the brim hangs over the
		# forehead with nothing holding it up) and the back of the crown rounds off into the drape
		var fr := pow(maxf(cos(a), 0.0), 1.5)
		var roll := smoothstep(0.0, 0.22, vv) * (1.0 - smoothstep(0.3, 0.62, vv))
		y -= HOOD_BROW_ROLL * fr * roll
		var occ := smoothstep(0.0, 0.08, vv) * (1.0 - smoothstep(0.18, 0.5, vv))
		r *= 1.0 - HOOD_BACK_ROUND * back * back * occ
		y -= 0.03 * back * back * occ
		# slumped a little to the wearer's right at the top, as worn cloth settles
		var slump := -0.012 * (1.0 - smoothstep(0.0, 0.5, vv))
		return Vector3(sin(a) * 0.168 * r + slump, y, cz + cos(a) * 0.192 * r + 0.01 * brow), 64, 28,
			HOOD_CAV if HOOD_AO > 0.0 else 0.0, Vector3(0.0, 1.85, -0.045))

## How many drape folds hang across the cowl (9..12), from its material seed.
static func hood_folds(mseed: float) -> float:
	return 9.0 + 3.0 * fposmod(sin(mseed * 39.425) * 43758.5453, 1.0)

## The harrier's coif: hugs the helm (head verts span x +-0.105, y 1.64..1.98, z -0.17..0.13
## at the soldier's scale), open over the visor, closing snug round the throat.
func _coif() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var gap := 0.5 + 0.3 * smoothstep(0.1, 0.4, v) - 0.55 * smoothstep(0.78, 1.0, v)
		var a := lerpf(gap, TAU - gap, u)
		var dome := sqrt(clampf(1.0 - pow(1.0 - minf(v / 0.3, 1.0), 2.0), 0.0, 1.0))
		# egg-shaped like the skull under it: fullest at the brow, drawn in under the jaw to the
		# neck, with a loose fold of collar at the very bottom
		# (18:00 11-03: drawn in all round, the back of the helm stood up to 3.5 cm proud of the
		# coif and the bare ash skull showed from behind: only the jaw and the sides draw in,
		# the back falls straight down the occiput to the nape)
		var jaw := smoothstep(-0.25, 0.6, cos(a))
		var r := dome * (1.0 - 0.26 * jaw * smoothstep(0.5, 0.9, v) + 0.1 * smoothstep(0.9, 1.0, v))
		r *= 1.0 + 0.03 * sin(a * 9.0 + v * 4.0) * v
		# stretched over the old helm's rear lugs behind the ears (the left one stands ~3 cm
		# proud of the skull's ellipse, the right barely): the strips ride over them
		var lug_v := exp(-pow((v - 0.6) / 0.17, 2.0))
		r += lug_v * (0.26 * exp(-pow(a - 2.2, 2.0) / 0.12) + 0.06 * exp(-pow(a - (TAU - 2.2), 2.0) / 0.12))
		var cz := -0.02 - 0.03 * smoothstep(0.5, 1.0, v)
		# each turn of strip laps over the last: a proud step at its lip (strips of uneven
		# width, the shader's warp), and the strip sags a little between the lips where it was
		# wound slack; none of it on the crown, where the dome closes
		var sw := _wrap_s(v * COIF_TURNS + u, 1.0, 0.0)
		var f := fposmod(sw, 1.0)
		var slack := 0.3 + 0.7 * fposmod(sin(floorf(sw) * 12.9898) * 43758.5453, 1.0)
		var lap := (0.011 * f - 0.006 * slack * sin(f * PI)) * smoothstep(0.08, 0.25, v)
		r += lap / 0.14
		# not a pot: wound lopsided by hand, fuller over the wearer's right ear and pulled in
		# over the left where the strip was drawn tight
		r *= 1.0 - 0.05 * sin(a + 0.4) * smoothstep(0.15, 0.45, v) * (1.0 - smoothstep(0.7, 0.95, v))
		# one strip crosses over the skull from the brow to the nape, lying proud of the turns
		# under it with a hard edge, so the profile of the crown steps instead of arcing
		var y := 2.0 - v * 0.38
		# a curtain of hemp let down over the nape: the crouch pitches the head well forward
		# and opened a gap between coif and collar where the bare ash neck burned in the tell
		var nape := smoothstep(0.1, -0.7, cos(a)) * smoothstep(0.6, 1.0, v)
		y -= 0.13 * nape
		r += 0.12 * nape * smoothstep(0.8, 1.0, v)
		var cross := (1.0 - smoothstep(0.16, 0.24, absf(a - PI - 0.12))) * (1.0 - smoothstep(0.5, 0.7, v))
		r += 0.013 * cross * smoothstep(0.03, 0.12, v) / 0.14
		y += 0.012 * (1.0 - smoothstep(0.0, 0.12, v))      # its thickness over the apex
		# the ends tied off in a bunched knot high on the back of the head, right of centre
		var ka := a - (PI + 0.75)                  # x < 0: the wearer's right
		var kv := (v - COIF_KNOT_V) / 0.09
		var knot := exp(-(ka * ka / 0.09 + kv * kv))
		# (18:00 11-03: one soft bump read as nothing from behind) a square knot is a hard
		# core with the two ends pulled out of it: two short splayed lobes, one up and toward
		# the crown, one down toward the nape, so the tie-off breaks the head's outline
		var la := ka - 0.3
		var lb := ka + 0.26
		var lobe_a := exp(-(la * la / 0.025 + pow(kv + 0.9, 2.0) / 0.45))
		var lobe_b := exp(-(lb * lb / 0.03 + pow(kv - 1.0, 2.0) / 0.5))
		knot = maxf(knot, 0.75 * maxf(lobe_a, lobe_b))
		knot *= 1.0 + 0.3 * sin(a * 23.0 + v * 31.0)        # crumpled, not a smooth ball
		r += COIF_KNOT * knot / 0.14
		y += 0.012 * knot
		return Vector3(sin(a) * 0.122 * r, y, cz + cos(a) * 0.158 * r), 56, 40)

## The coif's turn coordinate, warped so the strips are wound unevenly: wide and narrow turns
## that wander along their length. Monotone (|d warp| < 1); rag.gdshader does the same sum.
static func _wrap_s(s0: float, jitter: float, sd: float) -> float:
	return s0 + jitter * (0.2 * sin(s0 * 2.3 + sd) + 0.07 * sin(s0 * 5.1 + sd * 1.7))

## The coif strip's loose end: tucked under the last turn at the left temple, then a short
## frayed tongue that hangs down and a little out past the cheek-guard.
func _loose_end() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var w := lerpf(0.045, 0.034, v)
		var a := 1.15 + (u - 0.5) * w / 0.13       # round the skull at the wearer's left temple
		var hang := v * 0.16
		var out := 0.006 + 0.03 * v * v           # peels off the coif as it hangs
		var r := 1.1 + out / 0.13                 # in the coif's own ellipse, clear of its laps
		return Vector3(sin(a) * 0.122 * r, 1.86 - hang, -0.02 + cos(a) * 0.158 * r + 0.01 * sin(v * 5.0)), 4, 10)

## One knotted tail of the coif, hung from the nape down the upper back.
func _tail(side: float) -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		# a fat knot at the nape, then a strip that tapers and splays out over the shoulder
		# blades so the pair shows past the neck from the side; it lies a couple of cm off the
		# back, which (bot `harrier` measures it) bulges from z -0.16 at the nape to -0.21 at
		# the shoulder blades and back in to -0.19 lower down
		var knot := 0.025 * (1.0 - smoothstep(0.0, 0.12, v))
		var w := lerpf(0.06, 0.028, v) + knot
		var x := side * (0.03 + 0.10 * v) + (u - 0.5) * w
		var z := -0.185 - 0.05 * smoothstep(0.0, 0.6, v) + 0.02 * smoothstep(0.7, 1.0, v) \
				- knot + 0.008 * sin(v * 7.0 + side)
		return Vector3(x, 1.83 - v * TAIL_LEN, z), 4, 14)

## The shoulder mantle: rests tight on the shoulders and drapes from them in soft, uneven folds
## that fan out and deepen toward a hand-cut hem; it sags lower over the chest and between the
## shoulder blades where nothing holds it up. The fold phase is `pleat_phase()` over `n` folds
## round the whole cape, so rag.gdshader (uniform `pleats` = n) shades the same folds.
func _mantle(mseed: float, n: float) -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var gap := 0.4
		var a := lerpf(gap, TAU - gap, u)
		# a hand-cut hem: dips and rises unevenly round the cape, one or two deeper scallops
		var cut := 1.0 - 0.07 * (0.5 + 0.5 * sin(a * 2.3 + mseed)) \
				- 0.035 * (0.5 + 0.5 * sin(a * 11.0 + mseed * 2.0))
		var vv := v * cut
		var k := pow(vv, 0.42)
		var rx := lerpf(0.135, 0.375, k)
		var rz := lerpf(0.135, 0.31, k)
		# held up by the shoulders (|sin a| -> 1), free over the chest and the back
		var sh := pow(absf(sin(a)), 2.0)
		# drape folds: gathered small at the collar, fanning out and deepening to the hem, each
		# fold its own depth, and pressed shallow where the cloth lies on the shoulder; biased
		# outward so the valleys never sink into the armour underneath
		var ph := pleat_phase(u, v, n, mseed)
		var fh := sin(ph * TAU) + 0.35 * sin(ph * TAU * 2.0 + 1.3)
		var swell := 0.55 + 0.45 * sin(ph * TAU * 0.37 + mseed * 2.3) * sin(ph * 1.1 + mseed)
		var amp := lerpf(0.002, 0.028, smoothstep(0.0, 0.9, vv)) * (1.0 - 0.6 * sh) * swell
		var d := amp * (0.5 * fh + 0.55)
		# the hem kicks out a little where it hangs free
		d += 0.012 * vv * vv * vv * (1.0 - sh)
		# the hem hangs lower at the back, and sags over the chest between the shoulders
		var hem := lerpf(1.43, 1.30, (1.0 - cos(a)) * 0.5) - 0.035 * (1.0 - sh) * (0.5 + 0.5 * cos(a))
		var y := lerpf(1.71, hem, vv)
		return Vector3(sin(a) * (rx + d), y, -0.045 + cos(a) * (rz + d)), 72, 20)

## How many drape folds hang round the mantle (14..18), from its material seed.
static func mantle_folds(mseed: float) -> float:
	return 14.0 + 4.0 * fposmod(sin(mseed * 78.233) * 43758.5453, 1.0)

func _sash() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var bulge := 1.0 + 0.05 * sin(v * PI) + 0.02 * sin(a * 5.0 + v * 3.0)
		var tilt := 0.03 * sin(a)
		return Vector3(sin(a) * 0.258 * bulge, 1.245 - v * 0.15 + tilt, 0.005 + cos(a) * 0.222 * bulge), 36, 4)

## Panels that hang to gravity: the pelvis's forward tilt is taken back out of both, the front
## one rides the thighs right up to their angle on a deep stoop and folds down over the knees,
## and either one folds where it would go into the ground (a robe pooling behind a crouch).
func _hang_panels(fwd: float, bwd: float, k: float) -> void:
	var up := _body.global_basis.y.normalized()
	var ahead := _body.global_basis.z.normalized()
	# the pivots' rest frame against the body's: how far the pelvis tips forward
	var rot_f := _front.rotation.x
	_front.rotation.x = 0.0
	var down := -_front.global_basis.y.normalized()
	var fz := _front.global_basis.z.normalized()
	_front.rotation.x = rot_f
	tip = -atan2(down.dot(ahead), -down.dot(up)) * hang
	# the legs as posed after the skeleton's modifiers (a crouch bends them past the clip's
	# pose, which get_bone_global_pose does not see here): the deepest thigh off the pelvis
	var ground := INF
	var knee := Vector3.ZERO
	var knee_f := -INF
	var thigh := -INF
	for leg in _legs:
		var hp := _joint(leg[0])
		var kp := _joint(leg[1])
		var d := kp - hp
		thigh = maxf(thigh, atan2(d.dot(fz), d.dot(down)))
		# the ground under her: the lower foot's ankle, less the ankle height
		ground = minf(ground, _joint(leg[2]).dot(up) - 0.07)
		if kp.dot(ahead) > knee_f:
			knee_f = kp.dot(ahead)
			knee = kp
	var deep := hang * clampf(tip / 0.3, 0.0, 1.0)
	var cap := lerpf(0.7, maxf(thigh, 0.7), deep)
	fwd = maxf(fwd, lerpf(fwd, thigh - swing_slack, deep))
	_swing_f = lerpf(_swing_f, minf(maxf(fwd * 1.1, tip), cap), k)
	_swing_b = lerpf(_swing_b, minf(bwd * 1.1, 0.7) - tip, k)
	var sy := _front.global_basis.y.length()
	var ff := Vector2(1000.0, 0.0)
	var ff2 := Vector2(1000.0, 0.0)
	var fl: float = _front.get_meta("len", 1.0)
	var fw := _swing_f - tip
	if deep > 0.0:
		# down the panel to the knee, then the rest hangs straight down from it, and what is
		# longer than the knee is high pools forward on the ground in front of her
		var kd := (knee - _front.global_position).length() / sy
		if kd < fl:
			var kh := (knee.dot(up) - ground - 0.03) / sy
			ff = Vector2(kd, maxf(fw, 0.0) * deep)
			if kh > 0.0 and kd + kh < fl:
				ff2 = Vector2(kd + kh, -(PI * 0.5 - 0.05) * deep)
	fold_front = fold_front.lerp(ff, k)
	fold_front2 = fold_front2.lerp(ff2, k)
	var fb := Vector2(1000.0, 0.0)
	var bl: float = _back.get_meta("len", 1.0)
	var bw := _swing_b + tip
	var h := _back.global_position.dot(up) - ground - 0.03
	var c := maxf(cos(bw), 0.2)
	if bl * sy * c > h and h > 0.0:
		fb = Vector2(h / c / sy, maxf(PI * 0.5 - bw - 0.05, 0.0) * hang)
	fold_back = fold_back.lerp(fb, k)
	if fold_round > 0.0:
		# back from a tuck: the rolled knee fold eases back to the plain crease
		fold_round = lerpf(fold_round, 0.0, k)
		if fold_round <= 0.002:
			fold_round = 0.0
		_set_fold_len(fold_round)
	(_front.get_child(0) as MeshInstance3D).material_override.set_shader_parameter("fold", fold_front)
	(_front.get_child(0) as MeshInstance3D).material_override.set_shader_parameter("fold2", fold_front2)
	(_back.get_child(0) as MeshInstance3D).material_override.set_shader_parameter("fold", fold_back)

var KNEEFOLD_OFF := OS.has_environment("KNEEFOLD_OFF")   # the old flat board in the tuck (before)

## The pivot's rest frame (rotation 0): its down and forward axes, world.
func _pivot_frame(pv: Node3D) -> Array:
	var rot := pv.rotation.x
	pv.rotation.x = 0.0
	var down := -pv.global_basis.y.normalized()
	var fz := pv.global_basis.z.normalized()
	pv.rotation.x = rot
	return [down, fz]

## The free-hanging swing (as the plain path) plus the tuck: with the legs posed off the ground
## the front panel lies along the higher thigh (over its top, `TUCK_PAD` up) and folds down at
## the knee to hang plumb; the back panel swings back so its hem clears the heels.
func _tuck_panels(fwd: float, bwd: float, k: float) -> void:
	var tf := minf(fwd * 1.1, 0.7)
	var tb := minf(bwd * 1.1, 0.7)
	# what the limbs push the cloth to at once (a thigh or a heel is a contact, not a spring:
	# easing toward it, the fast fold drove the knee 11 cm through the panel)
	var push_f := -INF
	var push_b := -INF
	var gap_at := []
	var shin_at := []
	var heels := []
	var lie := 0.0
	var ff := fold_front
	var fd := ff.x if ff.x < 100.0 else 0.0
	var fa := INF          # the plumb line's angle in the pivot's frame (INF: no knee fold)
	var sy := _front.global_basis.y.length()
	var fl: float = _front.get_meta("len", 1.0)
	var up := _body.global_basis.y.normalized()
	if posed_legs and wall_n == Vector3.ZERO and _legs.size() == 2:
		var fr := _pivot_frame(_front)
		var down: Vector3 = fr[0]
		var fz: Vector3 = fr[1]
		var o := _front.global_position
		# the higher thigh (most forward off the pelvis, posed)
		var th := -INF
		var hp := Vector3.ZERO
		var kp := Vector3.ZERO
		for leg in _legs:
			var h := _joint(leg[0])
			var kn := _joint(leg[1])
			var d := kn - h
			var a := atan2(d.dot(fz), d.dot(down))
			if a > th:
				th = a
				hp = h
				kp = kn
		lie = smoothstep(TUCK_LIE0, TUCK_LIE1, th)
		if lie > 0.0:
			# the knee's top: out from the joint along the thigh line's outward normal
			var tn := (fz * cos(th) - down * sin(th)).normalized()
			var top := kp + tn * TUCK_PAD
			var r := top - o
			var aim := minf(atan2(r.dot(fz), r.dot(down)), TUCK_SWING_MAX)
			tuck_aim = aim
			tf = lerpf(tf, maxf(tf, aim), lie)
			push_f = lerpf(-0.5, aim, lie) if lie >= 0.5 else -INF
			var kd := r.length() / sy
			if kd < fl - 0.05:
				fd = kd
				# below the knee the cloth hangs plumb (the world's down in the pivot's frame)
				var g := -up
				var plumb := atan2(g.dot(fz), g.dot(down))
				fa = plumb
			if lie >= 0.9:
				gap_at = [o, down, fz, kp, r]
				for leg in _legs:
					if _joint(leg[1]).is_equal_approx(kp):
						shin_at = [o, down, fz, kp, _joint(leg[2])]
		# the back panel's hem behind the heels
		var br := _pivot_frame(_back)
		var bdown: Vector3 = br[0]
		var bz: Vector3 = br[1]
		var bo := _back.global_position
		var bl: float = _back.get_meta("len", 1.0) * _back.global_basis.y.length()
		for leg in _legs:
			var heel := _joint(leg[2]) - bz * 0.06
			var rh := heel - bo
			if rh.length() < bl:
				# back swing (+ = hem toward -fz) that puts the panel line 6 cm behind the heel
				var ah := atan2(-rh.dot(bz), rh.dot(bdown)) + 0.06 / maxf(rh.length(), 0.2)
				tb = maxf(tb, minf(ah, 1.2))
				push_b = maxf(push_b, minf(ah, 1.2))
				heels.append([rh.length(), ah - 0.06 / maxf(rh.length(), 0.2)])
	tuck_k = k
	tuck_lie = lerpf(tuck_lie, lie, k)
	tuck_lie_peak = maxf(tuck_lie_peak, tuck_lie)
	_swing_f = _drop_swing(0, _swing_f, tf, push_f, k, fl * sy)
	_swing_b = _drop_swing(1, _swing_b, tb, push_b, k, _back.get_meta("len", 1.0) * _back.global_basis.y.length())
	# the gaps the panel lines (at the swings they now have) leave over the knee's top and
	# behind the heels
	if not gap_at.is_empty():
		var pd: Vector3 = gap_at[1] * cos(_swing_f) + gap_at[2] * sin(_swing_f)
		var pn: Vector3 = gap_at[2] * cos(_swing_f) - gap_at[1] * sin(_swing_f)
		var rr: Vector3 = gap_at[4]
		if rr.dot(pd) > 0.0 and rr.dot(pd) < fl * sy:
			tuck_gap = minf(tuck_gap, _pn_gap(gap_at[0], pn, gap_at[3]))
	for hl in heels:
		tuck_heel = minf(tuck_heel, hl[0] * sin(_swing_b - hl[1]))
	# below the knee the cloth hangs plumb: the fold takes back what the panel lies out past it
	var fy := maxf(_swing_f - fa, 0.0) * lie if fa < INF else 0.0
	if lie > 0.0 or fold_front.y > 0.002:
		fold_front = Vector2(fd if fd > 0.0 else fl, lerpf(fold_front.y if fold_front.x < 100.0 else 0.0, fy, maxf(k, lie)))
	else:
		fold_front = Vector2(1000.0, 0.0)
	var round_to := 0.0 if OS.has_environment(KNEEROUND_OFF_ENV) else TUCK_ROUND
	fold_round = lerpf(fold_round, round_to, maxf(k, lie))
	if not shin_at.is_empty() and fold_front.x < 100.0 and fold_front.y > 0.3:
		# the bent cloth's centre line against the higher shin (knee -> ankle)
		var so: Vector3 = shin_at[0]
		var sd: Vector3 = shin_at[1] * cos(_swing_f) + shin_at[2] * sin(_swing_f)
		var sn: Vector3 = shin_at[2] * cos(_swing_f) - shin_at[1] * sin(_swing_f)
		for i in 12:
			var dl := fold_front.x + (fl - fold_front.x) * (i + 0.5) / 12.0
			var q := fold_arc(dl, fold_front, fold_round)
			var w := so + (sd * q.x + sn * q.y) * sy
			var a0: Vector3 = shin_at[3]
			var a1: Vector3 = shin_at[4]
			var seg := a1 - a0
			var u := clampf((w - a0).dot(seg) / maxf(seg.length_squared(), 1e-6), 0.0, 1.0)
			tuck_shin = minf(tuck_shin, (w - (a0 + seg * u)).length())
	_set_fold_len(fold_round)
	(_front.get_child(0) as MeshInstance3D).material_override.set_shader_parameter("fold", fold_front)

## A panel left high (the thigh it lay on drops away at a landing) FALLS: a heavy wool board
## hinged at the belt, under gravity with air drag, from rest, so it starts slow, speeds up,
## swings a little past its hang and settles, instead of easing shut like a damped lid (the old
## ease started at its fastest, 10 rad/s, the moment the thigh left it). A limb under it still
## catches it at once (`push`). Small swings (walking) keep the plain ease.
const DROP_START := 0.35      # rad above its rest a panel must be left to fall freely
const DROP_ZETA := 0.35       # air drag on the wool (damping ratio)
## cloth is no rigid board: the part below the knee hangs off the fold already and the rest
## bends as it goes, so it falls like a board this fraction of the panel's length (~0.3 s down)
const DROP_EFF := 0.42
const DROP_UNDER := 0.15      # rad past its rest it may swing (the legs are behind it)
var DROP_OFF := OS.has_environment("ROBEDROP_OFF")   # the old eased lid (before)
var _dt := 1.0 / 60.0
var _drop := [false, false]
var _drop_w := [0.0, 0.0]     # rad/s, each panel's swing speed
var _drop_t := [0.0, 0.0]     # s since the fall began
var drop_peak_w := 0.0        # fastest fall seen (rad/s), for the bots
var drop_under := 0.0         # deepest swing past the hang (rad), for the bots
var drop_first_w := 9.0       # swing speed on the fall's first tick (rad/s), for the bots
var drop_settle := 0.0        # s from release to within 0.1 rad of the hang, for the bots

func _drop_swing(i: int, s: float, rest: float, push: float, k: float, length: float) -> float:
	var eased := maxf(lerpf(s, rest, k), push)
	if DROP_OFF:
		return eased
	if not _drop[i] and s - rest > DROP_START and push < s - 0.02:
		_drop[i] = true
		_drop_t[i] = 0.0
		_drop_w[i] = minf(_drop_w[i], 0.0)
		if i == 0:                # (bots) each fall is judged on its own
			drop_first_w = 9.0
			drop_peak_w = 0.0
			drop_under = 0.0
			drop_settle = 0.0
	if not _drop[i]:
		_drop_w[i] = (eased - s) / maxf(_dt, 1e-4)
		return eased
	# a physical pendulum the panel's length (uniform board: w^2 = 3g / 2L), in substeps
	var w2 := 1.5 * 9.8 / maxf(length * DROP_EFF, 0.2)
	var w := sqrt(w2)
	var om: float = _drop_w[i]
	var n := 4
	var h := _dt / n
	# (11-09) gravity pulls the wool toward plumb, not toward the thigh it will come to lie on:
	# with the thigh still under it (rest > 0, a landing that stays down in the knees) it is
	# that thigh that stops it, with no swing past (the old pull toward `rest` let a panel left
	# 0.5 rad over a lowering thigh drift down at the speed of a lid)
	var hang := minf(rest, 0.0)
	var low := rest - DROP_UNDER * (1.0 - clampf(rest / 0.3, 0.0, 1.0))
	for j in n:
		om += (-w2 * sin(s - hang) - 2.0 * DROP_ZETA * w * om) * h
		s += om * h
		if s < low:
			s = low
			om = absf(om) * 0.3   # it meets the legs behind it (or the thigh under it)
	if s < push:
		s = push                  # a limb catches it
		om = maxf(om, 0.0)
	if i == 0:
		if _drop_t[i] == 0.0:
			drop_first_w = absf(om)
		drop_peak_w = maxf(drop_peak_w, -om)
		drop_under = maxf(drop_under, rest - s)
		if drop_settle == 0.0 and (s - rest < 0.1 or s <= push + 0.001):   # down, or caught by a limb
			drop_settle = _drop_t[i] + _dt
	_drop_t[i] += _dt
	_drop_w[i] = om
	# past the low point and on the way back up: the plain ease takes it home
	if (s < rest and om >= 0.0) or (absf(s - rest) < 0.03 and absf(om) < 0.5) or _drop_t[i] > 1.5:
		_drop[i] = false
	return s

## The front panel's (and the gores' front ends') knee-fold arc length; 0 = the old crease.
func _set_fold_len(v: float) -> void:
	var fv := v if v > 0.002 else 0.0
	(_front.get_child(0) as MeshInstance3D).material_override.set_shader_parameter("fold_len", fv)
	if has_method("_gore_fold_len"):
		call("_gore_fold_len", fv)

## Where a point `d` down a panel (local units, from the seam) sits once bent by fold `f`
## round an arc `len` long: (down along the unbent panel, out along its normal). Matches
## rag.gdshader fold_panel_arc().
static func fold_arc(d: float, f: Vector2, len: float) -> Vector2:
	var fd := d - f.x
	if fd <= 0.0 or absf(f.y) < 0.0005:
		return Vector2(d, 0.0)
	len = maxf(len, 0.07)
	var t := minf(fd, len)
	var a := f.y * t / len
	var rr := len / f.y
	var rest := fd - t
	return Vector2(f.x + rr * sin(a) + rest * cos(a), -rr * (1.0 - cos(a)) - rest * sin(a))

## The knee joint's distance out past the panel line (m, + = the cloth clear over the knee's top
## by that much less TUCK_PAD; the measure the bots gate on).
func _pn_gap(o: Vector3, pn: Vector3, kp: Vector3) -> float:
	return (o - kp).dot(pn) - TUCK_PAD

## The most the front panel may swing out (rad) before its hem meets the face, kept 4 cm
## off it; `front_clear` is the hem's gap at the swing it returns.
func _wall_swing() -> float:
	var rot := _front.rotation.x
	_front.rotation.x = 0.0
	var down := -_front.global_basis.y
	var fz := _front.global_basis.z
	var o := _front.global_position
	_front.rotation.x = rot
	var ln: float = _front.get_meta("len", 1.0)
	var gap := (o - wall_p).dot(wall_n)
	var hem := func(s: float) -> float:
		return gap + (down * cos(s) + fz * sin(s)).dot(wall_n) * ln
	var s := _swing_f
	var lo := -0.3
	if hem.call(s) >= 0.04:
		front_clear = hem.call(s)
		return s
	# bisect between a swing that clears and one that does not
	var hi := s
	for _i in 10:
		var mid := (lo + hi) * 0.5
		if hem.call(mid) >= 0.04:
			lo = mid
		else:
			hi = mid
	front_clear = hem.call(lo)
	return lo

var _joints := {}

## A bone's joint in world space as posed after the skeleton's modifiers.
func _joint(bone: int) -> Vector3:
	var att: BoneAttachment3D = _joints.get(bone)
	if att == null:
		att = BoneAttachment3D.new()
		att.bone_idx = bone
		_skel.add_child(att)
		_joints[bone] = att
	return att.global_position

## A cloth sheet from f(u, v) -> point, u across (nu cells), v from the seam to the hem.
## With `cavity` > 0 it also bakes a fold cavity term into COLOR.r (1 open, 0 deep in a
## hollow): how far each vertex sits inside its neighbours along the outward normal (one and
## two cells away, so both the sharp crease and the broad hollow under a fold read), scaled so
## a hollow `cavity` metres deep is fully dark. rag.gdshader shades it through `fold_ao`.
func _grid(f: Callable, nu: int, nv: int, cavity: float = 0.0, centre: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for j in nv + 1:
		for i in nu + 1:
			pts.append(f.call(float(i) / nu, float(j) / nv))
	var cav := PackedFloat32Array()
	if cavity > 0.0:
		cav = _cavity(pts, nu, nv, cavity, centre)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			st.set_uv(Vector2(u, v))
			if cavity > 0.0:
				st.set_color(Color(cav[j * (nu + 1) + i], 0.0, 0.0, 1.0))
			st.add_vertex(pts[j * (nu + 1) + i])
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			var b := a + 1
			var c := a + nu + 1
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _cavity(pts: PackedVector3Array, nu: int, nv: int, depth: float, centre: Vector3) -> PackedFloat32Array:
	var w := nu + 1
	var out := PackedFloat32Array()
	out.resize(pts.size())
	for j in nv + 1:
		for i in nu + 1:
			var p := pts[j * w + i]
			var tu := pts[j * w + mini(i + 1, nu)] - pts[j * w + maxi(i - 1, 0)]
			var tv := pts[mini(j + 1, nv) * w + i] - pts[maxi(j - 1, 0) * w + i]
			var n := tu.cross(tv)
			if n.length_squared() < 1e-12:
				n = p - centre
			n = n.normalized()
			if n.dot(p - centre) < 0.0:
				n = -n
			var ins := 0.0
			for s in [1, 2]:
				var acc := Vector3.ZERO
				var cnt := 0
				for o in [Vector2i(s, 0), Vector2i(-s, 0), Vector2i(0, s), Vector2i(0, -s)]:
					var ii: int = i + o.x
					var jj: int = j + o.y
					if ii < 0 or ii > nu or jj < 0 or jj > nv:
						continue
					acc += pts[jj * w + ii]
					cnt += 1
				if cnt > 0:
					# > 0: the neighbours stand out past this vertex, it sits in a hollow
					ins += (acc / cnt - p).dot(n) * (0.35 if s == 1 else 0.65)
			out[j * w + i] = 1.0 - smoothstep(0.0, depth, ins)
	return out

func set_param(param: String, v: Variant) -> void:
	for m in mats:
		m.set_shader_parameter(param, v)

func _physics_process(delta: float) -> void:
	if _skel == null or delta <= 0.0:
		return
	# the thighs push the panels: front panel rides the leg that swings forward, back the one back
	var hips_pose := _skel.get_bone_global_pose(_hips)
	var fwd := 0.0
	var bwd := 0.0
	for leg in _legs:
		var d := _skel.get_bone_global_pose(leg[1]).origin - _skel.get_bone_global_pose(leg[0]).origin
		var rd := _hips_rest.basis * (hips_pose.basis.inverse() * d)
		var ang := atan2(rd.z, -rd.y)
		fwd = maxf(fwd, ang)
		bwd = maxf(bwd, -ang)
	var drag := 0.0
	if posed_legs:
		# the climb pose's legs, as the modifiers left them, against the body's frame
		var up := _body.global_basis.y.normalized()
		var ahead := _body.global_basis.z.normalized()
		fwd = 0.0
		bwd = 0.0
		var rise := [0.0, 0.0]
		for i in 2:
			var d := _joint(_legs[i][1]) - _joint(_legs[i][0])
			var ang := atan2(d.dot(ahead), -d.dot(up))
			fwd = maxf(fwd, ang)
			bwd = maxf(bwd, -ang)
			rise[i] = d.dot(up)
		# the higher knee lifts the cloth over its thigh and the hems slide toward that side
		drag = clampf((rise[0] - rise[1]) * 0.35, -0.09, 0.09)
	fwd = maxf(fwd - swing_slack, 0.0)
	bwd = maxf(bwd - swing_slack, 0.0)
	# the body's motion through the air (the model rides any lift, so it is in here too)
	var p := _body.global_position
	var vel := (p - _last_pos) / delta
	_last_pos = p
	if vel.length() > 20.0:
		vel = Vector3.ZERO  # a teleport (return to post), not motion
	var local := _body.global_basis.inverse() * (vel + _body.global_basis.y.normalized() * air_y)
	var fk := minf(delta * 10.0, 1.0)
	fall = lerpf(fall, stream * clampf(-local.y / 6.0, 0.0, 1.0), fk)
	rise = lerpf(rise, stream * clampf(local.y / 6.0, 0.0, 1.0), fk)
	# in the air the back panel streams out behind over the trailing legs; coming down the
	# air under the cloth flares both panels out and up
	bwd = maxf(bwd, stream * 0.42 + fall * 0.4)
	fwd = maxf(fwd, fall * 0.5)
	var k := minf(delta * 14.0, 1.0)
	_dt = delta
	if hang > 0.0:
		_hang_panels(fwd, bwd, k)
	elif knee_fold and not KNEEFOLD_OFF:
		_tuck_panels(fwd, bwd, k)
	else:
		_swing_f = lerpf(_swing_f, minf(fwd * 1.1, 0.7), k)
		_swing_b = lerpf(_swing_b, minf(bwd * 1.1, 0.7), k)
	if wall_n != Vector3.ZERO:
		_swing_f = minf(_swing_f, _wall_swing())
	peak_swing = maxf(peak_swing, maxf(_swing_f, _swing_b))
	_front.rotation.x = -_swing_f
	_back.rotation.x = _swing_b
	if stream > 0.0:
		peak_back = maxf(peak_back, _swing_b)
	# the hems trail the body's motion and swing past when it stops
	var target := Vector3(-local.x, 0.0, -local.z) * 0.035
	target.y = absf(local.z) * 0.006
	target.x += drag
	# climbing: the hems lag a stride up the face, then settle past when it stops
	target.y -= clampf(local.y, -2.0, 2.0) * 0.02 * float(posed_legs)
	lateral = drag
	# under the glider the air lifts the hems a little and lets them stream further back
	target.y += stream * 0.05
	# coming down the hems lift on the air; going up they drag a little below the seam
	target.y += fall * 0.17 - rise * 0.04
	# a damped spring: a little overshoot when the body stops or turns
	_vel += ((target - _trail) * 55.0 - _vel * 7.0) * delta
	_trail = (_trail + _vel * delta).limit_length(lerpf(0.12, 0.3, stream))
	peak_lift = maxf(peak_lift, _trail.y)
	set_param("sway", _trail)
	set_param("flap", flap)
