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
const PACE := 0.74        # stone to stone along the track
const PROUD := 0.015      # the top's lip above the ground
const THICK := 0.07

var stone_count := 0
var stones: Array[Vector3] = []    # world centre of each slab's top (bots)
var _terrain: Terrain
var _per: Array = []

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
			var sz := Vector3(rng.randf_range(0.58, 0.72), THICK, rng.randf_range(0.46, 0.56))
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
		if o.length_squared() > pow(0.47 + maxf(margin, 0.0), 2.0):   # cheap reject: < 0.47 m centre to corner
			continue
		var bx := Vector2(cos(sl[4]), -sin(sl[4]))      # the slab's own x axis in xz (Basis(UP, yaw))
		var bz := Vector2(sin(sl[4]), cos(sl[4]))
		if absf(o.dot(bx)) <= sz.x * 0.5 + margin and absf(o.dot(bz)) <= sz.z * 0.5 + margin:
			return true
	return false

## How close (x, z) lies to the stones: 1 within `inner` metres of a slab's centre, 0 past
## `outer`. The tall meadow clumps thin and shorten in this band so they do not lean over the
## slabs and bury them.
static func near(x: float, z: float, inner := 0.4, outer := 1.05) -> float:
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
		# squarish slabs: rounder arrises worn by feet, only a couple of shallow splits
		meshes.append(YardWall.stone_mesh(seed, v, ruins.material, 0.2, 0.05, 0.42, 0.49, true, Vector2i(2, 3)))
		_per.append([])
	for sl: Array in plan():
		_lay(sl)
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Slabs_%d" % v)

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
