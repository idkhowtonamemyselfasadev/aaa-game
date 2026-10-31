class_name StoneRing
extends Node3D
## The Ashen Knight's vigil: a broken ring of standing stones far down the meadow, older than
## the village. Nine tall weathered uprights (the ruins' split-stone mesh, stood on end and
## stretched) lean a little on a circle round the knight's post; two have fallen inward and
## one is a stump. The gap in the ring faces back up the meadow toward the start, so the hero
## walks in through the old entrance, and the knight notices them just as they cross it.
## Each upright collides, so the fight is fought among the stones, not on an open lawn.

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 5150

const RADIUS := 10.5
const COUNT := 11            # slots round the circle; the entrance takes two of them
const VARIANTS := 4
const SINK := 0.35           # metres each upright is set below the low side of the turf

var centre := Vector3.ZERO
var facing := Vector2(0, -1)    # xz direction from the centre out through the entrance
var stones: Array[Vector3] = []     # world foot of each standing stone (bots)
var fallen := 0
var scorches := 0         # burnt-ground decals (bots)
var _per: Array = []
var _terrain: Terrain

## Lay the ring round `c` (world xz), its entrance toward `toward` (world xz).
func build(c: Vector2, toward: Vector2) -> void:
	var ruins: Ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	facing = (toward - c).normalized()
	centre = Vector3(c.x, _terrain.height_at(c.x, c.y), c.y)
	var meshes: Array[ArrayMesh] = []
	for v in VARIANTS:
		# rough, lumpy field stone with a few broken faces: weathered sarsens, not dressed blocks
		meshes.append(YardWall.stone_mesh(seed, v, ruins.material, 0.14, 0.09, 0.38, 0.48, false, Vector2i(3, 5)))
		_per.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a0 := atan2(facing.y, facing.x)
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	for i in COUNT:
		var a := a0 + TAU * (float(i) + 0.5) / COUNT
		# the entrance: the two slots either side of the gap's axis stay empty
		var off := wrapf(a - a0, -PI, PI)
		if absf(off) < TAU / COUNT * 0.9:
			continue
		a += rng.randf_range(-0.06, 0.06)
		var r := RADIUS + rng.randf_range(-0.5, 0.5)
		var q := c + Vector2(cos(a), sin(a)) * r
		var inward := (c - q).normalized()
		var h := rng.randf_range(2.8, 4.0)
		var w := rng.randf_range(1.3, 1.9)
		var d := rng.randf_range(0.6, 0.9)
		var kind := 0      # 0 standing, 1 fallen inward, 2 snapped stump
		if i == 3 or i == 8:
			kind = 1
		elif i == 6:
			kind = 2
		if kind == 2:
			h = rng.randf_range(0.9, 1.2)
		# the broad face toward the centre: local x along the circle, z toward the middle
		var yaw := atan2(inward.x, inward.y) + rng.randf_range(-0.15, 0.15)
		var b := Basis(Vector3.UP, yaw)
		var g := INF
		for k in 5:
			var s := Vector2(cos(k * 1.26), sin(k * 1.26)) * w * 0.5
			g = minf(g, _terrain.height_at(q.x + s.x, q.y + s.y))
		var foot := Vector3(q.x, g, q.y)
		var size := Vector3(w, h, d)
		var xf: Transform3D
		if kind == 1:
			# toppled toward the middle long ago: lying on its broad face, half sunk in the turf
			var lie := foot + Vector3(inward.x, 0, inward.y) * (h * 0.5 - 0.3)
			var lb := b.rotated(b.x, PI * 0.5 - rng.randf_range(0.0, 0.08))
			var gy := _terrain.height_at(lie.x, lie.z)
			xf = Transform3D(lb * Basis.from_scale(size), Vector3(lie.x, gy + d * 0.22, lie.z))
			fallen += 1
			_collider(body, xf.origin, lb, size)
		else:
			# leaning: weathered a few degrees off plumb, mostly outward as the ground gave
			var lean := rng.randf_range(0.02, 0.09)
			var lb := b.rotated(b.x, -lean).rotated(b.z, rng.randf_range(-0.05, 0.05))
			var mid := foot + lb.y * (h * 0.5 - SINK)
			xf = Transform3D(lb * Basis.from_scale(size), mid)
			_collider(body, mid, lb, size)
		var v := rng.randi() % VARIANTS
		# masonry custom data: r = height above ground / 8 m (0: grounded), g = random,
		# b = 0 (not a laid course), a = 1: long out in the weather -- dark crust, moss, lichen
		_per[v].append([xf.translated(-global_position), Color(0.0, rng.randf(), 0.0, 1.0)])
		stones.append(foot)
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Stones_%d" % v)
	_scorch_ground(rng)

## The knight's fires have burnt the ground inside the ring many times over: a wide old burn of
## grey ash round its post and a scatter of fresher black scorches where earlier challengers
## fell. Decals, so they lie on the real turf and darken the grass stems standing in them.
func _scorch_ground(rng: RandomNumberGenerator) -> void:
	var tex := AshFlame._scorch_texture()
	var marks := [[Vector2.ZERO, 9.5, Color(0.62, 0.58, 0.54, 0.55)]]
	for k in 6:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.5, RADIUS - 2.5)
		marks.append([Vector2(cos(a), sin(a)) * r, rng.randf_range(2.4, 4.4),
				Color(1, 1, 1, rng.randf_range(0.7, 0.95))])
	for m in marks:
		var at: Vector2 = m[0]
		var sz: float = m[1]
		var d := Decal.new()
		d.name = "Scorch"
		d.size = Vector3(sz, 1.4, sz)
		d.normal_fade = 0.55             # only up-facing ground: not the hero's legs or stone faces
		d.texture_albedo = tex
		d.modulate = m[2]
		d.albedo_mix = 1.0
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.cull_mask = 0xFFFFF & ~2       # not on the knight (layer 2) standing in it
		var wx := centre.x + at.x
		var wz := centre.z + at.y
		d.position = Vector3(wx, _terrain.height_at(wx, wz), wz) - global_position
		d.rotation.y = rng.randf() * TAU
		add_child(d)
		scorches += 1

func _collider(body: StaticBody3D, at: Vector3, b: Basis, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size * 0.92
	cs.shape = box
	cs.transform = Transform3D(b, at - global_position)
	body.add_child(cs)

## Whether (x, z) lies inside the ring (bots; the music could key off it later).
func inside(x: float, z: float) -> bool:
	return Vector2(x - centre.x, z - centre.z).length() < RADIUS - 0.8

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
