class_name AshFlame
extends Node3D
## One eruption of the Ashen Knight's burning ground (phase 3). The ground under the hero
## starts to glow: a ring of embers smoulders in the turf and tightens for WARN s (the tell:
## step or roll out of it), then a column of flame and sparks bursts up out of it and scorches
## anything still standing inside RADIUS. Dodge i-frames pass through it like any strike; the
## heavy cannot deflect fire. Frees itself when the last smoke has gone.

const WARN := 1.15
const RADIUS := 1.7
const DAMAGE := 18.0
const BURN := 0.55            # s the column stands
const LIFE := 3.6

var source: Node              # the knight (receive_attack's attacker)
var player: Player
var t := 0.0
var result := ""              # "" until the burst resolves, then hit / perfect / dodged / miss
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _fire: CPUParticles3D
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D

static var _soft: ImageTexture
static var _ring_tex: ImageTexture

func _ready() -> void:
	_ring = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(RADIUS * 2.4, RADIUS * 2.4)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_texture = _ring_texture()
	_ring_mat.albedo_color = Color(1.0, 0.4, 0.1, 0.0)
	_ring_mat.render_priority = 1
	q.material = _ring_mat
	_ring.mesh = q
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.18)
	_light.omni_range = 5.0
	_light.light_energy = 0.0
	_light.position.y = 0.6
	add_child(_light)
	_fire = _emitter(70, 0.7, Vector2(0.35, 0.75), Color(1.0, 0.62, 0.22), 3.0)
	_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fire.emission_sphere_radius = RADIUS * 0.6
	_fire.initial_velocity_min = 3.5
	_fire.initial_velocity_max = 6.5
	_fire.gravity = Vector3(0, 2.0, 0)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	g.set_color(1, Color(0.12, 0.08, 0.06, 0.0))
	g.add_point(0.35, Color(1.0, 0.42, 0.1, 0.9))
	g.add_point(0.7, Color(0.4, 0.12, 0.04, 0.5))
	_fire.color_ramp = g
	_sparks = _emitter(90, 1.4, Vector2(0.025, 0.05), Color(1.0, 0.6, 0.25), 6.0)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = RADIUS * 0.5
	_sparks.initial_velocity_min = 4.0
	_sparks.initial_velocity_max = 9.0
	_sparks.spread = 35.0
	_sparks.gravity = Vector3(0, -6.0, 0)
	_smoke = _emitter(40, 2.4, Vector2(0.6, 1.4), Color(0.16, 0.15, 0.14, 0.55), 0.0)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = RADIUS * 0.7
	_smoke.initial_velocity_min = 1.2
	_smoke.initial_velocity_max = 2.4
	_smoke.gravity = Vector3(0.3, 0.6, 0)
	var gs := Gradient.new()
	gs.set_color(0, Color(0.2, 0.18, 0.16, 0.0))
	gs.set_color(1, Color(0.2, 0.19, 0.18, 0.0))
	gs.add_point(0.2, Color(0.18, 0.16, 0.15, 0.5))
	_smoke.color_ramp = gs

func _emitter(n: int, life: float, size: Vector2, col: Color, glow: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.75
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 18.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.angle_min = -180.0
	p.angle_max = 180.0
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	m.albedo_color = Color(col.r * maxf(glow, 1.0) * 0.5, col.g * maxf(glow, 1.0) * 0.5, col.b * maxf(glow, 1.0) * 0.5, col.a) if glow > 0.0 else col
	q.material = m
	p.mesh = q
	p.position.y = 0.2
	add_child(p)
	return p

func _process(delta: float) -> void:
	t += delta
	if t < WARN:
		# the smoulder brightens and the ring draws in: the closer to the burst the hotter
		var u := t / WARN
		_ring_mat.albedo_color = Color(1.0, 0.38 + 0.2 * u, 0.1, 0.25 + 0.75 * u * u + 0.1 * sin(t * 30.0))
		_ring.scale = Vector3.ONE * lerpf(1.15, 1.0, u)
		_light.light_energy = 0.4 + 1.6 * u * u
		return
	if result == "":
		_burst()
	var b := t - WARN
	_light.light_energy = 6.0 * exp(-b * 3.0) + (1.2 * (1.0 - b / BURN) if b < BURN else 0.0)
	_ring_mat.albedo_color = Color(1.0, 0.35, 0.08, maxf(1.0 - b / 1.6, 0.0))
	if t > WARN + LIFE:
		queue_free()

func _burst() -> void:
	result = "miss"
	_fire.emitting = true
	_sparks.emitting = true
	_smoke.emitting = true
	if player == null or player.is_dead():
		return
	var d := player.global_position - global_position
	if Vector2(d.x, d.z).length() < RADIUS and absf(d.y) < 2.0:
		result = player.receive_attack(source if source != null else self, DAMAGE, true, true)
		if result == "hit":
			player.add_shake(0.5)

static func _soft_texture() -> ImageTexture:
	if _soft != null:
		return _soft
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var v := clampf(1.0 - p.length(), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v * v))
	_soft = ImageTexture.create_from_image(img)
	return _soft

## A ragged ring of embers: brightest at the rim, a faint glow inside, broken up by noise so
## it reads as burning turf and not a drawn circle.
static func _ring_texture() -> ImageTexture:
	if _ring_tex != null:
		return _ring_tex
	var n := 256
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.frequency = 0.06
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var r := p.length() * 1.2
			var k := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var rim := exp(-pow((r - 0.95) / 0.07, 2.0)) * (0.5 + 0.8 * k)
			var inner := (0.12 + 0.35 * k * k) * (1.0 - smoothstep(0.7, 1.0, r))
			var v := clampf(rim + inner, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	img.generate_mipmaps()
	_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex
