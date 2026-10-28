class_name HandMoths
extends Node3D
## A few moths that find a carried lantern on the road after dark (HandLantern, the pedlar's
## dusk walk). As the candle comes up they fly in out of the grass one at a time, loop the
## swinging horn panes in tight erratic circles, now and then dash blind at the glow, and
## string out behind it when the walker strides on, catching up in bursts. Rain and wind
## keep most of them in the grass; when the light dies they peel off and drop away.
## Same wing mesh and pattern as the post's moths (moth.gdshader); no settling here.

enum { AWAY, IN, CIRCLE, BUMP, OUT }

const COUNT := 5
const HALF_SPAN := 0.02
const FAR := 4.0                # where they come in from / are lost at
const PANE_R := 0.11            # clearance round the small lantern's horn
const LOST := 3.5               # a moth this far behind gives up and drops away

var lantern: HandLantern
var weather: Weather
var visible_count := 0          # bots: moths round the light now
var max_seen := 0               # bots
var bumps := 0                  # bots: dashes that hit the horn
var lost := 0                   # bots: moths that fell behind the walker and gave up
var near_max := 0.0             # bots: farthest a looping moth strayed (resets with max_seen)
var _mm: MultiMesh
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _m: Array = []
var _t := 0.0
var _prev_on := 0.0

class Moth:
	var state := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var basis := Basis.IDENTITY
	var r := 0.25
	var sense := 1.0
	var y_off := 0.0
	var speed := 1.6
	var timer := 0.0
	var hold := 0.0
	var gate := 0.0
	var phase := 0.0
	var kind := 0
	var gone := 0.0             # s before it may come back after giving up

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.seed = 9137
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 1.2)
	plane.subdivide_width = 1
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
	mmi.extra_cull_margin = 8.0
	add_child(mmi)
	for i in COUNT:
		var m := Moth.new()
		m.gate = (float(i) + 0.5) / COUNT * 0.9
		m.phase = _rng.randf() * TAU
		m.kind = [0, 1, 0, 2, 1][i]
		m.sense = 1.0 if _rng.randf() < 0.5 else -1.0
		# a walking man makes ~1.1 m/s on the dusk road: they must be able to keep up in bursts
		m.speed = _rng.randf_range(1.5, 2.1)
		_m.append(m)
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.DOWN * 500.0))

func moth_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m in _m:
		if m.state != AWAY:
			out.append(m.pos)
	return out

func _process(delta: float) -> void:
	if lantern == null or delta <= 0.0:
		return
	_t += delta
	var c := lantern.flame_center()
	# the mesh's bounds follow the light (the node itself sits at the origin)
	var mmi: MultiMeshInstance3D = get_child(0)
	mmi.custom_aabb = AABB(c - Vector3.ONE * 5.0, Vector3.ONE * 10.0)
	var rain := weather.rain if weather else 0.0
	var wind := weather.wind if weather else 0.0
	var on := lantern.lit if lantern.is_visible_in_tree() else 0.0
	var want := on * (1.0 - 0.85 * rain) * (1.0 - 0.6 * wind)
	_mat.set_shader_parameter("lamp_pos", c)
	_mat.set_shader_parameter("lamp_lit", on)
	var drift := Vector3(0.8, 0.0, 0.3) * wind * 0.9
	var jump := on - _prev_on > 0.5
	_prev_on = on
	visible_count = 0
	var steps := maxi(1, ceili(delta * 60.0))
	var dt := delta / steps
	for i in COUNT:
		var m: Moth = _m[i]
		m.gone = maxf(m.gone - delta, 0.0)
		var wanted := m.gate < want and m.gone <= 0.0
		if wanted and m.state == AWAY:
			_arrive(m, c)
			if jump:
				# a scene opening after dark with the candle already burning: round it already
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
		if m.state == AWAY:
			continue
		visible_count += 1
		if m.state == CIRCLE or m.state == BUMP:
			near_max = maxf(near_max, m.pos.distance_to(c))
		_mm.set_instance_transform(i, Transform3D(m.basis, m.pos))
		_mm.set_instance_custom_data(i, Color(m.phase, 0.0, float(m.kind), HALF_SPAN))
	max_seen = maxi(max_seen, visible_count)

func _arrive(m: Moth, c: Vector3) -> void:
	var a := _rng.randf() * TAU
	# up out of the verge grass round him
	m.pos = c + Vector3(cos(a) * FAR, _rng.randf_range(-0.5, -0.2), sin(a) * FAR)
	m.vel = (c - m.pos).normalized() * m.speed
	m.state = IN
	m.r = _rng.randf_range(0.16, 0.42)
	m.y_off = _rng.randf_range(-0.12, 0.25)
	m.timer = _rng.randf_range(0.4, 1.5)

func _leave(m: Moth, c: Vector3) -> void:
	var out := m.pos - c
	out.y = 0.0
	if out.length() < 0.01:
		out = Vector3.RIGHT
	m.vel = out.normalized() * m.speed * 0.7 + Vector3.DOWN * 0.5
	m.state = OUT

func _step(m: Moth, c: Vector3, dt: float, drift: Vector3) -> void:
	var desired := m.vel
	var rel := m.pos - c
	match m.state:
		IN:
			desired = (c + Vector3(0, m.y_off, 0) - m.pos).normalized() * m.speed * 1.2
			if rel.length() < m.r + 0.3:
				m.state = CIRCLE
		OUT:
			desired = m.vel.normalized() * m.speed + Vector3.DOWN * 0.3
			if rel.length() > FAR or m.pos.y < c.y - 0.9:
				m.state = AWAY
				return
		CIRCLE, BUMP:
			var rh := Vector3(rel.x, 0.0, rel.z)
			var d := maxf(rh.length(), 0.001)
			if d > LOST:
				# he walked on faster than it could follow: back to the grass for a while
				lost += 1
				m.gone = _rng.randf_range(4.0, 9.0)
				_leave(m, c)
				return
			var tang := Vector3.UP.cross(rh / d) * m.sense
			var bob := sin(_t * (1.9 + m.phase * 0.3) + m.phase) * 0.1
			# the pull grows with distance: a moth strung out behind the walker beelines back
			var pull := 4.0 + maxf(d - m.r, 0.0) * 6.0
			desired = tang * m.speed * clampf(1.2 - (d - m.r), 0.2, 1.0) + rh / d * (m.r - d) * pull + Vector3.UP * (m.y_off + bob - rel.y) * 3.5 + drift
			if desired.length() > m.speed * 1.6:
				desired = desired.normalized() * m.speed * 1.6
			if m.state == BUMP:
				desired = (c + Vector3(0, clampf(rel.y, -0.08, 0.1), 0) - m.pos).normalized() * m.speed * 1.6
				m.hold -= dt
				if m.hold <= 0.0:
					m.state = CIRCLE
			else:
				m.timer -= dt
				if m.timer <= 0.0:
					m.timer = _rng.randf_range(0.3, 1.3)
					if _rng.randf() < 0.08:
						m.state = BUMP
						m.hold = _rng.randf_range(0.3, 0.7)
					else:
						m.vel += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.7), _rng.randf_range(-1, 1)) * 1.2
						m.r = clampf(m.r + _rng.randf_range(-0.1, 0.1), 0.14, 0.45)
						if _rng.randf() < 0.25:
							m.sense = -m.sense
	m.vel = m.vel.lerp(desired, clampf(dt * 7.0, 0.0, 1.0))
	m.pos += m.vel * dt
	# never through the horn
	var rel2 := m.pos - c
	if rel2.y > -0.18 and rel2.y < 0.2:
		var rh2 := Vector2(rel2.x, rel2.z)
		if rh2.length() < PANE_R:
			if m.state == BUMP:
				bumps += 1
				m.state = CIRCLE
				m.vel = Vector3(rh2.x, 0.0, rh2.y).normalized() * m.speed * 0.7
			rh2 = rh2.normalized() * PANE_R if rh2.length() > 0.0001 else Vector2(PANE_R, 0.0)
			m.pos = c + Vector3(rh2.x, rel2.y, rh2.y)
	var sp := m.vel.length()
	if sp > 0.05:
		var f := m.vel / sp
		var up := Vector3.UP if absf(f.y) < 0.95 else Vector3.FORWARD
		m.basis = Basis.looking_at(f, up).rotated(f, clampf(m.sense * 0.5, -0.6, 0.6)).orthonormalized()
