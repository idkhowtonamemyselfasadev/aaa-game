class_name SentinelPlinth
extends Node3D
## The Stone Sentinel's post: a square two-step plinth of dressed granite the statue was set up
## on long ago, so at range it reads as a monument and not a man standing in a field. A broad
## lower course, a narrower upper course and a chamfered capstone the statue's feet stand on;
## one corner of the lower course has cracked off and lies tipped in the turf beside it, with a
## few spalls. The stones are the ruins' dressed blocks under the same weathered masonry
## material (lichen, moss, a dark crust), instanced and not colliding; one low frustum collider
## ramps up over both steps so the statue can step down off its post when it wakes and walk
## back up onto it to go still again (the controller has no step-up), and the hero can climb it.

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 6262

const LOW_HALF := 1.2        # half-width of the lower course (m)
const LOW_DEPTH := 0.46      # how far the lower course's blocks run in from its face
const UP_HALF := 0.82        # half-width of the upper course
const CAP_HALF := 0.72       # half-width of the capstone
const STEP := 0.24           # rise of each course
const CAP := 0.12            # capstone thickness
const RAMP_OUT := 2.05       # the collider meets the turf this far from the centre

var centre := Vector3.ZERO
var top_y := 0.0             # the capstone's top: where the statue stands (bots)
var block_count := 0
var spalls := 0
var _per: Array = []
var _cut := {}          # size -> dressed block mesh cut to it
var _cut_per := {}      # size -> instances
var _terrain: Terrain
## Plan of the plinth for the grass mask: centre xz, yaw; INF until built.
static var plan_centre := Vector2.INF
static var plan_yaw := 0.0

## Lay the plinth round `c` (world), square to `yaw` (the statue's facing). Returns top_y.
func build(c: Vector3, yaw: float) -> float:
	var ruins: Ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	centre = Vector3(c.x, _terrain.height_at(c.x, c.z), c.z)
	plan_centre = Vector2(c.x, c.z)
	plan_yaw = yaw
	var b := Basis(Vector3.UP, yaw)
	var meshes: Array[ArrayMesh] = ruins.block_meshes
	var dims: Array[Vector3] = ruins.block_dims
	for v in meshes.size():
		_per.append([])
	# the ground under the footprint: the base goes in below its lowest point
	var lo := INF
	var hi := -INF
	for k in 16:
		var a := TAU * k / 16.0
		for rr in [0.0, LOW_HALF, LOW_HALF * 1.42]:
			var g := _terrain.height_at(c.x + cos(a) * rr, c.z + sin(a) * rr)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	var base := lo - 0.14
	# set into the slope: the uphill edge of the lower course stands only a lip proud
	var t1 := maxf(centre.y + STEP, hi + 0.07)
	var t2 := t1 + STEP
	top_y = t2 + CAP
	# lower course: four long blocks round the square (each side split in two where the run
	# is long), run in LOW_DEPTH from the face; the corner on the statue's right-rear has
	# cracked off and lies in the turf
	var broken_side := 1
	for side in 4:
		var yaw_s := yaw + side * PI * 0.5
		var bs := Basis(Vector3.UP, yaw_s)
		var out := bs.z          # the face looks out along local +z of this side
		var along := bs.x
		var length := LOW_HALF * 2.0 - LOW_DEPTH      # corners lap: each side owns one corner
		var pieces := 2
		var y := base
		var course := 0
		while y < t1 - 0.02:
			var h := minf(0.3, t1 - y)
			var crest := y + h >= t1 - 0.02
			for i in pieces:
				var seg := length / pieces
				var s0 := -LOW_HALF + seg * (i + 0.5)
				var p := centre + out * (LOW_HALF - LOW_DEPTH * 0.5) + along * s0
				p.y = y + h * 0.5
				var tilt := Vector3.ZERO
				if crest:
					tilt = Vector3(rng.randfn() * 0.012, 0.0, rng.randfn() * 0.012)
					p.y -= absf(rng.randfn()) * 0.012     # settled treads
				var size := Vector3(seg - 0.022, h - 0.014, LOW_DEPTH)
				if crest and side == broken_side and i == pieces - 1:
					# the cracked-off corner: the block left in place is short, its piece lies below
					size.x *= 0.62
					p -= along * seg * 0.19
					_fallen_corner(centre + out * (LOW_HALF + 0.55) + along * (LOW_HALF + 0.1), yaw_s, Vector3(seg * 0.4, h, LOW_DEPTH), rng)
				_put(meshes, dims, p, bs * Basis.from_euler(tilt), size, y - centre.y, rng)
			y += h
			course += 1
	# the lower course's core under the upper course (hidden but keeps the tread from reading hollow)
	_put(meshes, dims, Vector3(centre.x, (base + t1) * 0.5 - 0.01, centre.z), b,
			Vector3(LOW_HALF * 2.0 - LOW_DEPTH * 2.0 + 0.02, t1 - base - 0.03, LOW_HALF * 2.0 - LOW_DEPTH * 2.0 + 0.02), 0.0, rng)
	# upper course: four blocks, one per side, lapped at the corners
	for side in 4:
		var bs := Basis(Vector3.UP, yaw + side * PI * 0.5 + rng.randfn() * 0.006)
		var p := centre + bs.z * (UP_HALF - 0.2) + bs.x * (-0.2)
		p.y = t1 + STEP * 0.5
		_put(meshes, dims, p, bs, Vector3(UP_HALF * 2.0 - 0.4 - 0.02, STEP - 0.014, 0.4), t1 - centre.y, rng)
	_put(meshes, dims, Vector3(centre.x, t1 + STEP * 0.5, centre.z), b,
			Vector3(UP_HALF * 2.0 - 0.8, STEP - 0.02, UP_HALF * 2.0 - 0.8), t1 - centre.y, rng)
	# capstone: one broad slab, a hair askew, its edge proud of the upper course
	_put(meshes, dims, Vector3(centre.x, t2 + CAP * 0.5, centre.z), b.rotated(Vector3.UP, 0.015),
			Vector3(CAP_HALF * 2.0, CAP, CAP_HALF * 2.0), t2 - centre.y, rng)
	# spalls off the broken corner and the treads' edges, half sunk in the turf
	for k in 5:
		var a := yaw + rng.randf_range(0.2, 1.5)
		var r := rng.randf_range(LOW_HALF + 0.25, LOW_HALF + 1.1)
		var q := Vector3(centre.x + sin(a) * r, 0, centre.z + cos(a) * r)
		q.y = _terrain.height_at(q.x, q.z) + 0.02
		var s := rng.randf_range(0.12, 0.26)
		_put(meshes, dims, q, Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)),
				Vector3(s, s * 0.55, s * 0.8), 0.0, rng, false)
		spalls += 1
	for v in meshes.size():
		_multimesh(meshes[v], _per[v], "Spalls_%d" % v)
	var ci := 0
	for key in _cut:
		_multimesh(_cut[key], _cut_per[key], "Plinth_%d" % ci)
		ci += 1
	_collider(t1)
	return top_y

## The corner piece that split away: tipped on its edge, half sunk in the turf.
func _fallen_corner(at: Vector3, yaw_s: float, size: Vector3, rng: RandomNumberGenerator) -> void:
	var ruins: Ruins = get_node(ruins_path)
	var g := _terrain.height_at(at.x, at.z)
	var bb := Basis(Vector3.UP, yaw_s + 0.7) * Basis.from_euler(Vector3(0.35, 0.0, -0.22))
	_put(ruins.block_meshes, ruins.block_dims, Vector3(at.x, g + size.y * 0.22, at.z), bb, size, 0.0, rng, false)

## Dressed blocks are cut to size (a mesh per size, crisp arrises, light chipping) so the
## plinth reads as squared, tooled granite; spalls and the broken corner use the ruins' rubble.
func _put(meshes: Array[ArrayMesh], dims: Array[Vector3], p: Vector3, bas: Basis, size: Vector3, above: float, rng: RandomNumberGenerator, dressed := true) -> void:
	var v := rng.randi() % meshes.size()
	var d: Vector3 = dims[v]
	if dressed:
		var key := size.snapped(Vector3.ONE * 0.04)
		if not _cut.has(key):
			var ruins: Ruins = get_node(ruins_path)
			var bev := minf(0.028, key.y * 0.25)
			_cut[key] = ruins._block_mesh(key, 40 + _cut.size() % 8, bev, 0.55)
			_cut_per[key] = []
		d = key
		var scd := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
		var xfd := Transform3D(bas.orthonormalized() * Basis.from_scale(scd), p - global_position)
		_cut_per[key].append([xfd, Color(clampf(above / 8.0, 0.0, 1.0), rng.randf(), 1.0, 1.0)])
		block_count += 1
		return
	var sc := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
	if rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(bas.orthonormalized() * Basis.from_scale(sc), p - global_position)
	# masonry custom data: r = height above ground / 8 m, g = random, b = 1 laid course,
	# a = 1 long out in the weather (crust, moss, lichen)
	_per[v].append([xf, Color(clampf(above / 8.0, 0.0, 1.0), rng.randf(), 1.0, 1.0)])
	block_count += 1

## A frustum from the turf RAMP_OUT out up onto the capstone: both steps walk as one slope.
func _collider(t1: float) -> void:
	var pts := PackedVector3Array()
	for k in 24:
		var a := TAU * k / 24.0
		var dv := Vector3(cos(a), 0, sin(a))
		var go := _terrain.height_at(centre.x + dv.x * RAMP_OUT, centre.z + dv.z * RAMP_OUT)
		var gm := _terrain.height_at(centre.x + dv.x * LOW_HALF, centre.z + dv.z * LOW_HALF)
		pts.append(centre + dv * RAMP_OUT + Vector3.UP * (go - 0.3 - centre.y))
		pts.append(centre + dv * LOW_HALF + Vector3.UP * (maxf(t1, gm + 0.03) - centre.y))
		pts.append(centre + dv * (CAP_HALF * 0.85) + Vector3.UP * (top_y - centre.y))
	for i in pts.size():
		pts[i] -= global_position
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.name = "Plinth"
	cs.shape = shape
	body.add_child(cs)

## Whether (x, z) lies under the plinth's footprint grown by `margin` (grass, flowers).
static func under(x: float, z: float, margin: float) -> bool:
	if plan_centre == Vector2.INF:
		return false
	var d := Vector2(x, z) - plan_centre
	var l := d.rotated(plan_yaw)
	return absf(l.x) < LOW_HALF + margin and absf(l.y) < LOW_HALF + margin

func _exit_tree() -> void:
	if plan_centre == Vector2(centre.x, centre.z):
		plan_centre = Vector2.INF

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
