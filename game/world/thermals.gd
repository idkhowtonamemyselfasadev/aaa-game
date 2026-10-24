class_name Thermals
extends Node3D
## Thermals: columns of warm air rising off sun-baked stone. One stands over the ruined keep's
## knoll, the others over the steepest sun-facing crags round the vale. They wake as the sun
## climbs, are strongest in the early afternoon, die away at dusk, and a front kills them
## (cloud shades the rock, rain wets it, a gale shreds the column). A glider that circles in
## the core climbs; just outside it the air sinks. Each column leans downwind with height.
## What gives them away: chaff and thistle-down spiralling up in the sun (one MultiMesh per
## column, animated in thermal.gdshader), and the red kites, which circle over them.

@export var terrain_path: NodePath
@export var crag_count := 2             # thermals over crags, besides the keep's
@export var seed := 9090

const TOP := 75.0          # m above the ground where the column has spread out and died
const LIFT := 3.6          # m/s up at the core of a full column
const SINK_RING := 0.45    # share of LIFT the air sinks by just outside the core
const MOTES := 220         # chaff per column
const NOON_SUN := Vector3(-0.883, 0.469, 0.0)   # toward the sun at noon (world.gd, 28 deg)

var columns: Array[Vector4] = []       # (x, ground y, z, core radius m)
var strength := 0.0                     # 0 dead (night, front) .. 1 a hot afternoon (bots read)
var lean := Vector3.ZERO                # m the axis drifts sideways per m of height
var _terrain: Terrain
var _world: Node
var _mats: Array[ShaderMaterial] = []
var _mmis: Array[MultiMeshInstance3D] = []

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_world = get_parent()
	var flora: Flora = _world.get_node_or_null("Flora")
	var keep := flora.ruin_site if flora else Vector3.INF
	if keep != Vector3.INF:
		columns.append(Vector4(keep.x, _terrain.height_at(keep.x, keep.z), keep.z, 9.0))
	_pick_crags()
	var shader: Shader = load("res://shaders/thermal.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for c in columns.size():
		var col := columns[c]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = MOTES
		for m in MOTES:
			mm.set_instance_transform(m, Transform3D.IDENTITY)
			# angle, height phase (0..1), radius share, kind (small chaff .. a leaf fleck)
			mm.set_instance_custom_data(m, Color(rng.randf() * TAU, rng.randf(),
				sqrt(rng.randf()) * rng.randf_range(0.55, 1.15), rng.randf()))
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("radius", col.w)
		mat.set_shader_parameter("top", TOP)
		mat.set_shader_parameter("seed", float(c) * 3.7)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Thermal%d" % c
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, TOP + 4.0, 80))
		add_child(mmi)
		mmi.global_position = Vector3(col.x, col.y, col.z)
		_mats.append(mat)
		_mmis.append(mmi)
	_send_kites()

## The steepest sun-facing crags 100-180 m out, well apart from each other, the keep and the
## east road (sun-facing rock on a steep face takes the most heat).
func _pick_crags() -> void:
	var cands: Array = []
	for gx in range(-180, 181, 10):
		for gz in range(-180, 181, 10):
			var x := float(gx)
			var z := float(gz)
			var r := Vector2(x, z).length()
			if r < 100.0 or r > 180.0 or absf(x - z) / sqrt(2.0) < 25.0:
				continue
			var h := _terrain.height_at(x, z)
			var ring := 0.0
			for k in 8:
				var a := TAU * k / 8.0
				ring += _terrain.height_at(x + cos(a) * 20.0, z + sin(a) * 20.0)
			var n := _terrain.normal_at(x, z, 4.0)
			var sc := h - ring / 8.0 + 60.0 * maxf(n.dot(NOON_SUN) - NOON_SUN.y, 0.0)
			cands.append(Vector3(x, z, sc))
	cands.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	for cd: Vector3 in cands:
		if columns.size() >= crag_count + 1:
			break
		var ok := true
		for col in columns:
			if Vector2(col.x - cd.x, col.z - cd.y).length() < 90.0:
				ok = false
		if ok:
			columns.append(Vector4(cd.x, _terrain.height_at(cd.x, cd.y), cd.y, 11.0))

## The kites soar over the thermals (a kite's circle tightens over a column).
func _send_kites() -> void:
	var birds = _world.get_node_or_null("Birds")
	if birds == null or columns.is_empty():
		return
	for k in birds._kites.size():
		var col := columns[k % columns.size()]
		var b = birds._kites[k]
		b.off = Vector3(col.x, b.off.y - 25.0, col.z)
		b.ring = 22.0 + 4.0 * k

func _process(_delta: float) -> void:
	_update_strength()
	var sun: DirectionalLight3D = _world.get("sun")
	var sun_dir := sun.global_basis.z if sun else Vector3.UP
	var light := sun.light_energy / 3.0 if sun and sun.visible else 0.0
	for c in _mats.size():
		var m := _mats[c]
		m.set_shader_parameter("strength", strength)
		m.set_shader_parameter("lean", Vector2(lean.x, lean.z))
		m.set_shader_parameter("sun_dir", sun_dir)
		m.set_shader_parameter("light", light)
		_mmis[c].visible = strength > 0.02

## How hard the columns draw: the sun's height (they lag it a little into the afternoon),
## less under cloud, wet ground or rain, and a gale tears them apart.
func _update_strength() -> void:
	var tod: float = _world.get("time_of_day") if _world.get("time_of_day") != null else 13.0
	var heat := clampf(sin((tod - 7.5) / 11.0 * PI), 0.0, 1.0)
	heat = pow(heat, 0.8)
	var wx = _world.get("weather")
	var cloud: float = wx.cloud if wx else 0.0
	var rain: float = wx.rain if wx else 0.0
	var wind: float = wx.wind if wx else 0.0
	var wet: float = wx.wet if wx else 0.0
	strength = heat * (1.0 - 0.8 * cloud) * (1.0 - rain) * (1.0 - 0.5 * wet) * (1.0 - 0.7 * wind)
	lean = Player.GLIDE_WIND_DIR.normalized() * lerpf(0.12, 0.6, wind)

## m/s of vertical air at world point p: up in a column's core, down in the ring round it.
func lift_at(p: Vector3) -> float:
	if strength <= 0.0:
		return 0.0
	var v := 0.0
	for col in columns:
		var above := p.y - col.y
		if above < 0.0 or above > TOP:
			continue
		var axis := Vector2(col.x + lean.x * above, col.z + lean.z * above)
		var r := col.w * (1.0 + above / TOP * 0.6)     # the column widens as it rises
		var d := Vector2(p.x, p.z).distance_to(axis) / r
		var hf := smoothstep(0.0, 6.0, above) * (1.0 - smoothstep(TOP * 0.65, TOP, above))
		v += hf * (exp(-d * d * 1.1) - SINK_RING * exp(-pow((d - 2.1) / 0.6, 2.0)))
	return v * LIFT * strength

## The column nearest p on the ground (x, ground y, z, radius), or Vector4.ZERO if none.
func nearest(p: Vector3) -> Vector4:
	var best := Vector4.ZERO
	var bd := INF
	for col in columns:
		var d := Vector2(col.x - p.x, col.z - p.z).length()
		if d < bd:
			bd = d
			best = col
	return best
