class_name DoorStones
extends Node3D
## Flat stepping stones worn into the turf outside each house door: a few split field slabs
## (YardWall's stone mesh, flattened) laid along the first couple of metres of the trodden
## track from the door, each set a step apart and a little to the left or right foot, sunk
## so only a lip stands proud of the dirt. The village walks to its doors on stone, not
## mud, and the tracks' puddles after rain lie round them.

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 7373

const VARIANTS := 5
const START := 0.55       # first stone's centre, metres along the track from the door
const PACE := 0.82        # stone to stone along the track
const PROUD := 0.015      # the top's lip above the ground
const THICK := 0.055

var stone_count := 0
var stones: Array[Vector3] = []    # world centre of each slab's top (bots)
var _terrain: Terrain
var _per: Array = []
var bounces: Array[OmniLight3D] = []   # daylight thrown back off each door's trodden yard

## The tracks out of each door, as world xz polylines starting at the door.
static func runs() -> Array:
	var out := []
	# the stone cottage: its door out across the yard toward the cart gateway
	var sc := PackedVector2Array()
	for l: Vector2 in YardGround.PATHS_LOCAL[1]:
		sc.append(DryWall._to_world(l))
	out.append([sc, 4])
	# the white cottage and the timber house: the village tracks that start at their doors
	for k in 2:
		var w := PackedVector2Array()
		for q: Array in YardGround.TRACKS[k]:
			w.append(q[0])
		out.append([w, 3])
	return out

## Point and direction `s` metres along a polyline.
static func along(w: PackedVector2Array, s: float) -> Array:
	for i in w.size() - 1:
		var l := w[i].distance_to(w[i + 1])
		if s <= l or i == w.size() - 2:
			var d := (w[i + 1] - w[i]) / maxf(l, 1e-4)
			return [w[i] + d * minf(s, l), d]
		s -= l
	return [w[w.size() - 1], Vector2(0, 1)]

## The slabs' layout in plan, worked out once from the seed alone (no terrain), so grass and
## the foley can ask where the stones lie before or without the node: per slab
## [centre xz, track dir, right, size, yaw, tilt x, tilt z, flipped, variant, tint].
static var _plan: Array = []

static func plan() -> Array:
	if not _plan.is_empty():
		return _plan
	var rng := RandomNumberGenerator.new()
	rng.seed = 7373
	for r in runs():
		var w: PackedVector2Array = r[0]
		var s := START + rng.randf_range(-0.05, 0.08)
		for i in r[1]:
			var a: Array = along(w, s)
			var q: Vector2 = a[0]
			var d: Vector2 = a[1]
			var right := Vector2(-d.y, d.x)
			# a step for the left foot, then the right: the slabs wander either side of the line
			q += right * (0.07 if i % 2 == 0 else -0.07) + right * rng.randf_range(-0.04, 0.04)
			# the last one out is smaller, half lost in the dirt where the track runs on
			# broad flags laid across the track (x along it, z across): wide enough to take a
			# whole foot and then some, thin field slabs split along their bedding
			var sz := Vector3(rng.randf_range(0.52, 0.64), THICK, rng.randf_range(0.72, 0.9))
			if i == r[1] - 1:
				sz *= Vector3(0.82, 1.0, 0.85)
			var yaw := atan2(right.x, right.y) + rng.randf_range(-0.35, 0.35)
			var tx := rng.randf_range(-0.03, 0.03)
			var tz := rng.randf_range(-0.03, 0.03)
			var flip := rng.randf() < 0.5
			_plan.append([q, d, right, sz, yaw, tx, tz, flip, rng.randi() % VARIANTS, rng.randf()])
			s += PACE + rng.randf_range(-0.06, 0.06)
	return _plan

## Whether (x, z) lies on a slab, its footprint grown by `margin` metres (negative shrinks).
static func under(x: float, z: float, margin := 0.0) -> bool:
	for sl: Array in plan():
		var c: Vector2 = sl[0]
		var o := Vector2(x, z) - c
		var sz: Vector3 = sl[3]
		if o.length_squared() > pow(0.6 + maxf(margin, 0.0), 2.0):   # cheap reject: < 0.6 m centre to corner
			continue
		var bx := Vector2(cos(sl[4]), -sin(sl[4]))      # the slab's own x axis in xz (Basis(UP, yaw))
		var bz := Vector2(sin(sl[4]), cos(sl[4]))
		if absf(o.dot(bx)) <= sz.x * 0.5 + margin and absf(o.dot(bz)) <= sz.z * 0.5 + margin:
			return true
	return false

## How close (x, z) lies to the stones: 1 within `inner` metres of a slab's centre, 0 past
## `outer`. The tall meadow clumps thin and shorten in this band so they do not lean over the
## slabs and bury them (wide enough that a storm gust laying a metre-tall clump flat from its
## edge still falls short of the flags and the pools along them).
static func near(x: float, z: float, inner := 0.75, outer := 1.75) -> float:
	var best := INF
	for sl: Array in plan():
		var c: Vector2 = sl[0]
		best = minf(best, Vector2(x - c.x, z - c.y).length_squared())
	if best > outer * outer:
		return 0.0
	return 1.0 - smoothstep(inner, outer, sqrt(best))

func _ready() -> void:
	var ruins: Ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	var meshes: Array[ArrayMesh] = []
	for v in VARIANTS:
		# flat flags: tight arrises worn by feet, a broad level top, the edges broken by a
		# couple of plumb splits so the outline is a split slab's, not a pebble's
		meshes.append(YardWall.stone_mesh(seed, v, ruins.material, 0.07, 0.035, 0.43, 0.49, false, Vector2i(2, 3), false, true))
		_per.append([])
	for sl: Array in plan():
		_lay(sl)
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Slabs_%d" % v)
	_gaps()
	_pools()
	_bounce()

## The doorways sit in the house's own shadow, and with only the sky ambient the reveal and
## the stones under it went blue-black at midday. A real doorway is lit from below by the
## sunlit yard in front of it: a broad, soft, unshadowed warm fill a metre out from each door,
## low, that follows the sun's strength and dies at dusk.
func _bounce() -> void:
	for r in runs():
		var w: PackedVector2Array = r[0]
		var a: Array = along(w, 1.3)
		var q: Vector2 = a[0]
		var l := OmniLight3D.new()
		l.name = "DoorBounce"
		l.shadow_enabled = false
		l.omni_range = 3.6
		l.omni_attenuation = 1.6
		l.light_color = Color(1.0, 0.86, 0.68)
		l.light_specular = 0.05
		l.light_energy = 0.0
		l.position = Vector3(q.x, _terrain.height_at(q.x, q.y) + 0.45, q.y)
		add_child(l)
		bounces.append(l)

func _process(_delta: float) -> void:
	var world := get_parent()
	if not ("sun" in world) or world.sun == null:
		return
	# the sun's 0..3 energy; overcast already dims it, and wet dark ground throws back less
	var e: float = clampf(world.sun.light_energy / 3.0, 0.0, 1.0) * 0.55
	if "weather" in world and world.weather != null:
		e *= 1.0 - 0.3 * world.weather.wet
	for l in bounces:
		l.light_energy = e
		l.visible = e > 0.01

func _lay(sl: Array) -> void:
	var q: Vector2 = sl[0]
	var d: Vector2 = sl[1]
	var right: Vector2 = sl[2]
	var sz: Vector3 = sl[3]
	# the slab's low corner sets it: sample the ground under its footprint
	var g := INF
	var hi := -INF
	for c in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2.ZERO]:
		var p: Vector2 = q + right * c.x * sz.x + d * c.y * sz.z
		var h := _terrain.height_at(p.x, p.y)
		g = minf(g, h)
		hi = maxf(hi, h)
	var top := lerpf(g, hi, 0.6) + PROUD
	var b := Basis(Vector3.UP, sl[4])
	b = b.rotated(b.x, sl[5]).rotated(b.z, sl[6])
	var sc := sz
	if sl[7]:
		sc = Vector3(-sc.x, sc.y, -sc.z)   # flipped so the same splits do not repeat
	var c3 := Vector3(q.x, top - THICK * 0.5, q.y) - global_position
	_per[sl[8]].append([Transform3D(b * Basis.from_scale(sc), c3), Color(-0.125, sl[9], 0.0, 2.0)])
	stones.append(Vector3(q.x, top, q.y))
	stone_count += 1

## The dirt packed into the crack round each slab: one patch of ground-hugging grid per slab,
## a hand's breadth bigger than it, draped on the terrain just above the track's dirt. The
## patch runs on another `POOL` past the dirt so rain can lie in pools along the slab's edges.
const GAP := 0.07
const POOL := 0.2
func _gaps() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	for sl: Array in plan():
		var q: Vector2 = sl[0]
		var sz: Vector3 = sl[3]
		var bx := Vector2(cos(sl[4]), -sin(sl[4]))
		var bz := Vector2(sin(sl[4]), cos(sl[4]))
		var hx := sz.x * 0.5 + GAP + POOL
		var hz := sz.z * 0.5 + GAP + POOL
		var verts := []
		for i in n + 1:
			for j in n + 1:
				var lx := lerpf(-hx, hx, float(i) / n)
				var lz := lerpf(-hz, hz, float(j) / n)
				var p := q + bx * lx + bz * lz
				verts.append([Vector3(p.x, _terrain.height_at(p.x, p.y) + 0.008, p.y) - global_position, Vector2(lx, lz)])
		var idx := []
		for i in n:
			for j in n:
				var a := i * (n + 1) + j
				idx.append_array([a, a + n + 1, a + 1, a + 1, a + n + 1, a + n + 2])
		for k: int in idx:
			st.set_normal(Vector3.UP)
			st.set_uv(verts[k][1])
			st.set_uv2(Vector2(sz.x, sz.z) * 0.5)
			st.add_vertex(verts[k][0])
	var mi := MeshInstance3D.new()
	mi.name = "Gaps"
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stone_gap.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## The rain pools themselves: an opaque skin (so screen-space reflections take it) on a fine
## ring of ground round each slab, out to `POOL_OUT` past its edges. Each vertex carries its
## metres out past the slab's edge in COLOR.r (/ POOL_OUT) -- the shader cuts the lobed pool
## out of the ring from that and discards the rest, and all of it while the ground is dry.
const POOL_OUT := 0.24
const POOL_CELL := 0.035
func _pools() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sl: Array in plan():
		var q: Vector2 = sl[0]
		var sz: Vector3 = sl[3]
		var bx := Vector2(cos(sl[4]), -sin(sl[4]))
		var bz := Vector2(sin(sl[4]), cos(sl[4]))
		var h := Vector2(sz.x, sz.z) * 0.5
		var e := h + Vector2(POOL_OUT, POOL_OUT)
		var nx := ceili(e.x * 2.0 / POOL_CELL)
		var nz := ceili(e.y * 2.0 / POOL_CELL)
		var at := func(i: int, j: int) -> Array:
			var l := Vector2(lerpf(-e.x, e.x, float(i) / nx), lerpf(-e.y, e.y, float(j) / nz))
			var p := q + bx * l.x + bz * l.y
			var out := maxf(absf(l.x) - h.x, absf(l.y) - h.y)
			return [Vector3(p.x, _terrain.height_at(p.x, p.y) + 0.006, p.y) - global_position,
				clampf(out / POOL_OUT, 0.0, 1.0)]
		for i in nx:
			for j in nz:
				# skip the cells wholly under the slab
				var cx := absf(lerpf(-e.x, e.x, (i + 0.5) / nx))
				var cz := absf(lerpf(-e.y, e.y, (j + 0.5) / nz))
				if cx < h.x - POOL_CELL and cz < h.y - POOL_CELL:
					continue
				var a: Array = at.call(i, j)
				var b: Array = at.call(i + 1, j)
				var c: Array = at.call(i, j + 1)
				var d: Array = at.call(i + 1, j + 1)
				for v: Array in [a, c, b, b, c, d]:
					st.set_normal(Vector3.UP)
					st.set_color(Color(v[1], 0.0, 0.0, 1.0))
					st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.name = "Pools"
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stone_pool.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Top of the slab under (x, z), or NAN off the stones (the foley's footsteps).
func top_at(x: float, z: float) -> float:
	if not under(x, z, 0.03):
		return NAN
	var best := NAN
	var bd := INF
	for q in stones:
		var dd := Vector2(q.x - x, q.z - z).length_squared()
		if dd < bd:
			bd = dd
			best = q.y
	return best

func _multimesh(mesh: Mesh, items: Array, nm: String) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_custom_data(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
