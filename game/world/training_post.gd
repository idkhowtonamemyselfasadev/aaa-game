class_name TrainingPost
extends StaticBody3D
## A weathered oak practice post set in the ground, its middle bound in a thick straw bundle
## lashed with three rope rings and an iron band under the chamfered top. Built in code as a
## lathe with per-vertex irregularity; training_post.gdshader adds the surface detail
## (COLOR.r: 0 oak, 0.33 iron, 0.66 straw, 1 rope). Staff hits rock it in its socket.

const HEIGHT := 1.72          # above ground
const BURY := 0.25
const POST_R := 0.105
const STRAW_R := 0.185
const STRAW_LO := 0.62
const STRAW_HI := 1.40
const SEG := 36
const OAK := 0.0
const IRON := 0.33
const STRAW := 0.66
const ROPE := 1.0

var impact_kind := "straw"
var hits := 0
var _mesh: MeshInstance3D
var _tilt := Vector2.ZERO      # rotation about world X and Z (rad)
var _tilt_v := Vector2.ZERO
var _freeze := 0.0

func _ready() -> void:
	add_to_group("hittable")
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/training_post.gdshader")
	_mesh.material_override = mat
	add_child(_mesh)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = STRAW_R
	cyl.height = HEIGHT
	col.shape = cyl
	col.position.y = HEIGHT * 0.5
	add_child(col)

## Snap the base onto the terrain.
func plant(terrain: Terrain) -> void:
	var p := global_position
	global_position = Vector3(p.x, terrain.height_at(p.x, p.z) - 0.02, p.z)

## World-space capsule the staff tests against: [bottom, top, radius].
func hurt_capsule() -> Array:
	return [global_position + Vector3.UP * 0.25, global_position + Vector3.UP * (HEIGHT - 0.05), STRAW_R]

func take_hit(_point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	hits += 1
	_freeze = hitstop
	var d := Vector3(dir.x, 0, dir.z).normalized()
	# a push along d tips the top along d: rotation about (up x d)
	var axis := Vector3.UP.cross(d)
	_tilt_v += Vector2(axis.x, axis.z) * 0.55 * power

func _physics_process(delta: float) -> void:
	if _freeze > 0.0:
		_freeze -= delta
		return
	# stiff damped spring: the post is tamped into loose earth and rocks back upright
	_tilt_v += (-_tilt * 260.0 - _tilt_v * 9.0) * delta
	_tilt += _tilt_v * delta
	_tilt = _tilt.limit_length(0.09)
	_mesh.rotation = Vector3(_tilt.x, 0, _tilt.y)

func tilt() -> float:
	return _tilt.length()

# --- mesh ---

static func _n(a: float, b: float) -> float:
	return sin(a * 12.9898 + b * 78.233) * 0.5 + sin(a * 3.1 + b * 7.7 + 1.3) * 0.3 + sin(a * 0.7 - b * 2.3) * 0.2

## Rows from the buried foot to the top: [height, radius, material, roughness of the outline].
static func _rows() -> Array:
	var r: Array = []
	r.append([-BURY, POST_R * 1.04, OAK, 0.012])
	r.append([STRAW_LO - 0.01, POST_R, OAK, 0.012])
	r.append([STRAW_LO - 0.01, POST_R, STRAW, 0.0])
	# straw: tucked in at each rope, bulging between them, loose fibres at the ends
	var ropes := [STRAW_LO + 0.07, (STRAW_LO + STRAW_HI) * 0.5, STRAW_HI - 0.07]
	var n := 40
	for i in n + 1:
		var h := lerpf(STRAW_LO, STRAW_HI, float(i) / n)
		var pinch := 1.0
		for rp in ropes:
			pinch = minf(pinch, clampf(absf(h - rp) / 0.11, 0.0, 1.0))
		var ends := minf(clampf((h - STRAW_LO) / 0.06, 0.0, 1.0), clampf((STRAW_HI - h) / 0.06, 0.0, 1.0))
		var rad := lerpf(POST_R + 0.01, STRAW_R * (0.9 + 0.1 * sin(pinch * PI * 0.5)), sqrt(ends))
		rad = lerpf(STRAW_R * 0.86, rad, 0.35 + 0.65 * pinch) if ends > 0.5 else rad
		r.append([h, rad, STRAW, 0.016])
	r.append([STRAW_HI + 0.01, POST_R, STRAW, 0.0])
	r.append([STRAW_HI + 0.01, POST_R, OAK, 0.012])
	r.append([HEIGHT - 0.16, POST_R, OAK, 0.012])
	r.append([HEIGHT - 0.16, POST_R, IRON, 0.0])
	r.append([HEIGHT - 0.155, POST_R + 0.008, IRON, 0.002])
	r.append([HEIGHT - 0.105, POST_R + 0.008, IRON, 0.002])
	r.append([HEIGHT - 0.10, POST_R, IRON, 0.0])
	r.append([HEIGHT - 0.10, POST_R, OAK, 0.012])
	r.append([HEIGHT - 0.03, POST_R * 0.98, OAK, 0.012])
	r.append([HEIGHT, POST_R * 0.72, OAK, 0.006])
	r.append([HEIGHT + 0.005, 0.0, OAK, 0.0])
	return r

static func build_mesh() -> ArrayMesh:
	var rows := _rows()
	var am := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ropes := [STRAW_LO + 0.07, (STRAW_LO + STRAW_HI) * 0.5, STRAW_HI - 0.07]
	var base := 0
	# group consecutive rows of one material into a band grid
	var i := 0
	while i < rows.size() - 1:
		var j := i
		while j + 1 < rows.size() and rows[j + 1][2] == rows[i][2]:
			j += 1
		if j > i:
			base = _band(st, rows.slice(i, j + 1), base)
		i = j + 1
	# rope rings: small tori over the straw pinches
	for rp in ropes:
		base = _torus(st, rp, STRAW_R * 0.9, 0.018, base)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _band(st: SurfaceTool, rows: Array, base: int) -> int:
	var mat: float = rows[0][2]
	for row in rows:
		for s in SEG + 1:
			var t := float(s) / SEG
			var ang := t * TAU
			var h: float = row[0]
			var rough: float = row[3]
			# seam-safe angular noise (periodic in ang)
			var wob := _n(cos(ang) * 2.0 + h * 3.0, sin(ang) * 2.0 - h * 5.0)
			if mat == STRAW:
				wob += 0.6 * _n(cos(ang) * 9.0 + h * 21.0, sin(ang) * 9.0)
			var rad: float = row[1] + rough * wob
			if mat == OAK:
				# the post leans and bows a little; old timber is never straight
				rad += 0.006 * sin(ang * 2.0 + h * 1.7)
			st.set_color(Color(mat, 0, 0))
			st.set_uv(Vector2(t, h))
			st.add_vertex(Vector3(cos(ang) * rad, h, sin(ang) * rad))
	for r in rows.size() - 1:
		for s in SEG:
			var a := base + r * (SEG + 1) + s
			var b := a + SEG + 1
			st.add_index(a); st.add_index(a + 1); st.add_index(b)
			st.add_index(a + 1); st.add_index(b + 1); st.add_index(b)
	return base + rows.size() * (SEG + 1)

static func _torus(st: SurfaceTool, h: float, R: float, r: float, base: int) -> int:
	var ring := 8
	for s in SEG + 1:
		var ang := float(s) / SEG * TAU
		var c := Vector3(cos(ang), 0, sin(ang))
		for k in ring + 1:
			var phi := float(k) / ring * TAU
			var p := c * (R + r * cos(phi)) + Vector3.UP * (h + r * sin(phi))
			st.set_color(Color(ROPE, 0, 0))
			st.set_uv(Vector2(float(s) / SEG, float(k) / ring))
			st.add_vertex(p)
	for s in SEG:
		for k in ring:
			var a := base + s * (ring + 1) + k
			var b := a + ring + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	return base + (SEG + 1) * (ring + 1)
