class_name CloudLayer
extends MeshInstance3D
## The Vale's cloud deck: an inside-out hemisphere riding on the camera, drawn with
## shaders/clouds.gdshader. Fair-weather cumulus drift over on a clear day; a weather front
## thickens them into a grey rain deck. `world.gd` feeds the light and colours each frame.

@export var radius := 3400.0           # inside the camera far plane, beyond the mountain ring
@export var fair_cover := 0.4         # cumulus cover on a clear day
@export var drift_speed := 6.0         # m/s the deck moves in the usual breeze

var mat := ShaderMaterial.new()
var shadow_strength := 0.0
var sun_dir_shadow := Vector3.UP
var cover := 0.4
var thick := 0.0
var _drift := Vector2.ZERO
var _wind_dir := Vector2(0.8, 0.6)

func _ready() -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.is_hemisphere = true
	m.radial_segments = 48
	m.rings = 16
	mesh = m
	mat.shader = load("res://shaders/clouds.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED

## Shadow strength 0..1 and the direction toward the sun for the cloud shadows on the land.
func set_shadow(sun_dir: Vector3, strength: float) -> void:
	shadow_strength = strength
	sun_dir_shadow = sun_dir
	RenderingServer.global_shader_parameter_set("cloud_sun", sun_dir)
	RenderingServer.global_shader_parameter_set("cloud_shadow", strength)

## cloud 0..1 and wind 0..1 from Weather; light/shade/haze colours already exposure-ready
func update(delta: float, cloud: float, wind: float, light_dir: Vector3, light_col: Color,
		shade_col: Color, haze_col: Color) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position
	_drift += _wind_dir * drift_speed * (1.0 + 3.0 * wind) * delta
	cover = lerpf(fair_cover, 1.0, cloud)
	thick = smoothstep(0.4, 1.0, cloud)
	mat.set_shader_parameter("drift", _drift)
	mat.set_shader_parameter("coverage", cover)
	mat.set_shader_parameter("thickness", thick)
	# the same deck casts shadows on the land (shaders/cloud_shadow.gdshaderinc)
	RenderingServer.global_shader_parameter_set("cloud_drift", _drift)
	RenderingServer.global_shader_parameter_set("cloud_cover", cover)
	RenderingServer.global_shader_parameter_set("cloud_thick", thick)
	mat.set_shader_parameter("haze_height", lerpf(0.1, 0.45, cloud))
	mat.set_shader_parameter("light_dir", light_dir)
	mat.set_shader_parameter("light_col", light_col)
	mat.set_shader_parameter("shade_col", shade_col)
	mat.set_shader_parameter("haze_col", haze_col)

# ---- CPU mirror of shaders/cloud_shadow.gdshaderinc (bots; later audio/AI "in shade") ----
static func _hash(p: Vector2) -> float:
	p = Vector2(fposmod(p.x * 123.34, 1.0), fposmod(p.y * 456.21, 1.0))
	var k := p.dot(p + Vector2(45.32, 45.32))
	p += Vector2(k, k)
	return fposmod(p.x * p.y, 1.0)

static func _noise(x: Vector2) -> float:
	var i := x.floor()
	var f := x - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x),
			lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)

static func _fbm(p: Vector2, oct: int, full: int) -> float:
	var s := 0.0
	var a := 0.5
	for i in oct:
		s += a * _noise(p)
		# GLSL mat2(c0, c1) * p with columns (0.8, -0.6) and (0.6, 0.8)
		p = Vector2(0.8 * p.x + 0.6 * p.y, -0.6 * p.x + 0.8 * p.y) * 2.03 + Vector2(17.1, 9.2)
		a *= 0.5
	if full > oct:
		s += a * (1.0 - pow(0.5, full - oct))
	return s

static func deck_density(p: Vector2, oct: int, detail: int, pad: bool, cov: float, thk: float) -> float:
	var fo := 5 if pad else 0
	var fd := 3 if pad else 0
	var q := p / 1700.0
	var w := Vector2(_fbm(q * 0.5 + Vector2(3.1, 1.7), detail, fd),
			_fbm(q * 0.5 + Vector2(8.3, 2.8), detail, fd))
	var n := _fbm(q + 0.7 * w, oct, fo)
	n -= 0.2 * (1.0 - _fbm(p / 300.0 + w * 2.0, detail, fd)) * (1.0 - 0.6 * thk)
	var lo := lerpf(0.5, 0.0, cov)
	return smoothstep(lo, lo + lerpf(0.1, 0.38, cov), n)

## 1 in full sun .. 1 - 0.55 * strength under a thick cloud (same as the shader)
func shade_at(wp: Vector3) -> float:
	if shadow_strength < 0.01:
		return 1.0
	var l := sun_dir_shadow.normalized()
	l.y = maxf(l.y, 0.12)
	var p := Vector2(wp.x, wp.z) + Vector2(l.x, l.z) * ((1500.0 - wp.y) / l.y) + _drift
	var d := deck_density(p, 3, 2, true, cover, thick)
	return 1.0 - 0.55 * shadow_strength * smoothstep(0.05, 0.75, d)
