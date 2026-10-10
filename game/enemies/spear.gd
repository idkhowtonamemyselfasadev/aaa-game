class_name HollowSpear
extends MeshInstance3D
## A Hollow soldier's spear, built in code: a grey, checked ash-wood shaft with an iron butt
## spike, two tarred cord bindings and a forged iron socket carrying a leaf-shaped blade with
## a diamond section. Origin at the shaft centre, +Y toward the blade. COLOR.r selects the
## layer in spear.gdshader (0 wood, 0.5 iron, 1 cord); UV = (around, metres along).

const LENGTH := 2.25             # butt to blade tip
const BLADE := 0.34
const SEG := 20
const WOOD := 0.0
const IRON := 0.5
const CORD := 1.0

func _ready() -> void:
	mesh = build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/spear.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func tip_local() -> Vector3:
	return Vector3(0, LENGTH * 0.5, 0)

## Lathe profile from the butt: [v (m), radius, material].
static func _profile() -> Array:
	var shaft_end := LENGTH - BLADE
	var p := [
		[0.000, 0.000, IRON], [0.000, 0.004, IRON], [0.060, 0.012, IRON], [0.120, 0.0175, IRON],
		[0.135, 0.0185, IRON], [0.140, 0.0172, IRON], [0.140, 0.0170, WOOD],
		[0.62, 0.0182, WOOD], [0.62, 0.0182, CORD], [0.62, 0.0196, CORD], [0.78, 0.0196, CORD],
		[0.78, 0.0182, CORD], [0.78, 0.0182, WOOD],
		[1.30, 0.0178, WOOD], [1.30, 0.0178, CORD], [1.30, 0.0192, CORD], [1.40, 0.0192, CORD],
		[1.40, 0.0176, CORD], [1.40, 0.0176, WOOD],
		[shaft_end - 0.17, 0.0170, WOOD], [shaft_end - 0.17, 0.0170, IRON],
		[shaft_end - 0.165, 0.0215, IRON], [shaft_end - 0.15, 0.0215, IRON],
		[shaft_end - 0.145, 0.0190, IRON], [shaft_end - 0.02, 0.0150, IRON],
		[shaft_end, 0.0105, IRON],
	]
	return p

static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof := _profile()
	var half := LENGTH * 0.5
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		if a[2] != b[2]:
			continue
		var dv: float = b[0] - a[0]
		var dr: float = b[1] - a[1]
		if absf(dv) < 1e-6 and absf(dr) < 1e-6:
			continue
		var col := Color(a[2], 0, 0)
		for s in SEG:
			var t0 := float(s) / SEG
			var t1 := float(s + 1) / SEG
			for q in [[t0, a], [t1, a], [t1, b], [t0, a], [t1, b], [t0, b]]:
				var t: float = q[0]
				var pr: Array = q[1]
				var ang := t * TAU
				var radial := Vector3(cos(ang), 0, sin(ang))
				st.set_normal((radial * dv - Vector3.UP * dr).normalized())
				st.set_color(col)
				st.set_uv(Vector2(t, pr[0]))
				st.add_vertex(radial * float(pr[1]) + Vector3.UP * (float(pr[0]) - half))
	_blade(st, LENGTH - BLADE - 0.004 - half)
	st.generate_tangents()
	return st.commit()

## Leaf blade: width swells from the socket to ~40% then tapers to the point; a diamond
## section (raised midrib, thin edges). Built as 4 facets per row.
static func _blade(st: SurfaceTool, y0: float) -> void:
	var rows := 18
	var col := Color(IRON, 0, 0)
	var prev: Array = []
	for r in rows + 1:
		var u := float(r) / rows
		var w := 0.012 + 0.036 * pow(sin(PI * pow(u, 0.62)), 0.9) * (1.0 - u * 0.15)
		if r == rows:
			w = 0.0
		var th := 0.0105 * (1.0 - u) + 0.0015
		var y := y0 + u * BLADE
		var ring := [Vector3(w, y, 0), Vector3(0, y, th), Vector3(-w, y, 0), Vector3(0, y, -th)]
		if r > 0:
			for k in 4:
				var a0: Vector3 = prev[k]
				var a1: Vector3 = prev[(k + 1) % 4]
				var b0: Vector3 = ring[k]
				var b1: Vector3 = ring[(k + 1) % 4]
				var n := (a1 - a0).cross(b0 - a0).normalized()
				if n.dot(Vector3(a0.x + a1.x, 0, a0.z + a1.z)) < 0.0:
					n = -n
				var la := u - 1.0 / rows
				_tri(st, n, col, [a0, b0, b1], [Vector2(k * 0.25, la), Vector2(k * 0.25, u), Vector2(k * 0.25 + 0.25, u)])
				_tri(st, n, col, [a0, b1, a1], [Vector2(k * 0.25, la), Vector2(k * 0.25 + 0.25, u), Vector2(k * 0.25 + 0.25, la)])
		prev = ring

## Godot treats clockwise as front: the right-hand normal of an emitted triangle must point
## away from the visible side, so flip the order when it points along n.
static func _tri(st: SurfaceTool, n: Vector3, col: Color, v: Array, uv: Array) -> void:
	var order := [0, 1, 2]
	if ((v[1] as Vector3) - v[0]).cross((v[2] as Vector3) - v[0]).dot(n) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_normal(n)
		st.set_color(col)
		var w: Vector2 = uv[i]
		st.set_uv(Vector2(w.x, LENGTH - BLADE + w.y * BLADE))
		st.add_vertex(v[i])
