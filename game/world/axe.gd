class_name Axe
extends Node3D
## A felling axe: an ash helve with a knob swell, a slight S curve and a hand-dark grip, and a
## forged iron head (poll, eye, flared cheeks to a bright ground edge, a short beard). Local
## frame: the grip (the knob end) at the origin, the helve up +Y, the head at HEAD_Y with its
## bit edge toward +Z.

const LEN := 0.74
const HEAD_Y := 0.70             # the head's middle on the helve
const EDGE_Z := 0.17             # the bit edge's reach in front of the helve

static var _helve_mesh: ArrayMesh
static var _head_mesh: ArrayMesh

func _ready() -> void:
	if _helve_mesh == null:
		_helve_mesh = _build_helve()
		_head_mesh = _build_head()
	for m in [_helve_mesh, _head_mesh]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		add_child(mi)

## The bit edge's middle in this node's frame.
static func edge_point() -> Vector3:
	return Vector3(0, HEAD_Y - 0.01, EDGE_Z)

static func _build_helve() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 18
	var segs := 10
	var y0 := -0.04
	var pts: Array = []
	for r in rings + 1:
		var u := float(r) / rings
		var y := lerpf(y0, LEN + 0.015, u)
		# knob swell at the end, a waist for the hands, thickening up to the eye
		var s := 1.0 + 0.38 * exp(-pow((y + 0.015) / 0.03, 2.0)) - 0.1 * exp(-pow((y - 0.3) / 0.18, 2.0)) + 0.12 * smoothstep(0.45, 0.66, y)
		var bend := 0.012 * sin(PI * clampf(y / 0.66, 0.0, 1.0)) - 0.006 * sin(TAU * clampf(y / 0.66, 0.0, 1.0))
		var ring: Array = []
		for i in segs:
			var a := TAU * i / segs
			ring.append([Vector3(cos(a) * 0.0135 * s, y, bend + sin(a) * 0.0185 * s), Vector3(cos(a) / 0.0135, 0, sin(a) / 0.0185).normalized()])
		pts.append(ring)
	for r in rings:
		var y := lerpf(y0, LEN, float(r) / rings)
		# hand-dark at the knob and the grip, pale worn ash elsewhere
		var grime := maxf(1.0 - smoothstep(0.0, 0.14, y), 0.6 * exp(-pow((y - 0.42) / 0.07, 2.0)))
		var c := Color(0.50, 0.37, 0.23).lerp(Color(0.22, 0.15, 0.09), grime)
		for i in segs:
			var j := (i + 1) % segs
			var quad := [pts[r][i], pts[r][j], pts[r + 1][j], pts[r + 1][i]]
			for t in [[0, 2, 1], [0, 3, 2]]:
				for k in t:
					st.set_color(c)
					st.set_normal(quad[k][1])
					st.add_vertex(quad[k][0])
	# the end grain at the knob
	for i in segs:
		var j := (i + 1) % segs
		for v in [Vector3(0, y0, 0.0), pts[0][i][0], pts[0][j][0]]:
			st.set_color(Color(0.3, 0.22, 0.14))
			st.set_normal(Vector3.DOWN)
			st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	mat.metallic_specular = 0.4
	st.set_material(mat)
	return st.commit()

static func _build_head() -> ArrayMesh:
	# side profile (z forward, y up): poll, eye, cheeks flaring to the bit, a short beard
	var prof := PackedVector2Array([
		Vector2(-0.038, 0.745), Vector2(0.03, 0.748), Vector2(0.075, 0.755), Vector2(0.125, 0.772),
		Vector2(0.158, 0.79), Vector2(0.168, 0.75), Vector2(0.172, 0.70), Vector2(0.166, 0.65),
		Vector2(0.15, 0.60), Vector2(0.115, 0.618), Vector2(0.075, 0.642), Vector2(0.03, 0.652),
		Vector2(-0.038, 0.655)])
	var half := func(z: float) -> float:
		if z < 0.03:
			return 0.024 - 0.004 * smoothstep(-0.01, -0.038, z)
		return lerpf(0.024, 0.0025, pow(clampf((z - 0.03) / 0.142, 0.0, 1.0), 0.8))
	var col := func(z: float, y: float) -> Color:
		var edge := smoothstep(0.142, 0.16, z)
		var poll := smoothstep(-0.02, -0.038, z) * 0.6
		var c := Color(0.13, 0.12, 0.115).lerp(Color(0.2, 0.17, 0.14), 0.5 + 0.5 * sin(y * 210.0 + z * 90.0))
		return c.lerp(Color(0.58, 0.58, 0.57), edge).lerp(Color(0.32, 0.31, 0.3), poll)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var tris := Geometry2D.triangulate_polygon(prof)
	for side in [1.0, -1.0]:
		for i in range(0, tris.size(), 3):
			var idx := [tris[i], tris[i + 1], tris[i + 2]]
			if side < 0.0:
				idx = [idx[0], idx[2], idx[1]]
			var vs: Array[Vector3] = []
			for k in idx:
				var p := prof[k]
				vs.append(Vector3(side * half.call(p.x), p.y, p.x))
			var n := (vs[1] - vs[0]).cross(vs[2] - vs[0])
			if n.x * side < 0.0:
				vs = [vs[0], vs[2], vs[1]]
			for v in vs:
				st.set_color(col.call(v.z, v.y))
				st.add_vertex(v)
	# the rim round the profile, joining the two cheeks
	var c2 := Vector2.ZERO
	for p in prof:
		c2 += p
	c2 /= prof.size()
	for i in prof.size():
		var p := prof[i]
		var q := prof[(i + 1) % prof.size()]
		var hp: float = half.call(p.x)
		var hq: float = half.call(q.x)
		var quad := [Vector3(hp, p.y, p.x), Vector3(hq, q.y, q.x), Vector3(-hq, q.y, q.x), Vector3(-hp, p.y, p.x)]
		var out := Vector3(0, (p + q).y * 0.5 - c2.y, (p + q).x * 0.5 - c2.x)
		for t in [[0, 1, 2], [0, 2, 3]]:
			var vs := [quad[t[0]], quad[t[1]], quad[t[2]]]
			if ((vs[1] - vs[0]) as Vector3).cross(vs[2] - vs[0]).dot(out) < 0.0:
				vs = [vs[0], vs[2], vs[1]]
			for v in vs:
				st.set_color(col.call(v.z, v.y))
				st.add_vertex(v)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.85
	mat.roughness = 0.48
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()
