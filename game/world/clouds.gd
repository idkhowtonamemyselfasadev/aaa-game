class_name CloudLayer
extends MeshInstance3D
## The Vale's cloud deck: an inside-out hemisphere riding on the camera, drawn with
## shaders/clouds.gdshader. Fair-weather cumulus drift over on a clear day; a weather front
## thickens them into a grey rain deck. `world.gd` feeds the light and colours each frame.

@export var radius := 3400.0           # inside the camera far plane, beyond the mountain ring
@export var fair_cover := 0.4         # cumulus cover on a clear day
@export var drift_speed := 6.0         # m/s the deck moves in the usual breeze

var mat := ShaderMaterial.new()
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

## cloud 0..1 and wind 0..1 from Weather; light/shade/haze colours already exposure-ready
func update(delta: float, cloud: float, wind: float, light_dir: Vector3, light_col: Color,
		shade_col: Color, haze_col: Color) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position
	_drift += _wind_dir * drift_speed * (1.0 + 3.0 * wind) * delta
	mat.set_shader_parameter("drift", _drift)
	mat.set_shader_parameter("coverage", lerpf(fair_cover, 1.0, cloud))
	mat.set_shader_parameter("thickness", smoothstep(0.4, 1.0, cloud))
	mat.set_shader_parameter("haze_height", lerpf(0.1, 0.45, cloud))
	mat.set_shader_parameter("light_dir", light_dir)
	mat.set_shader_parameter("light_col", light_col)
	mat.set_shader_parameter("shade_col", shade_col)
	mat.set_shader_parameter("haze_col", haze_col)
