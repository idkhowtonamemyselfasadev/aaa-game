class_name Wheatears
extends Node3D
## The fold's wheatears (owner's "alive" list: birds that scatter when you approach): a pair and
## a youngster that keep to Osric's old fold under the great stone. Each sits up on a wall top or
## the bell post's head, bobbing and flirting its tail, drops into the turf for a few hops and
## pecks after a grub, and flits low to another stone. When the hero comes close the nearest
## one "chacks" from its stone (two pebbles knocked together), then flies off low and fast,
## flashing its white rump, to a stone on the far side of the fold. They sit tight in the
## rain and go to roost in the wall's chinks at dusk.
## Geometry: Birds' rook mesh at a third of the size, its pose (and plumage: cock or hen) set per
## bird through instance uniforms in wheatear.gdshader.

enum { PERCH, FLIT, GROUND }

const SCALE := 0.34              # rook mesh 0.47 m beak to tail -> a 16 cm wheatear
const SHAPE := Vector3(1.08, 1.1, 0.8)   # dumpier than a rook: short-tailed, round-headed, upright
const SCARE := 4.5               # m from a still hero; +1.2 m per m/s he moves
const WARN := 8.0                # m: the bird on its stone chacks at a hero this near
const OUT := 19.5                # active hours: out of the wall at 5.2, back in by 19.5
const IN := 5.2

var terrain: Terrain
var player: Node3D
var weather: Weather
var perches: Array[Vector3] = []
var flushes := 0                 # bots read these
var drops := 0
var bobs := 0
var chacks := 0
var flits := 0
var hold := false               # shots: sit tight whoever comes
var _rng := RandomNumberGenerator.new()
var _birds: Array = []
var _prev := Vector3.INF
var _t := 0.0
var _calls: Array[AudioStreamWAV] = []

class W:
	var mi: MeshInstance3D
	var voice: AudioStreamPlayer3D
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var state := 0
	var timer := 0.0
	var perch := 0
	var flap := 0.0
	var legs := 1.0
	var peck := 0.0
	var fold := 1.0
	var bob := 0.0               # 0..1 bob dip in progress (seconds left * 4)
	var bob_t := 1.0
	var call_t := 0.0
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var to_perch := -1           # -1: landing in the turf
	var fly_t := 0.0
	var fly_dur := 1.0
	var hop_to := Vector3.ZERO
	var hop_t := 0.0
	var phase := 0.0             # wing beat
	var look := 0.0              # the way it faces on its stone

func build(t: Terrain, fold_perches: Array[Vector3], seed_v: int = 4417) -> void:
	terrain = t
	perches = fold_perches.duplicate()
	_rng.seed = seed_v
	if perches.size() < 2:
		return
	for k in 3:
		_calls.append(_make_chack(k))
	var maker := Birds.new()
	var mesh: ArrayMesh = maker._build_bird_mesh()
	maker.free()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wheatear.gdshader")
	for i in 3:
		var w := W.new()
		w.mi = MeshInstance3D.new()
		w.mi.name = "Wheatear_%d" % i
		w.mi.mesh = mesh
		w.mi.material_override = mat
		w.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(w.mi)
		# 0 the cock, 1 the hen, 2 this year's young one (hen-plumaged, paler)
		w.mi.set_instance_shader_parameter("hen", 0.0 if i == 0 else (1.0 if i == 1 else 1.4))
		w.voice = AudioStreamPlayer3D.new()
		w.voice.unit_size = 6.0
		w.voice.volume_db = -9.0
		w.voice.max_distance = 60.0
		add_child(w.voice)
		w.perch = (i * perches.size()) / 3
		w.pos = perches[w.perch]
		w.yaw = _rng.randf() * TAU
		w.look = w.yaw
		w.timer = _rng.randf_range(2.0, 9.0)
		w.bob_t = _rng.randf_range(0.5, 3.0)
		w.phase = _rng.randf() * TAU
		_birds.append(w)
	_write_all()

## Shots: sit the birds on the free stones nearest `eye` that stand over `clear` m from the
## hero, each faced a little off the lens, and keep them there.
func seat_for_shot(eye: Vector3, clear: float) -> void:
	var tp := player.global_position if player else Vector3.INF
	var c: Array[int] = []
	for i in perches.size():
		if Vector2(perches[i].x - tp.x, perches[i].z - tp.z).length() > clear:
			c.append(i)
	c.sort_custom(func(a: int, b: int) -> bool: return perches[a].distance_to(eye) < perches[b].distance_to(eye))
	for k in mini(_birds.size(), c.size()):
		var w: W = _birds[k]
		w.perch = c[k * 2] if k * 2 < c.size() else c[k]
		w.state = PERCH
		w.pos = perches[w.perch]
		w.look = atan2(-(eye.x - w.pos.x), -(eye.z - w.pos.z)) + (1.3 if k % 2 == 0 else -1.5)
		w.yaw = w.look
		w.timer = 1.0e6
		w.bob_t = 6.0 + k
	hold = true
	_write_all()

func active(h: float) -> bool:
	return h >= IN and h < OUT

func bird_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for w: W in _birds:
		out.append(w.pos)
	return out

func states() -> Array[int]:
	var out: Array[int] = []
	for w: W in _birds:
		out.append(w.state)
	return out

func _process(delta: float) -> void:
	if _birds.is_empty():
		return
	var dt := minf(delta, 0.1)
	_t += dt
	var h = get_parent().get("time_of_day")
	var awake: bool = h == null or active(h)
	visible = awake
	if not awake:
		# roosting in the wall: back on their own stones for the morning
		for w: W in _birds:
			w.state = PERCH
			w.pos = perches[w.perch]
		return
	var wet := weather.rain if weather else 0.0
	var tp := player.global_position if player else Vector3.INF
	var spd := 0.0
	if player and _prev != Vector3.INF:
		var step := Vector2(tp.x - _prev.x, tp.z - _prev.z).length()
		spd = minf(step / maxf(dt, 0.001), 12.0) if step < 2.0 else 0.0   # a teleport is no charge
	_prev = tp
	var scare := SCARE + spd * 1.2
	for w: W in _birds:
		var d := Vector2(w.pos.x - tp.x, w.pos.z - tp.z).length()
		if w.state != FLIT and d < scare and not hold:
			_flush(w, tp, scare)
		match w.state:
			PERCH:
				_perch(w, dt, wet, d, tp)
			GROUND:
				_ground(w, dt)
			FLIT:
				_fly(w, dt)
	_write_all()

## Away from the hero: the nearest stone well clear of him, else the farthest one.
func _flush(w: W, tp: Vector3, scare: float) -> void:
	var best := -1
	var best_d := INF
	var far := 0
	var far_d := -1.0
	for i in perches.size():
		var p := perches[i]
		var dt := Vector2(p.x - tp.x, p.z - tp.z).length()
		if dt > far_d:
			far_d = dt
			far = i
		if dt > scare + 3.0 and i != w.perch and not _taken(i, w):
			var dw := p.distance_to(w.pos)
			if dw < best_d:
				best_d = dw
				best = i
	_call(w)
	_take_off(w, perches[best if best >= 0 else far], best if best >= 0 else far)
	flushes += 1

func _taken(i: int, me: W) -> bool:
	for w: W in _birds:
		if w != me and (w.perch == i or w.to_perch == i):
			return true
	return false

func _take_off(w: W, to: Vector3, to_perch: int) -> void:
	w.state = FLIT
	w.from = w.pos
	w.to = to
	w.to_perch = to_perch
	w.fly_t = 0.0
	w.fly_dur = clampf(w.from.distance_to(to) / 6.5, 0.35, 4.0)
	flits += 1

func _perch(w: W, dt: float, wet: float, d: float, tp: Vector3) -> void:
	w.pos = perches[w.perch]
	w.vel = Vector3.ZERO
	w.fold = move_toward(w.fold, 1.0, dt * 6.0)
	w.legs = move_toward(w.legs, 1.0, dt * 6.0)
	w.flap = move_toward(w.flap, 0.0, dt * 8.0)
	# the bob: a quick dip and a flirt of the tail, every second or few
	w.bob = maxf(w.bob - dt * 4.0, 0.0)
	w.bob_t -= dt
	if w.bob_t < 0.0:
		w.bob_t = _rng.randf_range(0.8, 3.5) * (1.0 + wet * 2.0)
		w.bob = 1.0
		bobs += 1
	if d < WARN:
		# watching him: face him, chack now and then
		w.yaw = lerp_angle(w.yaw, atan2(-(tp.x - w.pos.x), -(tp.z - w.pos.z)), dt * 5.0)
		w.call_t -= dt
		if w.call_t < 0.0:
			w.call_t = _rng.randf_range(0.9, 2.2)
			_call(w)
	elif _rng.randf() < dt * 0.25:
		w.look = w.yaw + _rng.randf_range(-1.6, 1.6)
	if d >= WARN:
		w.yaw = lerp_angle(w.yaw, w.look, dt * 6.0)
	w.peck = 0.15 * sin(_t * 1.7 + w.look) - 0.1
	w.timer -= dt * (1.0 - wet * 0.8)      # sits tight in the rain
	if w.timer < 0.0:
		w.timer = _rng.randf_range(4.0, 12.0)
		if _rng.randf() < 0.55:
			# down into the turf after a grub, a couple of metres off the stone
			var a := _rng.randf() * TAU
			var q := w.pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.2, 3.2)
			q.y = terrain.height_at(q.x, q.z)
			_take_off(w, q, -1)
			drops += 1
		else:
			var j := _near_perch(w)
			if j >= 0:
				_take_off(w, perches[j], j)

## Another free stone within ~9 m (wheatears shift along the wall a few stones at a time).
func _near_perch(w: W) -> int:
	var c: Array[int] = []
	for i in perches.size():
		var dd := perches[i].distance_to(w.pos)
		if i != w.perch and dd > 1.0 and dd < 9.0 and not _taken(i, w):
			c.append(i)
	return c[_rng.randi() % c.size()] if not c.is_empty() else -1

func _ground(w: W, dt: float) -> void:
	w.fold = move_toward(w.fold, 1.0, dt * 6.0)
	w.legs = 1.0
	w.flap = move_toward(w.flap, 0.0, dt * 8.0)
	w.bob = maxf(w.bob - dt * 4.0, 0.0)
	w.hop_t -= dt
	if w.hop_t < 0.0:
		w.hop_t = _rng.randf_range(0.5, 1.6)
		var q := w.pos + Vector3(_rng.randfn(0.0, 0.35), 0, _rng.randfn(0.0, 0.35))
		w.hop_to = Vector3(q.x, terrain.height_at(q.x, q.z), q.z)
	var to := w.hop_to - w.pos
	to.y = 0.0
	var moving := to.length() > 0.02
	if moving:
		# quick bounding hops: wheatears run in spurts, then stand bolt upright
		w.yaw = lerp_angle(w.yaw, atan2(-to.x, -to.z), dt * 10.0)
		w.pos += to.normalized() * minf(to.length(), 1.1 * dt)
		w.pos.y = terrain.height_at(w.pos.x, w.pos.z) + absf(sin(_t * 14.0 + w.phase)) * 0.03
	var pk := clampf(1.0 - absf(w.hop_t - 0.25) * 5.0, 0.0, 1.0)
	w.peck = pk * 0.9 - (0.2 if not moving and pk <= 0.0 else 0.0)
	w.timer -= dt
	if w.timer < 0.0:
		w.timer = _rng.randf_range(4.0, 12.0)
		var j := _near_perch(w)
		if j < 0:
			j = w.perch
		_take_off(w, perches[j], j)

## Low and fast: a flat arc a few tens of cm over the turf, wings whirring, a closed-wing skip
## midway, rising onto the stone at the end.
func _fly(w: W, dt: float) -> void:
	w.fly_t += dt
	var f := clampf(w.fly_t / w.fly_dur, 0.0, 1.0)
	var e := f * f * (3.0 - 2.0 * f)
	var dist := Vector2(w.to.x - w.from.x, w.to.z - w.from.z).length()
	var lift := 0.25 + dist * 0.05
	var p := w.from.lerp(w.to, e)
	var floor_y := terrain.height_at(p.x, p.z)
	p.y = maxf(p.y + sin(f * PI) * lift, floor_y + 0.15 * sin(f * PI))
	var old := w.pos
	w.pos = p
	w.vel = (p - old) / maxf(dt, 0.001)
	if Vector2(w.vel.x, w.vel.z).length() > 0.3:
		w.yaw = atan2(-w.vel.x, -w.vel.z)
	w.fold = move_toward(w.fold, 0.0, dt * 14.0)
	w.legs = move_toward(w.legs, 1.0 if f > 0.8 or f < 0.1 else 0.0, dt * 8.0)
	w.peck = move_toward(w.peck, 0.0, dt * 4.0)
	var skip := f > 0.45 and f < 0.6 and dist > 4.0
	if skip:
		w.flap = move_toward(w.flap, -0.35, dt * 10.0)
	else:
		w.phase += 17.0 * TAU * dt
		w.flap = sin(w.phase) * 0.95 + 0.1
	if f >= 1.0:
		if w.to_perch >= 0:
			w.perch = w.to_perch
			w.state = PERCH
			w.timer = _rng.randf_range(4.0, 12.0)
			w.bob = 1.0
			w.look = w.yaw
		else:
			w.state = GROUND
			w.hop_to = w.pos
			w.hop_t = 0.3
			w.timer = _rng.randf_range(3.0, 9.0)
		w.to_perch = -1
		w.vel = Vector3.ZERO

func _call(w: W) -> void:
	chacks += 1
	w.voice.global_position = w.pos
	w.voice.stream = _calls[_rng.randi() % _calls.size()]
	w.voice.pitch_scale = _rng.randf_range(0.94, 1.06)
	w.voice.play()

func _write_all() -> void:
	for w: W in _birds:
		var pitch := 0.0
		if w.state == FLIT and w.vel.length() > 0.5:
			pitch = clampf(atan2(w.vel.y, Vector2(w.vel.x, w.vel.z).length()), -0.6, 0.7) * 0.5
		# the bob: body tips forward and the tail cocks up (pitch nose-down about the feet)
		pitch -= sin(w.bob * PI) * 0.45
		if w.state != FLIT:
			pitch += 0.22                # stands up tall on its legs
		var b := Basis(Vector3.UP, w.yaw) * Basis(Vector3.RIGHT, pitch) * Basis.from_scale(SHAPE * SCALE)
		w.mi.global_transform = Transform3D(b, w.pos)
		w.mi.set_instance_shader_parameter("pose", Vector4(w.flap, w.legs, w.peck, w.fold))

# ---------------------------------------------------------------- voice

## "weet-chack" / "chack-chack": hard clicks of two struck pebbles (decaying resonant noise bursts
## at ~3.4 and ~5.6 kHz), the first call led by a thin rising whistle.
func _make_chack(kind: int) -> AudioStreamWAV:
	const RATE := 22050
	var n := int(RATE * 0.42)
	var x := PackedFloat32Array()
	x.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 61 + kind
	var t0 := 0.0
	if kind == 0:
		# the whistle: 2.6 -> 3.5 kHz over 90 ms
		var ph := 0.0
		for i in int(RATE * 0.09):
			var t := float(i) / RATE
			ph += TAU * lerpf(2600.0, 3500.0, t / 0.09) / RATE
			x[i] += sin(ph) * 0.35 * sin(PI * t / 0.09)
		t0 = 0.13
	var clicks := 2 if kind != 2 else 3
	for c in clicks:
		var s0 := int((t0 + c * 0.11) * RATE)
		var y1 := 0.0
		var y2 := 0.0
		var z1 := 0.0
		var z2 := 0.0
		for i in int(RATE * 0.04):
			if s0 + i >= n:
				break
			var env := exp(-float(i) / (RATE * 0.006))
			var u := r.randf_range(-1.0, 1.0) * env
			# two two-pole resonators
			var a1 := 2.0 * 0.93 * cos(TAU * 3400.0 / RATE)
			var b1 := 2.0 * 0.9 * cos(TAU * 5600.0 / RATE)
			var o1 := u + a1 * y1 - 0.93 * 0.93 * y2
			y2 = y1
			y1 = o1
			var o2 := u + b1 * z1 - 0.81 * z2
			z2 = z1
			z1 = o2
			x[s0 + i] += o1 * 0.09 + o2 * 0.06 + u * 0.25
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
