class_name DustDevils
extends Node3D
## Dust devils: on a hot, still afternoon a whirl of dust and chaff stands up off the dry open
## meadow somewhere round the hero, wanders downwind for half a minute, its funnel leaning
## behind it, and slumps back into the grass. Only one at a time, a minute or two apart; they
## need the same sun the thermals do (Thermals.strength), so cloud, rain, wet ground and a
## gale keep them down. They keep off slopes, pools, the oak shade and the houses.
## Drawn as one MultiMesh of soft dust puffs and straw flecks, animated in dust_devil.gdshader.

@export var terrain_path: NodePath
@export var seed := 4242

const PUFFS := 500           # dust motes (skirt and funnel)
const FLECKS := 170          # straw flecks, dead leaves and chaff clumps whirled up the column
const HEIGHT := 11.0         # m: where the funnel frays out
const MIN_STRENGTH := 0.5    # Thermals.strength needed for a whirl to stand up
const SPEED := 1.3           # m/s of drift (downwind plus a wander)

var active := false
var pos := Vector3.ZERO       # foot of the whirl (bots read)
var age := 0.0
var life := 0.0
var env := 0.0                # 0 nothing .. 1 a full whirl (bots read)
var next_in := 0.0            # s until the next one may stand up
var spawned := 0              # whirls so far (bots read)
var _vel := Vector3.ZERO
var _wander := 0.0
var _blocked := 0.0            # s it has been hemmed in without a way on
var _terrain: Terrain
var _world: Node
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _mmi: MultiMeshInstance3D
var _grass_mat: ShaderMaterial   # the grass whips round the foot (grass.gdshader `whirl`)
var _whoosh: AudioStreamPlayer3D   # the roar of the whirl: dry hiss and grit, swelling as it turns
var whoosh_gain := 0.0             # linear gain of the whoosh this frame (bots read)

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_world = get_parent()
	var grass := _world.get_node_or_null("Grass") as GrassField
	if grass:
		_grass_mat = grass.material
	_rng.seed = seed
	next_in = _rng.randf_range(20.0, 60.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mrng := RandomNumberGenerator.new()   # own stream: mote count never shifts the spawns
	mrng.seed = seed + 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = PUFFS + FLECKS
	for m in mm.instance_count:
		mm.set_instance_transform(m, Transform3D.IDENTITY)
		# angle, height phase, radius share, kind (< 0.25 ground skirt, < 0.75 funnel dust,
		# above that a fleck; the flecks sit at the top of the range)
		var kind := mrng.randf() * 0.75 if m < PUFFS else mrng.randf_range(0.76, 1.0)
		mm.set_instance_custom_data(m, Color(mrng.randf() * TAU, mrng.randf(), mrng.randf(), kind))
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/dust_devil.gdshader")
	_mat.set_shader_parameter("height", HEIGHT)
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Whirl"
	_mmi.multimesh = mm
	_mmi.material_override = _mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.custom_aabb = AABB(Vector3(-12, -1, -12), Vector3(24, HEIGHT + 4.0, 24))
	_mmi.visible = false
	add_child(_mmi)
	_whoosh = AudioStreamPlayer3D.new()
	_whoosh.name = "Whoosh"
	var rec := Samples.load_loop("weather", "dust_devil_loop")   # recorded gusting wind (ASSETS.md)
	_whoosh.stream = rec if rec else _make_whoosh(mrng)
	_whoosh.unit_size = 9.0
	_whoosh.max_distance = 90.0
	_whoosh.attenuation_filter_cutoff_hz = 5000.0   # from far off only the low roar carries
	_whoosh.attenuation_filter_db = -14.0
	_whoosh.bus = &"Ambience"
	_whoosh.position = Vector3(0, 2.0, 0)
	_whoosh.volume_db = -80.0
	_mmi.add_child(_whoosh)

## The whoosh follows the whirl's strength; stopped (not just silent) while none is up.
func _sound() -> void:
	whoosh_gain = env if active else 0.0
	if whoosh_gain <= 0.001:
		if _whoosh.playing:
			_whoosh.stop()
		return
	if not _whoosh.playing:
		_whoosh.play(randf() * 5.0)
	_whoosh.volume_db = -3.0 + linear_to_db(whoosh_gain)

## A 6 s loop: a dry hiss band-passed through a sweep that rises and falls with the turning
## column (~0.7 Hz, the near side passing), a low buffet underneath, and a patter of grit and
## straw ticks thrown off the skirt.
func _make_whoosh(rng: RandomNumberGenerator) -> AudioStreamWAV:
	const RATE := 22050
	var n := RATE * 6
	var fade := RATE / 2
	var x := PackedFloat32Array()
	x.resize(n + fade)
	var lp := 0.0
	var bp1 := 0.0
	var bp2 := 0.0
	var br := 0.0
	var tick := 0.0
	for i in n + fade:
		var t := float(i) / RATE
		var w := rng.randf() * 2.0 - 1.0
		# the swirl: a sweep that rises as the near side of the funnel comes round
		var swirl := 0.5 + 0.5 * sin(TAU * 0.7 * t + 1.6 * sin(TAU * 0.13 * t))
		var cut := 0.05 + 0.16 * swirl
		bp1 += cut * (w - bp1)
		bp2 += cut * (bp1 - bp2)
		var hiss := (bp1 - bp2) * (0.5 + 0.7 * swirl)
		# low buffet: brown noise, slow swell
		br = br * 0.996 + w * 0.05
		lp += 0.03 * (br - lp)
		# grit: random sharp ticks, more on the swells
		if rng.randf() < 0.0012 * (0.4 + swirl):
			tick = rng.randf_range(0.3, 1.0)
		tick *= 0.985
		x[i] = hiss * 1.4 + lp * 1.6 * (0.6 + 0.4 * swirl) + w * tick * 0.35
	# seamless loop: cross-fade the tail into the head, normalise to 16-bit
	for i in fade:
		var k := float(i) / fade
		x[i] = x[i] * k + x[n + i] * (1.0 - k)
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(x[i]))
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		b.encode_s16(i * 2, int(clampf(x[i] * 0.89 / peak, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = b
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n
	return s

func _strength() -> float:
	var th = _world.get("thermals")
	return th.strength if th else 0.0

## Flat, open, dry meadow: no slope, pool, oak shade, moss or house within reach.
func dry_open(x: float, z: float) -> bool:
	var half := _terrain.size_m * 0.5 - 20.0
	if absf(x) > half or absf(z) > half:
		return false
	if _terrain.normal_at(x, z, 2.0).y < 0.95 or _terrain.pond_at(x, z) > 0.0:
		return false
	var flora: Flora = _world.get_node_or_null("Flora")
	if flora and (flora.shelter_at(x, z) > 0.05 or flora.moss_at(x, z) > 0.1):
		return false
	if flora and flora.ruin_site != Vector3.INF and Vector2(x - flora.ruin_site.x, z - flora.ruin_site.z).length() < 9.0:
		return false
	return not (Cottage.inside(x, z, 4.0) or StoneCottage.inside(x, z, 4.0) or WhiteCottage.covers(x, z, 4.0))

## Stand a whirl up 18-60 m from p (on dry open ground). False if the day is too dull or
## no such ground is found.
func spawn_near(p: Vector3, near := 18.0, far := 60.0) -> bool:
	if _strength() < MIN_STRENGTH:
		return false
	for i in 24:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(near, far)
		var x := p.x + cos(a) * d
		var z := p.z + sin(a) * d
		if dry_open(x, z):
			pos = Vector3(x, _terrain.height_at(x, z), z)
			active = true
			age = 0.0
			life = _rng.randf_range(25.0, 45.0)
			_wander = _rng.randf() * TAU
			_vel = Vector3.ZERO
			_blocked = 0.0
			spawned += 1
			_mat.set_shader_parameter("seed", _rng.randf() * 50.0)
			return true
	return false

func _process(delta: float) -> void:
	var s := _strength()
	if _grass_mat:
		_grass_mat.set_shader_parameter("whirl", Vector4(pos.x, pos.z, 4.5, env) if active else Vector4.ZERO)
	_sound()
	if not active:
		env = 0.0
		_mmi.visible = false
		next_in -= delta
		if next_in <= 0.0:
			next_in = _rng.randf_range(50.0, 140.0)
			var cam := get_viewport().get_camera_3d()
			if cam:
				spawn_near(cam.global_position)
		return
	age += delta
	# a cloud over the sun or a gust of rain and it slumps at once
	if s < MIN_STRENGTH * 0.6:
		age = maxf(age, life - 4.0)
	if age >= life:
		active = false
		_mmi.visible = false
		env = 0.0
		return
	env = smoothstep(0.0, 4.0, age) * (1.0 - smoothstep(life - 4.0, life, age))
	# drift downwind with a slow wander; turn away from ground it cannot cross
	_wander += _rng.randf_range(-1.0, 1.0) * delta * 1.2
	var want := (Player.GLIDE_WIND_DIR.normalized() * 1.4 + Vector3(cos(_wander), 0, sin(_wander))).normalized() * SPEED
	_vel = _vel.lerp(want, clampf(delta * 0.8, 0.0, 1.0))
	var nxt := pos + _vel * delta
	if dry_open(nxt.x + _vel.x * 3.0, nxt.z + _vel.z * 3.0):
		pos = Vector3(nxt.x, _terrain.height_at(nxt.x, nxt.z), nxt.z)
		_blocked = 0.0
	else:
		_wander += PI * 0.5 * delta * 4.0
		_vel *= maxf(0.0, 1.0 - delta * 2.0)     # it stalls and turns before it gives up
		_blocked += delta
		if age < life - 4.0 and _blocked > 5.0:
			age = life - 4.0             # hemmed in: it dies where it stands
	_mmi.visible = true
	_mmi.global_position = pos
	var sun: DirectionalLight3D = _world.get("sun")
	_mat.set_shader_parameter("env", env)
	_mat.set_shader_parameter("tilt", Vector2(-_vel.x, -_vel.z) * 0.12)
	_mat.set_shader_parameter("sun_dir", sun.global_basis.z if sun else Vector3.UP)
	_mat.set_shader_parameter("light", sun.light_energy / 3.0 if sun and sun.visible else 0.0)
