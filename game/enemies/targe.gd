class_name HollowTarge
extends MeshInstance3D
## A Hollow warden's targe, built in code: a round, slightly domed board of two layers of
## planks faced with hide, an iron boss with a short spike, a ring of iron studs and an iron
## rim band nailed round the edge. Origin at the boss centre on the board's back face; +Z out
## through the face, +Y "up" along the bearer's forearm. COLOR.r selects the layer in
## targe.gdshader (0 hide face, 0.5 iron, 1 bare wood back/edge); UV = local xy in metres.

const RADIUS := 0.29
const THICK := 0.024
const DOME := 0.035            # the face bulges this much at the centre
const RINGS := 14
const SEG := 48
const BOSS_R := 0.075
const HIDE := 0.0
const IRON := 0.5
const WOOD := 1.0

var _mat: ShaderMaterial

func _ready() -> void:
	mesh = build_mesh()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/targe.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func set_param(p: String, v: Variant) -> void:
	if _mat != null:
		_mat.set_shader_parameter(p, v)

## Face height above the back plane at radius r.
static func face_z(r: float) -> float:
	var f := clampf(r / RADIUS, 0.0, 1.0)
	return THICK + DOME * (1.0 - f * f)

static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the hide face: rings from the boss edge to the rim band
	var r0 := BOSS_R * 0.92
	var r1 := RADIUS - 0.018
	for i in RINGS:
		var ra := lerpf(r0, r1, float(i) / RINGS)
		var rb := lerpf(r0, r1, float(i + 1) / RINGS)
		_band(st, ra, face_z(ra), rb, face_z(rb), HIDE)
	# the iron rim band: over the face edge, round the side, a lip onto the back
	_band(st, r1, face_z(r1) + 0.002, RADIUS + 0.004, face_z(RADIUS) + 0.002, IRON)
	_band(st, RADIUS + 0.004, face_z(RADIUS) + 0.002, RADIUS + 0.004, -0.002, IRON)
	_band(st, RADIUS + 0.004, -0.002, RADIUS - 0.012, -0.002, IRON)
	# the bare plank back
	_band(st, RADIUS - 0.012, -0.0015, 0.0, -0.0015, WOOD)
	# the boss: a low dome with a short spike
	var bz := face_z(0.0) - 0.006
	var steps := 7
	for i in steps:
		var a0 := float(i) / steps * PI * 0.5
		var a1 := float(i + 1) / steps * PI * 0.5
		_band(st, BOSS_R * cos(a0), bz + BOSS_R * 0.62 * sin(a0),
				BOSS_R * cos(a1), bz + BOSS_R * 0.62 * sin(a1), IRON)
	var top := bz + BOSS_R * 0.62
	_band(st, 0.016, top - 0.002, 0.0, top + 0.05, IRON)
	# two rings of domed studs
	for ring in [[0.165, 10, 0.0], [0.238, 14, 0.5]]:
		var rr: float = ring[0]
		var n: int = ring[1]
		for k in n:
			var a: float = (float(k) + float(ring[2])) / n * TAU
			_stud(st, Vector3(cos(a) * rr, sin(a) * rr, face_z(rr)), 0.011)
	st.generate_normals()
	return st.commit()

## A ring band (a lathe strip) between radius ra at height za and rb at zb.
static func _band(st: SurfaceTool, ra: float, za: float, rb: float, zb: float, layer: float) -> void:
	var col := Color(layer, 0, 0)
	for s in SEG:
		var t0 := float(s) / SEG * TAU
		var t1 := float(s + 1) / SEG * TAU
		var p := [Vector3(cos(t0) * ra, sin(t0) * ra, za), Vector3(cos(t1) * ra, sin(t1) * ra, za),
				Vector3(cos(t1) * rb, sin(t1) * rb, zb), Vector3(cos(t0) * rb, sin(t0) * rb, zb)]
		for idx in [0, 2, 1, 0, 3, 2]:
			var v: Vector3 = p[idx]
			st.set_color(col)
			st.set_uv(Vector2(v.x, v.y))
			st.add_vertex(v)

static func _stud(st: SurfaceTool, c: Vector3, r: float) -> void:
	var col := Color(IRON, 0, 0)
	var n := 8
	for s in n:
		var t0 := float(s) / n * TAU
		var t1 := float(s + 1) / n * TAU
		for ring in 2:
			var e0 := float(ring) / 2.0 * PI * 0.5
			var e1 := float(ring + 1) / 2.0 * PI * 0.5
			var q := [
				c + Vector3(cos(t0) * cos(e0) * r, sin(t0) * cos(e0) * r, sin(e0) * r * 0.7),
				c + Vector3(cos(t1) * cos(e0) * r, sin(t1) * cos(e0) * r, sin(e0) * r * 0.7),
				c + Vector3(cos(t1) * cos(e1) * r, sin(t1) * cos(e1) * r, sin(e1) * r * 0.7),
				c + Vector3(cos(t0) * cos(e1) * r, sin(t0) * cos(e1) * r, sin(e1) * r * 0.7)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = q[idx]
				st.set_color(col)
				st.set_uv(Vector2(v.x, v.y))
				st.add_vertex(v)
