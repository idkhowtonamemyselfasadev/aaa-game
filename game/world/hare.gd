class_name Hare
extends Node3D
## A brown hare in the south-east meadow either side of Wat's road in (owner's "animals
## crossing the road", "herds that graze and flee"). It feeds crouched in the grass, nose
## down, now and then lifting its head to look round, and moves on in short lazy hops. Every
## few minutes by day it lopes off across the road to its feeding ground on the other side.
## A hero coming into sight makes it sit up on its haunches, ears straight up, watching him;
## come close, or run at it, and it is off flat out with its ears laid back, jinking left and
## right, and settles to feed again far off. In rain it squats in its form, ears flat.
## Procedural mesh (Herd's loft helpers), posed in hare.gdshader. Bots read `state`,
## `crossings`, `bolts`, `jinks`, `alert`, `side()`.

enum { FEED, HOP, CROSS, ALERT, BOLT, FORM }

const HOP_SPEED := 1.3     # m/s, the lazy hop between feeding spots
const LOPE := 3.4          # m/s crossing the road
const RUN := 11.0          # m/s bolting
const SEE_R := 30.0        # a hero this close (+1 m per m/s he moves) sits it up
const SHY_R := 11.0        # and this close (+1.5 m per m/s) puts it to flight
const RANGE := 9.0         # m round its feeding spot it hops about in
const BOLT_DIST := 55.0    # m it runs before it slows and settles
## The road in, as Pedlar.ROAD_IN's first leg (world x, z): its feeding grounds lie either side.
const ROAD_A := Vector2(44.0, -58.0)
const ROAD_B := Vector2(14.0, -20.0)

var world: Node3D
var terrain: Terrain
var weather: Weather
var state := FEED
var speed := 0.0
var yaw := 0.0
var alert := 0.0            # 0 crouched .. 1 sat up (shader)
var graze := 0.0            # 0 head up .. 1 nose in the grass (shader)
var ears_back := 0.0        # 0 up .. 1 laid flat along the back (shader)
var home := Vector3.ZERO    # the feeding spot it hops about
var target := Vector3.ZERO
var crossings := 0          # (bots)
var bolts := 0
var jinks := 0
var cross_t := 120.0        # s to its next run across the road (bots may set it)
var hold := false           # shots: held in its pose
var _phase := 0.0
var _t := 3.0
var _run_left := 0.0
var _flee_dir := Vector3.FORWARD
var _jink_t := 0.0
var _prev_hero := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial

## `along` (0..1 down the road from ROAD_A) and `off` (m to the road's right, + or -) place it.
func setup(w: Node3D, along: float, off: float, sd: int) -> void:
	world = w
	terrain = w.get_node("Terrain")
	weather = w.get("weather")
	_rng.seed = sd
	w.add_child(self)
	home = _ground(_road_point(along, off))
	global_position = home
	yaw = _rng.randf_range(-PI, PI)
	cross_t = _rng.randf_range(60.0, 200.0)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/hare.gdshader")
	# three fur shells over the skin (hare_shell.gdshader) so the coat reads as fur
	var shell_sh: Shader = load("res://shaders/hare_shell.gdshader")
	var prev: Material = _mat
	for h in [0.34, 0.67, 1.0]:
		var sm := ShaderMaterial.new()
		sm.shader = shell_sh
		sm.set_shader_parameter("shell_h", h)
		prev.next_pass = sm
		prev = sm
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = build_mesh()
	mi.material_override = _mat
	add_child(mi)

func _road_point(along: float, off: float) -> Vector3:
	var p := ROAD_A.lerp(ROAD_B, along)
	var d := (ROAD_B - ROAD_A).normalized()
	p += Vector2(-d.y, d.x) * off
	return Vector3(p.x, 0, p.y)

## Which side of the road it is on (+1 / -1), and how far along it (0..1).
func side() -> float:
	var d := ROAD_B - ROAD_A
	var q := Vector2(global_position.x, global_position.z) - ROAD_A
	return signf(d.x * q.y - d.y * q.x)

func _along() -> float:
	var d := ROAD_B - ROAD_A
	var q := Vector2(global_position.x, global_position.z) - ROAD_A
	return clampf(q.dot(d) / d.length_squared(), -0.3, 1.3)

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)

func _process(delta: float) -> void:
	if world == null or hold:
		_pose(0.0)
		return
	var dt := minf(delta, 0.1)
	var hero := world.get_node_or_null("Player") as Node3D
	var hp := hero.global_position if hero else Vector3(1e6, 0, 1e6)
	var hs := Vector2(hp.x - _prev_hero.x, hp.z - _prev_hero.z).length() / maxf(dt, 0.001)
	_prev_hero = hp
	if hs > 25.0:
		hs = 0.0                                 # a teleport, not a charge
	var to_hero := Vector3(hp.x - global_position.x, 0, hp.z - global_position.z)
	var near := to_hero.length()
	var seen := near < SEE_R + minf(hs, 8.0)
	var shy := near < SHY_R + 1.5 * minf(hs, 8.0)
	var rain: float = weather.rain if weather else 0.0
	var h: float = world.time_of_day
	var day := h > 5.5 and h < 20.5
	_t -= dt
	cross_t -= dt
	if shy and state != BOLT:
		_bolt(to_hero)
	match state:
		FEED, HOP, FORM:
			if seen and state != FORM:
				state = ALERT
				_t = _rng.randf_range(2.0, 4.0)
			elif rain > 0.5:
				state = FORM
			elif state == FORM:
				state = FEED
				_t = 2.0
			elif state == FEED:
				speed = move_toward(speed, 0.0, 6.0 * dt)
				if _t <= 0.0:
					if day and cross_t <= 0.0:
						_cross()
					else:
						state = HOP
						var a := _rng.randf_range(-PI, PI)
						var r := _rng.randf_range(0.6, 2.2)
						target = global_position + Vector3(cos(a), 0, sin(a)) * r
						if Vector2(target.x - home.x, target.z - home.z).length() > RANGE:
							target = global_position + (home - global_position).normalized() * r
			else:
				if _walk_to(target, HOP_SPEED, dt):
					state = FEED
					_t = _rng.randf_range(4.0, 11.0)
		CROSS:
			if seen:
				state = ALERT
				_t = _rng.randf_range(2.0, 4.0)
			elif _walk_to(target, LOPE, dt):
				crossings += 1
				home = target
				state = FEED
				_t = _rng.randf_range(3.0, 6.0)
				cross_t = _rng.randf_range(150.0, 320.0)
		ALERT:
			speed = move_toward(speed, 0.0, 8.0 * dt)
			yaw = lerp_angle(yaw, atan2(-to_hero.x, -to_hero.z), 3.0 * dt)
			if seen:
				_t = maxf(_t, 1.5)               # watches as long as he is in sight
			elif _t <= 0.0:
				state = FEED
				_t = _rng.randf_range(2.0, 5.0)
		BOLT:
			_jink_t -= dt
			if _jink_t <= 0.0 and _run_left > 8.0:
				# a jink: a sharp swerve off the line, then back the other way next time
				var sgn := 1.0 if jinks % 2 == 0 else -1.0
				_flee_dir = _flee_dir.rotated(Vector3.UP, sgn * _rng.randf_range(0.45, 0.8))
				var away := -to_hero.normalized() if near > 0.1 else _flee_dir
				_flee_dir = (_flee_dir + away * 0.6).normalized()
				jinks += 1
				_jink_t = _rng.randf_range(0.5, 0.9)
			var top := RUN if _run_left > 12.0 else lerpf(LOPE, RUN, _run_left / 12.0)
			speed = move_toward(speed, top, 14.0 * dt)
			yaw = lerp_angle(yaw, atan2(-_flee_dir.x, -_flee_dir.z), 9.0 * dt)
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			global_position = _ground(global_position + fwd * speed * dt)
			_run_left -= speed * dt
			if _run_left <= 0.0:
				home = global_position
				state = FEED
				_t = _rng.randf_range(3.0, 6.0)
	_pose(dt)

func _bolt(to_hero: Vector3) -> void:
	state = BOLT
	bolts += 1
	_run_left = BOLT_DIST
	_flee_dir = -to_hero.normalized() if to_hero.length() > 0.1 else Vector3(-sin(yaw), 0, -cos(yaw))
	_jink_t = _rng.randf_range(0.3, 0.6)

func _cross() -> void:
	state = CROSS
	var al := clampf(_along() + _rng.randf_range(-0.15, 0.15), 0.1, 0.9)
	target = _ground(_road_point(al, -side() * _rng.randf_range(9.0, 16.0)))

## Moves toward `p` at `top`; true once there.
func _walk_to(p: Vector3, top: float, dt: float) -> bool:
	var to := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	var d := to.length()
	if d < maxf(0.15, speed * dt * 1.5):
		return true
	speed = move_toward(speed, minf(top, d * 2.0 + 0.4), 6.0 * dt)
	yaw = lerp_angle(yaw, atan2(-to.x, -to.z), 6.0 * dt)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	global_position = _ground(global_position + fwd * minf(speed * dt, d))
	return false

func _pose(dt: float) -> void:
	var feeding := state == FEED
	var g_goal := 0.0
	if feeding:
		# nose down most of the time, head up to chew and look round every few seconds
		g_goal = 1.0 if fmod(_t, 4.0) > 1.2 else 0.0
	graze = move_toward(graze, g_goal, 3.0 * dt)
	alert = move_toward(alert, 1.0 if state == ALERT else 0.0, 3.5 * dt)
	var eb := 0.0
	if state == BOLT:
		eb = 0.85
	elif state == FORM:
		eb = 1.0
	elif state == CROSS:
		eb = 0.35
	ears_back = move_toward(ears_back, eb, 4.0 * dt)
	# one stride per ~0.55 m at a lope, ~1.1 m flat out (the long bound)
	_phase = fmod(_phase + speed * dt / lerpf(0.45, 1.15, clampf((speed - 2.0) / 8.0, 0.0, 1.0)), 1.0)
	rotation = Vector3(0, yaw, 0)
	if _mat:
		var mi := get_node("Body") as MeshInstance3D
		mi.set_instance_shader_parameter("phase", _phase)
		mi.set_instance_shader_parameter("speed", speed)
		mi.set_instance_shader_parameter("alert", alert)
		mi.set_instance_shader_parameter("graze", graze)
		mi.set_instance_shader_parameter("ears_back", ears_back)
		mi.set_instance_shader_parameter("crouch", 1.0 if state == FORM else 0.0)

## Shots: put it in a pose and hold it there.
func place(p: Vector3, face: float, st: int) -> void:
	global_position = _ground(p)
	yaw = face
	state = st
	speed = 0.0
	alert = 1.0 if st == ALERT else 0.0
	graze = 1.0 if st == FEED else 0.0
	ears_back = 1.0 if st == FORM else 0.0
	_t = 3.0
	_pose(0.0)
	hold = true

# ---------------------------------------------------------------- mesh

## A brown hare about 0.58 m nose to scut, crouched feeding pose, facing -Z, feet at y = 0.
## COLOR as the fox: r leg (0.25 LF, 0.5 RF, 0.75 LH, 1 RH), g below the knee/hock, b neck/head
## bend weight, a part (0 coat, 0.5 eye, 0.75 scut, 1 ear).
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body: the high round haunches falling to low shoulders, and the neck up to the head
	var body := [
		[0.255, 0.205, 0.01, 0.01, 0.01, 0.0],
		[0.24, 0.21, 0.058, 0.058, 0.065, 0.0],
		[0.18, 0.222, 0.088, 0.085, 0.095, 0.0],
		[0.09, 0.212, 0.084, 0.078, 0.085, 0.0],
		[0.0, 0.196, 0.074, 0.068, 0.075, 0.0],
		[-0.08, 0.188, 0.066, 0.062, 0.078, 0.1],
		[-0.14, 0.198, 0.056, 0.056, 0.066, 0.45],
		[-0.175, 0.22, 0.046, 0.046, 0.054, 0.85],
		[-0.19, 0.238, 0.036, 0.036, 0.04, 1.0],
	]
	Herd._loft(st, body, 0.0, 32, 5, 0.0, 0.0, 3)
	# head: a short blunt head with a deep rounded muzzle
	var head := [
		[-0.165, 0.258, 0.01, 0.01, 0.01, 1.0],
		[-0.18, 0.262, 0.038, 0.04, 0.04, 1.0],
		[-0.215, 0.262, 0.043, 0.044, 0.046, 1.0],
		[-0.25, 0.252, 0.037, 0.036, 0.04, 1.0],
		[-0.28, 0.24, 0.027, 0.026, 0.03, 1.0],
		[-0.302, 0.231, 0.016, 0.016, 0.018, 1.0],
		[-0.312, 0.227, 0.003, 0.003, 0.003, 1.0],
	]
	Herd._loft(st, head, 0.0, 28, 5, 0.0, 0.0, 3)
	for s in [-1.0, 1.0]:
		# ears: long, a little cupped, laid back a touch from upright (z, y, hw, thick, thick, bend, x)
		var ear := [
			[-0.2, 0.288, 0.011, 0.009, 0.009, 1.0, 0.017],
			[-0.196, 0.312, 0.021, 0.007, 0.007, 1.0, 0.021],
			[-0.186, 0.352, 0.024, 0.006, 0.006, 1.0, 0.027],
			[-0.174, 0.39, 0.017, 0.005, 0.005, 1.0, 0.031],
			[-0.168, 0.405, 0.003, 0.003, 0.003, 1.0, 0.032],
		]
		Herd._loft(st, ear, s, 10, 3, 0.0, 1.0)
		# big eyes set high on the sides of the head
		Herd._sphere(st, Vector3(0.034 * s, 0.272, -0.228), 0.012, 1.0, 0.5)
		# legs: (x, y, z, half-width, half-depth front, half-depth back)
		var fore := [
			[0.035, 0.17, -0.095, 0.026, 0.032, 0.03],
			[0.036, 0.11, -0.105, 0.016, 0.02, 0.018],
			[0.035, 0.05, -0.11, 0.012, 0.014, 0.013],
			[0.035, 0.012, -0.125, 0.014, 0.024, 0.012],
			[0.035, -0.002, -0.135, 0.003, 0.003, 0.003],
		]
		# the hind leg folded under the haunch: thigh forward-down to the stifle, shank back to
		# the hock, and the long hind foot flat along the ground forward to the toes
		var hind := [
			[0.055, 0.2, 0.17, 0.048, 0.06, 0.06],
			[0.062, 0.12, 0.12, 0.034, 0.04, 0.04],
			[0.06, 0.07, 0.17, 0.022, 0.024, 0.026],
			[0.058, 0.03, 0.225, 0.016, 0.018, 0.02],
			[0.055, 0.016, 0.15, 0.017, 0.012, 0.012],
			[0.052, 0.012, 0.07, 0.016, 0.01, 0.01],
			[0.05, 0.008, 0.045, 0.003, 0.003, 0.003],
		]
		Herd._leg(st, fore, s, 0.25 if s > 0 else 0.5, 0.08, 12, 4)
		Herd._leg(st, hind, s, 0.75 if s > 0 else 1.0, 0.11, 12, 4)
	# the scut: a short round tail tucked up against the rump
	Herd._sphere(st, Vector3(0.0, 0.225, 0.252), 0.03, 0.0, 0.75)
	st.generate_tangents()
	return st.commit()
