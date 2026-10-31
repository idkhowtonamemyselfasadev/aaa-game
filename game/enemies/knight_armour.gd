class_name KnightArmour
extends Node
## The Ashen Knight's armour, built in code and hung on its skeleton so it rides every animation:
## a closed great helm with a forged keel, a sight slit and a flared neck guard; a gorget; and
## a pair of layered pauldrons (a domed cap over two overlapping lames, riveted to an oiled
## leather strap) on the collarbones. Every piece is built in body space (metres, +Z forward,
## +X the knight's left) around the bones' rest positions, so it fits whatever scale the body
## has. Plate is fire-blackened steel worn bright on its ridges (armour.gdshader); hairline
## cracks glow with the ember as the knight's phase rises (`set_ember`).
## A heavier glaive blade is fitted over the soldier's leaf blade (`fit_glaive`).

const STEEL := 0.0
const LEATHER := 0.5
const RIVET := 1.0

var mats: Array[ShaderMaterial] = []
var pieces := 0          # meshes hung (bots)
var _skel: Skeleton3D
var _body: Node3D
var _mat: ShaderMaterial

func build(skel: Skeleton3D, body: Node3D) -> void:
	_skel = skel
	_body = body
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/armour.gdshader")
	mats.append(_mat)
	var head := _bone_pos("mixamorig_Head")
	var neck := _bone_pos("mixamorig_Neck")
	var top := _bone_pos("mixamorig_HeadTop_End")
	if top == Vector3.ZERO:
		top = head + Vector3(0, 0.28, 0)   # the Vanguard rig has no head-top bone
	_hang("mixamorig_Head", _helm(head, top))
	_hang("mixamorig_Spine2", _gorget(neck))
	for side in ["Left", "Right"]:
		var sx := 1.0 if side == "Left" else -1.0
		var arm := _bone_pos("mixamorig_%sArm" % side)
		_hang("mixamorig_%sShoulder" % side, _pauldron(arm, sx))

func set_ember(v: float) -> void:
	_mat.set_shader_parameter("ember", v)

## A long, broad glaive head over the spear's leaf blade: a single curved edge sweeping out to
## the knight's off side, a thick spine along the shaft line and a back spike. Spear space:
## +Y toward the tip, origin at the shaft centre.
func fit_glaive(spear: Node3D, shaft_end: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := shaft_end - 0.06
	var n := 18
	var length := 0.66
	# outline: spine at x = 0 (+ a hair off the shaft), the edge bellying out then hooking to the tip
	var spine: Array[Vector3] = []
	var edge: Array[Vector3] = []
	for i in n + 1:
		var f := float(i) / n
		var y := y0 + f * length
		var belly := 0.15 * sin(pow(f, 0.8) * PI) * (1.0 - 0.25 * f) + 0.03 * (1.0 - f)
		var lean := -0.05 * f * f          # the spine curves back toward the tip
		spine.append(Vector3(lean, y, 0))
		edge.append(Vector3(lean + belly, y + 0.03 * f, 0))
	# the blade: a lens section, thick at the spine, a fine edge
	var th := 0.022
	for i in n:
		for s in [-1.0, 1.0]:
			var a := spine[i]
			var b := spine[i + 1]
			var c := edge[i]
			var d := edge[i + 1]
			var m0 := a.lerp(c, 0.35) + Vector3(0, 0, th * s * (1.0 - float(i) / n * 0.6))
			var m1 := b.lerp(d, 0.35) + Vector3(0, 0, th * s * (1.0 - float(i + 1) / n * 0.6))
			_quad(st, a + Vector3(0, 0, th * 0.6 * s), b + Vector3(0, 0, th * 0.6 * s), m1, m0, 0.3)
			_quad(st, m0, m1, d, c, 1.0)
	# a back spike off the spine at the socket
	var sp := [Vector3(0, y0 + 0.08, 0), Vector3(0, y0 + 0.16, 0), Vector3(-0.13, y0 + 0.06, 0)]
	for s in [-1.0, 1.0]:
		var o := Vector3(0, 0, 0.01 * s)
		_tri(st, sp[0] + o, sp[1] + o, sp[2], 0.8)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Glaive"
	mi.mesh = st.commit()
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	spear.add_child(mi)
	pieces += 1
	return mi

func _bone_pos(bone: String) -> Vector3:
	var i := _skel.find_bone(bone)
	if i < 0:
		return Vector3.ZERO
	return (_body.global_transform.affine_inverse() * _skel.global_transform
			* _skel.get_bone_global_rest(i)).origin

func _hang(bone: String, mesh: ArrayMesh) -> void:
	var i := _skel.find_bone(bone)
	if i < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	att.name = "Armour" + bone.trim_prefix("mixamorig_")
	_skel.add_child(att)
	var off := Node3D.new()
	off.transform = (_body.global_transform.affine_inverse() * _skel.global_transform
			* _skel.get_bone_global_rest(i)).affine_inverse()
	att.add_child(off)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.layers = 2          # the knight's own ember light skips its body
	off.add_child(mi)
	pieces += 1

## Closed great helm round the skull: an egg dome, near-vertical cheeks drawn in under the jaw,
## a forged keel down the face, a sight slit across the eyes and a neck guard flared at the back.
func _helm(head: Vector3, top: Vector3) -> ArrayMesh:
	var h := maxf(top.y - head.y, 0.14)
	var c := Vector3(head.x, head.y, head.z + 0.03)
	var rx := h * 0.56
	var rz := h * 0.64
	var y_top := top.y + h * 0.10
	var y_bot := head.y - h * 0.72
	var slit_v := 0.40
	return _grid(func(u: float, v: float) -> Array:
		var a := u * TAU                        # 0 = straight ahead
		var front := cos(a)
		var y := lerpf(y_top, y_bot, v)
		# the dome rounds over the crown, then the sides fall nearly straight
		# a flat crown: the top plate rises almost square into the walls
		var dome := pow(clampf(minf(v / 0.16, 1.0), 0.0, 1.0), 0.28) * (1.0 - 0.06 * smoothstep(0.16, 0.0, v - 0.1))
		var jaw := 1.0 - 0.10 * smoothstep(0.6, 0.85, v) * maxf(front, 0.0)
		# the brim: the lower rim flares out all round, most at the back over the nape
		var flare := 1.0 + 0.38 * smoothstep(0.80, 1.0, v) * (0.55 + 0.45 * maxf(-front, 0.0))
		var r := dome * jaw * flare
		# the keel: a sharp ridge down the face from brow to chin
		var keel := exp(-pow(sin(a) / 0.09, 2.0)) * maxf(front, 0.0) * smoothstep(0.1, 0.35, v)
		r += keel * 0.10
		# the sight slit: a deep groove round the front at eye height, cut either side of the keel
		var slit := smoothstep(0.016, 0.0, absf(v - slit_v)) * smoothstep(0.35, 0.7, front) \
				* smoothstep(0.08, 0.2, absf(sin(a)))
		r *= 1.0 - slit * 0.13
		var p := Vector3(c.x + sin(a) * rx * r, y, c.z + front * rz * r - 0.02 * (1.0 - front) * v)
		var e := maxf(keel * 1.2, smoothstep(0.93, 1.0, v))
		e = maxf(e, smoothstep(0.03, 0.012, absf(v - slit_v - 0.03)) * smoothstep(0.35, 0.7, front))
		return [p, STEEL, e], 40, 22)

## A gorget: a two-lame steel collar round the neck base.
func _gorget(neck: Vector3) -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Array:
		var a := u * TAU
		var y := neck.y + 0.03 - v * 0.12
		var step := 0.012 if v > 0.5 else 0.0
		var r := lerpf(0.085, 0.17, pow(v, 1.4)) + step
		var p := Vector3(neck.x + sin(a) * r * 1.05, y, neck.z - 0.01 + cos(a) * r * 0.95)
		var e := smoothstep(0.9, 1.0, v) + smoothstep(0.1, 0.0, v) + smoothstep(0.06, 0.0, absf(v - 0.5))
		return [p, STEEL, minf(e, 1.0)], 30, 6)

## One pauldron over the shoulder joint: a cap and two lames, each a band of a sphere whose pole
## leans out over the arm, the lower ones a touch wider so each overlaps the next; a strap of
## leather across the top and a rivet row at each lame's rolled edge.
func _pauldron(arm: Vector3, sx: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := arm + Vector3(sx * 0.025, -0.01, -0.01)   # down off the collar, out over the arm
	var pole := Vector3(sx * 0.55, 1.0, 0.0).normalized()
	var out := Vector3(sx * 1.0, -0.55, 0.0).normalized()
	var fwd := Vector3(0, 0, 1)
	var bands := [[0.0, 0.78, 0.165], [0.66, 1.08, 0.174], [0.98, 1.38, 0.184]]
	for b in bands:
		var t0: float = b[0]
		var t1: float = b[1]
		var rad: float = b[2]
		var nu := 26
		var nv := 6
		var verts := []
		for j in nv + 1:
			for i in nu + 1:
				var v := float(j) / nv
				var p_ang := lerpf(-1.95, 1.95, float(i) / nu)
				var t := lerpf(t0, t1, v)
				var dir := pole * cos(t) + (out * cos(p_ang) + fwd * sin(p_ang)) * sin(t)
				# a rolled lip at each band's lower edge
				var lip := 1.0 + 0.06 * smoothstep(0.82, 1.0, v)
				var flute := 1.0 + 0.025 * sin(p_ang * 5.0) * v
				var pos := c + dir * rad * lip * flute
				var e := maxf(smoothstep(0.8, 1.0, v), smoothstep(1.7, 1.95, absf(p_ang)))
				verts.append([pos, e])
		for j in nv:
			for i in nu:
				var a := j * (nu + 1) + i
				var q := [verts[a], verts[a + 1], verts[a + nu + 2], verts[a + nu + 1]]
				_quad(st, q[0][0], q[1][0], q[2][0], q[3][0], (q[0][1] + q[2][1]) * 0.5)
		# rivets along the lip
		for k in 7:
			var p_ang := lerpf(-1.5, 1.5, (k + 0.5) / 7.0)
			var t := lerpf(t0, t1, 0.9)
			var dir := pole * cos(t) + (out * cos(p_ang) + fwd * sin(p_ang)) * sin(t)
			_stud(st, c + dir * rad * 1.065, dir, 0.0085)
	# leather strap over the cap, front to back across the pole
	for k in 10:
		var f0 := lerpf(-1.1, 1.1, k / 10.0)
		var f1 := lerpf(-1.1, 1.1, (k + 1) / 10.0)
		var pts := []
		for f in [f0, f1]:
			var dir := (pole * cos(f) + fwd * sin(f)).normalized()
			pts.append(c + dir * 0.172)
		var w := out * 0.022
		_quad(st, pts[0] - w, pts[1] - w, pts[1] + w, pts[0] + w, 0.0, LEATHER)
	st.generate_normals()
	return st.commit()

func _stud(st: SurfaceTool, p: Vector3, n: Vector3, r: float) -> void:
	var t := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := n.cross(t)
	var tip := p + n * r * 0.8
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		_tri(st, p + (t * cos(a0) + b * sin(a0)) * r, p + (t * cos(a1) + b * sin(a1)) * r, tip, 0.6, RIVET)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, e: float, layer := STEEL) -> void:
	_tri(st, a, b, c, e, layer)
	_tri(st, a, c, d, e, layer)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, e: float, layer := STEEL) -> void:
	for p in [a, b, c]:
		st.set_color(Color(layer, e, 0))
		st.add_vertex(p)

## Grid mesh from f(u, v) -> [position, layer, edge].
func _grid(f: Callable, nu: int, nv: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var r: Array = f.call(float(i) / nu, float(j) / nv)
			st.set_color(Color(r[1], r[2], 0))
			st.set_uv(Vector2(float(i) / nu, float(j) / nv))
			st.add_vertex(r[0])
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + nu + 1)
			st.add_index(a + 1); st.add_index(a + nu + 2); st.add_index(a + nu + 1)
	st.generate_normals()
	return st.commit()
