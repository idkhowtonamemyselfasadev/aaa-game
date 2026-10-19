class_name Moths
extends Node3D
## Moths round the lantern on the green. From dusk they come in out of the dark one by one,
## loop round the lit horn panes in erratic circles, dart, bump against the panes, and now
## and then settle on the post's face under the arm with their wings folded back, before
## taking off again. Rain and strong wind keep most of them away; when the candle goes out
## at first light they drift off into the grass. Wing beat and pattern: moth.gdshader.

enum { AWAY, IN, CIRCLE, BUMP, SETTLE, REST, OUT }

const COUNT := 9
const HALF_SPAN := 0.021        # m: ~4 cm moths
const FAR := 7.0                # where they come in from / go back to
const PANE_R := 0.14            # horizontal clearance round the lantern body (LW/2 + a bit)

var post: LanternPost
var weather: Weather
var visible_count := 0          # bots: moths out round the light now
var settled_count := 0          # bots: moths sat on the post now
var bumps := 0                  # bots: times a moth hit the panes
var max_dist := 0.0             # bots: farthest a circling moth strayed from the lantern
var _mm: MultiMesh
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _m: Array = []
var _t := 0.0
var _prev_lit := 0.0
var _perched := 0             # sat or settling, counted at the frame start

class Moth:
	var state := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var basis := Basis.IDENTITY
	var r := 0.3                # orbit radius
	var sense := 1.0            # orbit direction
	var y_off := 0.0
	var speed := 1.2
	var timer := 0.0            # to the next dart / bump / settle decision
	var hold := 0.0             # time left in BUMP / REST
	var gate := 0.0
	var phase := 0.0
	var kind := 0
	var rest := 0.0
	var spot := Vector3.ZERO    # settle point (world) and the face normal there
	var spot_n := Vector3.FORWARD

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY   # top_level keeps the post's transform otherwise
	_rng.seed = 7151
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 1.2)
	plane.subdivide_width = 1          # vertices at x = -1, 0, 1: the hinge on the body
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = plane
	_mm.instance_count = COUNT
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/moth.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "MothMesh"
	mmi.multimesh = _mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	add_child(mmi)
	for i in COUNT:
		var m := Moth.new()
		m.gate = (float(i) + 0.5) / COUNT * 0.95
		m.phase = _rng.randf() * TAU
		m.kind = [0, 0, 1, 2, 0, 1, 2, 0, 1][i]
		m.sense = 1.0 if _rng.randf() < 0.5 else -1.0
		m.speed = _rng.randf_range(0.9, 1.5)
		_m.append(m)

## Lantern centre in world space; this node is top-level so positions are world.
func _centre() -> Vector3:
	return post.lantern_center()

func _process(delta: float) -> void:
	_t += delta
	var c := _centre()
	var rain := weather.rain if weather else 0.0
	var wind := weather.wind if weather else 0.0
	var want := post.lit * (1.0 - 0.85 * rain) * (1.0 - 0.6 * wind)
	_mat.set_shader_parameter("lamp_pos", post.flame_pos.global_position)
	_mat.set_shader_parameter("lamp_lit", post.lit)
	var drift := Vector3(0.8, 0.0, 0.3) * wind * 0.9
	var jump := post.lit - _prev_lit > 0.5
	_prev_lit = post.lit
	visible_count = 0
	_perched = 0
	for m in _m:
		if m.state == REST or m.state == SETTLE:
			_perched += 1
	settled_count = 0
	var steps := maxi(1, ceili(delta * 60.0))
	var dt := delta / steps
	for i in COUNT:
		var m: Moth = _m[i]
		var wanted := m.gate < want
		if wanted and m.state == AWAY:
			_arrive(m, c)
			if jump:
				# time skipped to night (a scene opening after dark): already round the light
				var a := _rng.randf() * TAU
				m.pos = c + Vector3(cos(a) * m.r, m.y_off, sin(a) * m.r)
				m.state = CIRCLE
		elif not wanted and m.state != AWAY and m.state != OUT:
			_leave(m, c)
		if m.state == AWAY:
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), c + Vector3.DOWN * 50.0))
			continue
		for s in steps:
			_step(m, c, dt, drift)
		visible_count += 1
		if m.state == REST:
			settled_count += 1
		elif m.state == CIRCLE or m.state == BUMP:
			max_dist = maxf(max_dist, m.pos.distance_to(c))
		m.rest = move_toward(m.rest, 1.0 if m.state == REST else 0.0, delta * 6.0)
		_mm.set_instance_transform(i, Transform3D(m.basis, m.pos))
		_mm.set_instance_custom_data(i, Color(m.phase, m.rest, float(m.kind), HALF_SPAN))
	if OS.get_environment("MOTHDBG") != "" and Engine.get_process_frames() % 10 == 0:
		print("MOTHS lit %.2f want %.2f visible %d first %s centre %s" % [post.lit, want, visible_count, _m[0].pos, c])

func _arrive(m: Moth, c: Vector3) -> void:
	var a := _rng.randf() * TAU
	m.pos = c + Vector3(cos(a) * FAR, _rng.randf_range(-1.8, 0.5), sin(a) * FAR)
	m.vel = (c - m.pos).normalized() * m.speed
	m.state = IN
	m.r = _rng.randf_range(0.2, 0.6)
	m.y_off = _rng.randf_range(-0.25, 0.3)
	m.timer = _rng.randf_range(0.5, 2.0)

func _leave(m: Moth, c: Vector3) -> void:
	var out := m.pos - c
	out.y = 0.0
	if out.length() < 0.01:
		out = Vector3.RIGHT
	m.vel = out.normalized() * m.speed + Vector3.DOWN * 0.2
	m.state = OUT

## A settle point on the post's face toward the lantern, under the arm.
func _pick_spot(m: Moth) -> void:
	var pb := post.global_basis
	var face := pb.z.normalized()
	var h := _rng.randf_range(1.75, 2.3)
	var x := _rng.randf_range(-0.045, 0.045)
	m.spot_n = face
	m.spot = post.global_position + pb.y.normalized() * h + pb.x.normalized() * x + face * (LanternPost.POST_W * 0.5 + 0.004)

func _step(m: Moth, c: Vector3, dt: float, drift: Vector3) -> void:
	var desired := m.vel
	match m.state:
		IN:
			desired = (c + Vector3(0, m.y_off, 0) - m.pos).normalized() * m.speed * 1.2
			if m.pos.distance_to(c) < m.r + 0.4:
				m.state = CIRCLE
		OUT:
			desired = m.vel.normalized() * m.speed * 1.3
			if m.pos.distance_to(c) > FAR:
				m.state = AWAY
				return
		CIRCLE, BUMP:
			var rel := m.pos - c
			var rh := Vector3(rel.x, 0.0, rel.z)
			var d := maxf(rh.length(), 0.001)
			var tang := Vector3.UP.cross(rh / d) * m.sense
			var bob := sin(_t * (1.7 + m.phase * 0.3) + m.phase) * 0.14
			desired = tang * m.speed + rh / d * (m.r - d) * 4.0 + Vector3.UP * (m.y_off + bob - rel.y) * 3.5 + drift
			if m.state == BUMP:
				# a blind dash at the glowing horn
				desired = (c + Vector3(0, clampf(rel.y, -0.12, 0.15), 0) - m.pos).normalized() * m.speed * 1.6
			m.timer -= dt
			if m.state == BUMP:
				m.hold -= dt
				if m.hold <= 0.0:
					m.state = CIRCLE
			elif m.timer <= 0.0:
				var roll := _rng.randf()
				m.timer = _rng.randf_range(0.35, 1.6)
				if roll < 0.12:
					m.state = BUMP
					m.hold = _rng.randf_range(0.5, 1.0)
				elif roll < 0.17 and _perched < 2:
					_pick_spot(m)
					m.state = SETTLE
				else:
					# a dart: a sudden kick off the loop, a new radius, sometimes the other way
					m.vel += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.8), _rng.randf_range(-1, 1)) * 1.4
					m.r = clampf(m.r + _rng.randf_range(-0.15, 0.15), 0.18, 0.65)
					if _rng.randf() < 0.25:
						m.sense = -m.sense
		SETTLE:
			var to := m.spot + m.spot_n * 0.05 - m.pos
			desired = to.normalized() * minf(m.speed, to.length() * 5.0 + 0.15)
			if to.length() < 0.03:
				m.state = REST
				m.hold = _rng.randf_range(4.0, 12.0)
				m.pos = m.spot
				m.vel = Vector3.ZERO
				var head := Vector3.UP.rotated(m.spot_n, _rng.randf_range(-0.5, 0.5))
				m.basis = Basis.looking_at(head, m.spot_n)
				return
		REST:
			m.hold -= dt
			if m.hold <= 0.0:
				m.state = CIRCLE
				m.vel = m.spot_n * 0.6 + Vector3.DOWN * 0.2
				m.timer = 1.0
			return
	m.vel = m.vel.lerp(desired, clampf(dt * 7.0, 0.0, 1.0))
	m.pos += m.vel * dt
	# never through the lantern body or into the post
	var rel2 := m.pos - c
	if rel2.y > -0.25 and rel2.y < 0.28:
		var rh2 := Vector2(rel2.x, rel2.z)
		if rh2.length() < PANE_R:
			if m.state == BUMP:
				bumps += 1
				m.state = CIRCLE
				m.vel = Vector3(rh2.x, 0.0, rh2.y).normalized() * m.speed * 0.8
			rh2 = rh2.normalized() * PANE_R
			m.pos = c + Vector3(rh2.x, rel2.y, rh2.y)
	var sp := m.vel.length()
	if sp > 0.05:
		var f := m.vel / sp
		var up := Vector3.UP if absf(f.y) < 0.95 else Vector3.FORWARD
		# bank into the turn a little
		m.basis = Basis.looking_at(f, up).rotated(f, clampf(m.sense * 0.5, -0.6, 0.6)).orthonormalized()
