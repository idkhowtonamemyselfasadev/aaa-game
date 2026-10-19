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
## Short sward: a dense under-layer of fine, low blades that closes the soil between the
## tall clumps, streamed only round the camera (where the gaps show) in its own chunks.
@export var sward_m: float = 26.0
@export var sward_per_chunk: int = 2600

var _terrain: Terrain
## Short-cropped turf (x, z) where grazers/rooks feed: grass there is a few cm tall so the
## animals are visible. Set by Birds before the first chunks stream in.
var cropped_spots: Array[Vector3] = []
const CROP_R := 6.5
var _meshes: Array[ArrayMesh] = []   # tall clump shapes: 0 upright, 1 tussock, 2 seeding
var _sward_mesh: ArrayMesh
var _chunks := {}            # Vector2i -> MultiMeshInstance3D
var sward_build_ms := 0.0    # slowest sward build slice (one frame's work) so far (bots print it)
var _sward := {}             # Vector2i -> MultiMeshInstance3D (short-sward under-layer)
var _heads := {}             # Vector2i -> [PackedVector3Array heads, PackedInt32Array species]
@export var flowers_m: float = 56.0   # wildflowers (flowers.gd) only on chunks this close
var _patch := FastNoiseLite.new()
var _ruin := Vector3.INF      # watchtower keep centre (Flora.ruin_site), grass keeps off its floor

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_patch.seed = 91
	_patch.frequency = 1.0 / 22.0
	_patch.fractal_octaves = 2
	_meshes = [_build_clump_mesh(), _build_tussock_mesh(), _build_seeding_mesh()]
	_sward_mesh = _build_clump_mesh(true)
	if material:
		for m in _meshes:
			m.surface_set_material(0, material)
		_sward_mesh.surface_set_material(0, material)

## Number of chunks currently loaded (bots/tests read this).
func loaded_chunks() -> int:
	return _chunks.size()

## Short-sward chunks loaded round the camera, and their blade clumps (bots read these).
func sward_chunks() -> int:
	return _sward.size()

func sward_clumps() -> int:
	var n := 0
	for k in _sward:
		if _sward[k] is MultiMeshInstance3D:
			n += (_sward[k] as MultiMeshInstance3D).multimesh.instance_count
	return n

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	update_around(cam.global_position, builds_per_frame)

## Load chunks inside the radius (nearest first, up to `budget`), free those outside.
## The short sward streams the same way in a tighter ring, after the tall grass.
func update_around(p: Vector3, budget: int) -> void:
	var built := _stream(_chunks, p, radius_m, budget, _build_chunk)
	# the sward builds one chunk at a time, a slice of it per frame (no hitch while running),
	# and starts a new one only on a frame the tall grass left free
	if _job.is_empty():
		_stream(_sward, p, sward_m, 1 if built == 0 else 0, _start_sward)
	else:
		_stream(_sward, p, sward_m, 0, _start_sward)   # still drops far chunks
		_step_sward()

func _stream(chunks: Dictionary, p: Vector3, radius: float, budget: int, build: Callable) -> int:
	var c := Vector2i(floori(p.x / chunk_m), floori(p.z / chunk_m))
	var r := ceili(radius / chunk_m)
	var want: Array[Vector2i] = []
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var k := c + Vector2i(i, j)
			var centre := (Vector2(k) + Vector2(0.5, 0.5)) * chunk_m
			if centre.distance_to(Vector2(p.x, p.z)) <= radius + chunk_m * 0.75 and not chunks.has(k):
				want.append(k)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
	var built := mini(budget, want.size())
	for k in want.slice(0, built):
		chunks[k] = build.call(k)
	var drop_r := radius + chunk_m * 2.0
	for k: Vector2i in chunks.keys():
		var centre := (Vector2(k) + Vector2(0.5, 0.5)) * chunk_m
		if centre.distance_to(Vector2(p.x, p.z)) > drop_r:
			chunks[k].queue_free()
			chunks.erase(k)
			if chunks == _chunks:
				_heads.erase(k)
	return built

## Where the meadow grows: Vector3(patch, shade, keep distance) at (x, z), or x < 0 where
## nothing grows (rock slopes, bare patches, pools, the keep, deep oak shade). Shared by the
## tall clumps and the short sward so both follow the same mask.
func _site(x: float, z: float, rng: RandomNumberGenerator, flora: Node) -> Vector3:
	var nrm := _terrain.normal_at(x, z)
	var slope := 1.0 - nrm.y
	if slope > 0.22:
		return Vector3(-1, 0, 0)
	var patch := _patch.get_noise_2d(x, z) * 0.5 + 0.5
	# bare patches and thinning toward rock, matched loosely to the terrain shader
	if rng.randf() > smoothstep(0.05, 0.35, patch) * (1.0 - smoothstep(0.1, 0.22, slope)):
		return Vector3(-1, 0, 0)
	# rain pools in the flat hollows: only a few tufts stand in the water
	var pond := _terrain.pond_at(x, z)
	if pond > 0.0 and rng.randf() < pond * 0.75:
		return Vector3(-1, 0, 0)
	# the watchtower keep: no meadow inside its walls or through them, only a few short
	# tufts in the floor joints
	var keep := Vector2(x - _ruin.x, z - _ruin.z).length() if _ruin != Vector3.INF else 99.0
	# (< 1.9: the shrine plinth); tufts thicken toward the wall foot, where feet never went
	if keep < 1.9 or (keep < 4.6 and (keep > 3.0 or rng.randf() > 0.1 + 0.35 * smoothstep(2.3, 2.9, keep))):
		return Vector3(-1, 0, 0)
	# Harrowmere's first house: no meadow through its footing (a fringe stands under the eaves)
	if Cottage.inside(x, z, -0.4) or StoneCottage.inside(x, z, -0.4) or WhiteCottage.covers(x, z, -0.4) or DryWall.near(x, z, -0.12) or YardWall.near(x, z, -0.12):
		return Vector3(-1, 0, 0)
	# woodland floor: deep under the oak crowns the meadow gives way to ferns and litter,
	# with only thin, shorter shade grass
	var shade: float = flora.shelter_at(x, z) if flora else 0.0
	if rng.randf() < shade * 0.8:
		return Vector3(-1, 0, 0)
	# moss collars at the oak boles and boulder feet (Flora._bake_moss): a full cushion
	# smothers the meadow, its ragged outer edge keeps a few tufts poking through
	var moss: float = flora.moss_at(x, z) if flora else 0.0
	if rng.randf() < smoothstep(0.12, 0.6, moss) * 0.95:
		return Vector3(-1, 0, 0)
	return Vector3(patch, shade, keep)

func _crop_at(x: float, z: float) -> float:
	var crop := 1.0
	for c in cropped_spots:
		crop = minf(crop, smoothstep(CROP_R * 0.45, CROP_R, Vector2(x - c.x, z - c.z).length()))
	return crop

func _find_ruin() -> Node:
	var flora := get_node_or_null("../Flora")
	if _ruin == Vector3.INF:
		if flora and flora.ruin_site != Vector3.ZERO:
			_ruin = flora.ruin_site
	return flora

## Short sward under the tall clumps: many low, fine, greener blades that fill the soil the
## tall clumps leave bare. Custom data .y = 1 marks it for the shader (greener, lit roots,
## its own close fade). Built in slices of SWARD_SLICE candidates per frame: the chunk's
## slot holds an empty placeholder until the MultiMesh is ready.
const SWARD_SLICE := 520
var _job := {}

func _start_sward(k: Vector2i) -> Node3D:
	var holder := Node3D.new()
	holder.name = "SwardPending_%d_%d" % [k.x, k.y]
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k) ^ 0x5a17
	_job = {"k": k, "holder": holder, "rng": rng, "i": 0, "flora": _find_ruin(),
		"xf": [] as Array[Transform3D], "var": PackedFloat32Array()}
	return holder

func _step_sward() -> void:
	var holder: Node3D = _job.holder
	var k: Vector2i = _job.k
	if not is_instance_valid(holder) or holder.is_queued_for_deletion() or _sward.get(k) != holder:
		_job = {}   # the chunk streamed out before it finished
		return
	var t0 := Time.get_ticks_usec()
	var rng: RandomNumberGenerator = _job.rng
	var flora: Node = _job.flora
	var xf: Array[Transform3D] = _job.xf
	var var_: PackedFloat32Array = _job["var"]
	var half := _terrain.size_m * 0.5 - 2.0
	var end := mini(_job.i + SWARD_SLICE, sward_per_chunk)
	for n in range(_job.i, end):
		var x := (k.x + rng.randf()) * chunk_m
		var z := (k.y + rng.randf()) * chunk_m
		if absf(x) > half or absf(z) > half:
			continue
		var site := _site(x, z, rng, flora)
		if site.x < 0.0:
			continue
		# the hens' garth: scratched short and patchy, bare earth between
		var hen := Hens.scratched(x, z)
		if hen > 0.0 and rng.randf() < hen * 0.75:
			continue
		if rng.randf() < YardGround.worn(x, z) * 0.95:   # the beaten path to the door
			continue
		var y := _terrain.height_at(x, z)
		var nrm := _terrain.normal_at(x, z)
		var s := lerpf(0.7, 1.25, rng.randf()) * (0.6 if site.z < 3.1 else 1.0) * lerpf(1.0, 0.7, site.y) * lerpf(1.0, 0.55, hen)
		var crop := _crop_at(x, z)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = Basis(Quaternion(Vector3.UP, nrm.lerp(Vector3.UP, 0.3).normalized())) * basis
		basis = basis.scaled(Vector3(s, s * lerpf(0.7, 1.3, rng.randf()) * lerpf(0.45, 1.0, crop), s))
		xf.append(Transform3D(basis, Vector3(x, y - 0.02, z)))
		# greener than the tall grass on average (live leaf under the seed heads)
		var_.append(clampf(site.x * 0.5 + rng.randf() * 0.45 - 0.1, 0.0, 1.0))
	_job.i = end
	_job["var"] = var_   # packed arrays are values: write back
	if end < sward_per_chunk:
		sward_build_ms = maxf(sward_build_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _sward_mesh
	mm.instance_count = xf.size()
	for n in xf.size():
		mm.set_instance_transform(n, xf[n])
		mm.set_instance_custom_data(n, Color(var_[n], 1.0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.name = "Sward_%d_%d" % [k.x, k.y]
	add_child(mmi)
	holder.queue_free()
	_sward[k] = mmi
	_job = {}
	sward_build_ms = maxf(sward_build_ms, (Time.get_ticks_usec() - t0) / 1000.0)

func _build_chunk(k: Vector2i) -> MultiMeshInstance3D:
	var flora := _find_ruin()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var xfs: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var vars: Array = [[], [], []]   # plain Arrays: packed arrays inside an Array copy on append
	var half := _terrain.size_m * 0.5 - 2.0
	# distance LOD: chunks far from the camera get fewer, bigger clumps
	var cam := get_viewport().get_camera_3d()
	var centre := (Vector2(k) + Vector2(0.5, 0.5)) * chunk_m
	var d := 0.0 if cam == null else centre.distance_to(Vector2(cam.global_position.x, cam.global_position.z))
	var far := smoothstep(20.0, radius_m, d)
	var count := int(clumps_per_chunk * lerpf(1.0, 0.35, far))
	# clumps grow in stands: most sit a short step from the last one, the rest seed a new
	# stand somewhere else, so the meadow has knots and open runs (the sward fills between)
	var px := 0.0
	var pz := 0.0
	var have_prev := false
	for n in count:
		var x: float
		var z: float
		if have_prev and rng.randf() < 0.6:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.14, 0.55)
			x = px + cos(a) * r
			z = pz + sin(a) * r
		else:
			x = (k.x + rng.randf()) * chunk_m
			z = (k.y + rng.randf()) * chunk_m
		if absf(x) > half or absf(z) > half:
			have_prev = false
			continue
		var site := _site(x, z, rng, flora)
		if site.x < 0.0 or rng.randf() < Hens.scratched(x, z) * 1.05 or rng.randf() < YardGround.worn(x, z) * 1.2:
			have_prev = false
			continue
		px = x
		pz = z
		have_prev = true
		var patch := site.x
		var shade := site.y
		var keep := site.z
		var nrm := _terrain.normal_at(x, z)
		var y := _terrain.height_at(x, z)
		var crop := _crop_at(x, z)
		var dry := clampf(patch * 0.7 + rng.randf() * 0.4, 0.0, 1.0)
		# which clump: seeding stems on the drier, open turf; low tussocks in the lush and
		# shaded ground; upright leafy clumps elsewhere. Grazed turf and the keep floor only
		# keep the leafy kinds.
		var kind := 0
		var roll := rng.randf()
		if crop > 0.9 and keep > 3.1 and roll < 0.08 + 0.22 * smoothstep(0.35, 0.8, dry) * (1.0 - shade):
			kind = 2
		elif roll > 0.74 - 0.2 * shade - 0.12 * (1.0 - patch):
			kind = 1
		var s := lerpf(0.55, 1.2, rng.randf()) * (0.45 if keep < 3.1 else 1.0) * lerpf(1.0, 0.6, shade) * lerpf(0.75, 1.15, patch) * lerpf(1.0, 1.4, far)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		# lean with the slope a little so clumps don't look stuck on like pins, plus a
		# random tilt so neighbours never stand quite parallel
		var tilt := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12))
		basis = Basis(Quaternion(Vector3.UP, (nrm.lerp(Vector3.UP, 0.6) + tilt - Vector3.UP).normalized())) * basis
		# squash some clumps sideways: a fan, not a perfect ring
		var wide := rng.randf_range(0.75, 1.3)
		basis = basis.scaled(Vector3(s * wide, s * lerpf(0.8, 1.3, rng.randf()) * lerpf(0.22, 1.0, crop), s / wide))
		(xfs[kind] as Array[Transform3D]).append(Transform3D(basis, Vector3(x, y - 0.03, z)))
		(vars[kind] as Array).append(dry)
	var root: MultiMeshInstance3D = null
	for kind in 3:
		var xf: Array[Transform3D] = xfs[kind]
		var var_: Array = vars[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _meshes[kind]
		mm.instance_count = xf.size()
		for n in xf.size():
			mm.set_instance_transform(n, xf[n])
			mm.set_instance_custom_data(n, Color(var_[n], 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if root == null:
			mmi.name = "Grass_%d_%d" % [k.x, k.y]
			add_child(mmi)
			root = mmi
		else:
			mmi.name = ["Upright", "Tussock", "Seeding"][kind]
			root.add_child(mmi)
	if d < flowers_m:
		var fflora := _find_ruin()
		var fl := MeadowFlowers.build_chunk(k, chunk_m, _terrain, far, _ruin, fflora)
		root.add_child(fl[0])
		_heads[k] = [fl[1], fl[2]]
	return root

## A fixed set of tufts outside the streamed meadow (the grass on the ruin's wall tops):
## items are [Transform3D, kind] with kind 0 upright, 1 tussock, 2 seeding.
func static_tufts(items: Array) -> Node3D:
	var root := Node3D.new()
	for kind in 3:
		var xf: Array[Transform3D] = []
		var sc: PackedFloat32Array = []
		for it in items:
			if int(it[1]) == kind:
				xf.append(it[0])
				sc.append(float(it[2]) if it.size() > 2 else 0.0)
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _meshes[kind]
		mm.instance_count = xf.size()
		for n in xf.size():
			mm.set_instance_transform(n, xf[n])
			# drier straw-tipped tufts: thin soil on the stone dries out first
			# .z: singed by Hesper's fire (Ruins._scorch_tufts)
			mm.set_instance_custom_data(n, Color(0.55 + 0.4 * fmod(n * 0.618, 1.0), 0, sc[n], 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["Upright", "Tussock", "Seeding"][kind]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root

## Tall clumps by kind (0 upright, 1 tussock, 2 seeding) in the loaded chunks (bots read it).
func clump_kinds() -> PackedInt32Array:
	var out := PackedInt32Array([0, 0, 0])
	for k in _chunks:
		var root: MultiMeshInstance3D = _chunks[k]
		out[0] += root.multimesh.instance_count
		for c in root.get_children():
			if c is MultiMeshInstance3D and c.name == "Tussock":
				out[1] += c.multimesh.instance_count
			elif c is MultiMeshInstance3D and c.name == "Seeding":
				out[2] += c.multimesh.instance_count
	return out

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

## One clump: 12 curved, tapered blades from a shared root, 3 segments each, aimed at
## random headings (no even fan) with some blades arching over.
## `sward`: a low mat of 22 fine blades spread over ~0.5 m, 2 segments each.
## UV.y carries 0 (root) .. 1 (tip) for the shader's wind and shading; UV.x is 1 on seed
## stems and heads (grass.gdshader colours them as ripe straw).
func _build_clump_mesh(sward := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if sward else 7
	var seg := 2 if sward else 3
	var blades := 22 if sward else 12
	for b in blades:
		var yaw := b * TAU / blades + rng.randf_range(-0.3, 0.3) if sward else rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var root := dir * (rng.randf_range(0.0, 0.26) if sward else rng.randf_range(0.0, 0.2))
		if sward:
			_blade(st, root, dir, rng.randf_range(0.09, 0.24), rng.randf_range(0.04, 0.14), 0.0,
				rng.randf_range(0.008, 0.015), seg)
		else:
			var h := rng.randf_range(0.3, 0.8)
			# a third of the blades arch over and droop at the tip
			var arch := rng.randf_range(0.15, 0.4) if rng.randf() < 0.33 else 0.0
			_blade(st, root, dir, h, rng.randf_range(0.1, 0.35) + arch, arch * h * 0.6,
				rng.randf_range(0.02, 0.035), seg)
	return st.commit()

## Tussock: a dense, low, wide mound of 18 narrow blades that arch out and over on every
## side, like tufted hair-grass in damp ground.
func _build_tussock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for b in 18:
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var root := dir * rng.randf_range(0.0, 0.12)
		var h := rng.randf_range(0.2, 0.5)
		var out := rng.randf_range(0.18, 0.5)
		_blade(st, root, dir, h, out, h * rng.randf_range(0.2, 0.55), rng.randf_range(0.014, 0.024), 3)
	return st.commit()

## Seeding clump: 7 leaf blades round 4 thin flowering stems (0.6-1.05 m) that each carry a
## loose panicle of spikelets, ripening to straw (UV.x = 1 on stem and head).
func _build_seeding_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for b in 7:
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var h := rng.randf_range(0.22, 0.5)
		_blade(st, dir * rng.randf_range(0.0, 0.12), dir, h, rng.randf_range(0.15, 0.4),
			h * rng.randf_range(0.0, 0.4), rng.randf_range(0.018, 0.03), 3)
	for b in 4:
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var h := rng.randf_range(0.6, 1.05)
		var lean := rng.randf_range(0.05, 0.22)
		var root := dir * rng.randf_range(0.0, 0.08)
		_blade(st, root, dir, h, lean, 0.0, 0.006, 4, 1.0)
		# panicle: spikelets on short branches up the top 28 % of the stem, drooping a
		# little and leaning off the stem on alternating sides
		var head_n := 7
		for i in head_n:
			var t := lerpf(0.72, 0.98, float(i) / (head_n - 1))
			var at := root + dir * lean * t * t + Vector3.UP * h * t
			var ang := i * 2.4 + rng.randf_range(-0.4, 0.4)
			var out := (side * cos(ang) + dir * sin(ang)).normalized()
			var ln := rng.randf_range(0.05, 0.09) * (1.15 - 0.6 * float(i) / head_n)
			_spikelet(st, at, out, ln, t)
	return st.commit()

## One spikelet: a narrow lanceolate quad pair (crossed so it reads from any side) from
## `at` along `out`, angled up and drooping, UV.x = 1 and UV.y = `v` (its height on the stem).
func _spikelet(st: SurfaceTool, at: Vector3, out: Vector3, ln: float, v: float) -> void:
	var tip := at + (out * 0.75 + Vector3.UP * 0.55).normalized() * ln - Vector3.UP * ln * 0.25
	var mid := at.lerp(tip, 0.45)
	var axis := (tip - at).normalized()
	for side in [out.cross(Vector3.UP).normalized(), axis.cross(out.cross(Vector3.UP)).normalized()]:
		var w: Vector3 = side * ln * 0.13
		var n := (Vector3.UP + out * 0.3).normalized()
		for p in [at, mid - w, mid + w, mid - w, tip, mid + w]:
			st.set_normal(n)
			st.set_uv(Vector2(1.0, v))
			st.add_vertex(p)

## A tapered blade from `root` heading `dir`: rises `height`, leans `lean` out (quadratic)
## and droops `droop` at the tip (cubic), `width` half-width at the root. UV.x = `seed`.
func _blade(st: SurfaceTool, root: Vector3, dir: Vector3, height: float, lean: float,
		droop: float, width: float, seg: int, seed := 0.0) -> void:
	var side := Vector3(-dir.z, 0.0, dir.x)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var taper := 0.5 if seed > 0.5 else 0.92
	for s in seg + 1:
		var t := float(s) / seg
		var centre := root + dir * lean * t * t + Vector3.UP * (height * t - droop * t * t * t)
		var w := width * (1.0 - t * taper)
		var l := centre - side * w
		var r := centre + side * w
		if s > 0:
			var t0 := float(s - 1) / seg
			var n := (dir * -0.4 + Vector3.UP).normalized()
			for v in [[prev_l, t0], [l, t], [prev_r, t0], [prev_r, t0], [l, t], [r, t]]:
				st.set_normal(n)
				st.set_uv(Vector2(seed, v[1]))
				st.add_vertex(v[0])
		prev_l = l
		prev_r = r
