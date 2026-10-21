class_name RutStones
extends Node3D
## Stones along Wat's cart track (YardGround.ROAD): where the iron tyres have cut the wheel
## ruts down through the turf they have bared the stony subsoil, so the rut beds show patches
## of rounded cobbles and gravel, half-sunk, scoured clean on top by the wheels (trodden
## field stone: no moss or lichen on the tops). Out on the verges lie a few bigger field
## stones the carters have levered out of the ruts over the years and rolled aside, half in
## the sward, mossed and lichened, a cart-wheel's knock or two whitening their road side.

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 4141

const COBBLE_VARIANTS := 4
const BOULDER_VARIANTS := 3
const STEP := 0.09          # rut-bed sample spacing (m) along each rut

var cobble_count := 0
var boulder_count := 0
var cobbles: Array[Vector3] = []    # world centre of each stone's top (bots)
var boulders: Array[Vector3] = []
var _terrain: Terrain
var _per_c: Array = []
var _per_b: Array = []

static var _plan_c: Array = []      # [xz, size, yaw, tilt x, tilt z, variant, tint]
static var _plan_b: Array = []

## Patchiness 0..1 along the track: the ruts are stony where the subsoil comes up in bands.
static func _patch(s: float, side: float) -> float:
	var v := 0.5 + 0.3 * sin(s * 0.83 + side * 1.7) + 0.2 * sin(s * 2.31 + 0.6 + side * 0.4)
	return smoothstep(0.42, 0.78, v)

## Both plans worked out once from the seed alone (no terrain), so the grass and the
## flowers can ask where the stones lie before or without the node.
static func plan() -> void:
	if not _plan_c.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4141
	# cobbles in the rut beds
	for r in YardGround.road_ruts():
		var w: PackedVector2Array = r[0]
		var e: PackedFloat32Array = r[1]
		var side: float = -1.0 if _plan_c.is_empty() else 1.0
		var s0 := 0.0
		for i in w.size() - 1:
			var l := w[i].distance_to(w[i + 1])
			var d := (w[i + 1] - w[i]) / maxf(l, 1e-4)
			var right := d.orthogonal()
			var t := 0.0
			while t < l:
				var wear := lerpf(e[i], e[i + 1], t / l)
				var p := smoothstep(0.45, 0.72, wear) * _patch(s0 + t, side)
				if rng.randf() < p * 0.75:
					var q := w[i] + d * t + right * rng.randf_range(-0.15, 0.15)
					var big := rng.randf() < 0.15
					var a := rng.randf_range(0.05, 0.09) * (1.6 if big else 1.0)
					var sz := Vector3(a * rng.randf_range(0.9, 1.4), a * rng.randf_range(0.5, 0.75), a * rng.randf_range(0.8, 1.15))
					_plan_c.append([q, sz, rng.randf() * TAU, rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25), rng.randi() % COBBLE_VARIANTS, rng.randf()])
				t += STEP * rng.randf_range(0.6, 1.4)
			s0 += l
	# levered-out stones on the verges, every several metres along the worn stretch
	var road: Array = YardGround.ROAD
	var s := 3.0
	var sidek := 1.0
	for i in road.size() - 1:
		var a2: Vector2 = road[i][0]
		var b2: Vector2 = road[i + 1][0]
		var l := a2.distance_to(b2)
		var d := (b2 - a2) / maxf(l, 1e-4)
		while s < l:
			var wear := lerpf(road[i][1], road[i + 1][1], s / l)
			if wear > 0.4:
				sidek = -sidek if rng.randf() < 0.7 else sidek
				var q := a2 + d * s + d.orthogonal() * sidek * rng.randf_range(1.25, 1.75)
				var a := rng.randf_range(0.24, 0.42)
				var sz := Vector3(a * rng.randf_range(1.0, 1.35), a * rng.randf_range(0.55, 0.75), a * rng.randf_range(0.75, 1.0))
				_plan_b.append([q, sz, rng.randf() * TAU, rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12), rng.randi() % BOULDER_VARIANTS, rng.randf()])
				# now and then a second, smaller one rolled against it
				if rng.randf() < 0.35:
					var q2 := q + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * a * 0.9
					_plan_b.append([q2, sz * 0.55, rng.randf() * TAU, 0.1, -0.08, rng.randi() % BOULDER_VARIANTS, rng.randf()])
			s += rng.randf_range(4.5, 8.0)
		s -= l

static func cobble_plan() -> Array:
	plan()
	return _plan_c

static func boulder_plan() -> Array:
	plan()
	return _plan_b

## Whether (x, z) lies under a verge stone's footprint grown by `margin` metres.
static func under(x: float, z: float, margin := 0.0) -> bool:
	if x < -11.0 or x > 23.0 or z < -30.0 or z > 4.5:
		return false
	for b: Array in boulder_plan():
		var c: Vector2 = b[0]
		var sz: Vector3 = b[1]
		var r := maxf(sz.x, sz.z) * 0.5 + margin
		if Vector2(x - c.x, z - c.y).length_squared() < r * r:
			return true
	return false

func _ready() -> void:
	var ruins: Ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	var cm: Array[ArrayMesh] = []
	for v in COBBLE_VARIANTS:
		# water-worn cobbles: well rounded, lumpy, one or two old fractures
		cm.append(YardWall.stone_mesh(seed, v, ruins.material, 0.36, 0.06, 0.44, 0.5, false, Vector2i(1, 2)))
		_per_c.append([])
	var bm: Array[ArrayMesh] = []
	for v in BOULDER_VARIANTS:
		# field stones: blocky, a few split faces, softened arrises
		bm.append(YardWall.stone_mesh(seed + 50, v, ruins.material, 0.2, 0.07, 0.38, 0.47, false, Vector2i(2, 4)))
		_per_b.append([])
	for c: Array in cobble_plan():
		_lay(c, true)
	for b: Array in boulder_plan():
		_lay(b, false)
	for v in COBBLE_VARIANTS:
		_multimesh(cm[v], _per_c[v], "Cobbles_%d" % v, false)
	for v in BOULDER_VARIANTS:
		_multimesh(bm[v], _per_b[v], "VergeStones_%d" % v, true)

func _lay(it: Array, cobble: bool) -> void:
	var q: Vector2 = it[0]
	var sz: Vector3 = it[1]
	var g := _terrain.height_at(q.x, q.y)
	# cobbles stand a centimetre or two proud of the rut bed; the verge stones sit a third sunk
	var top := g + (sz.y * 0.3 if cobble else sz.y * 0.62)
	var b := Basis(Vector3.UP, it[2])
	b = b.rotated(b.x, it[3]).rotated(b.z, it[4])
	var c3 := Vector3(q.x, top - sz.y * 0.5, q.y) - global_position
	var xf := Transform3D(b * Basis.from_scale(sz), c3)
	if cobble:
		# a trodden (wheel-scoured) top: masonry.gdshader's r < 0, aged field stone
		_per_c[it[5]].append([xf, Color(-0.125, it[6], 0.0, 2.0)])
		cobbles.append(Vector3(q.x, top, q.y))
		cobble_count += 1
	else:
		_per_b[it[5]].append([xf, Color(0.0, it[6], 0.0, 2.0)])
		boulders.append(Vector3(q.x, top, q.y))
		boulder_count += 1

func _multimesh(mesh: Mesh, items: Array, nm: String, shadow: bool) -> void:
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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 70.0 if shadow else 40.0
	add_child(mmi)
