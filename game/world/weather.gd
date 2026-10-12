class_name Weather
extends Node3D
## Weather fronts for the Vale. Long dry spells; then cloud builds over a minute or two, the
## wind rises, rain sets in, holds a few minutes, and the front passes and the land dries.
## Writes the shader globals `weather_wind` / `weather_wet` (grass, flowers, trees, terrain,
## rocks read them), runs the rain streaks around the camera, and exposes `cloud`, `rain`,
## `wind` and `wet` for the world (sky, light, fog) and wildlife (butterflies, midges shelter).
## Drops burst into splashes on the ground in view of the camera (placed on the terrain
## height on the CPU: the GPU height-field collision + sub-emitter path does not fire under
## the software renderer, so it could not be verified); the hero splashes through pools.

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
var _splash: GPUParticles3D
var _wade: GPUParticles3D
var _splash_acc := 0.0
var rain_splashes := 0    # drop splashes emitted (bots)
@export var splash_rate := 1500.0   # splashes per second at full rain, within splash_radius
@export var splash_radius := 14.0
var _wade_dist := 0.0
var _wade_foot := 1.0
var wade_splashes := 0    # footfalls that splashed through a pool (bots)
const WAKE_RINGS := 8     # wade_ring_0..7 shader globals (terrain.gdshader)
const WAKE_LIFE := 1.8    # seconds a footfall's ring train runs
var _wake: Array[Vector4] = []   # (x, z, age, strength) per slot
var _wake_next := 0
var lightning: Lightning   # bolts + flashes once the rain is heavy

const FX_LAYER := 1 << 9  # rain + splashes

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
	_rain.layers = FX_LAYER
	add_child(_rain)
	_splash = _make_splash("Splashes", 2400, 0.32, 0.3, Vector2(0.6, 1.25))
	_splash.emitting = false    # fed by _update_splashes()
	_wade = _make_splash("WadeSplashes", 96, 0.5, 0.75, Vector2(0.8, 1.2))
	_wade.emitting = false      # fed by wade_splash()
	var wm := (_wade.draw_pass_1 as QuadMesh).material as ShaderMaterial
	wm.set_shader_parameter("opacity", 0.9)
	wm.set_shader_parameter("tint", Color(0.86, 0.88, 0.9))
	for i in WAKE_RINGS:
		_wake.append(Vector4.ZERO)
	lightning = Lightning.new()
	lightning.name = "Lightning"
	add_child(lightning)
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

## Splash bursts drawn by splash.gdshader. The process material resets each particle's
## scale every step, so the burst size is the shader's `size`, not the emit transform.
func _make_splash(nm: String, n: int, life: float, size: float, scale: Vector2) -> GPUParticles3D:
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3.UP
	spm.spread = 0.0
	spm.initial_velocity_min = 0.0
	spm.initial_velocity_max = 0.0
	spm.gravity = Vector3.ZERO
	spm.scale_min = scale.x
	spm.scale_max = scale.y
	var sq := QuadMesh.new()
	sq.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/splash.gdshader")
	m.set_shader_parameter("size", size)
	sq.material = m
	var ps := GPUParticles3D.new()
	ps.name = nm
	ps.amount = n
	ps.lifetime = life
	ps.local_coords = false
	ps.process_material = spm
	ps.draw_pass_1 = sq
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.layers = FX_LAYER
	ps.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	add_child(ps)
	return ps

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
	_update_wade(delta)
	_update_wake(delta)
	_update_splashes(delta)
	_push_globals()

## True where rain stands in a pool right now (mirrors the terrain shader's puddles: the
## water climbs from the deepest hollows to every one deeper than `puddle_soaked`).
func pool_at(x: float, z: float) -> bool:
	var terrain = get_parent().get("terrain")
	if terrain == null:
		return false
	var fill := smoothstep(0.35, 1.0, wet)
	if fill < 0.01:
		return false
	var thr := lerpf(0.85, 0.27, fill)
	var flat: float = 1.0 - smoothstep(0.0125, 0.025, 1.0 - terrain.normal_at(x, z, 2.0).y)
	return flat > 0.5 and terrain.baked_hollow(x, z) > thr + 0.03

## A footfall in water: a big crown at the foot, a smaller throw beside it, and a ring
## train that spreads across the pool from the foot.
func wade_splash(at: Vector3, strength := 1.0) -> void:
	wade_splashes += 1
	_wake[_wake_next] = Vector4(at.x, at.z, 0.0, strength)
	_wake_next = (_wake_next + 1) % WAKE_RINGS
	_wade.emit_particle(Transform3D(Basis(), at), Vector3.ZERO, Color.WHITE, Color.WHITE,
			GPUParticles3D.EMIT_FLAG_POSITION)
	var off := Vector3(_rng.randf_range(-0.15, 0.15), 0.0, _rng.randf_range(-0.15, 0.15))
	_splash.emit_particle(Transform3D(Basis(), at + off), Vector3.ZERO, Color.WHITE, Color.WHITE,
			GPUParticles3D.EMIT_FLAG_POSITION)

## Drops landing in front of the camera: crowns on the ground (and on the pools), mostly
## within the view cone, denser close in where they resolve.
func _update_splashes(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var terrain = get_parent().get("terrain")
	if cam == null or terrain == null or rain < 0.05:
		_splash_acc = 0.0
		return
	_splash_acc += splash_rate * rain * delta
	var n := mini(int(_splash_acc), 60)
	_splash_acc -= float(int(_splash_acc))
	var c := cam.global_position
	var f := -cam.global_basis.z
	var yaw := atan2(f.x, f.z)
	for k in n:
		var ang := yaw + _rng.randf_range(-1.1, 1.1)
		var r := splash_radius * sqrt(_rng.randf_range(0.004, 1.0))
		var x := c.x + sin(ang) * r
		var z := c.z + cos(ang) * r
		_splash.emit_particle(Transform3D(Basis(), Vector3(x, terrain.height_at(x, z) + 0.01, z)),
				Vector3.ZERO, Color.WHITE, Color.WHITE, GPUParticles3D.EMIT_FLAG_POSITION)
		rain_splashes += 1

func _update_wade(delta: float) -> void:
	var p = get_parent().get("player")
	if p == null or not (p is CharacterBody3D) or not p.is_on_floor():
		return
	var v := Vector2(p.velocity.x, p.velocity.z)
	var sp := v.length()
	if sp < 0.6:
		_wade_dist = 0.0
		return
	_wade_dist += sp * delta
	# a footfall every half stride: ~0.7 m walking, ~1.1 m running
	var half := lerpf(0.7, 1.1, clampf((sp - 1.5) / 4.5, 0.0, 1.0))
	if _wade_dist < half:
		return
	_wade_dist -= half
	_wade_foot = -_wade_foot
	var dir := Vector3(v.x, 0.0, v.y) / sp
	var at: Vector3 = p.global_position + dir.cross(Vector3.UP) * 0.11 * _wade_foot + dir * 0.25
	if pool_at(at.x, at.z):
		var terrain = get_parent().get("terrain")
		at.y = terrain.height_at(at.x, at.z) + 0.01
		wade_splash(at)

## Age the footfall rings and hand them to the terrain shader.
func _update_wake(delta: float) -> void:
	for i in WAKE_RINGS:
		var r := _wake[i]
		if r.w <= 0.0:
			continue
		r.z += delta
		if r.z > WAKE_LIFE:
			r = Vector4.ZERO
		_wake[i] = r
		RenderingServer.global_shader_parameter_set("wade_ring_%d" % i, r)

## Footfall rings still spreading (bots).
func wake_rings() -> int:
	var n := 0
	for r in _wake:
		if r.w > 0.0:
			n += 1
	return n

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
	for ps: GPUParticles3D in [_splash, _wade]:
		((ps.draw_pass_1 as QuadMesh).material as ShaderMaterial).set_shader_parameter("brightness", lerpf(0.08, 0.95, day))

func _push_globals() -> void:
	RenderingServer.global_shader_parameter_set("weather_wind", wind)
	RenderingServer.global_shader_parameter_set("weather_wet", wet)
	RenderingServer.global_shader_parameter_set("weather_rain", rain)

func raining() -> bool:
	return rain > 0.15
