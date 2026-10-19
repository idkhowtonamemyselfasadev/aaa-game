class_name Bat
extends Node3D
## A pipistrelle that hawks the moths round the lantern on the green. Once the candle is
## burning and the dusk has thickened it comes in out of the dark, beats a fast jinking
## circuit round the light a few metres out, and every few seconds picks a moth off the
## loop and stoops at it: a snap of the wings, and either the moth is gone or it has dropped
## out of the way (moths hear the bat and power-dive, `Moths.dodge`) and the bat overshoots
## and swings back round. Rain and strong wind send it off; it leaves before first light.
## By day it hangs head down under the white cottage's woodshed boards (`roost_at`, wings
## wrapped, swaying a little, now and then a stretch and a shiver of the wings); at dusk it
## lets go, drops, opens its wings and flies out of the open end to the light, and at first
## light (or when rain drives it in) it flies back in under the eaves, swings up and hangs.
## Membrane wings with finger bones, flap and fold: bat.gdshader. It is heard as well as
## seen: on its loop a thin, high trill of social chirps every few seconds, a rattle of
## clicks closing into a buzz as it stoops on a moth, and a scratchy grumble at the roost
## when it stretches (`chirped`, voiced by Foley).

signal chirped(at: Vector3, kind: int)   # CALL in flight, BUZZ on a stoop, GRUMBLE at the roost

enum { AWAY, IN, PATROL, CHASE, OUT, ROOST, DROP, HOME }

const HALF_SPAN := 0.12         # m: ~24 cm wingspan
const FAR := 14.0               # where it comes in from / goes back to
const LOOP_R := Vector2(1.4, 3.6)    # horizontal patrol radius round the lantern
const LOOP_Y := Vector2(-1.1, 2.2)   # patrol height relative to the lantern
const KEEP_OFF := 0.38          # never closer than this to the lantern body
const SPEED := 4.6              # m/s on patrol
const CHASE_SPEED := 6.4
const CATCH_R := 0.09           # wing scoop / tail pouch reach
const FLAP_HZ := 9.0
const HANG := 0.035             # roost point (its feet) to the body centre, hanging
const DROP_T := 0.32            # s falling, wings still wrapped, before it opens and flies
enum { CALL, BUZZ, GRUMBLE }

var post: LanternPost
var moths: Moths
var weather: Weather
var state := AWAY
var catches := 0                # bots: moths taken
var misses := 0                 # bots: stoops the moth got away from
var stoops := 0                 # bots: chases started
var nearest_lamp := 99.0        # bots: closest it came to the lantern centre while out
var lowest := 99.0              # bots: lowest height above the post foot while out
var hold := false               # shot tool: freeze it in place (still flapping)
var roost_at := Vector3.INF     # its feet's hold under the woodshed boards (world.gd)
var door_at := Vector3.INF      # just outside the woodshed's open end
var roost_face := Vector3.BACK  # out of the open end: the hanging bat's belly faces this way
var drops := 0                  # bots: times it let go of the roost at dusk
var homings := 0                # bots: times it hung up again under the eaves
var stretches := 0              # bots: wing stretches while roosting
var fell := 0.0                 # bots: how far below its hold it dropped before flying
var calls := 0                  # bots: social chirps on the wing
var buzzes := 0                 # bots: feeding buzzes (one per stoop)
var grumbles := 0               # bots: grumbles at the roost
var vel := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _flap := 0.0
var _glide := 0.0
var _ang := 0.0                 # patrol angle round the lantern
var _sense := 1.0
var _r := 2.5
var _y := 0.8
var _jink := 0.0
var _hunt := 3.0                # to the next stoop
var _target := -1               # moth index being chased
var _chase_t := 0.0
var _bank := 0.0
var _snap := 0.0                # 1 at a catch/miss wing snap, decays
var _furl := 0.0                # 0 wings flying .. 1 wrapped round it, hanging
var _leg := 0                   # HOME: 0 to the door, 1 in under the boards
var _drop_t := 0.0
var _stretch := 0.0             # s left in a stretch at the roost
var _stretch_in := 20.0         # s to the next
var _sway_t := 0.0
var _call_in := 2.0             # s to the next social chirp on the loop

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.seed = 40917
	visible = false
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 1.2)
	plane.subdivide_width = 7          # x at -1, -.75 .. 1: shoulder, elbow, wrist bend
	plane.subdivide_depth = 2
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/bat.gdshader")
	_mat.set_shader_parameter("half_span", HALF_SPAN)
	var wings := MeshInstance3D.new()
	wings.name = "Wings"
	wings.mesh = plane
	wings.material_override = _mat
	wings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wings.extra_cull_margin = 0.3
	add_child(wings)
	# furry body, head, ears and muzzle: a dark brown nub between the wings
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.20, 0.14, 0.10)
	fur.roughness = 1.0
	# fur passes no light: a backlit fur ball glowed red-orange against the bright open end
	fur.rim_enabled = true
	fur.rim = 0.3
	fur.rim_tint = 0.85
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 16
	ball.rings = 8
	_part("Body", ball, fur, Vector3(0, -0.004, 0.006), Vector3(0.024, 0.02, 0.05))
	_part("Head", ball, fur, Vector3(0, 0.0, -0.026), Vector3(0.019, 0.016, 0.02))
	_part("Muzzle", ball, fur, Vector3(0, -0.003, -0.037), Vector3(0.010, 0.008, 0.011))
	var ear := CylinderMesh.new()
	ear.top_radius = 0.0
	ear.bottom_radius = 0.5
	ear.height = 1.0
	ear.radial_segments = 6
	ear.rings = 1
	var skin := fur.duplicate() as StandardMaterial3D
	skin.albedo_color = Color(0.13, 0.09, 0.07)
	skin.backlight_enabled = true      # only the thin ears let a little light through
	skin.backlight = Color(0.16, 0.06, 0.03)
	for s in [-1.0, 1.0]:
		var e := _part("Ear", ear, skin, Vector3(s * 0.007, 0.011, -0.027), Vector3(0.008, 0.012, 0.004))
		e.rotation = Vector3(-0.35, 0.0, -s * 0.35)

func _part(n: String, m: Mesh, mat: Material, at: Vector3, sc: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Out hunting at this hour and weather: full dark with the candle burning, dry and still enough.
func wanted() -> bool:
	var h: float = post._world.time_of_day if "time_of_day" in post._world else 12.0
	var dark := h >= 19.75 or h < 4.9
	var rain := weather.rain if weather else 0.0
	var wind := weather.wind if weather else 0.0
	return dark and post.lit > 0.5 and rain < 0.35 and wind < 0.75

func _process(delta: float) -> void:
	var c := post.lantern_center()
	_mat.set_shader_parameter("lamp_pos", post.flame_pos.global_position)
	_mat.set_shader_parameter("lamp_lit", post.lit)
	var want := wanted()
	var roosts := roost_at != Vector3.INF
	if state == AWAY:
		if roosts:
			_hang_up()
		elif not want:
			visible = false
			return
		else:
			_arrive(c)
	if state == ROOST:
		visible = true
		if want and not hold:
			state = DROP
			_drop_t = 0.0
			vel = Vector3.ZERO
			drops += 1
		else:
			_roosting(delta)
			return
	elif not want and state not in [OUT, HOME, DROP]:
		state = HOME if roosts else OUT
		_leg = 0
		_target = -1
	visible = true
	if hold:
		# wings out level just past the top of the downstroke
		_mat.set_shader_parameter("flap", 0.25)
		_mat.set_shader_parameter("amp", 1.0)
		_mat.set_shader_parameter("snap", 0.0)
		return
	var steps := maxi(1, ceili(delta * 90.0))
	var dt := delta / steps
	for i in steps:
		_step(c, dt)
		if state == ROOST:
			break
		if state == AWAY:
			visible = false
			return
	if state == PATROL or state == CHASE:
		nearest_lamp = minf(nearest_lamp, global_position.distance_to(c))
		lowest = minf(lowest, global_position.y - post.global_position.y)
	if state == PATROL or state == IN:
		_call_in -= delta
		if _call_in <= 0.0:
			_call_in = _rng.randf_range(2.5, 7.0)
			calls += 1
			chirped.emit(global_position, CALL)
	if state == ROOST:
		_roosting(0.0)
		return
	_wings(delta, state == PATROL and _glide > 0.5)
	# face the flight line, banked into the turn
	if vel.length() > 0.2:
		var f := vel.normalized()
		var up := Vector3.UP if absf(f.y) < 0.95 else Vector3.FORWARD
		basis = Basis.looking_at(f, up).rotated(f, _bank).orthonormalized()

func _wings(delta: float, gliding: bool) -> void:
	_glide = move_toward(_glide, 1.0 if gliding else 0.0, delta * 4.0)
	_flap += delta * TAU * FLAP_HZ * (1.0 + 0.3 * _snap) * (1.0 - 0.75 * _glide)
	_snap = move_toward(_snap, 0.0, delta * 5.0)
	_mat.set_shader_parameter("flap", fmod(_flap, TAU))
	_mat.set_shader_parameter("amp", lerpf(1.0, 0.18, _glide))
	_mat.set_shader_parameter("snap", _snap)
	_furl = move_toward(_furl, 1.0 if state == DROP and _drop_t < DROP_T else 0.0, delta * 5.0)
	_mat.set_shader_parameter("furl", _furl)

## Hangs at the roost now, wings wrapped (dawn on a fresh load, or the end of the flight home).
func _hang_up() -> void:
	state = ROOST
	vel = Vector3.ZERO
	_target = -1
	_furl = 1.0
	_stretch = 0.0
	global_position = roost_at - Vector3.UP * HANG

## Hanging head down from the boards, belly to the open end: a slow sway in the draught, and
## every half minute or so it unwraps one wing a little, shivers it and wraps it again.
func _roosting(delta: float) -> void:
	_sway_t += delta
	var w := weather.wind if weather else 0.0
	var sway := (0.04 + 0.12 * w) * sin(_sway_t * 1.7) + 0.03 * sin(_sway_t * 0.63 + 1.0)
	_stretch_in -= delta
	if _stretch_in <= 0.0 and _stretch <= 0.0:
		_stretch = 1.6
		_stretch_in = _rng.randf_range(18.0, 45.0)
		stretches += 1
		if _rng.randf() < 0.7 or grumbles == 0:
			grumbles += 1
			chirped.emit(global_position, GRUMBLE)
	var open := 0.0
	if _stretch > 0.0:
		_stretch -= delta
		var u := 1.0 - _stretch / 1.6
		open = sin(u * PI) * 0.55
		_flap += delta * TAU * 3.0
	_furl = 1.0 - open
	_mat.set_shader_parameter("furl", _furl)
	_mat.set_shader_parameter("flap", fmod(_flap, TAU) if open > 0.0 else 4.0)
	_mat.set_shader_parameter("amp", 0.25 * open)
	_mat.set_shader_parameter("snap", 0.0)
	var face := Vector3(roost_face.x, 0, roost_face.z).normalized()
	var b := Basis.looking_at(Vector3.DOWN, -face)
	global_position = roost_at - Vector3.UP * HANG
	basis = b.rotated(face.cross(Vector3.UP).normalized(), sway).orthonormalized()

func _arrive(c: Vector3) -> void:
	var a := _rng.randf() * TAU
	global_position = c + Vector3(cos(a) * FAR, _rng.randf_range(1.0, 4.0), sin(a) * FAR)
	vel = (c - global_position).normalized() * SPEED
	state = IN
	_ang = a
	_hunt = _rng.randf_range(1.5, 3.5)
	nearest_lamp = 99.0
	lowest = 99.0

func _step(c: Vector3, dt: float) -> void:
	var p := global_position
	var desired := vel
	var accel := 9.0
	match state:
		DROP:
			# let go: a short fall with the wings still wrapped, then they snap open and it
			# flies out under the eaves, past the door point, and on to the light
			_drop_t += dt
			if _drop_t < DROP_T:
				desired = Vector3(0, -2.2, 0) + roost_face * 0.4
				accel = 6.0
				fell = maxf(fell, roost_at.y - p.y)
			else:
				var to_door := door_at - p
				desired = (to_door.normalized() + Vector3.UP * 0.1) * SPEED
				if to_door.length() < 0.5:
					state = IN
		HOME:
			# back under the eaves: to the door point, then in to the roost, slowing, and it
			# swings up and takes hold
			var tgt := door_at if _leg == 0 else roost_at - Vector3.UP * HANG
			var to := tgt - p
			if _leg == 0:
				desired = to.normalized() * SPEED * 1.2
				if to.length() < 0.5:
					_leg = 1
			else:
				desired = to.normalized() * minf(SPEED, 0.6 + to.length() * 3.0)
				accel = 12.0
				if to.length() < 0.06:
					homings += 1
					_hang_up()
					return
		IN:
			desired = (c + Vector3(0, 1.0, 0) - p).normalized() * SPEED * 1.2
			var rh := Vector2(p.x - c.x, p.z - c.z)
			if rh.length() < LOOP_R.y + 0.5:
				state = PATROL
				_ang = atan2(rh.y, rh.x)
		OUT:
			var away := Vector3(p.x - c.x, 0, p.z - c.z)
			if away.length() < 0.01:
				away = Vector3.RIGHT
			desired = (away.normalized() + Vector3.UP * 0.35).normalized() * SPEED * 1.3
			if away.length() > FAR:
				state = AWAY
				return
		PATROL:
			# a fast loop round the light, the radius and height wandering, jinks on top
			_ang += _sense * SPEED / maxf(_r, 0.5) * dt
			var tgt := c + Vector3(cos(_ang) * _r, _y, sin(_ang) * _r)
			desired = (tgt - p) * 3.0 + Vector3(-sin(_ang), 0, cos(_ang)) * _sense * SPEED
			desired = desired.limit_length(SPEED)
			_jink -= dt
			if _jink <= 0.0:
				_jink = _rng.randf_range(0.18, 0.7)
				vel += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.7, 0.7), _rng.randf_range(-1, 1)) * 2.6
				_r = clampf(_r + _rng.randf_range(-0.6, 0.6), LOOP_R.x, LOOP_R.y)
				_y = clampf(_y + _rng.randf_range(-0.6, 0.6), LOOP_Y.x, LOOP_Y.y)
				if _rng.randf() < 0.12:
					_sense = -_sense
				_glide = 1.0 if _rng.randf() < 0.18 else _glide
			_hunt -= dt
			if _hunt <= 0.0:
				_hunt = _rng.randf_range(3.0, 7.0)
				_target = moths.prey_for(p) if moths else -1
				if _target >= 0:
					state = CHASE
					_chase_t = 0.0
					stoops += 1
					buzzes += 1
					chirped.emit(p, BUZZ)
		CHASE:
			accel = 14.0
			_chase_t += dt
			if not moths.catchable(_target) or _chase_t > 1.4:
				_back_to_patrol(false)
			else:
				var mp := moths.moth_pos(_target)
				var lead := mp + moths.moth_vel(_target) * minf(p.distance_to(mp) / CHASE_SPEED, 0.3)
				desired = (lead - p).normalized() * CHASE_SPEED
				if p.distance_to(mp) < CATCH_R:
					moths.snatch(_target)
					catches += 1
					_snap = 1.0
					_back_to_patrol(true)
				elif p.distance_to(mp) < 0.9:
					# the moth hears it coming; folded and dropping, it is gone from under the bat
					moths.dodge(_target, p)
					if moths.diving(_target):
						_back_to_patrol(false)
	vel = vel.lerp(desired, clampf(dt * accel, 0.0, 1.0))
	var side := vel.cross(Vector3.UP).dot(desired - vel)
	_bank = lerpf(_bank, clampf(-side * 0.12, -1.0, 1.0), clampf(dt * 8.0, 0.0, 1.0))
	p += vel * dt
	if state == DROP or state == HOME:
		global_position = p
		return
	# never into the lantern, the post or the turf
	var rel := p - c
	if rel.length() < KEEP_OFF:
		p = c + rel.normalized() * KEEP_OFF
		vel = vel.slide(rel.normalized())
	var floor_y := post.global_position.y + 1.0
	if p.y < floor_y:
		p.y = floor_y
		vel.y = maxf(vel.y, 0.5)
	var to_post := Vector2(p.x - post.global_position.x, p.z - post.global_position.z)
	if to_post.length() < 0.3 and p.y < c.y + 0.3:
		to_post = to_post.normalized() * 0.3
		p.x = post.global_position.x + to_post.x
		p.z = post.global_position.z + to_post.y
	global_position = p

func _back_to_patrol(caught: bool) -> void:
	if not caught and state == CHASE:
		misses += 1
		_snap = 0.6
	state = PATROL
	_target = -1
	var rh := Vector2(global_position.x - post.lantern_center().x, global_position.z - post.lantern_center().z)
	_ang = atan2(rh.y, rh.x)
	_r = clampf(rh.length(), LOOP_R.x, LOOP_R.y)
