@tool
class_name Terrain
extends StaticBody3D
## Procedural heightfield terrain for the Harrowmere Vale slice.
## Builds a single ArrayMesh + HeightMapShape3D from layered FastNoiseLite.
## Height query is available to other systems (grass scatter, bots, placement).

@export var size_m: float = 512.0
@export var resolution: int = 256
@export var height_scale: float = 26.0
@export var seed: int = 1337
@export var material: Material

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _hollow := PackedFloat32Array()   # hollow_at per mesh vertex (pond_at reads it)

func _ready() -> void:
	_setup_noise()
	build()

func _setup_noise() -> void:
	_noise.seed = seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0 / 340.0
	_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.45
	_detail.seed = seed + 7
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 1.0 / 28.0
	_detail.fractal_octaves = 3

## World-space height at (x, z).
func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z)
	# ridged noise is 0..1-ish; shape into rolling vale with a flat-ish valley floor
	h = pow(clampf(h * 0.5 + 0.5, 0.0, 1.0), 1.4)
	# village floor: flatten the centre ~60 m, hills rise toward the edges (gentle bowl)
	var rm := Vector2(x, z).length()
	var flat := smoothstep(50.0, 170.0, rm)
	var r := rm / (size_m * 0.5)
	h = h * height_scale * flat + r * r * 24.0
	h += _detail.get_noise_2d(x, z) * lerpf(0.5, 1.6, flat)
	return h

## World-space surface normal at (x, z) by central differences.
func normal_at(x: float, z: float, e: float = 1.0) -> Vector3:
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

## How far (m) the ground at (x, z) lies below its surroundings: the mean of two rings
## (3 m and 7 m out) minus the height there. Positive in hollows, where rain pools.
## Written into the terrain's vertex colour (red) for the shader's puddles.
func hollow_at(x: float, z: float, y: float = NAN) -> float:
	if is_nan(y):
		y = height_at(x, z)
	var acc := 0.0
	for r: float in [3.0, 7.0]:
		for a in 8:
			var ang: float = a * TAU / 8.0 + r
			acc += height_at(x + cos(ang) * r, z + sin(ang) * r)
	return acc / 16.0 - y

## 0..1: how surely rain stands at (x, z) once the ground is soaked (a flat hollow deeper
## than the terrain shader's `puddle_soaked`). Grass and flowers keep out of the pools.
func pond_at(x: float, z: float) -> float:
	if _hollow.is_empty():
		return 0.0
	var step := size_m / float(resolution)
	var fx := clampf((x + size_m * 0.5) / step, 0.0, resolution - 0.001)
	var fz := clampf((z + size_m * 0.5) / step, 0.0, resolution - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var w := resolution + 1
	var hv := lerpf(lerpf(_hollow[j * w + i], _hollow[j * w + i + 1], tx),
			lerpf(_hollow[(j + 1) * w + i], _hollow[(j + 1) * w + i + 1], tx), tz)
	var flat := 1.0 - smoothstep(0.012, 0.025, 1.0 - normal_at(x, z, 2.0).y)
	return smoothstep(0.25, 0.37, hv) * flat

func build() -> void:
	for c in get_children():
		c.queue_free()
	var step := size_m / float(resolution)
	var half := size_m * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var heights := PackedFloat32Array()
	var cols := PackedColorArray()
	verts.resize((resolution + 1) * (resolution + 1))
	norms.resize(verts.size())
	uvs.resize(verts.size())
	heights.resize(verts.size())
	cols.resize(verts.size())
	for j in resolution + 1:
		for i in resolution + 1:
			var x := -half + i * step
			var z := -half + j * step
			var y := height_at(x, z)
			var k := j * (resolution + 1) + i
			verts[k] = Vector3(x, y, z)
			uvs[k] = Vector2(x, z) / 8.0
			heights[k] = y
	# normals by central differences
	for j in resolution + 1:
		for i in resolution + 1:
			var k := j * (resolution + 1) + i
			var x := -half + i * step
			var z := -half + j * step
			var hl := height_at(x - step, z)
			var hr := height_at(x + step, z)
			var hd := height_at(x, z - step)
			var hu := height_at(x, z + step)
			norms[k] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			cols[k] = Color(hollow_at(x, z, heights[k]), 0.0, 0.0)
	for j in resolution:
		for i in resolution:
			var a := j * (resolution + 1) + i
			var b := a + 1
			var c := a + resolution + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])   # clockwise seen from above = front face in Godot
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	_hollow.resize(cols.size())
	for k in cols.size():
		_hollow[k] = cols[k].r
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	var shape := HeightMapShape3D.new()
	shape.map_width = resolution + 1
	shape.map_depth = resolution + 1
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	add_child(cs)
	collision_layer = 1
	collision_mask = 0
