class_name HollowBow
extends Node3D
## A self bow of dark yew: a D-section stave ~1.5 m tip to tip, thick and leather-wrapped at
## the grip, tapering to horn nocks, the limbs bending a little more as the string is drawn.
## The string is a waxed hemp line from nock to nock through the nocking point (where the
## drawing hand holds it). An arrow (ash shaft, iron bodkin, grey goose fletching) can sit on
## the string. Local frame: the grip at the origin, the stave along +Y, the back of the bow
## (the side away from the archer) toward +Z, the string on the -Z side.

const HALF := 0.75               # m from the grip to each nock (braced)
const BRACE := 0.16              # m from the grip to the string at rest
const ARROW_LEN := 0.78
const SEGS := 16                 # rings per limb

var draw := 0.0                  # 0 braced .. 1 full draw (the nocking point at `nock_local`)
var nock_local := Vector3(0, 0, -BRACE)   # where the drawing hand holds the string (this frame)
var arrow_on := false            # an arrow sits on the string

var _stave: MeshInstance3D
var _string: MeshInstance3D
var _arrow: MeshInstance3D
var _string_mesh: ImmediateMesh
var _last_draw := -1.0

static var _arrow_mesh: ArrayMesh
static var _string_mat: StandardMaterial3D

func _ready() -> void:
	_stave = MeshInstance3D.new()
	_stave.name = "Stave"
	add_child(_stave)
	_string_mesh = ImmediateMesh.new()
	_string = MeshInstance3D.new()
	_string.name = "String"
	_string.mesh = _string_mesh
	if _string_mat == null:
		_string_mat = StandardMaterial3D.new()
		_string_mat.albedo_color = Color(0.55, 0.50, 0.40)
		_string_mat.roughness = 0.7
	_string.material_override = _string_mat
	add_child(_string)
	_arrow = MeshInstance3D.new()
	_arrow.name = "Arrow"
	_arrow.mesh = arrow_mesh()
	add_child(_arrow)
	_rebuild()

func _process(_d: float) -> void:
	_rebuild()

## The nock tips in this frame for the current draw (the limbs pull back as the bow bends).
func tip(sign_y: float) -> Vector3:
	var k := draw
	return Vector3(0, sign_y * (HALF - 0.05 * k), -0.10 * k)

func _rebuild() -> void:
	if absf(draw - _last_draw) > 0.01:
		_last_draw = draw
		_stave.mesh = _build_stave(draw)
	var top := tip(1.0)
	var bot := tip(-1.0)
	var n := nock_local if draw > 0.02 else Vector3(0, 0, -BRACE)
	_string_mesh.clear_surfaces()
	_string_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in [[top, n], [n, bot]]:
		_strand(seg[0], seg[1], 0.0022)
	_string_mesh.surface_end()
	_arrow.visible = arrow_on
	if arrow_on:
		# the nock on the string, the shaft resting on the bow hand over the grip
		var rest := Vector3(0.012, 0.02, 0.0)
		var dir := (rest - n).normalized()
		var x := Vector3.UP.cross(dir)
		if x.length() < 1e-3:
			x = Vector3.RIGHT
		x = x.normalized()
		_arrow.transform = Transform3D(Basis(x, dir, x.cross(dir).normalized()).orthonormalized(), n)

func _strand(a: Vector3, b: Vector3, r: float) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.UP).normalized() * r
	var v := d.cross(u).normalized() * r
	var ring := [u, v, -u, -v]
	for i in 4:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % 4]
		for q in [[a + p0, b + p0, b + p1], [a + p0, b + p1, a + p1]]:
			for w in q:
				_string_mesh.surface_set_normal(((w - a) - d * (w - a).dot(d)).normalized())
				_string_mesh.surface_add_vertex(w)

## The stave: a D section (flat back toward +Z, rounded belly toward the string), widest and
## thickest at the leather grip, the limbs tapering and bending back toward the string as `k`
## (draw) grows, a pale horn nock at each tip.
static func _build_stave(k: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var around := 10
	var rings: Array = []
	var cols: Array = []
	var n := SEGS * 2
	for r in n + 1:
		var s := lerpf(-1.0, 1.0, float(r) / n)          # -1 bottom nock .. +1 top nock
		var a := absf(s)
		var y := s * HALF * (1.0 - 0.067 * k * a * a)
		# the limbs bend back (toward -Z) with the square of the distance from the grip
		var z := -0.10 * k * a * a - 0.012 * (1.0 - a)
		var w := lerpf(0.017, 0.007, smoothstep(0.1, 1.0, a))   # half width
		var th := lerpf(0.016, 0.006, smoothstep(0.1, 1.0, a))  # half thickness
		if a < 0.1:
			w += 0.003
			th += 0.004
		var ring: Array = []
		for i in around:
			var ang := TAU * i / around
			var cx := cos(ang) * w
			# D section: flat-ish back (+Z), rounded belly (-Z)
			var cz := sin(ang) * th * (0.55 if sin(ang) > 0.0 else 1.0)
			ring.append(Vector3(cx, y, z + cz))
		rings.append(ring)
		var c := Color(0.30, 0.17, 0.09).lerp(Color(0.45, 0.30, 0.17), 0.5 + 0.5 * sin(s * 31.0))
		if a < 0.1:
			c = Color(0.16, 0.10, 0.06)                   # the dark leather grip wrap
		elif a > 0.95:
			c = Color(0.72, 0.66, 0.52)                   # horn nocks
		cols.append(c)
	for r in n:
		for i in around:
			var j := (i + 1) % around
			var q := [rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]]
			for t in [[0, 2, 1], [0, 3, 2]]:
				for idx in t:
					st.set_color(cols[r] if idx < 2 else cols[r + 1])
					st.add_vertex(q[idx])
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.45
	mat.metallic_specular = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()

## An arrow in its own frame: the nock at the origin, the shaft along +Y to the bodkin point
## at ARROW_LEN; fletching three grey vanes near the nock.
static func arrow_mesh() -> ArrayMesh:
	if _arrow_mesh != null:
		return _arrow_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var around := 6
	var r := 0.005   # a 10 mm war-arrow shaft (thin enough to read as a shaft, thick enough to hold a pixel at 15 m)
	var tip_y := ARROW_LEN
	var head_y := ARROW_LEN - 0.07
	# shaft
	for i in around:
		var a0 := TAU * i / around
		var a1 := TAU * (i + 1) / around
		var p := [Vector3(cos(a0) * r, 0.0, sin(a0) * r), Vector3(cos(a1) * r, 0.0, sin(a1) * r)]
		var q := [p[0] + Vector3(0, head_y, 0), p[1] + Vector3(0, head_y, 0)]
		for v in [p[0], q[1], q[0], p[0], p[1], q[1]]:
			# pale planed ash, a touch warmer toward the head (sRGB, see vertex_color_is_srgb)
			st.set_color(Color(0.78, 0.68, 0.50) if v.y < head_y * 0.5 else Color(0.72, 0.60, 0.42))
			st.add_vertex(v)
		# the iron bodkin: a socket and a four-sided point
		var s0 := [Vector3(cos(a0) * r * 1.5, head_y, sin(a0) * r * 1.5), Vector3(cos(a1) * r * 1.5, head_y, sin(a1) * r * 1.5)]
		for v in [s0[0], Vector3(0, tip_y, 0), s0[1]]:
			st.set_color(Color(0.30, 0.28, 0.26))
			st.add_vertex(v)
	# fletching: three vanes, ~0.12 m, a little in front of the nock
	for k in 3:
		var a := TAU * k / 3.0
		var o := Vector3(cos(a), 0, sin(a))
		var v0 := Vector3(0, 0.03, 0) + o * r
		var v1 := Vector3(0, 0.15, 0) + o * r
		var v2 := Vector3(0, 0.05, 0) + o * 0.016
		var v3 := Vector3(0, 0.12, 0) + o * 0.006
		for v in [v0, v1, v2, v2, v1, v3]:
			# two pale grey-goose hen feathers and a barred brown cock feather
			st.set_color(Color(0.86, 0.84, 0.79) if k > 0 else Color(0.42, 0.33, 0.24))
			st.add_vertex(v)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.55
	# a faint rim so the thin shaft keeps an edge against dark cloth / shade
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_arrow_mesh = st.commit()
	return _arrow_mesh
