class_name Lightning
extends Node3D
## Lightning for strong fronts. Once the rain is heavy, a bolt strikes somewhere in the far
## deck every 7–26 s: a jagged branching channel from the cloud base to the ground, a
## flickering flash (2–4 return strokes) that lights the deck around the strike, the haze
## and the land from the bolt's side. Child of Weather; the world's light/fog values are
## rebuilt each frame by world.gd before this runs (parents process first), so the flash
## is added on top. No thunder yet: the game has no audio.

@export var min_rain := 0.7                    # rain level a front must reach to strike
@export var interval := Vector2(7.0, 26.0)     # seconds between strikes in a full storm
@export var distance := Vector2(700.0, 2400.0) # metres from the camera
@export var flash_col := Color(0.74, 0.8, 1.0)
@export var flash_energy := 2.2                # directional light at a near strike's peak

const DECK_H := 1500.0      # cloud base (shaders/cloud_shadow.gdshaderinc CLOUD_DECK_H)
const BOLT_LIFE := 0.75     # seconds the channel can stay lit (last stroke + afterglow)

var flash := 0.0            # 0..1 the sky flash right now (bots, world)
var strikes := 0            # bolts so far (bots)
var auto_strikes := true    # false: only strike() makes bolts (shots)
var hold_age := -1.0        # shots: >= 0 freezes the flash this many seconds into a strike
var strike_pos := Vector3.ZERO   # where the last bolt met the ground
var bolt: MeshInstance3D
var light: DirectionalLight3D

var _age := 99.0
var _strokes: Array[Vector2] = []   # (start time, strength)
var _near := 1.0                    # 1 close .. ~0.35 at the far end of `distance`
var _next := 0.0
var _rng := RandomNumberGenerator.new()
var _bolt_mat := ShaderMaterial.new()

func _ready() -> void:
	_rng.seed = 4242
	_next = _rng.randf_range(2.0, interval.y)
	_bolt_mat.shader = load("res://shaders/bolt.gdshader")
	_bolt_mat.render_priority = 10   # after the cloud dome (it sorts nearer and hid the bolt)
	bolt = MeshInstance3D.new()
	bolt.name = "Bolt"
	bolt.top_level = true
	bolt.material_override = _bolt_mat
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	bolt.extra_cull_margin = 4096.0
	bolt.visible = false
	add_child(bolt)
	light = DirectionalLight3D.new()
	light.name = "Flash"
	light.top_level = true
	light.light_color = flash_col
	light.shadow_enabled = false
	light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	light.light_energy = 0.0
	light.visible = false
	add_child(light)

func _weather() -> Weather:
	return get_parent() as Weather

## 0 in light rain .. 1 in a full downpour: how stormy the front is.
func storm() -> float:
	var w := _weather()
	return smoothstep(min_rain, 1.0, w.rain) if w else 0.0

func _process(delta: float) -> void:
	var s := storm()
	if s > 0.0 and auto_strikes:
		_next -= delta * lerpf(0.4, 1.0, s)
		if _next <= 0.0:
			strike()
			_next = _rng.randf_range(interval.x, interval.y)
	_age = hold_age if hold_age >= 0.0 else _age + delta
	_update_flash()

## A bolt now, at `at` on the ground (default: a random spot 700–2400 m out, mostly ahead).
func strike(at := Vector3.INF) -> void:
	var cam := get_viewport().get_camera_3d()
	var c := cam.global_position if cam else Vector3.ZERO
	if at == Vector3.INF:
		var yaw := 0.0
		if cam:
			var f := -cam.global_basis.z
			yaw = atan2(f.x, f.z)
		# mostly ahead of the camera (a strike behind you only lights the land)
		var ang := yaw + _rng.randf_range(-1.2, 1.2) if _rng.randf() < 0.7 else _rng.randf_range(-PI, PI)
		var r := _rng.randf_range(distance.x, distance.y)
		at = Vector3(c.x + sin(ang) * r, 0.0, c.z + cos(ang) * r)
		at.y = _ground(at.x, at.z)
	strike_pos = at
	strikes += 1
	_age = 0.0
	_strokes.clear()
	var t := 0.0
	var n := _rng.randi_range(2, 4)
	for i in n:
		_strokes.append(Vector2(t, 1.0 if i == 0 else _rng.randf_range(0.45, 0.9)))
		t += _rng.randf_range(0.06, 0.16)
	var d := Vector2(at.x - c.x, at.z - c.z).length()
	_near = lerpf(1.0, 0.35, smoothstep(distance.x * 0.5, distance.y, d))
	_build_bolt(at, c)
	# the flash lights the land from the bolt's side, from high in the deck
	var to_bolt := Vector3(at.x - c.x, 0.0, at.z - c.z).normalized()
	var dir := (to_bolt + Vector3.UP * 0.9).normalized()   # toward the light
	light.global_basis = Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)

func _ground(x: float, z: float) -> float:
	var w := _weather().get_parent() if _weather() else null
	if w and w.has_node("Horizon") and w.get_node("Horizon").has_method("height_at"):
		return w.get_node("Horizon").height_at(x, z)
	return 0.0

## The flash envelope: each return stroke is a sharp spike with a fast decay.
func _envelope(t: float) -> float:
	var f := 0.0
	for st in _strokes:
		var u := t - st.x
		if u >= 0.0:
			f = maxf(f, st.y * exp(-u / 0.05))
	return f

func _update_flash() -> void:
	var w := _weather()
	var world := w.get_parent() if w else null
	flash = _envelope(_age) * _near if _age < BOLT_LIFE + 0.5 else 0.0
	# the channel holds a faint glow between strokes and dies after the last one
	var last := _strokes[-1].x if not _strokes.is_empty() else 0.0
	var glow := 0.12 * (1.0 - smoothstep(last, last + 0.3, _age)) if _age < BOLT_LIFE else 0.0
	bolt.visible = _age < BOLT_LIFE
	if bolt.visible:
		var cam := get_viewport().get_camera_3d()
		var d := strike_pos.distance_to(cam.global_position) if cam else 1000.0
		_bolt_mat.set_shader_parameter("brightness", maxf(_envelope(_age), glow))
		_bolt_mat.set_shader_parameter("veil", lerpf(1.0, 0.3, (w.rain if w else 0.0) * smoothstep(500.0, 3000.0, d)))
	light.visible = flash > 0.01
	light.light_energy = flash_energy * flash
	if world == null:
		return
	var cl = world.get("clouds")
	if cl:
		var drift: Vector2 = cl.mat.get_shader_parameter("drift")
		cl.mat.set_shader_parameter("flash", flash)
		cl.mat.set_shader_parameter("flash_at", Vector2(strike_pos.x, strike_pos.z) + drift)
		cl.mat.set_shader_parameter("flash_col", flash_col)
	var env: WorldEnvironment = world.get("env")
	if env and env.environment and flash > 0.0:
		var e := env.environment
		# the whole deck glows: skylight and haze jump with it
		e.ambient_light_energy += 1.6 * flash
		e.ambient_light_color = e.ambient_light_color.lerp(flash_col, 0.5 * flash)
		e.fog_light_color += flash_col * 0.45 * flash
		e.volumetric_fog_emission += flash_col * 0.04 * flash

## The channel: midpoint-displaced from the cloud base to the ground, with branches forking
## off downward from its upper part. Camera-facing ribbons, a few metres wide.
func _build_bolt(ground: Vector3, cam: Vector3) -> void:
	var top := Vector3(ground.x + _rng.randf_range(-250.0, 250.0), DECK_H, ground.z + _rng.randf_range(-250.0, 250.0))
	var main := _jag(top, ground, 6, 0.3)
	var dist := ground.distance_to(cam)
	# ~8 px ribbon, ~2 px core at 720p at any range: a 1 px core only lives a few frames and
	# TAA (with the volumetric fog) rejected it, so the bolt drew as dark dots
	var wmain := clampf(dist * 0.016, 6.0, 48.0)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	_ribbon(main, wmain, 1.0, cam, verts, uvs, cols)
	var nb := _rng.randi_range(4, 7)
	for i in nb:
		var k := _rng.randi_range(int(main.size() * 0.08), int(main.size() * 0.7))
		var a := main[k]
		var down := main[-1] - a
		var side := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
		var l := down.length() * _rng.randf_range(0.15, 0.4)
		var b := a + (down.normalized() * 0.6 + side * 0.8).normalized() * l
		var br := _jag(a, b, 5, 0.28)
		_ribbon(br, wmain * 0.55, _rng.randf_range(0.3, 0.6), cam, verts, uvs, cols)
		# a twig off the branch
		if _rng.randf() < 0.6:
			var a2 := br[br.size() / 2]
			var b2 := a2 + (Vector3.DOWN * 0.7 + Vector3(-side.z, 0.0, side.x) * _rng.randf_range(-1.0, 1.0)).normalized() * l * 0.45
			_ribbon(_jag(a2, b2, 4, 0.3), wmain * 0.35, 0.25, cam, verts, uvs, cols)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	bolt.mesh = m
	bolt.global_transform = Transform3D.IDENTITY

## Recursive midpoint displacement: each level splits every segment and kicks the midpoint
## sideways by `rough` of the segment's length (tortuous, never looping back up).
func _jag(a: Vector3, b: Vector3, levels: int, rough: float) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	for lv in levels:
		var nxt := PackedVector3Array()
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			var seg := q - p
			var len := seg.length()
			var off := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1.0, 1.0))
			off -= seg.normalized() * off.dot(seg.normalized())
			nxt.append(p)
			nxt.append((p + q) * 0.5 + off * len * rough)
		nxt.append(pts[-1])
		pts = nxt
	return pts

## A camera-facing strip along `pts`, tapering to 40 % width at its end.
func _ribbon(pts: PackedVector3Array, width: float, strength: float, cam: Vector3,
		verts: PackedVector3Array, uvs: PackedVector2Array, cols: PackedColorArray) -> void:
	var n := pts.size()
	var sides: Array[Vector3] = []
	for i in n:
		var tan := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var s := tan.cross(cam - pts[i]).normalized()
		var w := width * lerpf(1.0, 0.4, float(i) / float(n - 1)) * 0.5
		sides.append(s * w)
	for i in n - 1:
		var a0 := pts[i] - sides[i]
		var a1 := pts[i] + sides[i]
		var b0 := pts[i + 1] - sides[i + 1]
		var b1 := pts[i + 1] + sides[i + 1]
		var c := Color(1, 1, 1, strength)
		for v in [[a0, 0.0], [a1, 1.0], [b1, 1.0], [a0, 0.0], [b1, 1.0], [b0, 0.0]]:
			verts.append(v[0])
			uvs.append(Vector2(v[1], 0.0))
			cols.append(c)
