class_name AshFlame
extends Node3D
## One eruption of the Ashen Knight's burning ground (phase 3). The ground under the hero
## starts to glow: a ragged scorch with glowing fissures spreads through the turf and tightens for WARN s (the tell:
## step or roll out of it), then a column of flame and sparks bursts up out of it and scorches
## anything still standing inside RADIUS. Dodge i-frames pass through it like any strike; the
## heavy cannot deflect fire. Frees itself when the last smoke has gone.

signal burst(at: Vector3)

const WARN := 1.15
const RADIUS := 1.7
const DAMAGE := 18.0
const BURN := 0.55            # s the column stands
const LIFE := 3.6

var source: Node              # the knight (receive_attack's attacker)
var player: Player
var t := 0.0
var result := ""              # "" until the burst resolves, then hit / perfect / dodged / miss
var _ring: Decal
var _motes: CPUParticles3D
var _fire: CPUParticles3D
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D

static var _soft: ImageTexture
static var _scorch_tex: ImageTexture
static var _ember_tex: ImageTexture

func _ready() -> void:
	# the tell is a Decal so it hugs the real turf (slopes, tussocks, stones) instead of a flat
	# card floating over it: a charred scorch with glowing fissures and ember specks
	_ring = Decal.new()
	_ring.size = Vector3(RADIUS * 2.25, 1.6, RADIUS * 2.25)
	_ring.texture_albedo = _scorch_texture()
	_ring.texture_emission = _ember_texture()
	_ring.emission_energy = 0.0
	_ring.albedo_mix = 1.0
	_ring.modulate = Color(1, 1, 1, 0.0)
	_ring.upper_fade = 0.25
	_ring.lower_fade = 0.25
	_ring.rotation.y = randf() * TAU
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
	# heat over the smoulder: a thin trickle of ember motes lifting off the fissures
	_motes = _emitter(26, 1.3, Vector2(0.015, 0.035), Color(1.0, 0.55, 0.2), 4.0)
	_motes.one_shot = false
	_motes.explosiveness = 0.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3.UP
	_motes.emission_ring_radius = RADIUS * 0.85
	_motes.emission_ring_inner_radius = RADIUS * 0.2
	_motes.emission_ring_height = 0.05
	_motes.initial_velocity_min = 0.4
	_motes.initial_velocity_max = 1.1
	_motes.spread = 25.0
	_motes.gravity = Vector3(0.15, 0.5, 0.0)
	_motes.position.y = 0.05
	_motes.emitting = true

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
		# the char spreads fast, the fissures heat slowly then flicker hard just before the burst
		_ring.modulate = Color(1, 1, 1, minf(u * 3.0, 1.0))
		_ring.emission_energy = 0.4 + 3.2 * u * u + (0.5 + 1.5 * u) * sin(t * 23.0) * 0.25
		_ring.scale = Vector3.ONE * lerpf(1.12, 1.0, u)
		_light.light_energy = 0.4 + 1.6 * u * u
		return
	if result == "":
		_burst()
	var b := t - WARN
	_light.light_energy = 6.0 * exp(-b * 3.0) + (1.2 * (1.0 - b / BURN) if b < BURN else 0.0)
	# the fissures cool to dull red then black; the scorch itself lingers and fades last
	_ring.emission_energy = 6.0 * exp(-b * 2.2)
	_ring.modulate = Color(1, 1, 1, clampf((LIFE - b) / 1.2, 0.0, 1.0))
	if t > WARN + LIFE:
		queue_free()

func _burst() -> void:
	result = "miss"
	_motes.emitting = false
	_fire.emitting = true
	_sparks.emitting = true
	_smoke.emitting = true
	burst.emit(global_position)
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

## The char: near-black burnt turf, densest in the middle, its edge eaten ragged by noise so it
## reads as a scorch and never as a drawn circle. Ashy grey flecks break up the black.
static func _scorch_texture() -> ImageTexture:
	if _scorch_tex != null:
		return _scorch_tex
	var n := 256
	var lo := FastNoiseLite.new()
	lo.seed = 41
	lo.frequency = 0.022
	lo.fractal_octaves = 4
	var hi := FastNoiseLite.new()
	hi.seed = 7
	hi.frequency = 0.18
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var k := lo.get_noise_2d(x, y)
			var r := p.length() + k * 0.28
			var a := 1.0 - smoothstep(0.55, 0.92, r)
			var f := hi.get_noise_2d(x, y)
			a *= 0.75 + 0.25 * f
			var ash := smoothstep(0.35, 0.7, f) * 0.5
			var c := Color(0.045, 0.032, 0.024).lerp(Color(0.32, 0.3, 0.28), ash)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_scorch_tex = ImageTexture.create_from_image(img)
	return _scorch_tex

## The heat: glowing fissures (cell edges of a cellular noise) through the char, hottest in a
## broken band near the edge, plus scattered ember specks. Black where nothing burns.
static func _ember_texture() -> ImageTexture:
	if _ember_tex != null:
		return _ember_tex
	var n := 256
	var lo := FastNoiseLite.new()
	lo.seed = 41
	lo.frequency = 0.022
	lo.fractal_octaves = 4
	var cell := FastNoiseLite.new()
	cell.seed = 13
	cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	cell.frequency = 0.045
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cell.fractal_type = FastNoiseLite.FRACTAL_NONE
	var gap := FastNoiseLite.new()
	gap.seed = 99
	gap.frequency = 0.035
	var speck := FastNoiseLite.new()
	speck.seed = 5
	speck.frequency = 0.4
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var r := p.length() + lo.get_noise_2d(x, y) * 0.28
			var inside := 1.0 - smoothstep(0.6, 0.85, r)
			var e := cell.get_noise_2d(x, y)            # ~ -1 on the cell edges
			var crack := 1.0 - smoothstep(-1.0, -0.82, e)
			var band := exp(-pow((r - 0.62) / 0.14, 2.0)) * 0.9 + 0.3
			var broken := smoothstep(-0.15, 0.25, gap.get_noise_2d(x, y))
			var v := crack * band * broken * inside
			v += smoothstep(0.55, 0.8, speck.get_noise_2d(x, y)) * inside * 0.8
			v = clampf(v, 0.0, 1.0)
			# hot cores run yellow-orange, the thin edges dull red
			var c := Color(0.55, 0.06, 0.01).lerp(Color(1.0, 0.5, 0.12), v)
			img.set_pixel(x, y, Color(c.r * v, c.g * v, c.b * v, 1.0))
	img.generate_mipmaps()
	_ember_tex = ImageTexture.create_from_image(img)
	return _ember_tex
