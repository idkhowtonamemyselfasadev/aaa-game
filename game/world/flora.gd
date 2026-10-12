class_name Flora
extends Node3D
## Trees and boulders for Harrowmere Vale, all generated here (no imported meshes):
##  - black oaks: a gnarled trunk that forks into limbs and twigs (tapered tubes with bark
##    UVs), leaf sprig cards clustered at the twig ends with a procedurally painted leaf
##    atlas; a few variants, instanced through MultiMesh and scattered in groves.
##  - boulders: noise-displaced, flattened icospheres with a mossy rock shader, sunk into
##    the ground, scattered in outcrops on the slopes and lone stones in the meadow.
## Trunks and boulders get collision. The village floor and the road corridor stay clear.

@export var terrain_path: NodePath
@export var tree_count: int = 260
@export var rock_count: int = 420
@export var tree_variants: int = 4
@export var rock_variants: int = 6
@export var bark_material: ShaderMaterial
@export var leaf_material: ShaderMaterial
@export var rock_material: ShaderMaterial
@export var seed: int = 4242

var _terrain: Terrain
var _grove := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var tree_positions: Array[Vector3] = []
var rock_positions: Array[Vector3] = []

# per-variant scratch while building a tree
var _bark: SurfaceTool
var _leaves: SurfaceTool
var _canopy_c := Vector3.ZERO
var _crown := Vector2(0.0, 1000.0)   # (max horizontal reach, lowest leaf y) of the tree being built
var _variant_crown: Array[Vector2] = []
var _perch: Array[Vector3] = []              # twig tips of the tree being built
var _variant_perches: Array = []             # per variant: upper-crown twig tips (local)
var tree_xforms: Array[Transform3D] = []     # per tree, same order as tree_positions
var tree_variant: Array[int] = []

## Rain shelter under the oak crowns, for rain/drops/splashes/soak/wet ground:
## a SHELTER_RES^2 map over SHELTER_SIZE m centred on the origin, R = how much rain the
## crowns above catch (0 open sky .. ~0.85 under the trunk; crowns always leak a little),
## G = world height of the lowest leaves there. Pushed as global `shelter_map`.
const SHELTER_SIZE := 512.0
const SHELTER_RES := 256
var shelter: Image

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_rng.seed = seed
	_grove.seed = seed + 1
	_grove.frequency = 1.0 / 70.0
	_grove.fractal_octaves = 2
	if leaf_material:
		leaf_material.set_shader_parameter("leaf_tex", _leaf_atlas())
	_scatter_trees()
	_scatter_rocks()

## Places that must stay walkable: village floor and the road toward the east ridge.
func _blocked(x: float, z: float, margin: float) -> bool:
	var r := Vector2(x, z).length()
	if r < 38.0 + margin:
		return true
	# the diagonal road (0,0) -> (200,200): distance to the line x == z
	if absf(x - z) / sqrt(2.0) < 5.0 + margin and x > -10.0:
		return true
	var half := _terrain.size_m * 0.5 - 6.0
	return absf(x) > half or absf(z) > half

# ---------------------------------------------------------------- trees

func _scatter_trees() -> void:
	var meshes: Array[ArrayMesh] = []
	for v in tree_variants:
		meshes.append(_build_tree(v))
	var per: Array = []
	for v in tree_variants:
		per.append([])
	var body := StaticBody3D.new()
	body.name = "TreeCollision"
	add_child(body)
	var tries := 0
	while tree_positions.size() < tree_count and tries < tree_count * 40:
		tries += 1
		var x := _rng.randf_range(-250.0, 250.0)
		var z := _rng.randf_range(-250.0, 250.0)
		if _blocked(x, z, 4.0):
			continue
		var g := _grove.get_noise_2d(x, z) * 0.5 + 0.5      # groves: dense where g is high
		var slope := 1.0 - _terrain.normal_at(x, z).y
		if slope > 0.3 or _rng.randf() > smoothstep(0.45, 0.75, g) * 0.9 + 0.03:
			continue
		var p := Vector3(x, _terrain.height_at(x, z) - 0.25, z)
		var ok := true
		for q in tree_positions:
			if Vector2(q.x - x, q.z - z).length() < 9.0:
				ok = false
				break
		if not ok:
			continue
		tree_positions.append(p)
		var s := _rng.randf_range(1.05, 1.55)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.1), s))
		var tv := _rng.randi() % tree_variants
		per[tv].append(Transform3D(b, p))
		tree_xforms.append(Transform3D(b, p))
		tree_variant.append(tv)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.45 * s
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = p + Vector3.UP * 2.0
		body.add_child(cs)
	for v in tree_variants:
		_multimesh(meshes[v], per[v], "Oaks_%d" % v)
	_bake_shelter(per)

func _build_tree(v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 31 + v
	_bark = SurfaceTool.new()
	_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_leaves = SurfaceTool.new()
	_leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_h := r.randf_range(3.2, 4.6)
	_canopy_c = Vector3(0, trunk_h + 3.2, 0)
	_crown = Vector2(0.0, 1000.0)
	_perch.clear()
	var lean := Vector3(r.randf_range(-0.15, 0.15), 1.0, r.randf_range(-0.15, 0.15)).normalized()
	_branch(r, Vector3.ZERO, lean, trunk_h, r.randf_range(0.42, 0.55), 0, 0.0)
	var mesh := ArrayMesh.new()
	_bark.generate_tangents()
	_bark.commit(mesh)
	_leaves.commit(mesh)
	if bark_material:
		mesh.surface_set_material(0, bark_material)
	if leaf_material:
		mesh.surface_set_material(1, leaf_material)
	_variant_crown.append(_crown)
	# roost perches: the twig tips in the upper part of the crown, where rooks sit at night
	var top := -INF
	for q in _perch:
		top = maxf(top, q.y)
	var ups: Array[Vector3] = []
	for q in _perch:
		if q.y > top - 2.6:
			ups.append(q)
	_variant_perches.append(ups)
	return mesh

## World-space perch points (upper twig tips) in the crown of tree `i`.
func perch_points(i: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var xf := tree_xforms[i]
	for q: Vector3 in _variant_perches[tree_variant[i]]:
		out.append(xf * q)
	return out

## Paint each oak's crown into the shelter map: dense at the trunk, thinning to nothing at
## the drip line (the crown's reach); where crowns overlap the cover adds up toward 0.9.
func _bake_shelter(per: Array) -> void:
	shelter = Image.create(SHELTER_RES, SHELTER_RES, false, Image.FORMAT_RGF)
	shelter.fill(Color(0, -1000.0, 0))
	var cell := SHELTER_SIZE / SHELTER_RES
	for v in per.size():
		var cr: Vector2 = _variant_crown[v]
		for xf: Transform3D in per[v]:
			var s := xf.basis.get_scale().x
			var reach := cr.x * s * 0.92
			var lo := xf.origin.y + cr.y * xf.basis.get_scale().y
			var c := Vector2(xf.origin.x, xf.origin.z)
			var i0 := Vector2i(((c - Vector2.ONE * reach) / cell + Vector2.ONE * SHELTER_RES * 0.5).floor())
			var i1 := Vector2i(((c + Vector2.ONE * reach) / cell + Vector2.ONE * SHELTER_RES * 0.5).ceil())
			for j in range(maxi(i0.y, 0), mini(i1.y + 1, SHELTER_RES)):
				for i in range(maxi(i0.x, 0), mini(i1.x + 1, SHELTER_RES)):
					var w := (Vector2(i + 0.5, j + 0.5) - Vector2.ONE * SHELTER_RES * 0.5) * cell
					var d := w.distance_to(c) / reach
					if d >= 1.0:
						continue
					var a := (1.0 - smoothstep(0.45, 1.0, d)) * 0.85
					var old := shelter.get_pixel(i, j)
					var r := 1.0 - (1.0 - old.r) * (1.0 - a)
					shelter.set_pixel(i, j, Color(minf(r, 0.9), maxf(old.g, lo) if old.r > 0.0 else lo, 0))
	RenderingServer.global_shader_parameter_set("shelter_map", ImageTexture.create_from_image(shelter))

## How much rain the crowns overhead catch at (x, z): 0 open .. ~0.9 deep under an oak.
func shelter_at(x: float, z: float) -> float:
	if shelter == null:
		return 0.0
	var i := int(floor(x / (SHELTER_SIZE / SHELTER_RES) + SHELTER_RES * 0.5))
	var j := int(floor(z / (SHELTER_SIZE / SHELTER_RES) + SHELTER_RES * 0.5))
	if i < 0 or j < 0 or i >= SHELTER_RES or j >= SHELTER_RES:
		return 0.0
	return shelter.get_pixel(i, j).r

## World height of the lowest leaves over (x, z) (-1000 where no crown is overhead).
func leaf_height_at(x: float, z: float) -> float:
	if shelter == null:
		return -1000.0
	var i := int(floor(x / (SHELTER_SIZE / SHELTER_RES) + SHELTER_RES * 0.5))
	var j := int(floor(z / (SHELTER_SIZE / SHELTER_RES) + SHELTER_RES * 0.5))
	if i < 0 or j < 0 or i >= SHELTER_RES or j >= SHELTER_RES:
		return -1000.0
	return shelter.get_pixel(i, j).g

## Recursive limb: a bent, tapered tube from `from` along `dir`, then 2-3 children.
## `sway` (0 trunk .. 1 twig) goes into COLOR.r for the wind shader.
func _branch(r: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, radius: float, depth: int, sway: float) -> void:
	var rings := maxi(3, int(length / 0.45))
	var sides: int = [10, 8, 6, 5][mini(depth, 3)]
	var pts: Array[Vector3] = []
	var p := from
	var d := dir
	var bend := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)) * 0.06
	for i in rings + 1:
		pts.append(p)
		# limbs droop and wander as they get long, like old oaks
		d = (d + bend + Vector3(r.randf_range(-0.08, 0.08), -0.015 * depth, r.randf_range(-0.08, 0.08))).normalized()
		p += d * (length / rings)
	var end_r := radius * (0.62 if depth < 3 else 0.25)
	var sway_end := minf(1.0, sway + 0.25 + 0.1 * depth)
	_tube(pts, radius, end_r, sides, sway, sway_end, depth == 0)
	var tip := pts[pts.size() - 1]
	if depth >= 3:
		_perch.append(tip)
		_leaf_cluster(r, tip, d, sway_end, 16)
		return
	var kids := r.randi_range(2, 3) if depth > 0 else r.randi_range(3, 4)
	var phase := r.randf() * TAU
	for k in kids:
		var a := phase + k * TAU / kids + r.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a))
		# trunk forks spread wide (the black-oak crown), twigs angle up and out
		var up: float = [0.75, 0.6, 0.85][mini(depth, 2)]
		var cd: Vector3 = (d * up + out * (1.0 - up) * 1.6).normalized()
		var cl := length * r.randf_range(0.62, 0.85) * (1.25 if depth == 0 else 1.0)
		var start_t := 1.0 if k == 0 else r.randf_range(0.7, 1.0)
		var sp := pts[int(start_t * (pts.size() - 1))]
		_branch(r, sp, cd, cl, end_r * r.randf_range(0.75, 0.95), depth + 1, sway_end)
	# extra leaf sprigs along the outer limbs so the crown is full, not lollipops
	if depth == 2:
		_leaf_cluster(r, pts[pts.size() / 2], d, sway_end, 7)
		_leaf_cluster(r, pts[pts.size() - 1], d, sway_end, 6)

func _tube(pts: Array[Vector3], r0: float, r1: float, sides: int, s0: float, s1: float, flare: bool) -> void:
	var n := pts.size()
	var ring_prev: Array = []
	var v_acc := 0.0
	for i in n:
		var t := float(i) / (n - 1)
		var fwd := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.FORWARD if absf(fwd.z) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(fwd).normalized()
		var rad := lerpf(r0, r1, t)
		if flare:
			rad *= 1.0 + 0.9 * pow(1.0 - t, 6.0)   # root flare
		if i > 0:
			v_acc += pts[i].distance_to(pts[i - 1]) / (TAU * maxf(r0, 0.05)) * 2.0
		var ring: Array = []
		for s in sides + 1:
			var a := float(s) / sides * TAU
			var nrm := side * cos(a) + up * sin(a)
			# knobbly bark: a little radial noise so the silhouette is not a pipe
			var k := 1.0 + 0.08 * sin(a * 3.0 + i * 1.7) + 0.05 * sin(a * 7.0 - i * 0.9)
			ring.append([pts[i] + nrm * rad * k, nrm, Vector2(float(s) / sides * 2.0, v_acc)])
		if i > 0:
			var sw := lerpf(s0, s1, t)
			var swp := lerpf(s0, s1, float(i - 1) / (n - 1))
			for s in sides:
				var a0: Array = ring_prev[s]
				var a1: Array = ring_prev[s + 1]
				var b0: Array = ring[s]
				var b1: Array = ring[s + 1]
				for q in [[a0, swp], [a1, swp], [b0, sw], [a1, swp], [b1, sw], [b0, sw]]:
					var vv: Array = q[0]
					_bark.set_color(Color(q[1], 0, 0))
					_bark.set_normal(vv[1])
					_bark.set_uv(vv[2])
					_bark.add_vertex(vv[0])
		ring_prev = ring
	# (open ends are hidden inside the parent limb or the leaf cluster)

## A clump of crossed leaf-sprig cards around `c`; normals point out of the crown so it
## lights as a soft volume. UV picks one of 4 atlas tiles.
func _leaf_cluster(r: RandomNumberGenerator, c: Vector3, d: Vector3, sway: float, count: int) -> void:
	for i in count:
		var off := Vector3(r.randfn(0, 0.9), r.randfn(0.25, 0.55), r.randfn(0, 0.9))
		var centre := c + off + d * 0.3
		var size := r.randf_range(1.3, 2.0)
		var yaw := r.randf() * TAU
		var tilt := r.randf_range(-0.6, 0.6)
		var bx := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		var right := bx.x * size
		var upv := bx.y * size
		var crown_n := (centre - _canopy_c).normalized().lerp(Vector3.UP, 0.3).normalized()
		_crown = Vector2(maxf(_crown.x, Vector2(centre.x, centre.z).length() + size * 0.4), minf(_crown.y, centre.y))
		var tile := r.randi() % 4
		var uo := Vector2((tile % 2) * 0.5, (tile / 2) * 0.5)
		var phase := r.randf()
		var corners := [[-1, -1], [1, -1], [1, 1], [-1, 1]]
		var vs: Array = []
		for cc in corners:
			var pos: Vector3 = centre + right * 0.5 * cc[0] + upv * 0.5 * cc[1]
			var uv := uo + Vector2((cc[0] * 0.5 + 0.5) * 0.5, (0.5 - cc[1] * 0.5) * 0.5)
			vs.append([pos, uv])
		for idx in [0, 1, 2, 0, 2, 3]:
			var vv: Array = vs[idx]
			_leaves.set_color(Color(sway, phase, 0))
			_leaves.set_normal(crown_n)
			_leaves.set_uv(vv[1])
			_leaves.add_vertex(vv[0])

## 1024x1024 atlas, 4 tiles; each tile is an oak sprig: a twig with 9-13 lobed leaves.
func _leaf_atlas() -> ImageTexture:
	const S := 1024
	const T := 512
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.18, 0.2, 0.08, 0.0))
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for tile in 4:
		var ox := (tile % 2) * T
		var oy := (tile / 2) * T
		var base := Vector2(ox + T * 0.5, oy + T * 0.95)
		var stem_dir := Vector2(r.randf_range(-0.2, 0.2), -1.0).normalized()
		var stem_len := T * 0.75
		_line(img, base, base + stem_dir * stem_len, 3.0, Color(0.22, 0.16, 0.1, 1))
		var leaves := r.randi_range(22, 28)
		for i in leaves:
			var t := r.randf_range(0.15, 1.0)
			var at := base + stem_dir * stem_len * t
			var side := 1.0 if i % 2 == 0 else -1.0
			var ang := stem_dir.angle() + side * r.randf_range(0.5, 1.2)
			var ln := r.randf_range(0.2, 0.3) * T * (1.15 - t * 0.35)
			var dir := Vector2.from_angle(ang)
			# late-summer oak: deep olive, some yellowing, a rare dull-brown dead leaf (saturated
			# rust at 12 % read as apples on a fruit tree at close range)
			var hue := r.randf()
			var col := Color(0.16, 0.22, 0.07)
			if hue > 0.65:
				col = Color(0.26, 0.27, 0.09)
			if hue > 0.96:
				col = Color(0.27, 0.19, 0.1)
			col = col * r.randf_range(0.8, 1.15)
			_leaf(img, at, dir, ln, ln * 0.36, col, Rect2i(ox, oy, T, T))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _line(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var steps := int(a.distance_to(b))
	for i in steps:
		var p := a.lerp(b, float(i) / steps)
		for dy in range(-int(w), int(w) + 1):
			for dx in range(-int(w), int(w) + 1):
				var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, col)

## Lobed oak leaf rasterised in its bounding box: half-width along the midrib follows a
## sine envelope with 4 lobes; lighter midrib and veins, darker toward the edge.
func _leaf(img: Image, at: Vector2, dir: Vector2, ln: float, wd: float, col: Color, clip: Rect2i) -> void:
	var nrm := Vector2(-dir.y, dir.x)
	var lo := at.min(at + dir * ln) - Vector2(wd, wd) * 1.4
	var hi := at.max(at + dir * ln) + Vector2(wd, wd) * 1.4
	for y in range(maxi(int(lo.y), clip.position.y), mini(int(hi.y), clip.end.y)):
		for x in range(maxi(int(lo.x), clip.position.x), mini(int(hi.x), clip.end.x)):
			var rel := Vector2(x, y) - at
			var u := rel.dot(dir) / ln
			var v := rel.dot(nrm)
			if u < 0.0 or u > 1.0:
				continue
			var env := pow(sin(PI * clampf(u * 0.95 + 0.05, 0.0, 1.0)), 0.7)
			var lobes := 0.78 + 0.22 * absf(sin(u * PI * 4.5))
			var hw := wd * env * lobes
			if absf(v) > hw:
				continue
			var e := absf(v) / maxf(hw, 0.001)
			var c := col * lerpf(1.12, 0.78, e)
			if absf(v) < 1.2:
				c = c.lerp(Color(0.42, 0.42, 0.2), 0.5)              # midrib
			elif absf(fmod(u * 9.0 - absf(v) / wd * 1.5, 1.0)) < 0.08:
				c = c * 1.12                                             # veins
			c.a = 1.0
			img.set_pixel(x, y, c)

# ---------------------------------------------------------------- rocks

func _scatter_rocks() -> void:
	var meshes: Array[ArrayMesh] = []
	for v in rock_variants:
		meshes.append(_build_rock(v))
	var per: Array = []
	for v in rock_variants:
		per.append([])
	var body := StaticBody3D.new()
	body.name = "RockCollision"
	add_child(body)
	var outcrop := FastNoiseLite.new()
	outcrop.seed = seed + 5
	outcrop.frequency = 1.0 / 45.0
	var tries := 0
	while rock_positions.size() < rock_count and tries < rock_count * 40:
		tries += 1
		var x := _rng.randf_range(-250.0, 250.0)
		var z := _rng.randf_range(-250.0, 250.0)
		var big := _rng.randf() < 0.25
		if _blocked(x, z, 2.0 if big else 0.0):
			continue
		var nrm := _terrain.normal_at(x, z)
		var slope := 1.0 - nrm.y
		var o := outcrop.get_noise_2d(x, z) * 0.5 + 0.5
		# outcrops on slopes, rare lone stones on the flat
		var want := smoothstep(0.55, 0.8, o) * (0.4 + smoothstep(0.05, 0.25, slope)) + 0.04
		if _rng.randf() > want:
			continue
		var s := (_rng.randf_range(1.4, 3.2) if big else _rng.randf_range(0.25, 1.0))
		var p := Vector3(x, _terrain.height_at(x, z) - s * 0.3, z)
		rock_positions.append(p)
		var b := Basis(Quaternion(Vector3.UP, nrm.lerp(Vector3.UP, 0.4).normalized())) * Basis(Vector3.UP, _rng.randf() * TAU)
		b = b.scaled(Vector3(s, s * _rng.randf_range(0.55, 0.9), s * _rng.randf_range(0.8, 1.2)))
		per[_rng.randi() % rock_variants].append(Transform3D(b, p))
		if s > 0.6:
			var cs := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = s * 0.6
			cs.shape = sph
			cs.position = p
			body.add_child(cs)
	for v in rock_variants:
		_multimesh(meshes[v], per[v], "Rocks_%d" % v)

## Icosphere (3 subdivisions) displaced by ridged + fbm noise, flattened underneath,
## with a couple of planar cuts so it reads as fractured stone instead of a potato.
func _build_rock(v: int) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = seed + 100 + v
	n.frequency = 1.6
	n.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = seed + 200 + v
	ridge.frequency = 0.9
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 2
	var r := RandomNumberGenerator.new()
	r.seed = seed + v
	var cuts: Array = []
	for i in 3:
		cuts.append([Vector3(r.randfn(), r.randfn() * 0.5 + 0.4, r.randfn()).normalized(), r.randf_range(0.62, 0.8)])
	var ico := _icosphere(3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var out := PackedVector3Array()
	for p: Vector3 in ico[0]:
		var q := p * (1.0 + n.get_noise_3dv(p) * 0.28 + ridge.get_noise_3dv(p * 1.3) * 0.12)
		for c in cuts:
			var cn: Vector3 = c[0]
			var dd: float = q.dot(cn) - c[1]
			if dd > 0.0:
				q -= cn * dd * 0.85
		if q.y < -0.3:
			q.y = -0.3 + (q.y + 0.3) * 0.25
		out.append(q)
	for t in ico[1]:
		st.set_smooth_group(0)
		st.add_vertex(out[t])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	if rock_material:
		mesh.surface_set_material(0, rock_material)
	return mesh

func _icosphere(sub: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for p in [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t], [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]:
		verts.append(Vector3(p[0], p[1], p[2]).normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for s in sub:
		var cache := {}
		var nf := []
		for f in faces:
			var m := []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
				if not cache.has(key):
					cache[key] = verts.size()
					verts.append(((verts[e[0]] + verts[e[1]]) * 0.5).normalized())
				m.append(cache[key])
			nf.append_array([[f[0], m[0], m[2]], [f[1], m[1], m[0]], [f[2], m[2], m[1]], [m[0], m[1], m[2]]])
		faces = nf
	var idx := PackedInt32Array()
	for f in faces:
		# Godot front faces are clockwise seen from outside
		idx.append_array([f[0], f[2], f[1]])
	return [verts, idx]

# ---------------------------------------------------------------- shared

func _multimesh(mesh: Mesh, xfs: Array, nm: String) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
