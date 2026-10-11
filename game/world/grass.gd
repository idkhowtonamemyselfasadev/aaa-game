class_name GrassField
extends Node3D
## Streams wind-blown grass around the active camera in 16 m chunks (one MultiMesh each).
## Clumps are real blade geometry built here; density follows the terrain: none on rock
## slopes, thinner on dirt patches, so it matches the terrain shader's material mask.

@export var terrain_path: NodePath
@export var chunk_m: float = 16.0
@export var radius_m: float = 64.0
@export var clumps_per_chunk: int = 1700     # at the camera; far chunks thin to ~35 %
@export var builds_per_frame: int = 6
@export var material: ShaderMaterial

var _terrain: Terrain
## Short-cropped turf (x, z) where grazers/rooks feed: grass there is a few cm tall so the
## animals are visible. Set by Birds before the first chunks stream in.
var cropped_spots: Array[Vector3] = []
const CROP_R := 6.5
var _mesh: ArrayMesh
var _chunks := {}            # Vector2i -> MultiMeshInstance3D
var _heads := {}             # Vector2i -> [PackedVector3Array heads, PackedInt32Array species]
@export var flowers_m: float = 56.0   # wildflowers (flowers.gd) only on chunks this close
var _patch := FastNoiseLite.new()

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_patch.seed = 91
	_patch.frequency = 1.0 / 22.0
	_patch.fractal_octaves = 2
	_mesh = _build_clump_mesh()
	if material:
		_mesh.surface_set_material(0, material)

## Number of chunks currently loaded (bots/tests read this).
func loaded_chunks() -> int:
	return _chunks.size()

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	update_around(cam.global_position, builds_per_frame)

## Load chunks inside the radius (nearest first, up to `budget`), free those outside.
func update_around(p: Vector3, budget: int) -> void:
	var c := Vector2i(floori(p.x / chunk_m), floori(p.z / chunk_m))
	var r := ceili(radius_m / chunk_m)
	var want: Array[Vector2i] = []
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var k := c + Vector2i(i, j)
			var centre := (Vector2(k) + Vector2(0.5, 0.5)) * chunk_m
			if centre.distance_to(Vector2(p.x, p.z)) <= radius_m + chunk_m * 0.75 and not _chunks.has(k):
				want.append(k)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
	for k in want.slice(0, budget):
		_chunks[k] = _build_chunk(k)
	var drop_r := radius_m + chunk_m * 2.0
	for k: Vector2i in _chunks.keys():
		var centre := (Vector2(k) + Vector2(0.5, 0.5)) * chunk_m
		if centre.distance_to(Vector2(p.x, p.z)) > drop_r:
			_chunks[k].queue_free()
			_chunks.erase(k)
			_heads.erase(k)

func _build_chunk(k: Vector2i) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var xf: Array[Transform3D] = []
	var var_ := PackedFloat32Array()
	var half := _terrain.size_m * 0.5 - 2.0
	# distance LOD: chunks far from the camera get fewer, bigger clumps
	var cam := get_viewport().get_camera_3d()
	var centre := (Vector2(k) + Vector2(0.5, 0.5)) * chunk_m
	var d := 0.0 if cam == null else centre.distance_to(Vector2(cam.global_position.x, cam.global_position.z))
	var far := smoothstep(20.0, radius_m, d)
	var count := int(clumps_per_chunk * lerpf(1.0, 0.35, far))
	for n in count:
		var x := (k.x + rng.randf()) * chunk_m
		var z := (k.y + rng.randf()) * chunk_m
		if absf(x) > half or absf(z) > half:
			continue
		var nrm := _terrain.normal_at(x, z)
		var slope := 1.0 - nrm.y
		if slope > 0.22:
			continue
		var patch := _patch.get_noise_2d(x, z) * 0.5 + 0.5
		# bare patches and thinning toward rock, matched loosely to the terrain shader
		if rng.randf() > smoothstep(0.05, 0.35, patch) * (1.0 - smoothstep(0.1, 0.22, slope)):
			continue
		# rain pools in the flat hollows: only a few tufts stand in the water
		var pond := _terrain.pond_at(x, z)
		if pond > 0.0 and rng.randf() < pond * 0.75:
			continue
		var y := _terrain.height_at(x, z)
		var s := lerpf(0.55, 1.2, rng.randf()) * lerpf(0.75, 1.15, patch) * lerpf(1.0, 1.4, far)
		var crop := 1.0
		for c in cropped_spots:
			crop = minf(crop, smoothstep(CROP_R * 0.45, CROP_R, Vector2(x - c.x, z - c.z).length()))
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		# lean with the slope a little so clumps don't look stuck on like pins
		basis = Basis(Quaternion(Vector3.UP, nrm.lerp(Vector3.UP, 0.6).normalized())) * basis
		basis = basis.scaled(Vector3(s, s * lerpf(0.8, 1.3, rng.randf()) * lerpf(0.22, 1.0, crop), s))
		xf.append(Transform3D(basis, Vector3(x, y - 0.03, z)))
		var_.append(clampf(patch * 0.7 + rng.randf() * 0.4, 0.0, 1.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh
	mm.instance_count = xf.size()
	for n in xf.size():
		mm.set_instance_transform(n, xf[n])
		mm.set_instance_custom_data(n, Color(var_[n], 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.name = "Grass_%d_%d" % [k.x, k.y]
	add_child(mmi)
	if d < flowers_m:
		var fl := MeadowFlowers.build_chunk(k, chunk_m, _terrain, far)
		mmi.add_child(fl[0])
		_heads[k] = [fl[1], fl[2]]
	return mmi

## Total wildflower heads in the loaded chunks (bots read this).
func flower_count() -> int:
	var n := 0
	for k in _heads:
		n += (_heads[k][0] as PackedVector3Array).size()
	return n

## A random wildflower head within `r` of `p` (world), or Vector3.INF if none is loaded there.
## `species` >= 0 restricts it to one flower (0 daisy, 1 buttercup, 2 knapweed, 3 yarrow).
func flower_near(p: Vector3, r: float, rng: RandomNumberGenerator, species := -1) -> Vector3:
	var picks: Array[Vector3] = []
	var c0 := Vector2i(floori((p.x - r) / chunk_m), floori((p.z - r) / chunk_m))
	var c1 := Vector2i(floori((p.x + r) / chunk_m), floori((p.z + r) / chunk_m))
	for j in range(c0.y, c1.y + 1):
		for i in range(c0.x, c1.x + 1):
			var e = _heads.get(Vector2i(i, j))
			if e == null:
				continue
			var hs: PackedVector3Array = e[0]
			var ks: PackedInt32Array = e[1]
			for n in hs.size():
				if (species < 0 or ks[n] == species) and Vector2(hs[n].x - p.x, hs[n].z - p.z).length() <= r:
					picks.append(hs[n])
	return Vector3.INF if picks.is_empty() else picks[rng.randi() % picks.size()]

## One clump: 12 curved, tapered blades fanning out from a shared root, 3 segments each.
## UV.y carries 0 (root) .. 1 (tip) for the shader's wind and shading.
func _build_clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	const SEG := 3
	for b in 12:
		var yaw := b * TAU / 12.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var root := dir * rng.randf_range(0.0, 0.16)
		var height := rng.randf_range(0.3, 0.75)
		var lean := rng.randf_range(0.12, 0.35)
		var width := rng.randf_range(0.022, 0.035)
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for s in SEG + 1:
			var t := float(s) / SEG
			var centre := root + dir * lean * t * t + Vector3.UP * height * t
			var w := width * (1.0 - t * 0.92)
			var l := centre - side * w
			var r := centre + side * w
			if s > 0:
				var t0 := float(s - 1) / SEG
				var n := (dir * -0.4 + Vector3.UP).normalized()
				for v in [[prev_l, t0], [l, t], [prev_r, t0], [prev_r, t0], [l, t], [r, t]]:
					st.set_normal(n)
					st.set_uv(Vector2(0.0, v[1]))
					st.add_vertex(v[0])
			prev_l = l
			prev_r = r
	return st.commit()
