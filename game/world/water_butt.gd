class_name WaterButt
extends Node3D
## An old oak cask cut down for a water butt, standing on two stones under a cottage's
## eaves drip (no gutters: the drip line off the slates falls straight into it). Lathed
## staves bellied in the middle, four rusted iron hoops, rainwater inside that rises while
## it rains (faster than open ground: the eaves funnel a strip of roof into it), runs over
## the rim when full, and sinks slowly in dry weather. butt.gdshader / butt_water.gdshader.

const H := 0.92          # cask height (m)
const R_END := 0.29      # radius at the chimes
const R_MID := 0.335     # radius at the bilge
const THICK := 0.028     # stave thickness
const STAVES := 18
const ROWS := 14
const HOOPS := [0.1, 0.3, 0.62, 0.83]   # hoop heights (m)
const FILL := 1.0 / 420.0    # level per second in a downpour (eaves catch)
const DRY := 1.0 / 9000.0    # level per second lost on a dry day

var level := 0.86        # water depth as a share of the inside height
var spill := 0.0         # 0..1 running over the rim
var weather: Weather
var terrain_mat: ShaderMaterial
var _water: MeshInstance3D
var _water_mat: ShaderMaterial
var _stave_mat: ShaderMaterial

static func radius_at(y: float) -> float:
	var t := clampf(y / H, 0.0, 1.0)
	return lerpf(R_END, R_MID, sin(t * PI))

func _ready() -> void:
	_stave_mat = ShaderMaterial.new()
	_stave_mat.shader = preload("res://shaders/butt.gdshader")
	_stave_mat.set_shader_parameter("staves", float(STAVES))
	_stave_mat.set_shader_parameter("seed", 3.7)
	_stave_mat.set_shader_parameter("hoops", Vector4(HOOPS[0] / H, HOOPS[1] / H, HOOPS[2] / H, HOOPS[3] / H))
	var cask := MeshInstance3D.new()
	cask.name = "Cask"
	cask.mesh = _cask_mesh()
	cask.material_override = _stave_mat
	add_child(cask)
	var hm := ShaderMaterial.new()
	hm.shader = _stave_mat.shader
	hm.set_shader_parameter("part", 1.0)
	hm.set_shader_parameter("seed", 1.3)
	var hoops := MeshInstance3D.new()
	hoops.name = "Hoops"
	hoops.mesh = _hoop_mesh()
	hoops.material_override = hm
	add_child(hoops)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = preload("res://shaders/butt_water.gdshader")
	_water_mat.set_shader_parameter("seed", 2.2)
	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.mesh = _disc(1.0)
	_water.material_override = _water_mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)
	_set_level()

## The inside floor height (the head sits a little up from the foot).
func _floor_y() -> float:
	return 0.06

func _set_level() -> void:
	var y := lerpf(_floor_y() + 0.01, H - 0.03, level)
	_water.position.y = y
	var r := radius_at(y) - THICK - 0.002
	_water.scale = Vector3(r, 1.0, r)
	_stave_mat.set_shader_parameter("brim", y / H)
	_stave_mat.set_shader_parameter("spill", spill)

func _process(delta: float) -> void:
	var rain := weather.rain if weather else 0.0
	level = clampf(level + (rain * FILL - DRY * (1.0 - rain)) * delta, 0.0, 1.0)
	spill = move_toward(spill, rain if level >= 0.999 else 0.0, delta * 0.2)
	_water_mat.set_shader_parameter("drip", rain)
	if terrain_mat:
		_water_mat.set_shader_parameter("sky_sheen", terrain_mat.get_shader_parameter("puddle_sky"))
	_set_level()

## Water surface height above the butt's foot (bots).
func surface_y() -> float:
	return _water.position.y

# ---- meshes ----

func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array, inner: float) -> void:
	# p: a b c d round the quad; front faces wound so (b-a)x(c-a) points away from the normal
	var fn: Vector3 = (n[0] + n[1] + n[2] + n[3]) * 0.25
	var tris := [[0, 1, 2], [0, 2, 3]]
	for t in tris:
		var a: Vector3 = p[t[0]]
		var b: Vector3 = p[t[1]]
		var c: Vector3 = p[t[2]]
		var idx: Array = t
		if (b - a).cross(c - a).dot(fn) > 0.0:
			idx = [t[0], t[2], t[1]]
		for i in idx:
			st.set_color(Color(inner, 0, 0))
			st.set_normal(n[i])
			st.set_uv(uv[i])
			st.add_vertex(p[i])

func _cask_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in STAVES:
		# each stave a flat board (a chord between its two edges), a hair narrower so the
		# seams read; the inside the same, the rim its end grain
		var a0 := (s + 0.0) / STAVES * TAU
		var a1 := (s + 1.0) / STAVES * TAU
		var am := (a0 + a1) * 0.5
		var e0 := Vector3(cos(a0), 0, sin(a0))
		var e1 := Vector3(cos(a1), 0, sin(a1))
		var cn := Vector3(cos(am), 0, sin(am))
		for r in ROWS:
			var y0 := float(r) / ROWS * H
			var y1 := float(r + 1) / ROWS * H
			var r0 := radius_at(y0)
			var r1 := radius_at(y1)
			var slope := (r0 - r1) / (y1 - y0)
			var nrm := (cn + Vector3.UP * slope).normalized()
			var u0 := float(s) / STAVES
			var u1 := float(s + 1) / STAVES
			_quad(st, [e0 * r0 + Vector3.UP * y0, e1 * r0 + Vector3.UP * y0, e1 * r1 + Vector3.UP * y1, e0 * r1 + Vector3.UP * y1],
				[nrm, nrm, nrm, nrm], [Vector2(u0, y0 / H), Vector2(u1, y0 / H), Vector2(u1, y1 / H), Vector2(u0, y1 / H)], 0.0)
			var q0 := r0 - THICK
			var q1 := r1 - THICK
			_quad(st, [e0 * q0 + Vector3.UP * y0, e1 * q0 + Vector3.UP * y0, e1 * q1 + Vector3.UP * y1, e0 * q1 + Vector3.UP * y1],
				[-nrm, -nrm, -nrm, -nrm], [Vector2(u0, y0 / H), Vector2(u1, y0 / H), Vector2(u1, y1 / H), Vector2(u0, y1 / H)], 1.0)
		# rim: the staves' end grain, each stave stepped a few mm so the rim is uneven
		var rt := radius_at(H)
		var top := H + (fmod(s * 0.618, 1.0) - 0.5) * 0.008
		var u0 := float(s) / STAVES
		var u1 := float(s + 1) / STAVES
		_quad(st, [e0 * rt + Vector3.UP * top, e1 * rt + Vector3.UP * top, e1 * (rt - THICK) + Vector3.UP * top, e0 * (rt - THICK) + Vector3.UP * top],
			[Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP], [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0.995), Vector2(u0, 0.995)], 1.0)
		# the stepped bit of each stave's top above the mesh rows
		var ry := float(ROWS) / ROWS * H
		if top > ry:
			_quad(st, [e0 * rt + Vector3.UP * ry, e1 * rt + Vector3.UP * ry, e1 * rt + Vector3.UP * top, e0 * rt + Vector3.UP * top],
				[cn, cn, cn, cn], [Vector2(u0, 0.995), Vector2(u1, 0.995), Vector2(u1, 1), Vector2(u0, 1)], 0.0)
		# the head inside (the cask floor)
		var fy := _floor_y()
		var fr := radius_at(fy) - THICK
		var dn := Vector3.UP
		_quad(st, [Vector3.UP * fy, Vector3.UP * fy, e1 * fr + Vector3.UP * fy, e0 * fr + Vector3.UP * fy],
			[dn, dn, dn, dn], [Vector2(0.5, 0), Vector2(0.5, 0), Vector2(u1, 0), Vector2(u0, 0)], 1.0)
	return st.commit()

func _hoop_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	for hy in HOOPS:
		var y0: float = hy - 0.018
		var y1: float = hy + 0.018
		for i in seg:
			var a0 := float(i) / seg * TAU
			var a1 := float(i + 1) / seg * TAU
			var e0 := Vector3(cos(a0), 0, sin(a0))
			var e1 := Vector3(cos(a1), 0, sin(a1))
			# the hoop follows the bilge (driven on tight), 4 mm proud of the staves' chord
			var rb0 := radius_at(y0) + 0.004
			var rb1 := radius_at(y1) + 0.004
			var u0 := float(i) / seg
			var u1 := float(i + 1) / seg
			_quad(st, [e0 * rb0 + Vector3.UP * y0, e1 * rb0 + Vector3.UP * y0, e1 * rb1 + Vector3.UP * y1, e0 * rb1 + Vector3.UP * y1],
				[e0, e1, e1, e0], [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)], 0.0)
			var ri0 := rb0 - 0.006
			var ri1 := rb1 - 0.006
			_quad(st, [e0 * ri1 + Vector3.UP * y1, e1 * ri1 + Vector3.UP * y1, e1 * rb1 + Vector3.UP * y1, e0 * rb1 + Vector3.UP * y1],
				[Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP], [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 1), Vector2(u0, 1)], 0.0)
			_quad(st, [e0 * ri0 + Vector3.UP * y0, e1 * ri0 + Vector3.UP * y0, e1 * rb0 + Vector3.UP * y0, e0 * rb0 + Vector3.UP * y0],
				[Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 0), Vector2(u0, 0)], 0.0)
	return st.commit()

## A unit disc (radius 1, scaled to the inside at the waterline), UV 0..1 across it.
func _disc(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 36
	for i in seg:
		var a0 := float(i) / seg * TAU
		var a1 := float(i + 1) / seg * TAU
		var p0 := Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := Vector3(cos(a1), 0, sin(a1)) * r
		_quad(st, [Vector3.ZERO, Vector3.ZERO, p1, p0], [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP],
			[Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(p1.x * 0.5 + 0.5, p1.z * 0.5 + 0.5), Vector2(p0.x * 0.5 + 0.5, p0.z * 0.5 + 0.5)], 0.0)
	return st.commit()
