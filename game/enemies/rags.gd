class_name HollowRags
extends Node
## The Hollow Soldier's rags: a deep hood, a shoulder mantle, a knotted sash and a front and
## back tabard of grey, ash-stiff hemp over the old armour. Every piece is built in body space
## (metres, +Z forward, feet at 0) and hung on a skeleton bone, so it rides the animation.
## The tabards swing out of the way of the thighs; the hems trail the body's motion.

const BONE_HEAD := "mixamorig_Head"
const BONE_CHEST := "mixamorig_Spine2"
const BONE_HIPS := "mixamorig_Hips"

var mats: Array[ShaderMaterial] = []
var _skel: Skeleton3D
var _body: Node3D
var _hips_rest := Transform3D()
var _front: Node3D
var _back: Node3D
var _legs: Array[PackedInt32Array] = []
var _hips := -1
var _swing_f := 0.0
var _swing_b := 0.0
var peak_swing := 0.0   # largest tabard swing so far (rad), for the bots
var _last_pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _trail := Vector3.ZERO

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
				skel.find_bone("mixamorig_%sLeg" % side)]))
	head.add_child(_piece(_hood(), 0.0, 0.10, 0.0, 1.2))
	chest.add_child(_piece(_mantle(), 0.35, 0.22, 0.35, 1.0))
	hips.add_child(_piece(_sash(), 0.0, 0.0, 0.0, 0.25))
	_front = _panel(hips, Vector3(0, 1.20, 0.215), 0.30, 0.40, 0.68, 0.9, 1.0)
	_back = _panel(hips, Vector3(0, 1.21, -0.205), 0.32, 0.42, 0.76, -0.9, 2.0)
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
	mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = 2
	return mi

## A tabard panel hung from a pivot at its top edge; the pivot swings about body X.
func _panel(parent: Node3D, top: Vector3, w0: float, w1: float, length: float, bow: float,
		sd: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = top
	parent.add_child(pivot)
	var dir := signf(bow)
	var mesh := _grid(func(u: float, v: float) -> Vector3:
		var x := (u - 0.5) * lerpf(w0, w1, v)
		var s := x / 0.2
		# wraps round the hips at the top, hangs flatter lower down; soft vertical folds
		var z := -dir * (0.06 * (1.0 - v * 0.6)) * s * s
		z += dir * 0.012 * sin(u * PI * 5.0 + sd) * (0.3 + v)
		z += dir * 0.025 * v
		return Vector3(x * dir, -v * length, z), 12, 18)
	pivot.add_child(_piece(mesh, 0.25, 0.18, sd, length / w1))
	return pivot

func _hood() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		# open at the front: the face sits in the dark of the cowl, which closes at the throat
		var gap := 0.22 + 0.42 * smoothstep(0.12, 0.4, v) - 0.5 * smoothstep(0.72, 1.0, v)
		var a := lerpf(gap, TAU - gap, u)
		var dome := sqrt(clampf(1.0 - pow(1.0 - minf(v / 0.34, 1.0), 2.0), 0.0, 1.0))
		var r := dome * (1.0 + 0.45 * smoothstep(0.7, 1.0, v))
		r *= 1.0 + 0.03 * sin(a * 7.0) * v
		var cz := -0.045 - 0.06 * pow(1.0 - v, 3.0)
		return Vector3(sin(a) * 0.168 * r, 2.09 - v * 0.43, cz + cos(a) * 0.192 * r), 28, 16)

func _mantle() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var gap := 0.4
		var a := lerpf(gap, TAU - gap, u)
		var k := pow(v, 0.42)
		var rx := lerpf(0.135, 0.375, k)
		var rz := lerpf(0.135, 0.31, k)
		var fold := 1.0 + 0.07 * v * sin(a * 9.0)
		# the hem hangs lower at the back
		var hem := lerpf(1.43, 1.30, (1.0 - cos(a)) * 0.5)
		var y := lerpf(1.71, hem, v)
		return Vector3(sin(a) * rx * fold, y, -0.045 + cos(a) * rz * fold), 40, 14)

func _sash() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var bulge := 1.0 + 0.05 * sin(v * PI) + 0.02 * sin(a * 5.0 + v * 3.0)
		var tilt := 0.03 * sin(a)
		return Vector3(sin(a) * 0.258 * bulge, 1.245 - v * 0.15 + tilt, 0.005 + cos(a) * 0.222 * bulge), 36, 4)

## A cloth sheet from f(u, v) -> point, u across (nu cells), v from the seam to the hem.
func _grid(f: Callable, nu: int, nv: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			st.set_uv(Vector2(u, v))
			st.add_vertex(f.call(u, v))
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
	_swing_f = lerpf(_swing_f, minf(fwd * 1.1, 0.7), minf(delta * 14.0, 1.0))
	_swing_b = lerpf(_swing_b, minf(bwd * 1.1, 0.7), minf(delta * 14.0, 1.0))
	peak_swing = maxf(peak_swing, maxf(_swing_f, _swing_b))
	_front.rotation.x = -_swing_f
	_back.rotation.x = _swing_b
	# the hems trail the body's motion and swing past when it stops
	var p := _body.global_position
	var vel := (p - _last_pos) / delta
	_last_pos = p
	if vel.length() > 20.0:
		vel = Vector3.ZERO  # a teleport (return to post), not motion
	var local := _body.global_basis.inverse() * vel
	var target := Vector3(-local.x, 0.0, -local.z) * 0.035
	target.y = absf(local.z) * 0.006
	# a damped spring: a little overshoot when the body stops or turns
	_vel += ((target - _trail) * 55.0 - _vel * 7.0) * delta
	_trail = (_trail + _vel * delta).limit_length(0.12)
	set_param("sway", _trail)
