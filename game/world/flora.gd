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
## Hilltop where the ruined watchtower stands (see ruins.gd); trees and boulders keep clear.
var ruin_site := Vector3.ZERO
const RUIN_CLEAR := 17.0
var rock_positions: Array[Vector3] = []
var _rock_feet: Array[Vector3] = []   # (x, size, z) per boulder, for the moss rings

# per-variant scratch while building a tree
var _bark: SurfaceTool
var _leaves: SurfaceTool
var _canopy_c := Vector3.ZERO
var _crown := Vector2(0.0, 1000.0)   # (max horizontal reach, lowest leaf y) of the tree being built
var _variant_crown: Array[Vector2] = []
var _perch: Array[Vector3] = []              # twig tips of the tree being built
var _card_scale := 1.0                       # leaf card size/spread (1 oak, smaller on shrubs)
var _variant_perches: Array = []             # per variant: upper-crown twig tips (local)
var _cards: Array = []                       # leaf cards of the tree being built (see _emit_leaves)
var tree_xforms: Array[Transform3D] = []     # per tree, same order as tree_positions
var tree_variant: Array[int] = []

## Rain shelter under the oak crowns, for rain/drops/splashes/soak/wet ground:
## a SHELTER_RES^2 map over SHELTER_SIZE m centred on the origin, R = how much rain the
## crowns above catch (0 open sky .. ~0.85 under the trunk; crowns always leak a little),
## G = world height of the lowest leaves there. Pushed as global `shelter_map`.
const SHELTER_SIZE := 512.0
const SHELTER_RES := 256
var shelter: Image

## Moss collars round the oak boles and the boulder feet: a MOSS_RES^2 L8 map over the
## same SHELTER_SIZE square (0.5 m cells), 0 none .. 1 a full velvet cushion. The terrain
## shader breaks its edge up with noise. Pushed as global `moss_map`.
const MOSS_RES := 1024
const MOSS_SHADE := Vector2(-0.6, -0.8)   # away from the afternoon sun (terrain.gdshader)
var moss: Image

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_rng.seed = seed
	_grove.seed = seed + 1
	_grove.frequency = 1.0 / 70.0
	_grove.fractal_octaves = 2
	if leaf_material:
		var atl := _leaf_atlas()
		leaf_material.set_shader_parameter("leaf_tex", atl[0])
		leaf_material.set_shader_parameter("leaf_nrm", atl[1])
		leaf_material.set_shader_parameter("nmap_depth", 0.85)
	ruin_site = pick_ruin_site(_terrain)
	_scatter_trees()
	_build_roots()
	_scatter_rocks()
	_bake_moss()
	_scatter_understory()

## Places that must stay walkable: village floor and the road toward the east ridge.
func _blocked(x: float, z: float, margin: float) -> bool:
	var r := Vector2(x, z).length()
	if r < 38.0 + margin:
		return true
	if Vector2(x - ruin_site.x, z - ruin_site.z).length() < RUIN_CLEAR + margin:
		return true
	# the diagonal road (0,0) -> (200,200): distance to the line x == z
	if absf(x - z) / sqrt(2.0) < 5.0 + margin and x > -10.0:
		return true
	var half := _terrain.size_m * 0.5 - 6.0
	return absf(x) > half or absf(z) > half

## The most prominent knoll 90-190 m out from the village (height above the ring 25 m
## around it, minus slope), off the east road: where the watchtower ruin stands.
static func pick_ruin_site(t: Terrain) -> Vector3:
	var best := Vector3.ZERO
	var best_s := -INF
	for gx in range(-190, 191, 8):
		for gz in range(-190, 191, 8):
			var x := float(gx)
			var z := float(gz)
			var r := Vector2(x, z).length()
			if r < 90.0 or r > 190.0 or absf(x - z) / sqrt(2.0) < 30.0:
				continue
			var h := t.height_at(x, z)
			var ring := 0.0
			for k in 8:
				var a := TAU * k / 8.0
				ring += t.height_at(x + cos(a) * 25.0, z + sin(a) * 25.0)
			var sc := h - ring / 8.0 - (1.0 - t.normal_at(x, z, 4.0).y) * 40.0
			if sc > best_s:
				best_s = sc
				best = Vector3(x, h, z)
	return best

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
	_cards.clear()
	_branch(r, Vector3.ZERO, lean, trunk_h, r.randf_range(0.42, 0.55), 0, 0.0)
	_emit_leaves(1.0)
	var mesh := ArrayMesh.new()
	_bark.generate_tangents()
	_bark.commit(mesh)
	_leaves.generate_tangents()
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

## Surface roots: 4-7 per oak, running out from the root flare and diving into the soil
## 1.3-3 m out, built in world space so each one hugs the terrain under it (a shared
## instanced mesh would float on the downhill side). Chunked ROOT_CHUNK m for culling.
## COLOR.g = 1 marks a root for the bark shader, COLOR.b = height above the ground (m).
const ROOT_CHUNK := 64.0
var root_tips: Array[Vector3] = []   # bots: where each root goes under

func _build_roots() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7 + 3
	var chunks := {}
	for xf in tree_xforms:
		var s := xf.basis.get_scale().x
		var c := xf.origin
		var key := Vector2i(floori(c.x / ROOT_CHUNK), floori(c.z / ROOT_CHUNK))
		if not chunks.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			chunks[key] = st
		var n := r.randi_range(4, 7)
		var phase := r.randf() * TAU
		for k in n:
			var a := phase + k * TAU / n + r.randf_range(-0.35, 0.35)
			var big := r.randf() < 0.6
			var ln := (r.randf_range(1.8, 3.0) if big else r.randf_range(1.2, 1.9)) * s
			var r0 := (r.randf_range(0.2, 0.28) if big else r.randf_range(0.12, 0.17)) * s
			_root(chunks[key], r, c, a, ln, r0, s)
	for key in chunks:
		var st: SurfaceTool = chunks[key]
		st.index()
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = "OakRoots_%d_%d" % [key.x, key.y]
		mi.mesh = st.commit()
		if bark_material:
			mi.material_override = bark_material
		mi.visibility_range_end = 110.0
		mi.visibility_range_end_margin = 15.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)

## One root from the bole at `c` along heading `a`: it leaves the flare as a buttress,
## arches just proud of the soil (the top shows, the belly is buried) and sinks in at
## its tip; big roots throw a thinner side root from their middle.
func _root(st: SurfaceTool, r: RandomNumberGenerator, c: Vector3, a: float, ln: float, r0: float, s: float, depth := 0) -> void:
	const N := 7
	var pts: Array[Vector3] = []
	var rads: Array[float] = []
	var hs: Array[float] = []
	var p := Vector2(c.x, c.z) + Vector2(cos(a), sin(a)) * (0.25 * s if depth == 0 else 0.0)
	var heading := a
	var wob := r.randf_range(-0.25, 0.25)
	var step := ln / N
	for i in N + 1:
		var t := float(i) / N
		var g := _terrain.height_at(p.x, p.y)
		var rad := lerpf(r0, r0 * 0.3, pow(t, 0.8))
		# buttress: high on the bole at the start, then just the top of the root shows
		var y := g + lerpf(0.55 * s if depth == 0 else rad * 0.2, rad * 0.25 - 0.03, smoothstep(0.0, 0.4, t)) - 0.2 * t * t * t
		pts.append(Vector3(p.x, y, p.y))
		var flare := 1.0 + 0.6 * (1.0 - smoothstep(0.0, 0.3, t)) if depth == 0 else 1.0
		rads.append(rad * flare)
		hs.append(y - g)
		heading += wob + r.randf_range(-0.22, 0.22)
		p += Vector2(cos(heading), sin(heading)) * step
	_root_tube(st, pts, rads, c)
	root_tips.append(pts[N])
	if depth == 0 and r0 > 0.15 * s and r.randf() < 0.75:
		var m := pts[3]
		var side := 1.0 if r.randf() < 0.5 else -1.0
		_root(st, r, Vector3(m.x, 0.0, m.z), a + side * r.randf_range(0.5, 0.9), ln * 0.45, rads[3] * 0.55, s, 1)

func _root_tube(st: SurfaceTool, pts: Array[Vector3], rads: Array[float], bole: Vector3) -> void:
	const SIDES := 7
	var n := pts.size()
	var ring_prev: Array = []
	var v_acc := 0.0
	for i in n:
		var fwd := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.UP).normalized()
		var up := side.cross(fwd).normalized()
		if i > 0:
			v_acc += pts[i].distance_to(pts[i - 1]) / (TAU * maxf(rads[0], 0.05)) * 2.0
		var ring: Array = []
		for k in SIDES + 1:
			var ang := float(k) / SIDES * TAU
			var nrm := side * cos(ang) + up * sin(ang)
			# roots are flattened (wider than tall) and a little knotted
			var kn := 1.0 + 0.1 * sin(ang * 3.0 + i * 2.3)
			var off := (side * cos(ang) * 1.25 + up * sin(ang) * 0.8) * rads[i] * kn
			var v := pts[i] + off
			var g := _terrain.height_at(v.x, v.z)
			ring.append([v, nrm, Vector2(float(k) / SIDES * 2.0, v_acc), v.y - g])
		if i > 0:
			for k in SIDES:
				for q in [ring_prev[k], ring_prev[k + 1], ring[k], ring_prev[k + 1], ring[k + 1], ring[k]]:
					st.set_color(Color(0.0, 1.0, clampf(q[3], 0.0, 1.0)))
					st.set_normal(q[1])
					st.set_uv(q[2])
					st.add_vertex(q[0])
		ring_prev = ring

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

## Paint a moss collar round every trunk (wider on the shaded side, out over the root
## flare) and a ring round every boulder's foot, where the stone keeps the ground damp.
func _bake_moss() -> void:
	moss = Image.create(MOSS_RES, MOSS_RES, false, Image.FORMAT_L8)
	moss.fill(Color.BLACK)
	for xf in tree_xforms:
		var s := xf.basis.get_scale().x
		var tr := 0.5 * s
		_moss_ring(Vector2(xf.origin.x, xf.origin.z), tr + 0.4 * s, tr + 2.8 * s, 1.0)
	for k in _rock_feet.size():
		var f: Vector3 = _rock_feet[k]
		_moss_ring(Vector2(f.x, f.z), f.y * 0.55, f.y * 1.05 + 0.5, 0.85 if f.y > 0.8 else 0.6)
	RenderingServer.global_shader_parameter_set("moss_map", ImageTexture.create_from_image(moss))

## Max-blend a ring centred on `c`: full `peak` from r0 out to a shade-skewed falloff
## reaching `r1` (x1.35 on the shaded side, x0.7 on the sunny side).
func _moss_ring(c: Vector2, r0: float, r1: float, peak: float) -> void:
	var cell := SHELTER_SIZE / MOSS_RES
	var reach := r1 * 1.35
	var i0 := Vector2i(((c - Vector2.ONE * reach) / cell + Vector2.ONE * MOSS_RES * 0.5).floor())
	var i1 := Vector2i(((c + Vector2.ONE * reach) / cell + Vector2.ONE * MOSS_RES * 0.5).ceil())
	for j in range(maxi(i0.y, 0), mini(i1.y + 1, MOSS_RES)):
		for i in range(maxi(i0.x, 0), mini(i1.x + 1, MOSS_RES)):
			var w := (Vector2(i + 0.5, j + 0.5) - Vector2.ONE * MOSS_RES * 0.5) * cell - c
			var d := w.length()
			var shade := w.normalized().dot(MOSS_SHADE) * 0.5 + 0.5 if d > 0.01 else 0.5
			var edge := r1 * lerpf(0.7, 1.35, shade)
			if d >= edge:
				continue
			var a := peak * (1.0 - smoothstep(r0, edge, d))
			if a > moss.get_pixel(i, j).r:
				moss.set_pixel(i, j, Color(a, a, a))

## How much moss lies on the ground at (x, z) (bots).
func moss_at(x: float, z: float) -> float:
	if moss == null:
		return 0.0
	var i := int(floor(x / (SHELTER_SIZE / MOSS_RES) + MOSS_RES * 0.5))
	var j := int(floor(z / (SHELTER_SIZE / MOSS_RES) + MOSS_RES * 0.5))
	if i < 0 or j < 0 or i >= MOSS_RES or j >= MOSS_RES:
		return 0.0
	return moss.get_pixel(i, j).r

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
		_leaf_cluster(r, tip, d, sway_end, 22)
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
		_leaf_cluster(r, pts[pts.size() / 2], d, sway_end, 9)
		_leaf_cluster(r, pts[pts.size() - 1], d, sway_end, 8)
	# inner crown: shaded sprigs where the main limbs fork, so the crown is not see-through
	if depth == 1:
		_leaf_cluster(r, pts[pts.size() - 1], d, sway_end, 7)

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

## A clump of crossed leaf-sprig cards around `c`, collected into `_cards`; _emit_leaves
## writes them once the whole crown is known. UV picks one of 4 atlas tiles.
func _leaf_cluster(r: RandomNumberGenerator, c: Vector3, d: Vector3, sway: float, count: int) -> void:
	for i in count:
		var off := Vector3(r.randfn(0, 0.9), r.randfn(0.25, 0.55), r.randfn(0, 0.9)) * _card_scale
		var centre := c + off + d * 0.3 * _card_scale
		var size := r.randf_range(1.15, 1.75) * _card_scale
		var yaw := r.randf() * TAU
		var tilt := r.randf_range(-0.6, 0.6)
		var bx := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		_crown = Vector2(maxf(_crown.x, Vector2(centre.x, centre.z).length() + size * 0.4), minf(_crown.y, centre.y))
		var tile := r.randi() % 4
		_cards.append([centre, bx.x * size, bx.y * size, Vector2((tile % 2) * 0.5, (tile / 2) * 0.5), sway, r.randf()])

## Write the collected leaf cards. The crown is treated as an ellipsoid fitted round the
## card centres: vertex normals point out of it (soft volume lighting, per corner so the
## shading rolls across a card), and COLOR.b is how deep in the crown the card sits
## (0 outer shell .. 1 core, more on the underside): the shader darkens the inner leaves,
## which see little sky, so the crown reads as a mass with a lit skin, not a flat sheet.
## `occ_gain` scales that (shrubs are thin, so less).
func _emit_leaves(occ_gain: float) -> void:
	if _cards.is_empty():
		return
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for cd in _cards:
		lo = lo.min(cd[0])
		hi = hi.max(cd[0])
	var cen := (lo + hi) * 0.5
	var rad := ((hi - lo) * 0.5).max(Vector3(0.3, 0.3, 0.3))
	rad.x = maxf(rad.x, rad.z)
	rad.z = rad.x
	var corners := [[-1, -1], [1, -1], [1, 1], [-1, 1]]
	for cd in _cards:
		var centre: Vector3 = cd[0]
		var q := (centre - cen) / rad
		var occ := clampf(1.0 - q.length(), 0.0, 1.0)
		occ = clampf(occ * 1.25 + clampf(-q.y, 0.0, 1.0) * 0.35, 0.0, 1.0) * occ_gain
		var vs: Array = []
		for cc in corners:
			var pos: Vector3 = centre + cd[1] * 0.5 * cc[0] + cd[2] * 0.5 * cc[1]
			var uv: Vector2 = cd[3] + Vector2((cc[0] * 0.5 + 0.5) * 0.5, (0.5 - cc[1] * 0.5) * 0.5)
			var en := ((pos - cen) / (rad * rad)).normalized().lerp(Vector3.UP, 0.25).normalized()
			vs.append([pos, uv, en])
		for idx in [0, 1, 2, 0, 2, 3]:
			var vv: Array = vs[idx]
			_leaves.set_color(Color(cd[4], cd[5], occ))
			_leaves.set_normal(vv[2])
			_leaves.set_uv(vv[1])
			_leaves.add_vertex(vv[0])
	_cards.clear()

## 1024x1024 atlas, 4 tiles; each tile is an oak spray: 3-5 shoots fanning from the base,
## each a twig ending in a rosette of small lobed leaves (~12 cm on a 1.5 m card, oak size),
## over a back layer of darker, shaded leaves so the card has depth. Returns [albedo, normal]:
## every leaf gets its own tilt and a fold along the midrib in the normal map, so the sun
## catches some leaves and not others (real foliage glitter instead of a painted sheet).
func _leaf_atlas() -> Array:
	const S := 1024
	const T := 512
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.18, 0.2, 0.08, 0.0))
	var nimg := Image.create(S, S, false, Image.FORMAT_RGBA8)
	nimg.fill(Color(0.5, 0.5, 1.0, 1.0))
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for tile in 4:
		var ox := (tile % 2) * T
		var oy := (tile / 2) * T
		var clip := Rect2i(ox, oy, T, T)
		var base := Vector2(ox + T * 0.5, oy + T * 0.97)
		var shoots := r.randi_range(3, 5)
		var tips: Array = []
		for k in shoots:
			var a := -PI * 0.5 + (float(k) / maxf(shoots - 1, 1) - 0.5) * 1.1 + r.randf_range(-0.15, 0.15)
			var ln := T * r.randf_range(0.45, 0.68)
			var mid := base + Vector2.from_angle(a) * ln * 0.5 + Vector2(r.randf_range(-20, 20), 0)
			var tip := base + Vector2.from_angle(a + r.randf_range(-0.2, 0.2)) * ln
			_line(img, base, mid, 2.0, Color(0.2, 0.15, 0.1, 1))
			_line(img, mid, tip, 1.5, Color(0.22, 0.17, 0.1, 1))
			tips.append([base, mid, tip])
		# back layer: shaded leaves deeper in the spray
		for pass_i in 2:
			var back := pass_i == 0
			for sh in tips:
				var n := r.randi_range(9, 12) if back else r.randi_range(13, 18)
				for i in n:
					# leaves crowd toward the shoot tip (oak leaves grow in rosettes at the end)
					var t := 1.0 - pow(r.randf(), 1.8) * 0.85
					var at: Vector2 = (sh[0] as Vector2).lerp(sh[1], minf(t * 2.0, 1.0)) if t < 0.5 else (sh[1] as Vector2).lerp(sh[2], (t - 0.5) * 2.0)
					var sdir := ((sh[2] as Vector2) - (sh[0] as Vector2)).normalized()
					var ang := sdir.angle() + (1.0 if i % 2 == 0 else -1.0) * r.randf_range(0.3, 1.3) + r.randf_range(-0.2, 0.2)
					if t > 0.9:
						ang = r.randf() * TAU   # the terminal rosette spreads all round
					var ll := r.randf_range(0.065, 0.095) * T * (0.85 if back else 1.0)
					var hue := r.randf()
					var col := Color(0.15, 0.21, 0.07)
					if hue > 0.6:
						col = Color(0.22, 0.25, 0.08)
					if hue > 0.85:
						col = Color(0.12, 0.17, 0.08)
					if hue > 0.97:
						col = Color(0.26, 0.19, 0.1)
					col = col * r.randf_range(0.82, 1.12) * (0.72 if back else 1.0)
					var tiltv := Vector2(r.randf_range(-0.7, 0.7), r.randf_range(-0.7, 0.7))
					_leaf(img, at, Vector2.from_angle(ang), ll, ll * 0.34, col, clip, nimg, tiltv, true)
	img.generate_mipmaps()
	nimg.generate_mipmaps()
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(nimg)]

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
func _leaf(img: Image, at: Vector2, dir: Vector2, ln: float, wd: float, col: Color, clip: Rect2i, nimg: Image = null, tiltv := Vector2.ZERO, obovate := false) -> void:
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
			if obovate:
				# oak: narrow at the stalk, widest two thirds out, a rounded tip
				env = pow(sin(PI * pow(clampf(u * 0.97 + 0.03, 0.0, 1.0), 1.4)), 0.75)
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
			if nimg:
				# leaf tilt + a V-fold along the midrib + the blade curling down to the tip
				var side := signf(v) * minf(absf(v) / maxf(hw, 0.001) * 2.0, 1.0)
				var g := tiltv + nrm * side * 0.45 - dir * (u - 0.4) * 0.5
				var nn := Vector3(g.x, -g.y, 1.0).normalized()
				nimg.set_pixel(x, y, Color(nn.x * 0.5 + 0.5, nn.y * 0.5 + 0.5, nn.z * 0.5 + 0.5, 1.0))

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
		_rock_feet.append(Vector3(x, s, z))
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

# ---------------------------------------------------------------- understory

## Ferns and hazel/thorn shrubs under and around the oak groves, so the woods are not
## bare lawn between trunks:
##  - shuttlecock ferns (male fern / lady fern): 9-15 arching fronds from a crown, each a
##    curved strip textured with a painted pinnate frond (pinnae with pinnules) from a
##    4-tile atlas; some outer fronds are browning. Thickest in the shade under crowns,
##    on the grove edges and between outcrop boulders.
##  - shrubs: 4-7 thin stems from the ground with small leaf sprigs (the oak atlas, smaller
##    cards, a fresher tint) on the grove fringe where the crowns open to the meadow.
## Both share the leaf shader (wind, rain wetting, cloud shade, bounce fill) and are chunked
## into 64 m MultiMesh cells with a visibility range so far cells are not drawn.
@export var fern_count: int = 2200
@export var shrub_count: int = 320
const UNDER_CELL := 64.0
var fern_positions: Array[Vector3] = []
var shrub_positions: Array[Vector3] = []

func _scatter_understory() -> void:
	if leaf_material == null:
		return
	var fern_mat := leaf_material.duplicate() as ShaderMaterial
	fern_mat.set_shader_parameter("leaf_tex", _fern_atlas())
	fern_mat.set_shader_parameter("tint", Color(1.0, 1.0, 1.0))
	fern_mat.set_shader_parameter("fill", 2.0)
	fern_mat.set_shader_parameter("trample_gain", 1.0)
	fern_mat.set_shader_parameter("nmap_depth", 0.0)   # fern strips carry no tangents
	var shrub_leaf := leaf_material.duplicate() as ShaderMaterial
	shrub_leaf.set_shader_parameter("tint", Color(1.15, 1.18, 0.95))
	var ferns: Array[ArrayMesh] = []
	for v in 5:
		ferns.append(_build_fern(v, fern_mat))
	var shrubs: Array[ArrayMesh] = []
	for v in 3:
		shrubs.append(_build_shrub(v, shrub_leaf))
	var fern_cells := {}
	var shrub_cells := {}
	var r := RandomNumberGenerator.new()
	r.seed = seed + 900
	# ferns: around trunks (shade), clumped by a patch noise, and among boulders
	var patch := FastNoiseLite.new()
	patch.seed = seed + 17
	patch.frequency = 1.0 / 9.0
	var tries := 0
	while fern_positions.size() < fern_count and tries < fern_count * 12:
		tries += 1
		var anchor: Vector3
		var reach: float
		if r.randf() < 0.82 and not tree_positions.is_empty():
			anchor = tree_positions[r.randi() % tree_positions.size()]
			reach = 11.0
		elif not rock_positions.is_empty():
			anchor = rock_positions[r.randi() % rock_positions.size()]
			reach = 3.5
		else:
			break
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * reach
		var x := anchor.x + cos(a) * d
		var z := anchor.z + sin(a) * d
		if _blocked(x, z, 0.5):
			continue
		if 1.0 - _terrain.normal_at(x, z).y > 0.35:
			continue
		# patchy: ferns grow in drifts, densest under the crown, thinning at the edge
		var pn := patch.get_noise_2d(x, z) * 0.5 + 0.5
		var shade := shelter_at(x, z)
		if r.randf() > smoothstep(0.35, 0.7, pn) * (0.35 + shade):
			continue
		var p := Vector3(x, _terrain.height_at(x, z) - 0.03, z)
		fern_positions.append(p)
		var s := r.randf_range(0.9, 1.5) * lerpf(0.85, 1.2, shade)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.85, 1.15), s))
		var key := Vector2i(floori(x / UNDER_CELL), floori(z / UNDER_CELL))
		if not fern_cells.has(key):
			fern_cells[key] = []
			for v in ferns.size():
				fern_cells[key].append([])
		fern_cells[key][r.randi() % ferns.size()].append(Transform3D(b, p))
	# shrubs: the grove fringe, 5-13 m from a trunk, where the crowns open up
	tries = 0
	while shrub_positions.size() < shrub_count and tries < shrub_count * 20 and not tree_positions.is_empty():
		tries += 1
		var t := tree_positions[r.randi() % tree_positions.size()]
		var a := r.randf() * TAU
		var d := r.randf_range(5.0, 13.0)
		var x := t.x + cos(a) * d
		var z := t.z + sin(a) * d
		if _blocked(x, z, 1.5) or 1.0 - _terrain.normal_at(x, z).y > 0.3:
			continue
		var sh := shelter_at(x, z)
		if sh > 0.6 or r.randf() > 0.25 + sh:
			continue
		var ok := true
		for q in shrub_positions:
			if Vector2(q.x - x, q.z - z).length_squared() < 9.0:
				ok = false
				break
		if not ok:
			continue
		var p := Vector3(x, _terrain.height_at(x, z) - 0.1, z)
		shrub_positions.append(p)
		var s := r.randf_range(0.75, 1.3)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s * r.randf_range(0.9, 1.25), s, s * r.randf_range(0.9, 1.25)))
		var key := Vector2i(floori(x / UNDER_CELL), floori(z / UNDER_CELL))
		if not shrub_cells.has(key):
			shrub_cells[key] = []
			for v in shrubs.size():
				shrub_cells[key].append([])
		shrub_cells[key][r.randi() % shrubs.size()].append(Transform3D(b, p))
	for key: Vector2i in fern_cells:
		for v in ferns.size():
			_multimesh(ferns[v], fern_cells[key][v], "Ferns_%d_%d_%d" % [key.x, key.y, v], 110.0)
	for key: Vector2i in shrub_cells:
		for v in shrubs.size():
			_multimesh(shrubs[v], shrub_cells[key][v], "Shrubs_%d_%d_%d" % [key.x, key.y, v], 220.0)

## One shuttlecock fern: fronds rise from the crown, arch out and droop at the tip. Each
## frond is a strip along its curved rachis, slightly V-folded (the pinnae angle up from
## the rachis), with the frond tile of the atlas mapped along it.
func _build_fern(v: int, mat: Material) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7 + 300 + v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := r.randi_range(9, 15)
	var phase0 := r.randf() * TAU
	const SEG := 8
	for f in fronds:
		var a := phase0 + f * TAU / fronds + r.randf_range(-0.25, 0.25)
		var out := Vector3(cos(a), 0, sin(a))
		var inner := f % 3 == 0          # younger, more upright fronds in the middle
		var ln := r.randf_range(0.9, 1.4) * (0.8 if inner else 1.0)
		var rise := r.randf_range(0.95, 1.35) if inner else r.randf_range(0.55, 0.95)   # initial elevation (rad from horizontal)
		var droop := r.randf_range(1.2, 1.9)                      # how much the arch bends down
		var wd := ln * r.randf_range(0.28, 0.36)                  # blade width at its widest
		var tile := r.randi() % 3
		if not inner and r.randf() < 0.22:
			tile = 3                                               # an outer frond going brown
		var u0 := tile * 0.25
		var side := out.cross(Vector3.UP).normalized()
		var twist := r.randf_range(-0.25, 0.25)
		var fold := 0.35                                           # V-fold: edges lifted
		var pts: Array = []
		var p := Vector3(cos(a), 0, sin(a)) * 0.04
		for i in SEG + 1:
			var t := float(i) / SEG
			pts.append(p)
			var el := rise - droop * t * t
			var dir := out * cos(el) + Vector3.UP * sin(el)
			p += dir * ln / SEG
		for i in SEG:
			var rows: Array = []
			for k in 2:
				var j := i + k
				var t := float(j) / SEG
				var c: Vector3 = pts[j]
				var fwd: Vector3 = (pts[mini(j + 1, SEG)] - pts[maxi(j - 1, 0)]).normalized()
				var sd := side.rotated(fwd, twist * t)
				var up := sd.cross(fwd).normalized()
				if up.y < 0.0:
					up = -up
				# frond outline: a short bare stipe, widest at 35 %, tapering to the tip
				var w := wd * (0.0 if t < 0.08 else pow(sin(PI * clampf((t - 0.08) / 0.92 * 0.9 + 0.1, 0.0, 1.0)), 0.8))
				var sway := 0.15 + 0.75 * t
				var nrm := up.lerp(Vector3.UP, 0.45).normalized()
				var l := c - sd * w * 0.5 + up * w * fold * 0.5
				var rr := c + sd * w * 0.5 + up * w * fold * 0.5
				rows.append([l, rr, c, t, sway, nrm])
			var ph := r.randf()
			var r0: Array = rows[0]
			var r1: Array = rows[1]
			# two quads per segment (left half, right half) so the V-fold is real geometry
			var quads := [[r0[0], r0[2], r1[2], r1[0], 0.0, 0.5], [r0[2], r0[1], r1[1], r1[2], 0.5, 1.0]]
			for q in quads:
				var vs := [[q[0], Vector2(u0 + q[4] * 0.25, 1.0 - r0[3]), r0[4], r0[5]],
					[q[1], Vector2(u0 + q[5] * 0.25, 1.0 - r0[3]), r0[4], r0[5]],
					[q[2], Vector2(u0 + q[5] * 0.25, 1.0 - r1[3]), r1[4], r1[5]],
					[q[3], Vector2(u0 + q[4] * 0.25, 1.0 - r1[3]), r1[4], r1[5]]]
				for idx in [0, 1, 2, 0, 2, 3]:
					var vv: Array = vs[idx]
					st.set_color(Color(vv[2], ph, 0))
					st.set_normal(vv[3])
					st.set_uv(vv[1])
					st.add_vertex(vv[0])
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

## A hazel/thorn shrub: a handful of thin stems fanning out of one root, each ending in a
## few small leaf sprigs, with extra sprigs along the stems so it reads as a dense bush.
func _build_shrub(v: int, leaf_mat: Material) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 11 + 500 + v
	_bark = SurfaceTool.new()
	_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_leaves = SurfaceTool.new()
	_leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var keep_crown := _crown
	_card_scale = 0.42
	_canopy_c = Vector3(0, 0.9, 0)
	_cards.clear()
	var stems := r.randi_range(4, 7)
	for k in stems:
		var a := r.randf() * TAU
		var dir := Vector3(cos(a) * r.randf_range(0.25, 0.6), 1.0, sin(a) * r.randf_range(0.25, 0.6)).normalized()
		var ln := r.randf_range(1.1, 1.9)
		var pts: Array[Vector3] = []
		var p := Vector3(cos(a), 0, sin(a)) * 0.08
		var d := dir
		for i in 6:
			pts.append(p)
			d = (d + Vector3(r.randf_range(-0.12, 0.12), -0.04, r.randf_range(-0.12, 0.12))).normalized()
			p += d * ln / 5.0
		_tube(pts, 0.035, 0.012, 5, 0.1, 0.7, false)
		var tip := pts[pts.size() - 1]
		_leaf_cluster(r, tip, d, 0.75, 9)
		_leaf_cluster(r, pts[3], d, 0.55, 6)
		_leaf_cluster(r, pts[2] + Vector3(r.randfn(0, 0.2), 0, r.randfn(0, 0.2)), d, 0.45, 4)
	_emit_leaves(0.5)
	_card_scale = 1.0
	_crown = keep_crown
	var mesh := ArrayMesh.new()
	_bark.generate_tangents()
	_bark.commit(mesh)
	_leaves.generate_tangents()
	_leaves.commit(mesh)
	if bark_material:
		mesh.surface_set_material(0, bark_material)
	mesh.surface_set_material(1, leaf_mat)
	return mesh

## 1024x1024 atlas of 4 frond tiles (256 x 1024, base at the bottom): a rachis with
## alternate pinnae that shorten toward the tip, each pinna a row of rounded pinnules.
## Tiles 0-2 are green (varied), tile 3 is a frond turning russet at the end of summer.
func _fern_atlas() -> ImageTexture:
	const W := 256
	const H := 1024
	var img := Image.create(W * 4, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.14, 0.2, 0.06, 0.0))
	var r := RandomNumberGenerator.new()
	r.seed = 91
	for tile in 4:
		var ox := tile * W
		var clip := Rect2i(ox, 0, W, H)
		var base_col: Color = [Color(0.2, 0.33, 0.08), Color(0.24, 0.36, 0.09), Color(0.18, 0.3, 0.07), Color(0.42, 0.28, 0.11)][tile]
		var cx := ox + W * 0.5
		# rachis
		_line(img, Vector2(cx, H - 1), Vector2(cx, 8), 2.0, base_col.darkened(0.35).lerp(Color(0.3, 0.26, 0.12), 0.4))
		var y := float(H) * 0.93
		while y > 20.0:
			for side in [-1.0, 1.0]:
				var t := 1.0 - y / H                          # 0 base .. 1 tip (pinnae nearly opposite)
				var env := pow(sin(PI * clampf((t - 0.04) / 0.96 * 0.9 + 0.1, 0.0, 1.0)), 0.8)
				var pl := (W * 0.48) * env                     # pinna length to the tile edge
				if pl > 6.0:
					var ang := -0.32 - 0.25 * t                # pinnae angle toward the tip
					var dir := Vector2(side * cos(ang), sin(ang))
					var at := Vector2(cx, y + side * 5.0)
					var col := base_col * r.randf_range(0.85, 1.15)
					if tile == 3:
						col = col.lerp(Color(0.2, 0.22, 0.07), clampf(0.7 - t, 0.0, 1.0) * 0.6)
					_line(img, at, at + dir * pl, 1.0, col.darkened(0.2))
					var nr := maxi(2, int(pl / 9.0))
					for k in nr:
						var u := (k + 0.6) / nr
						var pp := at + dir * pl * u
						var sz := (1.0 - u * 0.6) * minf(pl * 0.22, 11.0) + 2.0
						var nrm := Vector2(-dir.y, dir.x)
						for sgn in [-1.0, 1.0]:
							_leaf(img, pp, (dir * 0.45 + nrm * sgn).normalized(), sz * 1.25, sz * 0.5, col * r.randf_range(0.9, 1.1), clip)
			y -= maxf(10.0, 30.0 * (1.0 - (1.0 - y / H) * 0.6))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- shared

func _multimesh(mesh: Mesh, xfs: Array, nm: String, vis_end := 0.0) -> void:
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
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 15.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
