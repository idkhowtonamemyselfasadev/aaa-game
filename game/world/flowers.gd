class_name MeadowFlowers
extends RefCounted
## Meadow wildflowers for the Vale (owner's "alive" list; perches for the butterflies).
## Four lowland species, each a real procedural mesh (stem, leaves, head) built once:
##   0 ox-eye daisy  — white ray petals round a yellow disc
##   1 meadow buttercup — five glossy yellow petals in a shallow cup
##   2 common knapweed — a dark scaly bract bulb under a purple brush of florets
##   3 yarrow — a flat-topped white umbel of tiny florets over feathery leaves
## GrassField scatters them per grass chunk in drifts (each drift mostly one species) and keeps
## each chunk's flower-head positions so butterflies can settle on a real head.
## Vertex COLOR: r = part (0 stem/leaf, 0.5 petal, 1 centre), g = along the petal 0 base .. 1
## tip; UV.y = 0 root .. 1 head (wind weight). flower.gdshader does the colour and the wind.

const SPECIES := 4
## head height of each species' mesh at scale 1 (m)
const HEAD_H := [0.50, 0.52, 0.60, 0.46]

static var _meshes: Array[ArrayMesh] = []
static var _mat: ShaderMaterial

static var _drift := FastNoiseLite.new()
static var _kind := FastNoiseLite.new()
static var _noise_ready := false

static func mesh(sp: int) -> ArrayMesh:
	if _meshes.is_empty():
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/flower.gdshader")
		for s in SPECIES:
			var m := _build(s)
			m.surface_set_material(0, _mat)
			_meshes.append(m)
	return _meshes[sp]

## Scatter one chunk's flowers. Returns [Node3D holding the MultiMeshes, PackedVector3Array of
## head positions (world), PackedInt32Array of species per head].
static func build_chunk(k: Vector2i, chunk_m: float, terrain: Terrain, far: float,
		ruin := Vector3.INF, flora: Node = null) -> Array:
	if not _noise_ready:
		_noise_ready = true
		_drift.seed = 4242
		_drift.frequency = 1.0 / 18.0
		_drift.fractal_octaves = 2
		_kind.seed = 515
		_kind.frequency = 1.0 / 30.0
		_kind.fractal_octaves = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k) ^ 0x5f1a
	var xfs := [[], [], [], []]
	var vars := [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	var heads := PackedVector3Array()
	var kinds := PackedInt32Array()
	var half := terrain.size_m * 0.5 - 2.0
	# dense near the camera, a sprinkle of colour farther out (flower meshes are a few hundred
	# triangles each, so far chunks carry far fewer)
	var tries := int(620.0 * (1.0 - far) * (1.0 - far) + 60.0)
	for n in tries:
		var x := (k.x + rng.randf()) * chunk_m
		var z := (k.y + rng.randf()) * chunk_m
		if absf(x) > half or absf(z) > half:
			continue
		# drifts: flowers gather where the drift noise is high, thin sprinkles elsewhere
		var drift := _drift.get_noise_2d(x, z) * 0.5 + 0.5
		if rng.randf() > smoothstep(0.30, 0.72, drift) * 0.92 + 0.08:
			continue
		var nrm := terrain.normal_at(x, z)
		if nrm.y < 0.86 or terrain.pond_at(x, z) > 0.2:
			continue
		# no meadow flowers on the watchtower keep floor or through its walls, few in deep
		# oak shade, none through the moss cushions (same masks as the grass)
		if ruin != Vector3.INF and Vector2(x - ruin.x, z - ruin.z).length() < 4.8:
			continue
		if Cottage.inside(x, z, -0.2) or StoneCottage.inside(x, z, -0.2) or DryWall.near(x, z, 0.0) or YardWall.near(x, z, 0.0):
			continue
		if flora and (rng.randf() < flora.shelter_at(x, z) * 0.9 or flora.moss_at(x, z) > 0.12):
			continue
		# which species: a slow field picks the drift's flower, with some mixing at the seams
		var kn := _kind.get_noise_2d(x, z) * 0.5 + 0.5 + rng.randfn(0.0, 0.08)
		var sp := 1 if kn < 0.33 else 0 if kn < 0.5 else 2 if kn < 0.7 else 3
		var s := rng.randf_range(1.0, 1.5)     # heads just over the grass tops
		var y := terrain.height_at(x, z)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		var t := Transform3D(basis, Vector3(x, y - 0.02, z))
		xfs[sp].append(t)
		vars[sp].append(rng.randf())
		heads.append(t * Vector3(0, HEAD_H[sp], 0))
		kinds.append(sp)
	var root := Node3D.new()
	root.name = "Flowers"
	for sp in SPECIES:
		if xfs[sp].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh(sp)
		mm.instance_count = xfs[sp].size()
		for i in xfs[sp].size():
			mm.set_instance_transform(i, xfs[sp][i])
			mm.set_instance_custom_data(i, Color(vars[sp][i], float(sp), 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mmi.visibility_range_end = 60.0
		root.add_child(mmi)
	return [root, heads, kinds]

# ---------------------------------------------------------------- mesh building

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, ha: float, hb: float, hc: float, n := Vector3.ZERO) -> void:
	var nn := n if n != Vector3.ZERO else (b - a).cross(c - a).normalized()
	if nn.y < 0.0 and n == Vector3.ZERO:
		nn = -nn
	for v in [[a, ca, ha], [b, cb, hb], [c, cc, hc]]:
		st.set_normal(nn)
		st.set_color(v[1])
		st.set_uv(Vector2(0.0, v[2]))
		st.add_vertex(v[0])

## A tapered ribbon stem from the root to `top`, crossed (two ribbons at 90 deg) so it reads
## from any side; bows a little sideways.
static func _stem(st: SurfaceTool, top: Vector3, w0: float, w1: float, bow: Vector3, head_h: float) -> void:
	const SEG := 4
	var g := Color(0, 0, 0)
	for side: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for s in SEG + 1:
			var t := float(s) / SEG
			var c := top * t + bow * sin(t * PI)
			var w := lerpf(w0, w1, t)
			var l := c - side * w
			var r := c + side * w
			if s > 0:
				var t0 := float(s - 1) / SEG
				var h0 := t0 * top.y / head_h
				var h1 := t * top.y / head_h
				var n := side.cross(Vector3.UP).normalized()
				_tri(st, prev_l, l, prev_r, g, g, g, h0, h1, h0, n)
				_tri(st, prev_r, l, r, g, g, g, h0, h1, h1, n)
			prev_l = l
			prev_r = r

## A leaf blade from `base` out along `dir`, `len` long, max half-width `w` at `wpos` along it,
## arching down by `droop`. `lobes` > 0 cuts the edge into teeth/lobes.
static func _leaf(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, w: float, droop: float, head_h: float, lobes := 0, wpos := 0.4) -> void:
	const SEG := 6
	var side := dir.cross(Vector3.UP).normalized()
	var g := Color(0.0, 0.0, 0.0)
	var prev_c := base
	var prev_l := base
	var prev_r := base
	for s in range(1, SEG + 1):
		var t := float(s) / SEG
		var c := base + dir * length * t + Vector3.DOWN * droop * t * t + Vector3.UP * length * 0.25 * t
		var ww := w * (sin(minf(t / wpos, 1.0) * PI * 0.5) if t < wpos else cos((t - wpos) / (1.0 - wpos) * PI * 0.5))
		if lobes > 0:
			ww *= 0.55 + 0.45 * absf(sin(t * lobes * PI))
		var l := c - side * ww
		var r := c + side * ww
		var h0 := prev_c.y / head_h
		var h1 := c.y / head_h
		# a slight V fold along the midrib
		var cu := c + Vector3.UP * ww * 0.25
		_tri(st, prev_c, prev_l, cu, g, g, g, h0, h0, h1)
		_tri(st, prev_l, l, cu, g, g, g, h0, h1, h1)
		_tri(st, prev_c, cu, prev_r, g, g, g, h0, h1, h0)
		_tri(st, prev_r, cu, r, g, g, g, h0, h1, h1)
		prev_c = cu
		prev_l = l
		prev_r = r

## One petal: a rounded spoon from `base` along `dir` (unit), with `cup` lifting it upward.
static func _petal(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, w: float, cup: float, curl: float) -> void:
	const SEG := 3
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var prev := [base, base, base]
	for s in range(1, SEG + 1):
		var t := float(s) / SEG
		var c := base + dir * length * t + Vector3.UP * (cup * t - curl * t * t) * length
		var ww := w * (0.35 + 0.65 * sin(minf(t * 1.25, 1.0) * PI * 0.5)) * (1.0 if t < 0.85 else 0.75)
		var l := c - side * ww + Vector3.UP * ww * cup * 0.6
		var r := c + side * ww + Vector3.UP * ww * cup * 0.6
		var t0 := float(s - 1) / SEG
		var c0 := Color(0.5, t0, 0)
		var c1 := Color(0.5, t, 0)
		var pc: Vector3 = prev[0]
		var pl: Vector3 = prev[1]
		var pr: Vector3 = prev[2]
		_tri(st, pc, pl, c, c0, c0, c1, 1.0, 1.0, 1.0)
		_tri(st, pl, l, c, c0, c1, c1, 1.0, 1.0, 1.0)
		_tri(st, pc, c, pr, c0, c1, c0, 1.0, 1.0, 1.0)
		_tri(st, pr, c, r, c0, c1, c1, 1.0, 1.0, 1.0)
		prev = [c, l, r]

## A low-poly ellipsoid (lat-long) at `c` with radii `r`, coloured `col`.
static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, rings := 4, segs := 7) -> void:
	for i in rings:
		var a0 := PI * float(i) / rings - PI * 0.5
		var a1 := PI * float(i + 1) / rings - PI * 0.5
		for j in segs:
			var b0 := TAU * float(j) / segs
			var b1 := TAU * float(j + 1) / segs
			var p := func(a: float, b: float) -> Vector3: return c + Vector3(cos(a) * cos(b) * r.x, sin(a) * r.y, cos(a) * sin(b) * r.z)
			var q00: Vector3 = p.call(a0, b0)
			var q01: Vector3 = p.call(a0, b1)
			var q10: Vector3 = p.call(a1, b0)
			var q11: Vector3 = p.call(a1, b1)
			var n := ((q00 + q11) * 0.5 - c).normalized()
			_tri(st, q00, q10, q11, col, col, col, 1.0, 1.0, 1.0, n)
			_tri(st, q00, q11, q01, col, col, col, 1.0, 1.0, 1.0, n)

static func _build(sp: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + sp
	var hh: float = HEAD_H[sp]
	var top := Vector3(rng.randf_range(-0.03, 0.03), hh, rng.randf_range(-0.03, 0.03))
	var bow := Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
	# the head faces up and a little to one side, like a flower turned to the light
	var face := Vector3(0.25, 1.0, 0.1).normalized()
	var fb := Basis(Quaternion(Vector3.UP, face))
	match sp:
		0:  # ox-eye daisy
			_stem(st, top, 0.0022, 0.0014, bow, hh)
			for i in 5:
				var a := i * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
				_leaf(st, Vector3(0, 0.01, 0), Vector3(cos(a), 0, sin(a)), rng.randf_range(0.07, 0.11), 0.012, 0.03, hh, 3, 0.7)
			for i in 3:
				var a := rng.randf() * TAU
				_leaf(st, top * rng.randf_range(0.25, 0.6), Vector3(cos(a), 0.3, sin(a)).normalized(), 0.04, 0.005, 0.01, hh, 4, 0.5)
			var nr := 21
			for i in nr:
				var a := i * TAU / nr + rng.randf_range(-0.05, 0.05)
				var d := fb * Vector3(cos(a), -0.08, sin(a)).normalized()
				_petal(st, top + fb * Vector3(cos(a), 0, sin(a)) * 0.006, d, rng.randf_range(0.015, 0.019), 0.0028, 0.05, 0.25)
			_blob(st, top + fb * Vector3(0, 0.002, 0), Vector3(0.0075, 0.003, 0.0075), Color(1, 0, 0), 3, 9)
		1:  # meadow buttercup: branched, small glossy cups
			_stem(st, top, 0.0018, 0.0012, bow, hh)
			for i in 4:
				var a := i * TAU / 4.0 + rng.randf_range(-0.4, 0.4)
				_leaf(st, Vector3(0, 0.01, 0), Vector3(cos(a), 0, sin(a)), rng.randf_range(0.05, 0.08), 0.022, 0.025, hh, 3, 0.55)
			# a second, lower bloom on a side branch
			var top2 := top * 0.78 + Vector3(0.05, 0, -0.02)
			_stem_branch(st, top * 0.55, top2, hh)
			for tp: Vector3 in [top, top2]:
				for i in 5:
					var a := i * TAU / 5.0 + rng.randf_range(-0.1, 0.1)
					_petal(st, tp + fb * Vector3(cos(a), 0, sin(a)) * 0.002, fb * Vector3(cos(a), 0.55, sin(a)).normalized(), 0.0115, 0.0055, 0.45, 0.1)
				_blob(st, tp + fb * Vector3(0, 0.003, 0), Vector3(0.003, 0.0025, 0.003), Color(1, 0, 0), 2, 6)
		2:  # common knapweed
			_stem(st, top, 0.0026, 0.0018, bow, hh)
			for i in 4:
				var a := rng.randf() * TAU
				_leaf(st, top * rng.randf_range(0.1, 0.55), Vector3(cos(a), 0.6, sin(a)).normalized(), rng.randf_range(0.05, 0.08), 0.007, 0.02, hh, 0, 0.35)
			# the hard bract bulb (dark, scaly) and a tuft of purple florets on top
			_blob(st, top + Vector3(0, 0.004, 0), Vector3(0.0085, 0.009, 0.0085), Color(0, 0.5, 0), 4, 8)
			for i in 30:
				var a := rng.randf() * TAU
				var up := rng.randf_range(0.35, 1.0)
				var d := Vector3(cos(a) * (1.1 - up), up, sin(a) * (1.1 - up)).normalized()
				var b := top + Vector3(0, 0.011, 0) + Vector3(cos(a), 0, sin(a)) * 0.004
				_petal(st, b, d, rng.randf_range(0.011, 0.016), 0.0012, 0.0, 0.05)
		3:  # yarrow: feathery leaves and a flat umbel
			_stem(st, top, 0.002, 0.0015, bow, hh)
			for i in 6:
				var a := rng.randf() * TAU
				_leaf(st, top * rng.randf_range(0.0, 0.5), Vector3(cos(a), 0.25, sin(a)).normalized(), rng.randf_range(0.06, 0.1), 0.007, 0.02, hh, 9, 0.5)
			for i in 64:
				var r := sqrt(rng.randf()) * 0.024
				var a := rng.randf() * TAU
				var c := top + Vector3(cos(a) * r, 0.006 - r * r * 8.0, sin(a) * r)
				if i % 9 == 0:
					_stem_branch(st, top - Vector3(0, 0.015, 0), c, hh)
				_floret(st, c, 0.0032, rng.randf() * TAU)
	return st.commit()

## A tiny flat floret: five rounded lobes as a 10-triangle fan round a cream centre.
static func _floret(st: SurfaceTool, c: Vector3, r: float, rot: float) -> void:
	var cc := Color(1, 0, 0)
	for j in 10:
		var a0 := rot + j * TAU / 10.0
		var a1 := rot + (j + 1) * TAU / 10.0
		var r0 := r * (0.75 + 0.25 * cos(a0 * 5.0 - rot * 5.0))
		var r1 := r * (0.75 + 0.25 * cos(a1 * 5.0 - rot * 5.0))
		var p0 := c + Vector3(cos(a0) * r0, -r0 * 0.12, sin(a0) * r0)
		var p1 := c + Vector3(cos(a1) * r1, -r1 * 0.12, sin(a1) * r1)
		_tri(st, c + Vector3(0, r * 0.08, 0), p0, p1, cc, Color(0.5, 1, 0), Color(0.5, 1, 0), 1.0, 1.0, 1.0, Vector3.UP)

static func _stem_branch(st: SurfaceTool, a: Vector3, b: Vector3, head_h: float) -> void:
	var g := Color(0, 0, 0)
	var d := (b - a)
	var side := d.cross(Vector3.UP).normalized() * 0.0012
	if side.length() < 0.0001:
		side = Vector3(0.0012, 0, 0)
	_tri(st, a - side, b - side * 0.7, a + side, g, g, g, a.y / head_h, b.y / head_h, a.y / head_h)
	_tri(st, a + side, b - side * 0.7, b + side * 0.7, g, g, g, a.y / head_h, b.y / head_h, b.y / head_h)
