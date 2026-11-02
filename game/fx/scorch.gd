class_name Scorch
extends Node3D
## Where the Ashen Knight's ember-hot glaive bites the turf at the end of its leap: a burnt
## star scorched into the ground round a split in the earth, its cracks glowing ember orange
## that cools to dull red and then to black over a few seconds; a scatter of embers sits in
## the char winking and drifting up as sparks, a thin grey smoke curls off it, and the char
## itself fades out over ~20 s. Harmless: the landing has already done the damage.

const LIFE := 20.0          # s until the char has faded right out
const GLOW_T := 6.0         # s the cracks keep glowing (hot -> cooled black)
const EMBER_T := 9.0        # s embers keep winking and sparking up
const SIZE := 2.8           # m across the burnt star
const GLOW_E := 3.2         # decal emission energy when fresh

var t := 0.0
var heat := 1.0             # 1 fresh .. 0 cold (bots)
var char_alpha := 1.0       # the burn's opacity (bots)
var blasted := 0            # grass points laid flat round the burn (bots)
var _decal: Decal
var _sparks: CPUParticles3D
var _coals: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D

static var _burn_tex: ImageTexture
static var _glow_tex: ImageTexture
static var _spark_tex: ImageTexture

func _ready() -> void:
	_decal = Decal.new()
	_decal.name = "Burn"
	_decal.size = Vector3(SIZE, 1.2, SIZE)
	_decal.texture_albedo = burn_texture()
	_decal.texture_emission = glow_texture()
	_decal.emission_energy = GLOW_E
	_decal.albedo_mix = 1.0
	_decal.upper_fade = 0.3
	_decal.lower_fade = 0.3
	_decal.rotation.y = randf() * TAU
	add_child(_decal)
	_coals = _make_coals()
	add_child(_coals)
	_sparks = _make_sparks()
	add_child(_sparks)
	_smoke = _make_smoke()
	add_child(_smoke)
	for p in [_coals, _sparks, _smoke]:
		(p as CPUParticles3D).emitting = true
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = Color(1.0, 0.42, 0.12)
	_light.light_energy = 1.1
	_light.omni_range = 2.6
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.35, 0)
	add_child(_light)
	_blast_grass.call_deferred()   # the knight places us after add_child

## The blast of the bite lays the sward flat round the burn, combed outward, so the scorch
## is not lost under standing meadow grass.
func _blast_grass() -> void:
	var tr := get_node_or_null("../Trample") as Trample
	if tr == null:
		return
	var c := Vector2(global_position.x, global_position.z)
	tr.add_herd_point(c, Vector2(1, 0).rotated(randf() * TAU), 1.0, 0.0, 0.15)
	blasted += 1
	for ring: Array in [[0.6, 6, 1.0], [1.15, 9, 0.9], [1.7, 12, 0.6]]:
		var r: float = ring[0]
		var k: int = ring[1]
		var off := randf() * TAU
		for i in k:
			var d := Vector2.from_angle(off + TAU * i / k)
			tr.add_herd_point(c + d * r, d, ring[2], 0.0, 0.15)
			blasted += 1

func _process(delta: float) -> void:
	t += delta
	# heat: holds a beat, then cools off on an ease-out curve
	var g := clampf((t - 0.6) / (GLOW_T - 0.6), 0.0, 1.0)
	heat = (1.0 - g) * (1.0 - g)
	_decal.emission_energy = GLOW_E * heat
	# the glow reddens as it cools (ember orange -> dull red)
	_decal.modulate = Color(1.0, lerpf(0.35, 1.0, heat), lerpf(0.25, 1.0, heat), char_alpha)
	_light.light_energy = 1.1 * heat * (0.85 + 0.15 * sin(t * 13.0) * sin(t * 7.3))
	_light.visible = heat > 0.01
	if _sparks.emitting and t > EMBER_T:
		_sparks.emitting = false
	if _coals.emitting and t > EMBER_T * 0.5:
		_coals.emitting = false
	if _smoke.emitting and t > GLOW_T + 3.0:
		_smoke.emitting = false
	var u := clampf((t - GLOW_T) / (LIFE - GLOW_T), 0.0, 1.0)
	char_alpha = 1.0 - u * u
	_decal.modulate.a = char_alpha
	if t > LIFE + 0.5:
		queue_free()

# --- particles ---

## Live coals sitting on the char: tiny glowing dots that wink out where they lie.
func _make_coals() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Coals"
	p.amount = 40
	p.lifetime = 2.4
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.local_coords = false
	p.position = Vector3(0, 0.04, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = SIZE * 0.32
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.03
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.mesh = _glow_quad(0.05, Color(1.0, 0.45, 0.12), 4.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 0.6, 0.25, 0.0), Color(1, 0.55, 0.2, 1.0),
		Color(0.9, 0.3, 0.08, 0.8), Color(0.5, 0.1, 0.02, 0.0)])
	p.color_ramp = g
	return p

## Sparks lifting off the burn on the heat, flickering out a metre or two up.
func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.amount = 36
	p.lifetime = 1.8
	p.randomness = 0.7
	p.local_coords = false
	p.position = Vector3(0, 0.08, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = SIZE * 0.25
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 0.4
	p.damping_max = 1.0
	p.tangential_accel_min = -0.8
	p.tangential_accel_max = 0.8
	p.scale_amount_min = 0.3
	p.scale_amount_max = 1.0
	p.mesh = _glow_quad(0.035, Color(1.0, 0.55, 0.18), 6.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 0.8, 0.4, 0.0), Color(1, 0.7, 0.3, 1.0),
		Color(1, 0.35, 0.08, 0.7), Color(0.6, 0.12, 0.02, 0.0)])
	p.color_ramp = g
	return p

## Thin grey smoke curling off the hot char, drifting up and spreading.
func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 26
	p.lifetime = 3.6
	p.randomness = 0.5
	p.local_coords = false
	p.position = Vector3(0, 0.15, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = SIZE * 0.22
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.55
	p.gravity = Vector3(0.15, 0.12, 0.05)
	p.damping_min = 0.1
	p.damping_max = 0.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -20.0
	p.angular_velocity_max = 20.0
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = GroundCrack._soft_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.3
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0.3, 0.28, 0.26, 0.0), Color(0.36, 0.34, 0.32, 0.32),
		Color(0.5, 0.49, 0.47, 0.16), Color(0.6, 0.6, 0.58, 0.0)])
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = c
	return p

func _glow_quad(sz: float, col: Color, e: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(sz, sz)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	m.albedo_texture = _spark_texture()
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = e
	q.material = m
	return q

static func _spark_texture() -> ImageTexture:
	if _spark_tex != null:
		return _spark_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var a := clampf(1.0 - p.length(), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * a))
	_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex

# --- the burn ---

## The burnt star as an alpha field (built once): a charred core, ragged scorch tongues
## licking outward along the blade's blast, a split in the earth and hairline cracks out of it.
## Returns [char field, crack field].
static func _fields(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var burn := PackedFloat32Array()
	burn.resize(n * n)
	var crack := PackedFloat32Array()
	crack.resize(n * n)
	var c := Vector2(n, n) * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = 91
	noise.frequency = 0.018
	noise.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = 17
	fine.frequency = 0.09
	fine.fractal_octaves = 2
	# tongues: the char's radius varies with angle (a star, not a disc)
	var lobes := PackedFloat32Array()
	var lobe_n := 11
	for i in lobe_n:
		lobes.append(rng.randf_range(0.45, 1.0))
	for y in n:
		for x in n:
			var p := (Vector2(x, y) - c) / (n * 0.5)
			var ang := atan2(p.y, p.x)
			var f := fposmod(ang / TAU * lobe_n, lobe_n)
			var i0 := int(f) % lobe_n
			var i1 := (i0 + 1) % lobe_n
			var reach := lerpf(lobes[i0], lobes[i1], smoothstep(0.0, 1.0, f - floorf(f)))
			reach = 0.32 + 0.6 * reach
			var r := p.length() + noise.get_noise_2d(x, y) * 0.22
			var v := 1.0 - smoothstep(reach * 0.35, reach, r)
			# mottled: blackened patches and browned turf between them
			v *= 0.75 + 0.35 * fine.get_noise_2d(x, y)
			burn[y * n + x] = clampf(v, 0.0, 1.0)
	# the split where the edge went in, and hairline cracks out of it
	GroundCrack._stamp(crack, n, c, 9.0, 1.0)
	var rays := 9
	for i in rays:
		var ang := TAU * (i + rng.randf_range(-0.35, 0.35)) / rays
		GroundCrack._crack(crack, n, rng, c + Vector2.from_angle(ang) * 6.0, ang, rng.randf_range(0.3, 0.7) * n * 0.42, 3.2, 1)
	return [burn, crack]

## Albedo: brown-scorched turf at the edge, black char in the core, the cracks blackest.
static func burn_texture() -> ImageTexture:
	if _burn_tex != null:
		return _burn_tex
	_build()
	return _burn_tex

## Emission: the cracks and the hottest char glow ember orange (dimmed and reddened by heat).
static func glow_texture() -> ImageTexture:
	if _glow_tex != null:
		return _glow_tex
	_build()
	return _glow_tex

static func _build() -> void:
	var n := 512
	var fl := _fields(n)
	var burn: PackedFloat32Array = fl[0]
	var crack: PackedFloat32Array = fl[1]
	var speck := FastNoiseLite.new()
	speck.seed = 303
	speck.frequency = 0.25
	var alb := Image.create(n, n, true, Image.FORMAT_RGBA8)
	var emi := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var b := burn[y * n + x]
			var k := crack[y * n + x]
			var col := Color(0.24, 0.17, 0.10).lerp(Color(0.035, 0.03, 0.028), smoothstep(0.25, 0.75, b))
			col = col.lerp(Color(0.01, 0.008, 0.006), k)
			var a := maxf(smoothstep(0.0, 0.5, b) * 0.95, k)
			alb.set_pixel(x, y, Color(col.r, col.g, col.b, a))
			# glow: in the cracks, and speckled embers in the char's hot core
			var s := smoothstep(0.55, 0.85, speck.get_noise_2d(x, y)) * smoothstep(0.6, 0.95, b)
			var gl := clampf(k * 0.9 + s * 0.7, 0.0, 1.0)
			var gc := Color(1.0, 0.36, 0.07) * gl
			emi.set_pixel(x, y, Color(gc.r, gc.g, gc.b, 1.0))
	alb.generate_mipmaps()
	emi.generate_mipmaps()
	_burn_tex = ImageTexture.create_from_image(alb)
	_glow_tex = ImageTexture.create_from_image(emi)
