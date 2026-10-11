class_name Weather
extends Node3D
## Weather fronts for the Vale. Long dry spells; then cloud builds over a minute or two, the
## wind rises, rain sets in, holds a few minutes, and the front passes and the land dries.
## Writes the shader globals `weather_wind` / `weather_wet` (grass, flowers, trees, terrain,
## rocks read them), runs the rain streaks around the camera, and exposes `cloud`, `rain`,
## `wind` and `wet` for the world (sky, light, fog) and wildlife (butterflies, midges shelter).

@export var auto_fronts := true
@export var clear_hold := Vector2(360.0, 900.0)   # seconds between fronts
@export var front_hold := Vector2(150.0, 360.0)   # seconds a front rains for
@export var build_rate := 1.0 / 70.0              # cloud cover per second as a front arrives
@export var drops := 9000

var cloud := 0.0     # 0 clear .. 1 full overcast (leads the rain in, lingers after it)
var rain := 0.0      # 0 dry .. 1 downpour
var wind := 0.0      # 0 usual breeze .. 1 storm (gusting)
var wet := 0.0       # 0 dry ground .. 1 soaked (lags the rain; dries slowly)
var fronts := 0      # fronts that have rolled in (bots)

var _target := 0.0   # front strength being built toward (0 when clearing)
var _timer := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _rain: GPUParticles3D
var _rain_mat: ShaderMaterial
var _pm: ParticleProcessMaterial

func _ready() -> void:
	_rng.seed = 7071
	_timer = _rng.randf_range(clear_hold.x, clear_hold.y)
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_pm.emission_box_extents = Vector3(22.0, 0.5, 22.0)
	_pm.direction = Vector3(0, -1, 0)
	_pm.spread = 2.0
	_pm.initial_velocity_min = 9.5
	_pm.initial_velocity_max = 11.5
	_pm.gravity = Vector3(0, -2.0, 0)
	_pm.particle_flag_align_y = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = load("res://shaders/rain.gdshader")
	q.material = _rain_mat
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = drops
	_rain.lifetime = 1.6
	_rain.preprocess = 1.6
	_rain.local_coords = false
	_rain.process_material = _pm
	_rain.draw_pass_1 = q
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.visibility_aabb = AABB(Vector3(-30, -25, -30), Vector3(60, 32, 60))
	_rain.emitting = false
	_rain.amount_ratio = 0.0
	add_child(_rain)
	_push_globals()

## Bots/shots: set a front strength now (instant) or let it build (instant = false).
func force(strength: float, instant := true) -> void:
	auto_fronts = false
	_target = clampf(strength, 0.0, 1.0)
	if strength > 0.0 and cloud < 0.3:
		fronts += 1
	if instant:
		cloud = _target
		rain = _rain_level(cloud)
		wet = minf(1.0, rain * 1.2)
		wind = cloud
		_update_rain(0.0)
		_push_globals()

func _rain_level(c: float) -> float:
	# rain only sets in once the sky is mostly covered
	return smoothstep(0.55, 0.95, c) * maxf(_target, c * 0.8)

func _process(delta: float) -> void:
	_t += delta
	if auto_fronts:
		_timer -= delta
		if _timer <= 0.0:
			if _target > 0.0:
				_target = 0.0
				_timer = _rng.randf_range(clear_hold.x, clear_hold.y)
			else:
				_target = _rng.randf_range(0.65, 1.0)
				fronts += 1
				_timer = _rng.randf_range(front_hold.x, front_hold.y)
	# cloud builds over ~a minute, clears a little slower
	cloud = move_toward(cloud, _target, delta * (build_rate if _target > cloud else build_rate * 0.7))
	rain = move_toward(rain, _rain_level(cloud), delta * 0.08)
	# gusts ride on the front; strongest at its leading edge
	var gust := 0.5 + 0.5 * sin(_t * 0.37) * sin(_t * 0.11 + 1.3)
	wind = move_toward(wind, clampf(cloud * (0.65 + 0.45 * gust), 0.0, 1.0), delta * 0.2)
	# ground soaks in ~40 s of real rain and dries over a few minutes
	if rain > 0.05:
		wet = move_toward(wet, 1.0, delta * rain / 40.0)
	else:
		wet = move_toward(wet, 0.0, delta / 240.0)
	_update_rain(delta)
	_push_globals()

func _update_rain(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		# the emitter rides above the camera, a little upwind so the slant fills the view
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		global_position = cam.global_position + fwd.normalized() * 6.0 + Vector3(0, 9.0, 0)
	_rain.amount_ratio = rain
	_rain.emitting = rain > 0.01
	# wind slants the rain along the meadow wind direction (0.8, 0.6)
	_pm.direction = Vector3(0.8 * wind * 0.35, -1.0, 0.6 * wind * 0.35).normalized()
	var w := get_parent()
	var day := 1.0
	if w and w.get("time_of_day") != null:
		var h: float = w.time_of_day
		day = smoothstep(5.0, 7.5, h) * (1.0 - smoothstep(18.0, 20.0, h))
	_rain_mat.set_shader_parameter("brightness", lerpf(0.08, 0.9, day))

func _push_globals() -> void:
	RenderingServer.global_shader_parameter_set("weather_wind", wind)
	RenderingServer.global_shader_parameter_set("weather_wet", wet)

func raining() -> bool:
	return rain > 0.15
