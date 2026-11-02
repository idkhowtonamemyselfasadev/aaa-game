class_name HollowWisp
extends CharacterBody3D
## Hollow Wisp, the vale's fodder: what is left when a Hollow burns down to nothing -- a heart
## of live coal the size of a fist, a ring of charred bone shards still orbiting it, a veil of
## smoke and a trickle of sparks. They drift in small knots over the turf and wake when the
## hero comes near. Rules:
##  CIRCLE. Awake, a wisp hangs ~3.6 m out from the hero and drifts round them; a knot takes
##    turns, never two darting at once (PACK_GAP).
##  FLARE (the tell). Before it darts the shards snap in tight round the heart, the heart and
##    its light flare white-hot and it draws back and up a little: GATHER_T to read it.
##  DART. It flies straight at where the hero's chest was when the flare peaked and sears on
##    contact. Step across the line or roll on the flare's peak; the heavy parries it.
##  SLACK. After a dart it hangs low and dim for RECOVER_T, shards drooping: the punish window.
## Fragile: two light strikes put it out. Killed, the heart bursts into sparks and ash and the
## shards drop into the grass.

enum { IDLE, STALK, WINDUP, STRIKE, RECOVER, STAGGER, DEAD }

const HEALTH_MAX := 22.0
const DMG_PER_POWER := 13.0
const NOTICE := 11.0
const GIVE_UP := 24.0
const HOVER := 1.3            # heart height over the turf
const SLACK_HOVER := 0.85     # hangs lower after a dart (easy to reach with a level swing)
const DRIFT := 2.6            # m/s drifting in / round
const ORBIT := 3.6            # circling distance
const ORBIT_RATE := 0.45      # rad/s round the hero
const DART_MIN := 2.0         # it darts from between these distances
const DART_MAX := 5.8
const GATHER_T := 0.7         # the flare: the tell
const DART_T := 0.34          # the flight
const DART_OVER := 1.4        # m it overshoots the chest point
const SEAR_R := 0.8           # heart within this of the hero's chest line sears
const DAMAGE := 9.0
const RECOVER_T := 1.15
const STAGGER_T := 0.45
const PARRIED_T := 1.2
const PACK_GAP := 0.7         # s after a kin's dart before the next may flare
const COOLDOWN := 1.8         # s it circles after a dart (+ up to COOL_JITTER)
const COOL_JITTER := 1.4
const SHARDS := 7
const SHARD_R := 0.5

signal flared(at: Vector3)
signal darted(at: Vector3)
signal struck(result: String)
signal snuffed(at: Vector3)
signal died

var state := IDLE
var t := 0.0
var health := HEALTH_MAX
var health_max := HEALTH_MAX
var kin: Array = []           # the other wisps of its knot
var orbit := 1.0
var terrain: Terrain
var impact_kind := "stone"
var darts := 0
var sears := 0
var staggers := 0
var hits_taken := 0
var parried_count := 0
var last_result := ""
var max_heat := 0.0
var _player: Player
var _home := Vector3.ZERO
var _cool := 0.0
var _freeze := 0.0
var _flash := 0.0
var _resolved := false
var _aim := Vector3.ZERO
var _dart_speed := 0.0
var _knock := Vector3.ZERO
var _stagger_len := STAGGER_T
var _ang := 0.0
var _heat := 0.6
var _gather := 0.0            # 0 loose .. 1 shards pulled in
var _droop := 0.0
var _hover := HOVER
var _rng := RandomNumberGenerator.new()
var _heart: MeshInstance3D
var _heart_mat: ShaderMaterial
var _shards: Array[MeshInstance3D] = []
var _shard_mats: Array[ShaderMaterial] = []
var _shard_axis: Array[Vector3] = []
var _shard_vel: Array[Vector3] = []
var _shard_spin: Array[Vector3] = []
var _shard_size: Array[float] = []
var _light: OmniLight3D
var _smoke: CPUParticles3D
var _sparks: CPUParticles3D
var _burst: CPUParticles3D
var _ash: CPUParticles3D

static var _soft: ImageTexture
static var _shard_meshes: Array[ArrayMesh] = []

func _ready() -> void:
	add_to_group("hittable")
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_rng.seed = hash(name) ^ 5531
	_ang = _rng.randf() * TAU
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.32
	col.shape = sph
	add_child(col)
	var sh: Shader = load("res://shaders/wisp_char.gdshader")
	# the heart: a lumpy coal burning through its own crust
	_heart_mat = ShaderMaterial.new()
	_heart_mat.shader = sh
	_heart_mat.set_shader_parameter("lump", 0.07)
	_heart_mat.set_shader_parameter("fill", 1.4)
	_heart_mat.set_shader_parameter("heat", 2.5)
	_heart_mat.set_shader_parameter("seed", Vector3(_rng.randf() * 50.0, _rng.randf() * 50.0, 0.0))
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.29
	sm.radial_segments = 24
	sm.rings = 12
	_heart = MeshInstance3D.new()
	_heart.name = "Heart"
	_heart.mesh = sm
	_heart.material_override = _heart_mat
	_heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_heart)
	# the orbiting shards: splinters of charred bone and ash-stone, each on its own tilted ring
	if _shard_meshes.is_empty():
		var mr := RandomNumberGenerator.new()
		mr.seed = 4417
		for i in 4:
			_shard_meshes.append(_build_shard(mr))
	for i in SHARDS:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("heat", 0.6)
		m.set_shader_parameter("seed", Vector3(i * 7.3, _rng.randf() * 30.0, i * 1.9))
		var s := MeshInstance3D.new()
		s.name = "Shard%d" % i
		s.mesh = _shard_meshes[i % _shard_meshes.size()]
		s.material_override = m
		_shard_size.append(_rng.randf_range(1.3, 2.0))
		add_child(s)
		_shards.append(s)
		_shard_mats.append(m)
		var ax := Vector3(_rng.randf_range(-0.6, 0.6), 1.0, _rng.randf_range(-0.6, 0.6)).normalized()
		_shard_axis.append(ax)
		_shard_vel.append(Vector3.ZERO)
		_shard_spin.append(Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3), _rng.randf_range(-3, 3)))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.52, 0.2)
	_light.omni_range = 4.5
	_light.omni_attenuation = 1.6
	_light.light_energy = 0.9
	_light.shadow_enabled = false
	add_child(_light)
	# smoke trailing off it (world space, so it streams behind a dart)
	_smoke = _emitter(32, 1.8, Vector2(0.5, 1.0), Color(0.075, 0.068, 0.062, 0.6), false)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.22
	_smoke.initial_velocity_min = 0.1
	_smoke.initial_velocity_max = 0.35
	_smoke.gravity = Vector3(0.1, 0.45, 0.0)
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.45))
	sc.add_point(Vector2(1.0, 1.0))
	_smoke.scale_amount_curve = sc
	var gs := Gradient.new()
	gs.set_color(0, Color(0.07, 0.06, 0.055, 0.0))
	gs.set_color(1, Color(0.2, 0.19, 0.18, 0.0))
	gs.add_point(0.2, Color(0.08, 0.07, 0.065, 0.55))
	gs.add_point(0.6, Color(0.14, 0.13, 0.12, 0.3))
	_smoke.color_ramp = gs
	_smoke.emitting = true
	# a trickle of sparks lifting off the heart
	_sparks = _emitter(24, 1.1, Vector2(0.012, 0.03), Color(1.0, 0.55, 0.2), true)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.12
	_sparks.initial_velocity_min = 0.3
	_sparks.initial_velocity_max = 0.9
	_sparks.spread = 60.0
	_sparks.gravity = Vector3(0.0, 0.8, 0.0)
	_sparks.emitting = true
	# snuffed: a burst of sparks and a puff of ash
	_burst = _emitter(60, 1.2, Vector2(0.015, 0.04), Color(1.0, 0.6, 0.25), true)
	_burst.one_shot = true
	_burst.explosiveness = 0.95
	_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_burst.emission_sphere_radius = 0.1
	_burst.spread = 180.0
	_burst.initial_velocity_min = 2.5
	_burst.initial_velocity_max = 6.0
	_burst.gravity = Vector3(0, -5.0, 0)
	_ash = _emitter(18, 2.4, Vector2(0.5, 1.0), Color(0.16, 0.15, 0.14, 0.7), false)
	_ash.one_shot = true
	_ash.explosiveness = 0.85
	_ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_ash.emission_sphere_radius = 0.2
	_ash.spread = 180.0
	_ash.initial_velocity_min = 0.4
	_ash.initial_velocity_max = 1.4
	_ash.gravity = Vector3(0.15, 0.25, 0)
	_ash.color_ramp = gs
	_ash.scale_amount_curve = sc
	_home = global_position
	_cool = _rng.randf_range(0.0, COOL_JITTER)

func _emitter(n: int, life: float, size: Vector2, col: Color, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 30.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.emitting = false
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	m.albedo_color = Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, col.a) if glow else col
	q.material = m
	p.mesh = q
	p.color = Color.WHITE if glow else Color.WHITE
	add_child(p)
	return p

## A splinter: a long, irregular, faceted wedge (charred bone or ash-stone), flat shaded.
static func _build_shard(r: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var len := r.randf_range(0.09, 0.15)
	var ring := []
	var n := 5
	for k in n:
		var a := TAU * k / n + r.randf_range(-0.3, 0.3)
		var rad := r.randf_range(0.018, 0.034)
		ring.append(Vector3(cos(a) * rad, r.randf_range(-0.01, 0.015), sin(a) * rad * 0.7))
	var top := Vector3(r.randf_range(-0.012, 0.012), len, r.randf_range(-0.01, 0.01))
	var bot := Vector3(r.randf_range(-0.01, 0.01), -len * r.randf_range(0.35, 0.6), r.randf_range(-0.01, 0.01))
	for k in n:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % n]
		st.add_vertex(top); st.add_vertex(b); st.add_vertex(a)
		st.add_vertex(bot); st.add_vertex(a); st.add_vertex(b)
	st.generate_normals()
	return st.commit()

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

func plant(t_: Terrain) -> void:
	terrain = t_
	global_position = Vector3(global_position.x, _ground_y(global_position) + HOVER, global_position.z)
	_home = global_position

func face(_point: Vector3) -> void:
	pass

func is_dead() -> bool:
	return state == DEAD

func hurt_capsule() -> Array:
	# the heart and its shard ring; stretched down so a level staff swing at the waist still
	# meets a wisp hanging at chest height
	var c := global_position
	return [c + Vector3.DOWN * 0.45, c + Vector3.UP * 0.2, 0.42]

## The heart's world position (bots, shots, foley).
func heart() -> Vector3:
	return global_position

func heat() -> float:
	return _heat

## The hero woke at a rest point: the knot is back, rekindled, on its ground.
func return_to_post() -> void:
	health = HEALTH_MAX
	state = IDLE
	t = 0.0
	_cool = _rng.randf_range(0.0, COOL_JITTER)
	global_position = _home
	visible = true
	for i in _shards.size():
		var s := _shards[i]
		s.top_level = false
		s.visible = true
		_shard_mats[i].set_shader_parameter("heat", 0.6)
	_heart.visible = true
	_smoke.emitting = true
	_sparks.emitting = true
	_light.visible = true
	if not is_in_group("hittable"):
		add_to_group("hittable")
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)

func take_hit(_point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	hits_taken += 1
	_freeze = hitstop
	health -= DMG_PER_POWER * power
	_flash = 1.0
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 1e-3:
		d = global_basis.z
	d = d.normalized()
	if health <= 0.0:
		_die(d)
		return
	# light as ash: every blow bats it away and scatters its flare
	staggers += 1
	_knock = d * (3.0 + 2.0 * power) + Vector3.UP * 0.6
	_stagger_len = STAGGER_T
	_enter(STAGGER)

## The hero's heavy met the dart: batted aside, guttering, open for PARRIED_T.
func parried(dir: Vector3, hitstop: float) -> void:
	if state == DEAD:
		return
	parried_count += 1
	staggers += 1
	_freeze = hitstop
	_resolved = true
	_knock = Vector3(dir.x, 0, dir.z).normalized() * 4.5 + Vector3.UP * 0.4
	_stagger_len = PARRIED_T
	_enter(STAGGER)

func _enter(s: int) -> void:
	state = s
	t = 0.0

func _ground_y(p: Vector3) -> float:
	return terrain.height_at(p.x, p.z) if terrain else 0.0

func _kin_busy() -> bool:
	for k in kin:
		if k == self or not is_instance_valid(k):
			continue
		var w := k as HollowWisp
		if w.state == WINDUP or w.state == STRIKE or (w.state == RECOVER and w.t < PACK_GAP):
			return true
	return false

func _chest() -> Vector3:
	return _player.global_position + Vector3.UP * 1.15

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			_player = get_parent().get_node_or_null("Player") as Player
	if state == DEAD:
		t += delta
		_die_tick(delta)
		return
	if _freeze > 0.0:
		_freeze -= delta
		_visuals(delta)
		return
	t += delta
	_cool -= delta
	_flash = maxf(_flash - delta * 4.0, 0.0)
	var to := Vector3.ZERO
	var dist := 1e9
	if _player != null and not _player.is_dead():
		to = _chest() - global_position
		dist = Vector2(to.x, to.z).length()
	var want := Vector3.ZERO
	var heat_to := 0.6
	var gather_to := 0.0
	var droop_to := 0.0
	var hover_to := HOVER
	match state:
		IDLE:
			# drifting slow loops over its ground, bobbing
			var w := _home + Vector3(sin(t * 0.31 + _ang) * 2.2, 0.0, cos(t * 0.23 + _ang * 1.7) * 2.2)
			want = (w - global_position) * 0.6
			want.y = 0.0
			want = want.limit_length(0.8)
			if dist < NOTICE:
				_enter(STALK)
		STALK:
			if dist > GIVE_UP or _player == null or _player.is_dead():
				_enter(IDLE)
			else:
				# hang ORBIT out and drift round the hero
				_ang += orbit * ORBIT_RATE * delta
				var away := Vector3(-to.x, 0, -to.z).normalized() if dist > 0.1 else Vector3.BACK
				var cur := atan2(away.x, away.z)
				var tgt_a := lerp_angle(cur, cur + orbit * 0.6, 0.5)
				var spot := _player.global_position + Vector3(sin(tgt_a), 0, cos(tgt_a)) * ORBIT
				want = spot - global_position
				want.y = 0.0
				want = want.limit_length(DRIFT)
				heat_to = 0.8
				if _cool <= 0.0 and dist > DART_MIN and dist < DART_MAX and not _kin_busy():
					_enter(WINDUP)
					flared.emit(global_position)
		WINDUP:
			# the flare: shards snap in, the heart goes white-hot, it draws back and up
			var u := clampf(t / GATHER_T, 0.0, 1.0)
			want = Vector3(-to.x, 0, -to.z).normalized() * 0.7 * (1.0 - u)
			heat_to = 0.8 + 3.6 * u * u
			gather_to = smoothstep(0.0, 0.6, u)
			hover_to = HOVER + 0.25 * u
			if u >= 1.0:
				_aim = (_chest() - global_position)
				var l := _aim.length()
				_aim = _aim / maxf(l, 0.01)
				_dart_speed = (l + DART_OVER) / DART_T
				_resolved = false
				darts += 1
				_enter(STRIKE)
				darted.emit(global_position)
		STRIKE:
			want = _aim * _dart_speed
			heat_to = 4.4
			gather_to = 1.0
			hover_to = -1.0
			if not _resolved and _player != null:
				var c := Geometry3D.get_closest_point_to_segment(global_position, _player.global_position + Vector3.UP * 0.5, _player.global_position + Vector3.UP * 1.6)
				if c.distance_to(global_position) < SEAR_R:
					_resolved = true
					_sear()
			if t >= DART_T:
				if not _resolved:
					_resolved = true
					last_result = "miss"
					struck.emit("miss")
				_cool = COOLDOWN + _rng.randf() * COOL_JITTER
				_enter(RECOVER)
		RECOVER:
			# slack: low, dim, the shards hanging loose
			var u := clampf(t / RECOVER_T, 0.0, 1.0)
			want = Vector3.ZERO
			heat_to = 0.3 + 0.4 * u
			droop_to = 1.0 - smoothstep(0.7, 1.0, u)
			hover_to = lerpf(SLACK_HOVER, HOVER, smoothstep(0.75, 1.0, u))
			if u >= 1.0:
				_enter(STALK)
		STAGGER:
			var u := clampf(t / _stagger_len, 0.0, 1.0)
			want = _knock * (1.0 - u) * 1.6
			heat_to = 0.35
			droop_to = 0.6
			hover_to = SLACK_HOVER + 0.2
			if u >= 1.0:
				_cool = maxf(_cool, 0.6)
				_enter(STALK if _player != null else IDLE)
	# height: settle toward the hover over the turf (a dart flies its own straight line)
	if hover_to >= 0.0:
		_hover = lerpf(_hover, hover_to, 1.0 - exp(-4.0 * delta))
		var gy := _ground_y(global_position) + _hover + sin(Time.get_ticks_msec() * 0.0021 + _ang) * 0.06
		want.y = (gy - global_position.y) * 5.0
	else:
		# never dive into the turf
		var floor_y := _ground_y(global_position) + 0.45
		if global_position.y + want.y * delta < floor_y:
			want.y = maxf(want.y, (floor_y - global_position.y) / delta)
	velocity = velocity.lerp(want, 1.0 if state == STRIKE else 1.0 - exp(-6.0 * delta))
	move_and_slide()
	_heat = lerpf(_heat, heat_to + _flash * 1.5, 1.0 - exp(-10.0 * delta))
	_gather = lerpf(_gather, gather_to, 1.0 - exp(-12.0 * delta))
	_droop = lerpf(_droop, droop_to, 1.0 - exp(-6.0 * delta))
	max_heat = maxf(max_heat, _heat)
	_visuals(delta)

func _sear() -> void:
	var r := _player.receive_attack(self, DAMAGE, false, false)
	if r == "hit":
		sears += 1
		ImpactFX.spawn(get_parent(), global_position, _aim, "stone", 0.5)
	last_result = r
	struck.emit(r)

func _visuals(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var r := lerpf(SHARD_R, SHARD_R * 0.42, _gather) + 0.08 * _droop
	var spin := 1.1 + 6.0 * _gather
	for i in _shards.size():
		var s := _shards[i]
		if s.top_level:
			continue
		var ax := _shard_axis[i]
		var a := now * spin * (1.0 + 0.13 * i) + TAU * i / _shards.size()
		var side := ax.cross(Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.FORWARD).normalized()
		var p := side.rotated(ax, a) * r
		p.y -= 0.18 * _droop * (0.6 + 0.4 * sin(i * 1.7))
		s.position = p
		# each splinter points along its path, tumbling slowly
		s.basis = Basis(ax, a * 0.6 + i).rotated(Vector3.RIGHT, now * 0.7 + i).scaled(Vector3.ONE * _shard_size[i])
		_shard_mats[i].set_shader_parameter("heat", 0.35 + _heat * 0.45)
	# the crust stays dark between the veins even at the flare's peak, so it reads as a coal,
	# not a white ball (the first frame blew it out to a featureless fireball)
	_heart_mat.set_shader_parameter("fill", 0.45 + _heat * 0.18)
	_heart_mat.set_shader_parameter("heat", 1.4 + _heat * 0.7)
	_heart.scale = Vector3.ONE * (0.9 + 0.12 * _heat / 4.4 + 0.03 * sin(now * 13.0))
	_light.light_energy = 0.7 + _heat * 0.55
	_light.omni_range = 4.0 + _heat * 0.6

func _die(dir: Vector3) -> void:
	state = DEAD
	t = 0.0
	remove_from_group("hittable")
	_heart.visible = false
	_smoke.emitting = false
	_sparks.emitting = false
	_burst.restart()
	_burst.emitting = true
	_ash.restart()
	_ash.emitting = true
	# the shards fly loose and drop into the grass
	for i in _shards.size():
		var s := _shards[i]
		var gp := s.global_transform
		s.top_level = true
		s.global_transform = gp
		var out := (gp.origin - global_position)
		out = out.normalized() if out.length() > 1e-3 else Vector3.UP
		_shard_vel[i] = out * _rng.randf_range(1.0, 2.6) + dir * 1.5 + Vector3.UP * _rng.randf_range(0.5, 1.6)
	snuffed.emit(global_position)
	died.emit()

func _die_tick(delta: float) -> void:
	_light.light_energy = 3.0 * exp(-t * 5.0)
	for i in _shards.size():
		var s := _shards[i]
		var v := _shard_vel[i]
		var p := s.global_position
		var gy := _ground_y(p) + 0.02
		if p.y > gy + 0.001 or v.y > 0.0:
			v.y -= 9.8 * delta
			p += v * delta
			s.global_basis = s.global_basis.rotated(_shard_spin[i].normalized(), _shard_spin[i].length() * delta)
			gy = _ground_y(p) + 0.02
			if p.y <= gy:
				p.y = gy
				v = Vector3.ZERO
			_shard_vel[i] = v
			s.global_position = p
		# the veins cool to black
		_shard_mats[i].set_shader_parameter("heat", maxf(0.9 * exp(-t * 0.6), 0.0))
	if t > 8.0:
		_light.visible = false
		set_physics_process(false)

## True once every shard lies in the grass (bots).
func shards_down() -> bool:
	for i in _shards.size():
		var s := _shards[i]
		if not s.top_level or _shard_vel[i] != Vector3.ZERO:
			return false
		if absf(s.global_position.y - (_ground_y(s.global_position) + 0.02)) > 0.05:
			return false
	return true
