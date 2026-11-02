class_name GroundCrack
extends Node3D
## Where the Stone Sentinel's glaive comes down: the turf splits in a star of cracks round a
## shallow pit, stone chips and clods kick up, and a shock runs out along the ground as a
## ring of dust. The ring throws down a hero it passes under who is standing on the ground
## (unblockable); a hero in the air (a jump timed on the slam) lets it run under their feet,
## and dodge i-frames pass through it like any strike. The cracks linger and fade.

signal rang(result: String)

const RING_R := 4.4            # m the shock runs out before it dies
const RING_SPEED := 9.0        # m/s: ~0.5 s to its edge
const INNER := 0.9             # inside this the glaive itself did the work
const DAMAGE := 16.0
const AIR := 0.32              # feet this far over the turf are clear of the shock
const LIFE := 7.0

var source: Node               # receive_attack's attacker (the sentinel)
var player: Player
var terrain: Terrain
var spare_player := false      # the glaive already struck (or the hero was parrying): no second blow
var t := 0.0
var result := ""               # "" until the ring reaches the hero: hit / perfect / dodged / jumped / miss
var front := 0.0
var _decal: Decal
var _dust: CPUParticles3D
var _chips: CPUParticles3D
var _puff: CPUParticles3D
var _front_dust: CPUParticles3D  # laid along the shock front as it runs: the ring that reads
var blasted := 0                 # grass points laid flat round the pit (bots)

static var _crack_tex: ImageTexture
static var _soft: ImageTexture

func _ready() -> void:
	_decal = Decal.new()
	_decal.size = Vector3(3.6, 1.4, 3.6)
	_decal.texture_albedo = crack_texture()
	_decal.albedo_mix = 1.0
	_decal.upper_fade = 0.3
	_decal.lower_fade = 0.3
	_decal.rotation.y = randf() * TAU
	add_child(_decal)
	_chips = _make_chips()
	add_child(_chips)
	_puff = _make_puff()
	add_child(_puff)
	_dust = _make_ring_dust()
	add_child(_dust)
	_front_dust = _make_front_dust()
	add_child(_front_dust)
	for p in [_chips, _puff, _dust, _front_dust]:
		(p as CPUParticles3D).emitting = true
	_blast_grass.call_deferred()   # the sentinel places us after add_child

## Lay the sward flat round the pit, the stems combed outward away from the blow, so the
## crack star is not hidden in standing grass and the ground shows where the shock went.
func _blast_grass() -> void:
	var tr := get_node_or_null("../Trample") as Trample
	if tr == null:
		return
	var c := Vector2(global_position.x, global_position.z)
	tr.add_herd_point(c, Vector2(1, 0).rotated(randf() * TAU), 1.0, 0.0, 0.15)
	blasted += 1
	for ring: Array in [[0.85, 7, 1.0], [1.7, 11, 0.8], [2.6, 14, 0.5]]:
		var r: float = ring[0]
		var k: int = ring[1]
		var off := randf() * TAU
		for i in k:
			var d := Vector2.from_angle(off + TAU * i / k)
			tr.add_herd_point(c + d * r, d, ring[2], 0.0, 0.15)
			blasted += 1

func _physics_process(delta: float) -> void:
	var prev := front
	t += delta
	front = minf(t * RING_SPEED, RING_R + 0.5)
	if _front_dust.emitting:
		if front >= RING_R:
			_front_dust.emitting = false
		else:
			_front_dust.emission_ring_radius = maxf(front, 0.7)
			_front_dust.emission_ring_inner_radius = maxf(front - 0.25, 0.5)
	if result == "" and front > prev:
		_check_ring(prev)
	var u := clampf((t - 2.5) / (LIFE - 2.5), 0.0, 1.0)
	_decal.modulate = Color(1, 1, 1, 1.0 - u * u)
	if t > LIFE + 0.5:
		queue_free()

func _check_ring(_prev: float) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		result = "miss"
		return
	var d := player.global_position - global_position
	var flat := Vector2(d.x, d.z).length()
	if flat > RING_R or absf(d.y) > 1.8:
		if front >= RING_R:
			result = "miss"
			rang.emit(result)
		return
	if flat >= front:
		return                     # not reached them yet (a hero rolling in meets it sooner)
	if spare_player:
		result = "miss"
	elif _airborne():
		result = "jumped"
	else:
		result = player.receive_attack(source, DAMAGE, true, true)
	if result == "hit":
		ImpactFX.spawn(get_parent(), player.global_position + Vector3.UP * 0.25, Vector3(d.x, 0, d.z).normalized(), "dirt", 0.9)
	rang.emit(result)

func _airborne() -> bool:
	if player.is_on_floor():
		return false
	var g := global_position.y
	if terrain != null:
		g = terrain.height_at(player.global_position.x, player.global_position.z)
	return player.global_position.y - g > AIR

# --- particles ---

## Stone chips and clods thrown up out of the pit.
func _make_chips() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Chips"
	p.one_shot = true
	p.amount = 46
	p.lifetime = 1.3
	p.explosiveness = 0.95
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.position = Vector3(0, 0.08, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -14.0, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.5
	var q := SphereMesh.new()
	q.radius = 0.035
	q.height = 0.05
	q.radial_segments = 5
	q.rings = 2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.27, 0.22)
	m.roughness = 0.95
	q.material = m
	p.mesh = q
	return p

## A heavy grey-brown puff out of the pit itself.
func _make_puff() -> CPUParticles3D:
	var p := _dust_base(44, 2.2)
	p.name = "Puff"
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.9
	p.damping_min = 2.5
	p.damping_max = 4.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	return p

## The shock: a ring of dust thrown low and outward that keeps pace with the ring's front.
func _make_ring_dust() -> CPUParticles3D:
	var p := _dust_base(120, 1.5)
	p.name = "RingDust"
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.6
	p.emission_ring_inner_radius = 0.45
	p.emission_ring_height = 0.05
	p.direction = Vector3(0, 1, 0)
	p.spread = 15.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	# thrown outward hard, then the air takes it
	p.radial_accel_min = 26.0
	p.radial_accel_max = 32.0
	p.damping_min = 9.0
	p.damping_max = 12.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	return p

## Dust kicked up off the turf right where the shock front is, emitted on a ring whose radius
## follows `front` each frame (world coords: each puff stays where it was raised), so the run
## of the shock leaves a widening, low, hugging band of dust you can read as a ring.
func _make_front_dust() -> CPUParticles3D:
	var p := _dust_base(280, 1.3)
	p.name = "FrontDust"
	p.one_shot = false
	p.explosiveness = 0.0
	p.position = Vector3(0, 0.08, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.7
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.04
	p.direction = Vector3(0, 1, 0)
	p.spread = 20.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.8
	p.radial_accel_min = 2.0
	p.radial_accel_max = 4.0
	p.damping_min = 2.5
	p.damping_max = 4.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.8
	return p

func _dust_base(n: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.97
	p.local_coords = false
	p.position = Vector3(0, 0.15, 0)
	p.gravity = Vector3(0, 0.25, 0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	# grey-brown earth dust, paling and thinning as it hangs
	g.offsets = PackedFloat32Array([0.0, 0.06, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.40, 0.38, 0.35, 0.0), Color(0.40, 0.38, 0.35, 0.55),
		Color(0.47, 0.46, 0.44, 0.32), Color(0.52, 0.51, 0.50, 0.0)])
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 0.45))
	c.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = c
	return p

static func _soft_texture() -> ImageTexture:
	if _soft != null:
		return _soft
	var n := 64
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.09
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var a := clampf(1.0 - p.length(), 0.0, 1.0)
			a = a * a * (0.7 + 0.3 * noise.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_soft = ImageTexture.create_from_image(img)
	return _soft

# --- the crack star ---

## A star of jagged cracks (each forking once or twice) out of a crushed pit, crossed by two
## broken rings of fracture, on a faint dusty bruise of the turf. Dark in the cracks (alpha
## high), clear between them.
static func crack_texture() -> ImageTexture:
	if _crack_tex != null:
		return _crack_tex
	var n := 512
	var rng := RandomNumberGenerator.new()
	rng.seed = 1709
	var a := PackedFloat32Array()
	a.resize(n * n)
	var c := Vector2(n, n) * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = 23
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	# the bruise: crushed, dusty turf round the pit
	for y in n:
		for x in n:
			var p := (Vector2(x, y) - c) / (n * 0.5)
			var r := p.length() + noise.get_noise_2d(x, y) * 0.18
			a[y * n + x] = 0.42 * (1.0 - smoothstep(0.08, 0.55, r))
	# the pit
	_stamp(a, n, c, 22.0, 0.95)
	# the star
	var rays := 13
	var ends: Array[Vector2] = []
	for i in rays:
		var ang := TAU * (i + rng.randf_range(-0.3, 0.3)) / rays
		var length := rng.randf_range(0.55, 0.95) * n * 0.48
		ends.append(_crack(a, n, rng, c + Vector2.from_angle(ang) * 14.0, ang, length, 5.0, 2))
	# two broken rings of fracture between the rays
	for ring_r: float in [n * 0.11, n * 0.24]:
		var segs := 26
		for s in segs:
			if rng.randf() < 0.45:
				continue
			var a0 := TAU * s / segs
			var pos: Vector2 = c + Vector2.from_angle(a0) * ring_r * rng.randf_range(0.9, 1.1)
			var steps := int(ring_r * TAU / segs / 3.0)
			for k in steps:
				var aa := a0 + float(k) / steps * TAU / segs
				var tgt: Vector2 = c + Vector2.from_angle(aa) * ring_r * (1.0 + 0.08 * noise.get_noise_1d(aa * 60.0))
				pos = pos.lerp(tgt, 0.6)
				_stamp(a, n, pos, 1.6 if ring_r < n * 0.2 else 1.2, 0.85)
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := clampf(a[y * n + x], 0.0, 1.0)
			# deep cracks near black, the bruise a dull grey-brown dust
			var col := Color(0.32, 0.29, 0.24).lerp(Color(0.03, 0.025, 0.02), smoothstep(0.45, 0.9, v))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, v))
	img.generate_mipmaps()
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex

## One jagged crack from `from` along `ang`, thinning to nothing; forks `forks` times.
static func _crack(a: PackedFloat32Array, n: int, rng: RandomNumberGenerator, from: Vector2, ang: float, length: float, width: float, forks: int) -> Vector2:
	var pos := from
	var step := 2.5
	var steps := int(length / step)
	var heading := ang
	for i in steps:
		var f := float(i) / steps
		heading += rng.randf_range(-0.22, 0.22)
		heading = lerp_angle(heading, ang, 0.12)
		pos += Vector2.from_angle(heading) * step
		_stamp(a, n, pos, maxf(width * (1.0 - f * 0.85), 0.7), 1.0 - 0.3 * f)
		if forks > 0 and i > 6 and rng.randf() < 1.6 / steps:
			forks -= 1
			_crack(a, n, rng, pos, heading + rng.randf_range(0.35, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0), length * (1.0 - f) * rng.randf_range(0.45, 0.8), width * (1.0 - f) * 0.7, 0)
	return pos

static func _stamp(a: PackedFloat32Array, n: int, at: Vector2, r: float, v: float) -> void:
	var x0 := maxi(int(at.x - r - 1), 0)
	var x1 := mini(int(at.x + r + 1), n - 1)
	var y0 := maxi(int(at.y - r - 1), 0)
	var y1 := mini(int(at.y + r + 1), n - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(at)
			var k := clampf(r + 0.5 - d, 0.0, 1.0) * v
			if k > a[y * n + x]:
				a[y * n + x] = k
