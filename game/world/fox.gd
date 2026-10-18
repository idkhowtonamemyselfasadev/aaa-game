class_name Fox
extends Node3D
## A red fox that comes to Hesper's fire (owner's "campfires attract wildlife at night").
## Once her fire has been burning a while after dark (a jittered hour each night, ~21-22 h)
## it trots in out of the dark meadow, through the curtain gateway, creeps the last metres
## and sits just in through the keep's breach at the edge of the firelight, brush curled round its feet,
## watching the flames and looking round now and then, eyes shining back the fire. It slips
## away before dawn, when the fire burns low or rain comes on; a hero walking up on it makes
## it bolt back out into the dark, and it keeps away a while after.
## Procedural mesh (Herd's loft helpers), posed in fox.gdshader.
## When Hesper tosses it a crust it gets up, creeps to it, noses it and eats it head down,
## then goes back to its seat.
## Bots read `state`, `sit`, `visits`, `bolts`, `sit_at`, `den`, `eaten`.

signal barked(at: Vector3, alarm: bool)   # its night call from the dark, or a yelp as it bolts
signal crunched(at: Vector3)              # a bite into Hesper's crust

enum { AWAY, COME, SIT, GO, BOLT, EAT }

const TROT := 2.3          # m/s on its way in and out
const CREEP := 0.7         # m/s over the last few metres to its seat
const RUN := 6.5           # m/s bolting
const SHY_R := 9.0         # a hero this close (+1.5 m per m/s he moves) puts it to flight
const LEAVE_H := 4.6       # slips away before first light
const SNOUT := 0.40        # m from its middle to its nose (where it stands to eat)
const SNIFF := 1.2         # s nosing the crust before it takes it
const CHEW := 4.5          # s eating it
const PEEK := 1.6          # s from the crust landing to it getting up: looks at it, at her, at it
const SHAKE := 1.1         # s licking its chops and shaking its head once the crust is gone

var world: Node3D
var keeper: Keeper
var hearth: Hearth
var terrain: Terrain
var weather: Weather
var state := AWAY
var sit := 0.0             # 0 standing .. 1 sat (shader)
var speed := 0.0
var yaw := 0.0
var head_yaw := 0.0
var _head_goal := 0.0
var _look_t := 3.0
var _phase := 0.0
var path: Array[Vector3] = []
var sit_at := Vector3.ZERO
var den := Vector3.ZERO
var arrive_h := 21.4        # tonight's hour to come in (bots may set it)
var shy_t := 0.0            # s it keeps away after a scare
var visits := 0             # (bots)
var bolts := 0
var barks := 0
var _bark_t := 40.0         # s to its next call out in the dark
var _yelp_t := -1.0         # s to the alarm yelp once it has bolted
var _night := -1            # which night arrive_h was drawn for
var _prev_hero := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _mi: MeshInstance3D
var graze := 0.0            # 0 head up .. 1 nose on the ground (shader)
var eaten := 0              # crusts eaten (bots)
var _scrap: Node3D
var _eat_t := -1.0          # s with its nose at the crust (negative: still going to it)
var _bite_t := 0.0          # s to its next crunch
var _shake_t := -1.0        # s into its after-meal head shake (negative: not shaking)
var glance := 0.0           # how far round toward Hesper it looked before the crust (bots)
var shook := 0.0            # widest swing of its after-meal head shake (bots)
var licks := 0              # chops licked (bots)

func setup(w: Node3D) -> void:
	world = w
	keeper = w.get("keeper")
	hearth = w.get("hearth")
	weather = w.get("weather")
	terrain = w.get_node("Terrain")
	name = "Fox"
	_rng.seed = 9137
	w.add_child(self)
	var site := keeper.site
	var tv := keeper.to_v
	sit_at = _ground(seat_of(site))
	# its lying-up place out in the long grass, off to one side of the keep's gateway
	den = _ground(site + tv.rotated(Vector3.UP, 1.25) * 34.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fox.gdshader")
	_mi = MeshInstance3D.new()
	_mi.name = "Body"
	_mi.mesh = build_mesh()
	_mi.material_override = mat
	add_child(_mi)
	global_position = den
	visible = false

## Its seat: just in from the breach on the keep floor, at the edge of the light, swung off
## the breach line away from Hesper's way in to the lid so it sits on open floor (in the
## breach mouth at 2.8 m its legs and the crust hid behind the rubble slabs). Ruins sweeps
## the floor clear round it and out to where the crust lands (`seat_sweep`).
static func seat_of(site: Vector3) -> Vector3:
	var tv := Vector3(-site.x, 0, -site.z).normalized()
	return site + tv.rotated(Vector3.UP, 0.42) * 2.3

## [seat, crust] for Ruins' sweep: the crust lands ~0.7 m toward the fire, it stands a
## snout's length back from it to eat.
static func seat_sweep(site: Vector3) -> Array[Vector3]:
	var s := seat_of(site)
	var hp: Vector3 = Keeper.hearth_layout(site)[0]
	var f := Vector3(hp.x - s.x, 0, hp.z - s.z).normalized()
	return [s, s + f * 0.8, lens_of(site)]

## Where the `fox` shot looks from: on the keep floor ring (r 2.4) swung ~1.7 m round from
## the seat away from the breach and Hesper's way in, so it sees the fox three-quarter with
## the fire across the floor (a lens 1.5 m back toward the fire stood on the plinth).
static func lens_of(site: Vector3) -> Vector3:
	var tv := Vector3(-site.x, 0, -site.z).normalized()
	return site + tv.rotated(Vector3.UP, 0.42 + 0.72) * 2.4

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)

func _hour() -> float:
	return world.time_of_day

## Its way in: out of the grass round to the gateway, through the yard to the breach.
func _way_in() -> Array[Vector3]:
	var site := keeper.site
	var tv := keeper.to_v
	return [_ground(site + tv.rotated(Vector3.UP, 0.55) * 17.5), _ground(keeper._spots["gate_out"][0]),
		_ground(keeper._spots["gate_in"][0]), _ground(keeper._spots["breach_out"][0]), sit_at]

func _way_out() -> Array[Vector3]:
	var w := _way_in()
	w.reverse()
	w.remove_at(0)
	w.append(den)
	return w

## Is it fox time: well after dark, before first light, the fire going, no rain.
func _wanted(h: float) -> bool:
	var n := int(floor((h + 12.0) / 24.0))   # one draw per night (noon to noon)
	if n != _night:
		_night = n
		if visits > 0 or bolts > 0:
			arrive_h = 20.9 + _rng.randf() * 1.3
	var night := h >= arrive_h or h < LEAVE_H
	var rain := weather.rain if weather != null else 0.0
	return night and hearth.level > 0.2 and rain < 0.3

## Shots: sat in its place by the fire.
func place_sitting() -> void:
	state = SIT
	sit = 1.0
	speed = 0.0
	global_position = sit_at
	yaw = _face_fire()
	visible = true

func _face_fire() -> float:
	var to := hearth.global_position - sit_at
	return atan2(-to.x, -to.z)

func _process(delta: float) -> void:
	if world == null:
		return
	var dt := minf(delta, 0.1)
	var h := _hour()
	var hero := world.get_node_or_null("Player") as Node3D
	var hp := hero.global_position if hero else Vector3(1e6, 0, 1e6)
	var hs := Vector2(hp.x - _prev_hero.x, hp.z - _prev_hero.z).length() / maxf(dt, 0.001)
	_prev_hero = hp
	if hs > 25.0:
		hs = 0.0                                 # a teleport, not a charge
	var near := Vector2(hp.x - global_position.x, hp.z - global_position.z).length()
	var shy := visible and near < SHY_R + 1.5 * minf(hs, 8.0)
	shy_t = maxf(shy_t - dt, 0.0)
	_call(dt, h)
	match state:
		AWAY:
			visible = false
			sit = 0.0
			var hero_at_seat := Vector2(hp.x - sit_at.x, hp.z - sit_at.z).length() < SHY_R + 6.0
			if shy_t <= 0.0 and _wanted(h) and not hero_at_seat:
				state = COME
				global_position = den
				path = _way_in()
				visible = true
				visits += 1
		COME:
			if shy:
				_bolt()
			elif not _wanted(h):
				_leave()
			elif _walk(dt, TROT if path.size() > 1 else CREEP):
				state = SIT
				_look_t = _rng.randf_range(3.0, 6.0)
		SIT:
			speed = move_toward(speed, 0.0, 3.0 * dt)
			sit = move_toward(sit, 1.0, dt / 1.1)
			yaw = lerp_angle(yaw, _face_fire(), 2.0 * dt)
			_look_t -= dt
			if _look_t < 0.0:
				# mostly into the fire; now and then a look round into the dark, or at her
				var r := _rng.randf()
				_head_goal = 0.0 if r < 0.5 else _rng.randf_range(-0.9, 0.9)
				_look_t = _rng.randf_range(2.5, 7.0) if _head_goal == 0.0 else _rng.randf_range(1.2, 3.0)
			if shy:
				_bolt()
			elif not _wanted(h):
				_leave()
		EAT:
			_update_eat(dt)
			if shy:
				_bolt()
			elif not _wanted(h):
				_leave()
		GO, BOLT:
			sit = move_toward(sit, 0.0, dt / (0.25 if state == BOLT else 0.9))
			if sit < 0.3 and _walk(dt, RUN if state == BOLT else TROT):
				state = AWAY
				visible = false
	if state == COME or state == GO or state == BOLT:
		_head_goal = 0.0
		if state == COME and path.size() <= 1:
			_head_goal = 0.0
	if state == BOLT and hero:
		# a glance back over its shoulder as it goes
		var to := Vector3(hp.x - global_position.x, 0, hp.z - global_position.z)
		_head_goal = clampf(wrapf(atan2(-to.x, -to.z) - yaw, -PI, PI), -0.7, 0.7) * 0.6
	if state != EAT:
		graze = move_toward(graze, 0.0, dt / 0.5)
	head_yaw = lerpf(head_yaw, _head_goal, 1.0 - exp(-3.0 * dt))
	_phase = fposmod(_phase + dt * (speed / 0.95 if speed < 3.0 else speed / 1.6), 1.0)
	global_rotation = Vector3(0, yaw, 0)
	_mi.set_instance_shader_parameter("phase", _phase)
	_mi.set_instance_shader_parameter("speed", speed)
	_mi.set_instance_shader_parameter("sit", sit)
	_mi.set_instance_shader_parameter("head_yaw", head_yaw)
	_mi.set_instance_shader_parameter("graze", graze)
	var fire := hearth.level if hearth else 0.0
	_mi.set_instance_shader_parameter("eyeshine", fire * smoothstep(9.0, 3.0, global_position.distance_to(hearth.global_position)))

## Its voice. Out in the dark grass at night (not sat by the fire, not in rain) it barks
## now and then from round its den, a run of hoarse yaps; a bolting fox gives one sharp
## yelp a moment after it breaks away.
func _call(dt: float, h: float) -> void:
	if _yelp_t >= 0.0:
		_yelp_t -= dt
		if _yelp_t < 0.0:
			barks += 1
			barked.emit(global_position + Vector3.UP * 0.5, true)
	var dark := h >= 20.5 or h < 5.0
	var rain := weather.rain if weather != null else 0.0
	if not dark or rain > 0.3 or state == SIT or state == BOLT or state == EAT:
		return
	_bark_t -= dt
	if _bark_t <= 0.0:
		_bark_t = _rng.randf_range(70.0, 260.0)
		var at := global_position if visible else den + Vector3(_rng.randf_range(-12.0, 12.0), 0.0, _rng.randf_range(-12.0, 12.0))
		barks += 1
		barked.emit(_ground(at) + Vector3.UP * 0.5, false)

## Hesper's crust has landed near it: up off its haunches and over to it.
func take_scrap(scrap: Node3D) -> void:
	_drop_scrap()
	_scrap = scrap
	state = EAT
	_eat_t = -1.0
	_shake_t = -1.0
	_bite_t = 0.0
	var to := Vector3(scrap.global_position.x - global_position.x, 0, scrap.global_position.z - global_position.z)
	var stand := scrap.global_position - to.normalized() * SNOUT if to.length() > SNOUT else global_position
	path = [_ground(stand)]
	_head_goal = 0.0
	_look_t = PEEK              # a look at it where it fell, a wary glance up at her, then it gets up
	glance = 0.0

## Shots: stood head down at a crust in front of its seat, part way through eating it.
func place_eating() -> void:
	place_sitting()
	var to_fire := Vector3(hearth.global_position.x - sit_at.x, 0, hearth.global_position.z - sit_at.z).normalized()
	var c := Keeper.crust()
	world.add_child(c)
	c.global_position = _ground(sit_at + to_fire * 0.7) + Vector3.UP * 0.018
	c.rotation.y = 0.7
	take_scrap(c)
	sit = 0.0
	_look_t = 0.0
	global_position = _ground(c.global_position - to_fire * SNOUT)
	path.clear()
	_eat_t = SNIFF - 0.8
	graze = 1.0

func _drop_scrap() -> void:
	if _scrap != null:
		_scrap.queue_free()
	_scrap = null

func _update_eat(dt: float) -> void:
	if _scrap == null:
		state = COME
		path = [sit_at]
		return
	var to := _scrap.global_position - global_position
	var want_yaw := atan2(-to.x, -to.z)
	if _look_t > 0.0:
		_look_t -= dt
		_head_goal = clampf(wrapf(want_yaw - yaw, -PI, PI), -0.8, 0.8)
		# between the two looks at the crust, a glance up at the hand that threw it
		if keeper != null and _look_t < PEEK - 0.45 and _look_t > 0.45:
			var tk := keeper.global_position - global_position
			var at_her := wrapf(atan2(-tk.x, -tk.z) - yaw, -PI, PI)
			_head_goal = clampf(at_her, -1.0, 1.0)
			glance = maxf(glance, absf(head_yaw) * signf(head_yaw * at_her))
		return
	if _shake_t >= 0.0:
		_after_meal(dt)
		return
	if _eat_t < 0.0:
		sit = move_toward(sit, 0.0, dt / 0.5)
		if sit < 0.3 and _walk(dt, CREEP):
			_eat_t = 0.0
		return
	speed = move_toward(speed, 0.0, 3.0 * dt)
	yaw = lerp_angle(yaw, want_yaw, 3.0 * dt)
	_head_goal = 0.0
	_eat_t += dt
	# nose down to it, a sniff, then the head working as it chews and swallows
	var chew := 0.0 if _eat_t < SNIFF else 0.06 * (1.0 + sin(_eat_t * 14.0)) * smoothstep(SNIFF, SNIFF + 0.3, _eat_t)
	var lift := smoothstep(SNIFF + CHEW - 0.8, SNIFF + CHEW, _eat_t)
	graze = move_toward(graze, (1.0 - chew) * (1.0 - lift * 0.7), dt / 0.35)
	var left := 1.0 - smoothstep(SNIFF + 0.4, SNIFF + CHEW - 0.6, _eat_t)
	_scrap.scale = Vector3.ONE * maxf(left, 0.05)
	if _eat_t > SNIFF + 0.3 and _eat_t < SNIFF + CHEW - 0.9:
		_bite_t -= dt
		if _bite_t <= 0.0:
			_bite_t = _rng.randf_range(0.35, 0.8)
			crunched.emit(_scrap.global_position + Vector3.UP * 0.12)
	if _eat_t >= SNIFF + CHEW:
		_scrap.visible = false
		eaten += 1
		_shake_t = 0.0
		shook = 0.0
		licks = 0

## The crust gone: two licks round its chops (a dip and lift of the muzzle), then a quick
## shake of the head side to side, dying away, before it goes back to its seat.
func _after_meal(dt: float) -> void:
	var t0 := _shake_t
	_shake_t += dt
	var t := _shake_t
	speed = move_toward(speed, 0.0, 3.0 * dt)
	# licks: the muzzle bobs down and up twice over the first half second
	var lick := 0.0
	if t < 0.55:
		lick = 0.22 * maxf(sin(t / 0.55 * TAU * 2.0 - PI * 0.5) * 0.5 + 0.5, 0.0)
		for c in [0.14, 0.41]:
			if t0 < c and t >= c:
				licks += 1
	graze = move_toward(graze, 0.3 * (1.0 - smoothstep(0.4, 0.9, t)) + lick, dt / 0.12)
	# the shake: ~5 Hz, set straight on the head (too quick for the head's lag)
	var s := 0.0
	if t > 0.5:
		var u := t - 0.5
		s = 0.55 * sin(u * TAU * 5.0) * exp(-u * 4.0)
	_head_goal = s
	head_yaw = s
	shook = maxf(shook, absf(s))
	if t >= SHAKE:
		_shake_t = -1.0
		_head_goal = 0.0
		_drop_scrap()
		state = COME
		path = [sit_at]

func _bolt() -> void:
	_drop_scrap()
	state = BOLT
	bolts += 1
	_yelp_t = _rng.randf_range(0.6, 1.2)
	shy_t = 150.0
	path = _way_out() if global_position.distance_to(sit_at) < 9.0 else _to_den()
	_trim_path()

func _leave() -> void:
	_drop_scrap()
	state = GO
	path = _way_out() if global_position.distance_to(sit_at) < 9.0 else _to_den()
	_trim_path()

func _to_den() -> Array[Vector3]:
	return [den]

## Drop the way's points it has already passed on its way in (nearer the den than it is).
func _trim_path() -> void:
	while path.size() > 1 and path[0].distance_to(global_position) > path[1].distance_to(global_position) \
			and global_position.distance_to(den) > path[0].distance_to(den):
		path.remove_at(0)

## Trots along `path`; true once it has reached the end.
func _walk(dt: float, top: float) -> bool:
	if path.is_empty():
		return true
	var to := Vector3(path[0].x - global_position.x, 0, path[0].z - global_position.z)
	var d := to.length()
	var last := path.size() == 1
	var want := top
	if last and (state == COME or state == EAT):
		want = minf(top, maxf(d * 0.9, 0.12))       # creeps to a halt on its seat
	speed = move_toward(speed, want, (9.0 if state == BOLT else 2.5) * dt)
	if d < maxf(0.25, speed * dt * 1.5):
		path.remove_at(0)
		return path.is_empty()
	var want_yaw := atan2(-to.x, -to.z)
	yaw += clampf(wrapf(want_yaw - yaw, -PI, PI), -5.0 * dt, 5.0 * dt)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var p := global_position + fwd * minf(speed * dt, d)
	global_position = _ground(p)
	return false

# ---------------------------------------------------------------- mesh

## A red fox about 0.38 m at the shoulder, 0.56 m nose to rump with a 0.4 m brush, facing
## -Z, paws at y = 0. COLOR as the deer: r leg (0.25 LF, 0.5 RF, 0.75 LH, 1 RH), g below the
## wrist/hock, b neck/head bend weight, a part (0 coat, 0.5 eye, 0.75 brush, 1 ear).
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body + neck: rump round to the throat (z, y, half-width, half-height above, below, bend)
	var body := [
		[0.335, 0.37, 0.01, 0.01, 0.01, 0.0],
		[0.31, 0.375, 0.065, 0.055, 0.075, 0.0],
		[0.24, 0.38, 0.088, 0.065, 0.095, 0.0],
		[0.11, 0.375, 0.085, 0.06, 0.075, 0.0],
		[-0.03, 0.375, 0.09, 0.065, 0.095, 0.0],
		[-0.15, 0.385, 0.09, 0.07, 0.12, 0.0],
		[-0.24, 0.405, 0.078, 0.075, 0.115, 0.15],
		[-0.30, 0.45, 0.064, 0.062, 0.085, 0.45],
		[-0.335, 0.50, 0.055, 0.052, 0.068, 0.75],
		[-0.35, 0.53, 0.045, 0.04, 0.05, 1.0],
	]
	Herd._loft(st, body, 0.0, 24, 3, 0.0, 0.0)
	# head: broad cheeks tapering to a long narrow muzzle
	var head := [
		[-0.315, 0.56, 0.01, 0.01, 0.01, 1.0],
		[-0.335, 0.56, 0.06, 0.05, 0.056, 1.0],
		[-0.372, 0.55, 0.074, 0.048, 0.064, 1.0],
		[-0.415, 0.537, 0.046, 0.036, 0.04, 1.0],
		[-0.46, 0.524, 0.025, 0.023, 0.026, 1.0],
		[-0.505, 0.512, 0.016, 0.015, 0.017, 1.0],
		[-0.54, 0.505, 0.011, 0.011, 0.012, 1.0],
		[-0.555, 0.503, 0.002, 0.002, 0.002, 1.0],
	]
	Herd._loft(st, head, 0.0, 16, 3, 0.0, 0.0)
	for s in [-1.0, 1.0]:
		# ears: tall pointed triangles, upright and a little out (z, y, hw, thick, thick, bend, x)
		var ear := [
			[-0.345, 0.585, 0.014, 0.01, 0.01, 1.0, 0.03],
			[-0.348, 0.605, 0.03, 0.008, 0.008, 1.0, 0.036],
			[-0.352, 0.64, 0.022, 0.006, 0.006, 1.0, 0.043],
			[-0.355, 0.672, 0.003, 0.003, 0.003, 1.0, 0.05],
		]
		Herd._loft(st, ear, s, 10, 2, 0.0, 1.0)
		Herd._sphere(st, Vector3(0.033 * s, 0.566, -0.402), 0.012, 1.0, 0.5)
		# legs: (x, y, z, half-width, half-depth front, half-depth back)
		var fore := [
			[0.045, 0.40, -0.165, 0.038, 0.05, 0.05],
			[0.05, 0.31, -0.18, 0.026, 0.034, 0.032],
			[0.05, 0.21, -0.185, 0.017, 0.02, 0.019],
			[0.05, 0.12, -0.19, 0.014, 0.016, 0.015],
			[0.05, 0.045, -0.195, 0.014, 0.017, 0.015],
			[0.05, 0.014, -0.21, 0.019, 0.028, 0.016],
			[0.05, -0.003, -0.218, 0.003, 0.003, 0.003],
		]
		var hind := [
			[0.05, 0.39, 0.22, 0.05, 0.07, 0.06],
			[0.06, 0.29, 0.195, 0.038, 0.05, 0.048],
			[0.06, 0.21, 0.225, 0.022, 0.024, 0.028],
			[0.055, 0.125, 0.268, 0.015, 0.017, 0.019],
			[0.05, 0.05, 0.258, 0.014, 0.017, 0.015],
			[0.05, 0.014, 0.245, 0.019, 0.028, 0.016],
			[0.05, -0.003, 0.238, 0.003, 0.003, 0.003],
		]
		Herd._leg(st, fore, s, 0.25 if s > 0 else 0.5, 0.12)
		Herd._leg(st, hind, s, 0.75 if s > 0 else 1.0, 0.125)
	# the brush: thick, carried low and straight out behind
	var tail := [
		[0.30, 0.385, 0.012, 0.012, 0.012, 0.0],
		[0.345, 0.38, 0.034, 0.034, 0.034, 0.0],
		[0.42, 0.35, 0.064, 0.062, 0.064, 0.0],
		[0.52, 0.30, 0.072, 0.068, 0.07, 0.0],
		[0.62, 0.25, 0.06, 0.058, 0.058, 0.0],
		[0.69, 0.22, 0.032, 0.03, 0.03, 0.0],
		[0.71, 0.212, 0.003, 0.003, 0.003, 0.0],
	]
	Herd._loft(st, tail, 0.0, 14, 3, 0.0, 0.75)
	st.generate_tangents()
	return st.commit()
