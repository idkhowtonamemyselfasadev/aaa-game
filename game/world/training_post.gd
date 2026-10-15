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

const ROPES := [STRAW_LO + 0.07, (STRAW_LO + STRAW_HI) * 0.5, STRAW_HI - 0.07]

## Outer radius of the straw bundle at height h: pinched in at each rope, bulging between.
static func straw_r(h: float) -> float:
	var pinch := 1.0
	for rp in ROPES:
		pinch = minf(pinch, clampf(absf(h - rp) / 0.11, 0.0, 1.0))
	var ends := minf(clampf((h - STRAW_LO) / 0.06, 0.0, 1.0), clampf((STRAW_HI - h) / 0.06, 0.0, 1.0))
	var rad := lerpf(POST_R + 0.01, STRAW_R * (0.9 + 0.1 * sin(pinch * PI * 0.5)), sqrt(ends))
	return lerpf(STRAW_R * 0.86, rad, 0.35 + 0.65 * pinch) if ends > 0.5 else rad

## Rows from the buried foot to the top: [height, radius, material, roughness of the outline].
static func _rows() -> Array:
	var r: Array = []
	r.append([-BURY, POST_R * 1.04, OAK, 0.012])
	r.append([STRAW_LO - 0.01, POST_R, OAK, 0.012])
	r.append([STRAW_LO - 0.01, POST_R, STRAW, 0.0])
	# straw core: the dark packed heart of the bundle under the loose stalks (build_stalks)
	var n := 40
	for i in n + 1:
		var h := lerpf(STRAW_LO, STRAW_HI, float(i) / n)
		r.append([h, straw_r(h) * 0.9, STRAW, 0.008])
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
	# rope lashings: sagging rings bitten into the straw, each tied off in a knot with two
	# frayed tails hanging from it
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for k in ROPES.size():
		base = _lashing(st, ROPES[k], rng, base)
	st.generate_normals()
	st.generate_tangents()
	st.commit(am)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_stalks().commit_to_arrays())
	return am

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

## One rope lashing round the bundle at height h: a ring that wanders up and down (it was
## pulled tight by hand) and bites into the stalks, a knot, and two tails hanging from it.
static func _lashing(st: SurfaceTool, h: float, rng: RandomNumberGenerator, base: int) -> int:
	var r := 0.017
	var ph := rng.randf() * TAU
	var tilt := rng.randf_range(0.008, 0.016)
	var knot_a := rng.randf() * TAU
	var pts: Array = []
	for s in SEG * 2 + 1:
		var ang := float(s) / (SEG * 2) * TAU
		var y := h + tilt * sin(ang + ph) + 0.003 * sin(ang * 5.0 + ph * 2.0)
		var rad := straw_r(y) * 0.92 + r * 0.55
		pts.append(Vector3(cos(ang) * rad, y, sin(ang) * rad))
	base = _tube(st, pts, r, base, true)
	# knot: a fat lump of rope where the ends were tied
	var ky := h + tilt * sin(knot_a + ph)
	var kd := Vector3(cos(knot_a), 0, sin(knot_a))
	var kc := kd * (straw_r(ky) * 0.92 + r * 1.3) + Vector3.UP * ky
	var kt := Vector3.UP.cross(kd)
	var knot: Array = []
	for s in 13:
		var t := float(s) / 12.0 * TAU * 1.5
		knot.append(kc + kt * cos(t) * 0.022 + Vector3.UP * sin(t) * 0.02 + kd * (0.008 * sin(t * 0.5) + 0.004))
	base = _tube(st, knot, r * 1.05, base, false)
	# two tails: out of the knot, over the bulge below, hanging slack
	for tail in 2:
		var side := -1.0 if tail == 0 else 1.0
		var length := rng.randf_range(0.09, 0.17)
		var a0 := knot_a + side * 0.12
		var p := kc + kt * side * 0.01
		var tp: Array = [p]
		var nseg := 10
		for s in nseg:
			var u := float(s + 1) / nseg
			var y := p.y - length * u
			var a := a0 + side * 0.25 * u
			var rr := straw_r(clampf(y, STRAW_LO, STRAW_HI)) * 0.95 + r * (1.4 + 1.2 * u)
			tp.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		base = _tube(st, tp, r * 0.85, base, false, true)
	return base

## A rope tube along pts (8 sides). UV.x runs along it in rope-ring units, so the ply twist
## in the shader keeps its pitch; frayed ends taper and open into loose fibres in the shader.
static func _tube(st: SurfaceTool, pts: Array, r: float, base: int, closed: bool, taper := false) -> int:
	var ring := 8
	var n := pts.size()
	var along := 0.0
	var prev_side := Vector3.ZERO
	for s in n:
		var p: Vector3 = pts[s]
		var fwd: Vector3 = ((pts[mini(s + 1, n - 1)] as Vector3) - (pts[maxi(s - 1, 0)] as Vector3)).normalized()
		if s > 0:
			along += p.distance_to(pts[s - 1])
		var side := prev_side if s > 0 else (Vector3.UP if absf(fwd.y) < 0.9 else Vector3.RIGHT).cross(fwd).normalized()
		side = (side - fwd * side.dot(fwd)).normalized()
		prev_side = side
		var up := fwd.cross(side)
		var rr := r * (lerpf(1.0, 0.55, smoothstep(0.6, 1.0, float(s) / (n - 1))) if taper else 1.0)
		for k in ring + 1:
			var phi := float(k) / ring * TAU
			st.set_color(Color(ROPE, 0, 0))
			st.set_uv(Vector2(along / (TAU * STRAW_R * 0.9), float(k) / ring))
			st.add_vertex(p + (side * cos(phi) + up * sin(phi)) * rr)
	for s in n - 1:
		for k in ring:
			var a := base + s * (ring + 1) + k
			var b := a + ring + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	return base + n * (ring + 1)

## The straw itself: ~420 flat stalks laid lengthwise over the core in two layers, following
## the bundle's pinches and bulges with a slight spiral, their cut ends splaying out like a
## broom above and below the lashings, plus broken stalks sticking out of the sides.
## COLOR: r STRAW, g 1 (a stalk), b per-stalk tone, a depth (0 inner layer .. 1 outer).
## UV.x across the stalk (0..1), UV.y metres along it; UV2.x 0..1 along the stalk.
static func build_stalks() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2031
	var base := 0
	for layer in 2:
		var count := 190 if layer == 0 else 230
		for k in count:
			var a0 := (float(k) + rng.randf() * 0.8) / count * TAU
			var h0 := STRAW_LO - rng.randf_range(0.0, 0.07)
			var h1 := STRAW_HI + rng.randf_range(-0.01, 0.08)
			if rng.randf() < 0.25:
				# shorter stalks that end inside the bundle, so the surface isn't one combing
				if rng.randf() < 0.5:
					h0 = rng.randf_range(STRAW_LO + 0.1, STRAW_HI - 0.3)
				else:
					h1 = rng.randf_range(STRAW_LO + 0.3, STRAW_HI - 0.1)
			var off := -0.008 + rng.randf() * 0.004 if layer == 0 else rng.randf() * 0.006
			var info := {
				"a0": a0, "twist": rng.randf_range(-0.18, 0.18), "h0": h0, "h1": h1, "off": off,
				"w": rng.randf_range(0.0035, 0.0065), "splay": rng.randf_range(0.4, 1.6),
				"bulge": rng.randf_range(-0.004, 0.008), "tone": rng.randf(), "depth": 0.25 + 0.75 * layer,
				"wig": rng.randf() * TAU,
			}
			base = _stalk(st, info, base)
	# broken stalks poking out of the sides, tipped up or down
	for k in 70:
		var a := rng.randf() * TAU
		var h := rng.randf_range(STRAW_LO + 0.05, STRAW_HI - 0.05)
		var d := Vector3(cos(a), 0, sin(a))
		var p0 := d * (straw_r(h) - 0.005) + Vector3.UP * h
		var dir := (d * rng.randf_range(0.4, 1.0) + Vector3.UP * rng.randf_range(-1.0, 1.0)).normalized()
		var length := rng.randf_range(0.03, 0.09)
		var pts: Array = []
		for s in 5:
			var u := s / 4.0
			pts.append(p0 + dir * length * u - Vector3.UP * 0.015 * u * u)
		base = _ribbon(st, pts, d, rng.randf_range(0.003, 0.005), rng.randf(), 1.0, base, 0.2)
	return st

static func _stalk(st: SurfaceTool, f: Dictionary, base: int) -> int:
	var nseg := 18
	var pts: Array = []
	var h0: float = f.h0
	var h1: float = f.h1
	for s in nseg + 1:
		var u := float(s) / nseg
		var h := lerpf(h0, h1, u)
		var a: float = f.a0 + f.twist * u + 0.02 * sin(h * 23.0 + f.wig)
		var hc := clampf(h, STRAW_LO, STRAW_HI)
		var rad: float = straw_r(hc) + f.off
		# between the lashings the stalks bulge out unevenly
		var pinch := 1.0
		for rp in ROPES:
			pinch = minf(pinch, clampf(absf(hc - rp) / 0.11, 0.0, 1.0))
		rad += f.bulge * pinch
		# past the outer lashings the cut ends splay out like a broom
		var lo := clampf((ROPES[0] - h) / 0.12, 0.0, 1.5)
		var hi := clampf((h - ROPES[2]) / 0.12, 0.0, 1.5)
		rad += (lo * lo + hi * hi) * 0.035 * f.splay
		pts.append(Vector3(cos(a) * rad, h, sin(a) * rad))
	var mid := (f.a0 as float) + (f.twist as float) * 0.5
	return _ribbon(st, pts, Vector3(cos(mid), 0, sin(mid)), f.w, f.tone, f.depth, base, 0.6)

## A flat stalk along pts, its face turned out along `out`; tapers over the last tip_frac.
static func _ribbon(st: SurfaceTool, pts: Array, out: Vector3, w: float, tone: float, depth: float, base: int, tip: float) -> int:
	var n := pts.size()
	var along := 0.0
	for s in n:
		var p: Vector3 = pts[s]
		var fwd: Vector3 = ((pts[mini(s + 1, n - 1)] as Vector3) - (pts[maxi(s - 1, 0)] as Vector3)).normalized()
		if s > 0:
			along += p.distance_to(pts[s - 1])
		var radial := Vector3(p.x, 0, p.z).normalized() if Vector2(p.x, p.z).length() > 0.01 else out
		var side := fwd.cross(radial).normalized()
		var nrm := side.cross(fwd).normalized()
		var u := float(s) / (n - 1)
		# both cut ends narrow a little; a broken stalk narrows to a split point
		var ww := w * (1.0 - 0.55 * smoothstep(1.0 - tip * 0.3, 1.0, u) - 0.3 * smoothstep(tip * 0.1, 0.0, u))
		for e in 2:
			st.set_color(Color(STRAW, 1.0, tone, depth))
			st.set_normal(nrm)
			st.set_uv(Vector2(float(e), along))
			st.set_uv2(Vector2(u, 0))
			st.add_vertex(p + side * ww * (float(e) - 0.5))
	for s in n - 1:
		var a := base + s * 2
		st.add_index(a); st.add_index(a + 2); st.add_index(a + 1)
		st.add_index(a + 1); st.add_index(a + 2); st.add_index(a + 3)
	return base + n * 2
