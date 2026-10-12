class_name Horizon
extends Node3D
## Far mountain ring around the 512 m Vale tile so the world no longer ends at 256 m.
## One ArrayMesh on a non-uniform grid: cells start exactly on the tile edge (+-half) and
## grow geometrically out to `outer_m`; cells inside the tile are skipped. At the tile edge
## the height follows Terrain.height_at (slightly sunk) so the seam is closed, then blends
## into wooded foothills and a ridged mountain wall. Visual only: no collision (the playable
## edge gets a cliff/border in the world-streaming milestone).

@export var terrain_path: NodePath
@export var material: Material
@export var outer_m: float = 2800.0
@export var first_step_m: float = 4.0
@export var growth: float = 1.06
@export var max_step_m: float = 40.0
@export var peak_height_m: float = 520.0

var _ridge := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _terrain: Terrain
var _half := 256.0
var inner_step_m := 2.0

func _ready() -> void:
	_terrain = get_node_or_null(terrain_path)
	if _terrain:
		_half = _terrain.size_m * 0.5
		inner_step_m = _terrain.size_m / float(_terrain.resolution)
	_ridge.seed = 4242
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 1.0 / 900.0
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 5
	_ridge.fractal_gain = 0.5
	# domain warp: bends the ridge lines into hooked spurs, saddles and uneven peak groups
	# instead of the evenly spaced pyramids plain ridged noise gives
	_ridge.domain_warp_enabled = true
	_ridge.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	_ridge.domain_warp_amplitude = 200.0
	_ridge.domain_warp_frequency = 1.0 / 2200.0
	_ridge.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_PROGRESSIVE
	_ridge.domain_warp_fractal_octaves = 2
	_hills.seed = 4243
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 1.0 / 260.0
	_hills.fractal_octaves = 4
	build()

## Height of the far ring at (x, z). Continuous with the terrain at the tile edge.
func height_at(x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z)) - _half          # distance outside the tile (square)
	var edge := 0.0
	if _terrain:
		# sample the terrain at the nearest tile-edge point: exact at the seam, and avoids the
		# terrain formula's r^2 bowl, which keeps climbing outside the tile
		edge = _terrain.height_at(clampf(x, -_half, _half), clampf(z, -_half, _half))
	var t := smoothstep(0.0, 260.0, d)
	# foothills: rolling, 40..110 m above the rim
	var foot := edge + 30.0 + (_hills.get_noise_2d(x, z) * 0.5 + 0.5) * 80.0 * smoothstep(0.0, 500.0, d)
	# mountain wall: ridged peaks rising with distance, a lower notch toward the south-east
	# (the road to Greywold) so the horizon has a shape instead of a uniform rim
	var ridge := _ridge.get_noise_2d(x, z) * 0.5 + 0.5
	ridge = pow(clampf(ridge, 0.0, 1.0), 1.6)
	var ang := atan2(z, x)
	var notch := 1.0 - 0.45 * exp(-pow(wrapf(ang - 0.6, -PI, PI) / 0.5, 2.0))
	var mount := peak_height_m * ridge * smoothstep(300.0, 1500.0, d) * notch
	return lerpf(edge - 0.05, foot, t) + mount

func _axis() -> PackedFloat32Array:
	# positive half: +half, then growing steps (capped at max_step_m) out to outer_m
	var pos := PackedFloat32Array()
	var x := _half
	var s := first_step_m
	while x < outer_m:
		pos.append(x)
		x += s
		s = minf(s * growth, max_step_m)
	pos.append(outer_m)
	var out := PackedFloat32Array()
	for i in range(pos.size() - 1, -1, -1):
		out.append(-pos[i])
	# inside the tile: the terrain's own vertex spacing, so cells along the seam share the
	# terrain's edge vertices exactly (inner cells are skipped)
	var k := 1
	while -_half + k * inner_step_m < _half - 0.01:
		out.append(-_half + k * inner_step_m)
		k += 1
	out.append_array(pos)
	return out

func build() -> void:
	var t0 := Time.get_ticks_msec()
	for c in get_children():
		c.queue_free()
	var ax := _axis()
	var n := ax.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var x := ax[i]
			var z := ax[j]
			var inside := absf(x) < _half - 0.01 and absf(z) < _half - 0.01
			var y := 0.0 if inside else height_at(x, z)
			verts[j * n + i] = Vector3(x, y, z)
			uvs[j * n + i] = Vector2(x, z) / 64.0
	var norms := PackedVector3Array()
	norms.resize(n * n)
	for j in n:
		for i in n:
			var x := ax[i]
			var z := ax[j]
			if absf(x) < _half - 0.01 and absf(z) < _half - 0.01:
				norms[j * n + i] = Vector3.UP
				continue
			var e := maxf(2.0, (ax[mini(i + 1, n - 1)] - ax[maxi(i - 1, 0)]) * 0.5)
			var hl := height_at(x - e, z)
			var hr := height_at(x + e, z)
			var hd := height_at(x, z - e)
			var hu := height_at(x, z + e)
			norms[j * n + i] = Vector3(hl - hr, 2.0 * e, hd - hu).normalized()
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var cx := (ax[i] + ax[i + 1]) * 0.5
			var cz := (ax[j] + ax[j + 1]) * 0.5
			if absf(cx) < _half and absf(cz) < _half:
				continue
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])   # same winding as Terrain (front face up)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# huge bounds: keep it out of the per-object culling's way and the GI probes
	mi.extra_cull_margin = 64.0
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	print("HORIZON grid=%d tris=%d build=%d ms" % [n, idx.size() / 3, Time.get_ticks_msec() - t0])
