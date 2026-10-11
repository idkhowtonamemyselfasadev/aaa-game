class_name Insects
extends Node3D
## Insects in the light (DESIGN §8, owner's "alive" list). Two layers that stream around
## the camera:
##  - fireflies after dusk: drift low over the meadow, each blinking on its own slow
##    rhythm; when the hero walks through them they scatter upward and flash together. The
##    brightest few near the camera carry a tiny real light so the grass around them glows.
##  - midge swarms by day: tight dancing clouds beside tree trunks that only catch the eye
##    against the low sun (a backlit glint) and drift off when crowded.
## All dots are one quad MultiMesh per layer; the motion is CPU-side (a few hundred points).

@export var terrain_path: NodePath
@export var firefly_count: int = 420
@export var firefly_radius: float = 34.0
@export var swarm_count: int = 6
@export var midges_per_swarm: int = 40
@export var light_count: int = 6
@export var scare_radius: float = 2.6
@export var seed: int = 4242

var _terrain: Terrain
var _world: Node
var _rng := RandomNumberGenerator.new()
var _ff: Array = []
var _swarms: Array = []
var _ff_mm: MultiMesh
var _mid_mm: MultiMesh
var _mid_mat: ShaderMaterial
var _lights: Array[OmniLight3D] = []
var _anchor := Vector3.INF
var _threat_prev := Vector3.INF
var _t := 0.0
var _sun_dir := Vector3.UP
var night := 0.0             # 0 day .. 1 full firefly night
var day := 0.0
var startled_total := 0      # bots read this: fireflies the hero has scattered
var swarm_flees := 0         # bots read this: swarms that drifted off from the hero
var butterflies: Butterflies   # the day layer that settles and flies (butterflies.gd)

class Fly:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var ground := 0.0
	var height := 1.0
	var heading := 0.0
	var turn := 0.0
	var phase := 0.0
	var period := 4.0
	var flash := 0.5
	var gate := 0.0           # fades in with the night: index-ordered so the count ramps
	var startle := 0.0
	var glow := 0.0

class Swarm:
	var home := Vector3.ZERO
	var centre := Vector3.ZERO
	var flee := 0.0
	var flee_dir := Vector3.ZERO
	var offs: Array = []      # per midge: Vector3 orbit radii
	var phases: Array = []

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_world = get_parent()
	_rng.seed = seed
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var shader: Shader = load("res://shaders/insect.gdshader")
	var ffm := ShaderMaterial.new()
	ffm.shader = shader
	_ff_mm = _make_mm(quad, ffm, firefly_count, "Fireflies")
	_mid_mat = ShaderMaterial.new()
	_mid_mat.shader = shader
	_mid_mat.set_shader_parameter("glow_color", Color(1.0, 0.86, 0.62))
	_mid_mat.set_shader_parameter("energy", 5.0)
	_mid_mat.set_shader_parameter("min_px_angle", 0.0016)
	_mid_mm = _make_mm(quad, _mid_mat, swarm_count * midges_per_swarm, "Midges")
	for i in light_count:
		var l := OmniLight3D.new()
		l.name = "FireflyLight%d" % i
		l.light_color = Color(0.78, 1.0, 0.36)
		l.omni_range = 2.4
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_lights.append(l)
	for i in firefly_count:
		var f := Fly.new()
		f.phase = _rng.randf() * 10.0
		f.period = _rng.randf_range(2.4, 5.5)
		f.flash = _rng.randf_range(0.6, 1.4)
		f.heading = _rng.randf() * TAU
		f.height = _height_pick()
		f.gate = float(i) / firefly_count
		_ff.append(f)
	for s in swarm_count:
		var w := Swarm.new()
		for m in midges_per_swarm:
			w.offs.append(Vector3(_rng.randfn(0.0, 0.32), _rng.randfn(0.0, 0.28), _rng.randfn(0.0, 0.32)))
			w.phases.append(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf_range(2.5, 6.0)))
		w.home = Vector3.INF
		_swarms.append(w)
	butterflies = Butterflies.new()
	butterflies.name = "Butterflies"
	butterflies.terrain = _terrain
	butterflies.grass = get_node_or_null("../Grass")
	add_child(butterflies)

func _make_mm(mesh: Mesh, mat: Material, n: int, nm: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-400, -50, -400), Vector3(800, 300, 800))
	add_child(mmi)
	return mm

func _height_pick() -> float:
	# most hang just over the grass heads, a few climb to head height and above
	return 0.35 + pow(_rng.randf(), 2.2) * 2.4

## Fireflies currently lit up enough to see (bots/tests read this).
func visible_fireflies() -> int:
	var n := 0
	for f: Fly in _ff:
		if f.glow > 0.1:
			n += 1
	return n

func firefly_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f: Fly in _ff:
		out.append(f.pos)
	return out

func swarm_centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for w: Swarm in _swarms:
		out.append(w.centre)
	return out

func _hour() -> float:
	var h = _world.get("time_of_day")
	return 17.25 if h == null else float(h)

func _process(delta: float) -> void:
	_t += delta
	var h := _hour()
	night = smoothstep(18.3, 19.3, h) if h > 12.0 else 1.0 - smoothstep(4.3, 5.4, h)
	# midges: from mid-morning, thickest in the long evening light, gone at dusk
	day = smoothstep(7.0, 9.0, h) * (1.0 - smoothstep(18.4, 19.1, h))
	var cam := get_viewport().get_camera_3d()
	var player: Node3D = _world.get_node_or_null("Player")
	var anchor := cam.global_position if cam else (player.global_position if player else Vector3.ZERO)
	var threat := player.global_position if player else anchor
	var tvel := Vector3.ZERO if _threat_prev == Vector3.INF or delta <= 0.0 else (threat - _threat_prev) / delta
	_threat_prev = threat
	# first frame or a teleport (respawn, fast travel, cutscene cut): refill the bubble
	if _anchor == Vector3.INF or _anchor.distance_to(anchor) > firefly_radius:
		_anchor = anchor
		for f: Fly in _ff:
			_spawn_fly(f, anchor, _rng.randf_range(0.0, firefly_radius))
	_anchor = anchor
	var sun: Node3D = _world.get_node_or_null("Sun")
	if sun:
		_sun_dir = sun.global_transform.basis.z.normalized()   # toward the sun
	_update_fireflies(delta, anchor, threat, tvel)
	_update_midges(delta, anchor, threat, cam.global_position if cam else Vector3.INF)

func _spawn_fly(f: Fly, anchor: Vector3, r: float, toward := Vector3.ZERO) -> void:
	for tries in 6:
		var a := _rng.randf() * TAU
		if toward != Vector3.ZERO:
			a = atan2(toward.z, toward.x) + _rng.randf_range(-0.9, 0.9)
		var p := anchor + Vector3(cos(a) * r, 0.0, sin(a) * r)
		# meadow only: not on rock slopes, not on the far edge of the map
		var half := _terrain.size_m * 0.5 - 4.0
		if absf(p.x) > half or absf(p.z) > half:
			continue
		if _terrain.normal_at(p.x, p.z).y < 0.86 and tries < 5:
			continue
		f.ground = _terrain.height_at(p.x, p.z)
		f.height = _height_pick()
		f.pos = Vector3(p.x, f.ground + f.height, p.z)
		f.vel = Vector3.ZERO
		f.startle = 0.0
		return

func _update_fireflies(delta: float, anchor: Vector3, threat: Vector3, tvel: Vector3) -> void:
	var tspeed := Vector2(tvel.x, tvel.z).length()
	var scare_r := scare_radius + minf(tspeed, 8.0) * 0.25
	var lit: Array = []
	var n := _ff.size()
	for i in n:
		var f: Fly = _ff[i]
		# active share of the swarm ramps with the night
		var on := clampf((night - f.gate * 0.85) * 6.0, 0.0, 1.0)
		var to_anchor := Vector2(f.pos.x - anchor.x, f.pos.z - anchor.z)
		if to_anchor.length() > firefly_radius + 4.0:
			# left the bubble behind the camera: re-enter on the far side, ahead of travel
			_spawn_fly(f, anchor, firefly_radius * _rng.randf_range(0.8, 0.98), Vector3(-to_anchor.x, 0, -to_anchor.y))
		# lazy meandering flight: heading wanders, slow vertical bob back to its band
		f.turn = lerpf(f.turn, _rng.randfn(0.0, 1.6), delta * 0.8)
		f.heading += f.turn * delta
		var want := Vector3(cos(f.heading), 0.0, sin(f.heading)) * 0.32
		if (i + int(_t * 30.0)) % 8 == 0:
			f.ground = _terrain.height_at(f.pos.x, f.pos.z)
		var target_y := f.ground + f.height + sin(_t * 0.9 + f.phase) * 0.18
		want.y = clampf((target_y - f.pos.y) * 0.8, -0.5, 0.5)
		# the hero walking through: scatter away and up, all flashing at once
		var rel := f.pos - threat - Vector3(0, 0.9, 0)
		var d := rel.length()
		if on > 0.0 and d < scare_r and (tspeed > 0.6 or d < scare_r * 0.55):
			if f.startle <= 0.0:
				startled_total += 1
			f.startle = _rng.randf_range(1.4, 2.4)
			var away := Vector3(rel.x, 0.0, rel.z).normalized() if Vector2(rel.x, rel.z).length() > 0.05 else Vector3.RIGHT
			want = away * (1.6 + tspeed * 0.25) + Vector3(0, 0.9, 0)
		if f.startle > 0.0:
			f.startle -= delta
			if f.startle > 0.0 and d >= scare_r:
				want = f.vel     # keep coasting on the escape
		f.vel = f.vel.lerp(want, clampf(delta * (3.0 if f.startle > 0.0 else 1.2), 0.0, 1.0))
		f.pos += f.vel * delta
		f.pos.y = maxf(f.pos.y, f.ground + 0.15)
		# blink: a slow swell and fade once per period; startled ones flicker bright
		var b := fposmod(_t + f.phase, f.period)
		var pulse := pow(sin(clampf(b / f.flash, 0.0, 1.0) * PI), 2.0)
		if f.startle > 0.0:
			pulse = maxf(pulse, 0.65 + 0.35 * sin(_t * 23.0 + f.phase * 7.0))
		f.glow = (pulse * 0.94 + 0.06) * on
		_ff_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, f.pos))
		_ff_mm.set_instance_custom_data(i, Color(f.glow, 0.07, 0.0, 0.0))
		if f.glow > 0.35 and f.pos.distance_squared_to(anchor) < 400.0:
			lit.append(i)
	# the few brightest near the camera light the grass around them
	lit.sort_custom(func(a: int, b2: int) -> bool:
		return _ff[a].glow * 1.0 / (1.0 + _ff[a].pos.distance_to(anchor)) > _ff[b2].glow * 1.0 / (1.0 + _ff[b2].pos.distance_to(anchor)))
	for k in _lights.size():
		var l := _lights[k]
		if k < lit.size():
			var f: Fly = _ff[lit[k]]
			l.visible = true
			l.global_position = f.pos
			l.light_energy = f.glow * 0.55
		else:
			l.visible = false

func _update_midges(delta: float, anchor: Vector3, threat: Vector3, cam_pos: Vector3) -> void:
	var flora: Flora = _world.get_node_or_null("Flora")
	var idx := 0
	for s in _swarms.size():
		var w: Swarm = _swarms[s]
		if w.home == Vector3.INF or Vector2(w.home.x - anchor.x, w.home.z - anchor.z).length() > 60.0:
			_place_swarm(w, s, flora, anchor)
		# crowded by the hero: the cloud drifts off, then settles back by its trunk
		var rel := w.centre - threat - Vector3(0, 1.0, 0)
		if rel.length() < 2.4 and day > 0.05:
			if w.flee <= 0.0:
				swarm_flees += 1
			w.flee = 2.5
			w.flee_dir = (Vector3(rel.x, 0.4, rel.z)).normalized()
		var goal := w.home
		if w.flee > 0.0:
			w.flee -= delta
			w.centre += w.flee_dir * 1.4 * delta
		else:
			w.centre = w.centre.lerp(goal, clampf(delta * 0.35, 0.0, 1.0))
		var spread := 1.0 + (0.8 if w.flee > 0.0 else 0.0)
		# midges only catch the eye against the light: brightest with the sun behind them
		var back := 0.0
		if cam_pos != Vector3.INF:
			back = pow(maxf((w.centre - cam_pos).normalized().dot(_sun_dir), 0.0), 6.0)
		var glint := day * (0.3 + back * 3.0)
		for m in w.offs.size():
			var o: Vector3 = w.offs[m]
			var ph: Vector3 = w.phases[m]
			var sp := ph.z
			var p := w.centre + Vector3(
				o.x + sin(_t * sp + ph.x) * 0.22,
				o.y + sin(_t * sp * 1.7 + ph.y) * 0.3,
				o.z + cos(_t * sp * 1.3 + ph.x) * 0.22) * spread
			_mid_mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, p))
			_mid_mm.set_instance_custom_data(idx, Color(glint, 0.032, 0.0, 0.0))
			idx += 1

func _place_swarm(w: Swarm, s: int, flora: Flora, anchor: Vector3) -> void:
	# beside a tree trunk near the camera, on the sheltered side, head high
	var best := Vector3.INF
	if flora:
		var near: Array[Vector3] = []
		for t in flora.tree_positions:
			if Vector2(t.x - anchor.x, t.z - anchor.z).length() < 45.0:
				near.append(t)
		if not near.is_empty():
			best = near[(s * 7 + _rng.randi_range(0, 3)) % near.size()]
	if best == Vector3.INF:
		var a := _rng.randf() * TAU
		best = anchor + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(8.0, 30.0)
	var a2 := _rng.randf() * TAU
	var p := best + Vector3(cos(a2), 0, sin(a2)) * _rng.randf_range(2.2, 3.4)
	p.y = _terrain.height_at(p.x, p.z) + _rng.randf_range(1.3, 2.4)
	w.home = p
	w.centre = p
	w.flee = 0.0
