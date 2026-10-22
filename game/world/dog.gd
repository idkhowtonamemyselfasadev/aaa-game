class_name Dog
extends Node3D
## Brack, Edda's black-and-white working collie (owner's "villages with movement", "react to
## the player and the time of day"). By day it potters about the green in front of the white
## cottage: trots off to a spot, noses the turf, sits a while watching the yard, trots on.
## When the hero comes up the track it gives a couple of barks, trots out to meet him with its
## tail going, and keeps at his heel while he stays about the cottage, then goes back to its
## pottering. At night and in rain it sits by the white cottage door under the eaves, and a
## hero walking up in the dark sets it barking. Procedural mesh on the fox's rig (Herd's loft
## helpers), posed in dog.gdshader.
## It keeps mostly to the trodden tracks, and the grass it sits or noses about in is pressed
## flat under it (a point on Trample's herd trail), so it is not lost in the meadow.
## Lying at night it dozes, its chin sinking onto its paws, and lifts its head when the hero
## comes within 11 m; about a third of its daytime rests are taken lying down, head up.
## When Wat the pedlar comes by on the road it gives him a gruff "wuff-wuff", stiff-tailed,
## and trots a few steps out after him, then stands watching him off down the road before it
## goes back to its pottering (from its place at the door in rain, it only woofs and watches).
## Bots read `state`, `sit`, `lie`, `doze`, `wag`, `greets`, `barks`, `bed`, `home`, `pressed`,
## `woofs`, `warns`.

signal barked(at: Vector3, alarm: bool)   # a greeting bark, or a guard bark at night
signal woofed(at: Vector3)                # its gruff two-bark at a stranger on the road

enum { POTTER, SNIFF, REST, GREET, HEEL, BED, WARN }

const SCALE := 1.3          # on the fox rig: ~0.5 m at the shoulder
const WALK := 1.1           # m/s pottering
const TROT := 2.6           # m/s going out to meet the hero, or back to its door
const NOTICE_R := 16.0      # it notices the hero this far off
const HEEL_R := 2.2         # keeps about this far from him
const RANGE := 26.0         # never strays further than this from its door
const AGAIN := 90.0         # s the hero must be away before it greets him again
const ON_TRACK := 0.7       # share of its potter spots picked on a trodden track
const PRESS := 0.2          # trail point age it holds under itself (full lay in the shader)
const WARN_R := 15.0        # it takes notice of the pedlar this far off
const FOLLOW := 6.0         # trots at most this far out after him
const SEE_OFF := 20.0       # watches him till he is this far off, then goes back to pottering

var world: Node3D
var terrain: Terrain
var weather: Weather
var state := POTTER
var sit := 0.0
var lie := 0.0               # 0 sat .. 1 lying down (at night by the door, some daytime rests)
var doze := 0.0              # lying, 0 head up .. 1 chin on its paws
var rest_down := false       # the current daytime rest is taken lying
var wag := 0.0
var speed := 0.0
var yaw := 0.0
var head_yaw := 0.0
var graze := 0.0
var home := Vector3.ZERO     # the green in front of the white cottage door
var bed := Vector3.ZERO      # its place beside the door under the eaves
var bed_yaw := 0.0
var goal := Vector3.ZERO
var greets := 0              # (bots)
var barks := 0
var _t := 0.0                # s left in the current state
var _away_t := AGAIN         # s since the hero was last near
var _bark_n := 0             # barks still to give in this run
var _bark_t := 0.0
var _guarded := false        # has barked at the hero in the dark already
var _stuck_t := 0.0
var _phase := 0.0
var _obstacles: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _mi: MeshInstance3D
var _trample: Trample
var pressed := 0             # trail points it has laid (bots)
var woofs := 0               # gruff woofs at the pedlar (bots)
var warns := 0               # times it has seen the pedlar off (bots)
var _warned := -1            # the pedlar's walk (journeys count) it has already seen off
var _warn_from := Vector3.ZERO
var _woof_t := 0.0
var _press_at := Vector3.INF
var _fox_at := Vector3.INF   # where it heard the fox at the hen house (looks that way, sat up)
var _fox_t := 0.0            # s it keeps sat up staring that way
var fox_alarms := 0          # times it has given tongue at the fox in the night (bots)

func setup(w: Node3D) -> void:
	world = w
	terrain = w.get_node("Terrain")
	weather = w.get("weather")
	name = "Dog"
	_rng.seed = 5521
	w.add_child(self)
	_trample = w.get_node_or_null("Trample")
	# the white cottage's door and the way out of it (the village track that starts there)
	var run: PackedVector2Array = DoorStones.runs()[1][0]
	var d0 := Vector3(run[0].x, 0, run[0].y)
	var out := Vector3(run[1].x - run[0].x, 0, run[1].y - run[0].y).normalized()
	var side := out.cross(Vector3.UP)
	bed = _ground(d0 + out * 0.75 + side * 1.0)
	bed_yaw = atan2(-out.x, -out.z)
	home = _ground(d0 + out * 6.0)
	var wct := w.get("white_cottage") as WhiteCottage
	if wct:
		_obstacles.append_array(wct.outline(1.2))
	var sct = w.get("stone_cottage")
	if sct:
		_obstacles.append_array(sct.outline(1.2))
	var dw = w.get("dry_wall")
	if dw:
		_obstacles.append_array(dw.outline(1.0))
	_obstacles.append_array(YardWall.outline(1.0))
	_obstacles.append_array(Cottage.outline_points())
	_obstacles.append(Vector3(LanternPost.SITE.x, 0.0, LanternPost.SITE.y))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/dog.gdshader")
	_mi = MeshInstance3D.new()
	_mi.name = "Body"
	_mi.mesh = build_mesh()
	_mi.material_override = mat
	_mi.scale = Vector3.ONE * SCALE
	add_child(_mi)
	if _night_or_rain():
		place_bed()
	else:
		global_position = home
		_start(REST, 4.0)

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)

func _hour() -> float:
	return world.time_of_day

func _night_or_rain() -> bool:
	var h := _hour()
	return h >= 21.0 or h < 5.75 or (weather != null and weather.rain > 0.3)

## A fox at Osric's hen house in the night, the hens squawking: up off its side at its
## place by the door, staring across the green that way and giving tongue, a hard run of
## barks, until it goes quiet again.
func hear_fox(at: Vector3) -> void:
	if state != BED or _fox_t > 0.0:
		return
	_fox_at = at
	_fox_t = 9.0
	fox_alarms += 1
	_bark_n = 4 + _rng.randi() % 3
	_bark_t = _rng.randf_range(0.25, 0.5)

## Straight onto its place by the door, sat (bots and the night start).
func place_bed() -> void:
	global_position = bed
	yaw = bed_yaw
	sit = 1.0
	var h := _hour()
	lie = 1.0 if h >= 21.0 or h < 5.75 else 0.0
	speed = 0.0
	state = BED

func _start(s: int, t: float) -> void:
	state = s
	_t = t

func _process(delta: float) -> void:
	if world == null:
		return
	var dt := minf(delta, 0.1)
	var hero := world.get_node_or_null("Player") as Node3D
	var hp := hero.global_position if hero else Vector3(1e6, 0, 1e6)
	var to_hero := Vector3(hp.x - global_position.x, 0, hp.z - global_position.z)
	var near := to_hero.length()
	var hero_home := Vector2(hp.x - home.x, hp.z - home.z).length()
	var shelter := _night_or_rain()
	var noticed := near < NOTICE_R and hero_home < RANGE
	_t -= dt
	var want_sit := 0.0
	var want_lie := 0.0
	var want_doze := 0.0
	var top := 0.0
	var look := Vector3.INF
	var wag_goal := 0.0
	match state:
		POTTER:
			top = WALK
			if _steer_to(goal, dt):
				_start(SNIFF, _rng.randf_range(2.0, 5.0))
		SNIFF:
			graze = move_toward(graze, 1.0, dt / 0.6)
			if _t <= 0.0:
				_start(REST, _rng.randf_range(8.0, 20.0))
		REST:
			want_sit = 1.0
			want_lie = 1.0 if rest_down else 0.0
			if _t <= 0.0:
				_pick_goal()
				_start(POTTER, 0.0)
		GREET:
			top = TROT
			look = hp
			wag_goal = 1.0
			goal = hp - to_hero.normalized() * HEEL_R
			if _steer_to(goal, dt) or near < HEEL_R + 0.3:
				_start(HEEL, 0.0)
		HEEL:
			look = hp
			wag_goal = 0.5
			if near > HEEL_R + 1.2 or near < 1.0:   # catch him up, or step out from under his feet
				top = TROT if near > 5.0 else WALK
				_steer_to(hp - to_hero.normalized() * HEEL_R, dt)
			else:
				want_sit = 1.0 if near < HEEL_R + 0.6 and speed < 0.2 else 0.0
		WARN:
			# stiff-legged after the stranger a few steps, then stood watching him go
			var pd := _pedlar()
			if pd != null and pd.on_road and pd.visible:
				var pp := pd.global_position
				look = pp
				var gone := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
				var out := Vector2(global_position.x - _warn_from.x, global_position.z - _warn_from.z).length()
				if gone > 5.0 and out < FOLLOW and _t > 0.0:
					top = TROT * 0.8
					_steer_to(pp - (pp - global_position).normalized() * 4.5, dt)
				else:
					_t = 0.0
					want_sit = 1.0 if gone > 9.0 else 0.0
					yaw += clampf(wrapf(atan2(-(pp.x - global_position.x), -(pp.z - global_position.z)) - yaw, -PI, PI), -3.0 * dt, 3.0 * dt)
				if gone > SEE_OFF:
					_pick_goal()
					_start(POTTER, 0.0)
			else:
				_pick_goal()
				_start(POTTER, 0.0)
		BED:
			want_sit = 1.0
			# at night it lies down in its place, up on its haunches again to bark or watch him
			var h := _hour()
			_fox_t = maxf(_fox_t - dt, 0.0)
			want_lie = 1.0 if (h >= 21.0 or h < 5.75) and _bark_n == 0 and near > 6.0 and _fox_t <= 0.0 else 0.0
			want_doze = want_lie if near > 11.0 else 0.0
			if global_position.distance_to(bed) > 0.3:
				want_sit = 0.0
				want_lie = 0.0
				top = TROT
				_steer_to(bed, dt)
			else:
				yaw += clampf(wrapf(bed_yaw - yaw, -PI, PI), -3.0 * dt, 3.0 * dt)
			if near < 10.0:
				look = hp
			elif _fox_t > 0.0:
				look = _fox_at
			else:
				var pw := _pedlar()
				if pw != null and pw.on_road and pw.visible and global_position.distance_to(pw.global_position) < SEE_OFF:
					look = pw.global_position
	# what takes it from one thing to the next
	if noticed:
		_away_t = 0.0
	else:
		_away_t += dt
		if _away_t > 20.0:
			_guarded = false    # it barks at him afresh once he has been gone a while
	if shelter:
		if state != BED:
			state = BED
		# a hero walking up on the dark house sets it off
		if near < 9.0 and not _guarded:
			_guarded = true
			_bark_n = 3 + _rng.randi() % 3
			_bark_t = 0.2
	elif state == BED:
		_start(REST, _rng.randf_range(3.0, 8.0))
	elif state in [POTTER, SNIFF, REST] and noticed and (_last_greet_ok()):
		state = GREET
		greets += 1
		_bark_n = 2
		_bark_t = 0.15
	elif state in [GREET, HEEL] and (hero_home > RANGE or near > NOTICE_R + 6.0):
		_pick_goal()
		_start(POTTER, 0.0)
	elif state in [POTTER, SNIFF, REST] and _pedlar_by():
		_warned = _pedlar().journeys
		warns += 1
		_warn_from = global_position
		_start(WARN, 9.0)
		_woof_t = 0.35
	if shelter and state == BED and _pedlar_by():
		_warned = _pedlar().journeys
		_woof_t = 0.5
	if _woof_t > 0.0:
		_woof_t -= dt
		if _woof_t <= 0.0:
			woofs += 1
			woofed.emit(global_position + Vector3.UP * 0.5)
	_greet_gap = (_greet_gap + dt) if state not in [GREET, HEEL] else 0.0
	# its voice
	if _bark_n > 0:
		_bark_t -= dt
		if _bark_t <= 0.0:
			_bark_n -= 1
			barks += 1
			barked.emit(global_position + Vector3.UP * 0.5, shelter)
			_bark_t = _rng.randf_range(0.45, 0.8)
	elif _bark_t > 0.0:
		_bark_t -= dt
	if top <= 0.0:
		speed = move_toward(speed, 0.0, 4.0 * dt)
	sit = move_toward(sit, want_sit if speed < 0.3 else 0.0, dt / 0.6)
	lie = move_toward(lie, want_lie if sit > 0.95 else 0.0, dt / (1.4 if want_lie > 0.0 else 0.5))
	if lie > 0.01:
		sit = 1.0
	doze = move_toward(doze, want_doze * lie, dt / (2.5 if want_doze * lie > doze else 0.4))
	if state != SNIFF:
		graze = move_toward(graze, 0.0, dt / 0.5)
	wag = move_toward(wag, wag_goal * (1.0 if near < 8.0 else 0.4), dt / (0.15 if state == WARN else 0.4))
	var hg := 0.0
	if look != Vector3.INF:
		var tl := look - global_position
		hg = clampf(wrapf(atan2(-tl.x, -tl.z) - yaw, -PI, PI), -0.8, 0.8)
	elif state == REST:
		hg = 0.6 * sin(Time.get_ticks_msec() * 0.00031 + 1.3)   # watching the yard
	head_yaw = lerpf(head_yaw, hg, 1.0 - exp(-3.0 * dt))
	_phase = fposmod(_phase + dt * (speed / (0.95 * SCALE) if speed < 3.0 else speed / (1.6 * SCALE)), 1.0)
	global_rotation = Vector3(0, yaw, 0)
	_press_grass()
	_mi.set_instance_shader_parameter("phase", _phase)
	_mi.set_instance_shader_parameter("speed", speed / SCALE)
	_mi.set_instance_shader_parameter("sit", sit)
	_mi.set_instance_shader_parameter("head_yaw", head_yaw)
	_mi.set_instance_shader_parameter("graze", graze)
	_mi.set_instance_shader_parameter("wag", wag)
	_mi.set_instance_shader_parameter("lie", lie)
	_mi.set_instance_shader_parameter("doze", doze)

var _greet_gap := AGAIN   # s since it last left the hero's side

func _pedlar() -> Pedlar:
	return world.get("pedlar") as Pedlar

## Wat on the road within notice, and not yet seen off on this walk of his.
func _pedlar_by() -> bool:
	var pd := _pedlar()
	if pd == null or not pd.on_road or not pd.visible or pd.journeys == _warned:
		return false
	return global_position.distance_to(pd.global_position) < WARN_R

func _last_greet_ok() -> bool:
	return _greet_gap >= AGAIN or greets == 0

## Grass it sits or noses about in lies pressed down round it while it stays (one point on the
## herd trail, held fresh; it stands up again over HERD_TRAIL_LIFE once it trots on). Only
## when still, so its pottering does not spend the herd's 64 points.
func _press_grass() -> void:
	if _trample == null or speed > 0.3:
		return
	var p := global_position
	_trample.add_herd_point(Vector2(p.x, p.z), Vector2(-sin(yaw), -cos(yaw)), 1.0, PRESS, 0.2)
	if _press_at == Vector3.INF or p.distance_to(_press_at) > 0.3:
		pressed += 1
	_press_at = p

## A new spot to potter to: mostly along the trodden tracks near the cottage (where the
## sward is short and it shows), else on the open green, clear of the walls.
func _pick_goal() -> void:
	if _rng.randf() < ON_TRACK:
		var paths := YardGround._paths()
		for i in 12:
			var w: PackedVector2Array = paths[_rng.randi() % paths.size()]
			var k := _rng.randi() % (w.size() - 1)
			var q := w[k].lerp(w[k + 1], _rng.randf())
			var p := Vector3(q.x, 0, q.y)
			var r := Vector2(p.x - home.x, p.z - home.z).length()
			if r > 1.5 and r < 10.0 and _clear(p, 1.3):
				goal = _ground(p)
				rest_down = _rng.randf() < 0.35
				return
	for i in 12:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.5, 9.0)
		var p := home + Vector3(cos(a), 0, sin(a)) * r
		if _clear(p, 1.3):
			goal = _ground(p)
			rest_down = _rng.randf() < 0.35
			return
	goal = home
	rest_down = false

func _clear(p: Vector3, r: float) -> bool:
	for o in _obstacles:
		if Vector2(p.x - o.x, p.z - o.z).length() < r:
			return false
	return true

## One step toward `to`, edging round the walls and houses; true on arrival (or when stuck
## for a while, so it gives up on a spot it cannot reach).
func _steer_to(to: Vector3, dt: float) -> bool:
	var d3 := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	var d := d3.length()
	if d < 0.3:
		_stuck_t = 0.0
		return true
	var top := TROT if state in [GREET, HEEL, BED, WARN] else WALK
	if state == HEEL:
		top = TROT if d > 3.0 else WALK
	var want := minf(top, maxf(d * 1.2, 0.3))
	if lie > 0.15:
		want = 0.0    # up on its feet before it goes
	speed = move_toward(speed, want, 3.0 * dt)
	var dir := d3 / d
	var push := Vector3.ZERO
	for o in _obstacles:
		var a := Vector3(global_position.x - o.x, 0, global_position.z - o.z)
		var l := a.length()
		if l < 1.4 and l > 0.001:
			push += a / l * (1.4 - l) / 1.4
	if state == BED:
		push *= clampf((d - 0.6) / 2.0, 0.0, 1.0)   # its place is in against the wall
	if push.length() > 0.01:
		# slide along the wall rather than into it
		var tang := push.cross(Vector3.UP).normalized()
		if tang.dot(dir) < 0.0:
			tang = -tang
		dir = (dir + push * 1.5 + tang * push.length()).normalized()
	var want_yaw := atan2(-dir.x, -dir.z)
	yaw += clampf(wrapf(want_yaw - yaw, -PI, PI), -5.0 * dt, 5.0 * dt)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var before := global_position
	global_position = _ground(global_position + fwd * minf(speed * dt, d))
	if Vector2(global_position.x - before.x, global_position.z - before.z).length() < speed * dt * 0.3 + 0.0005:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)
	if _stuck_t > 4.0:
		_stuck_t = 0.0
		return true
	return false

# ---------------------------------------------------------------- mesh

## A collie on the fox's rig (Fox.build_mesh's keys, so fox.gdshader's joints fit), facing -Z,
## paws at y = 0: a deeper chest, a shorter, blunter muzzle, ears that tip over at the top,
## and a plumed tail carried low. Scaled up by SCALE on the node. COLOR as the fox.
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := [
		[0.335, 0.37, 0.01, 0.01, 0.01, 0.0],
		[0.31, 0.378, 0.07, 0.06, 0.08, 0.0],
		[0.24, 0.385, 0.092, 0.07, 0.10, 0.0],
		[0.11, 0.38, 0.09, 0.066, 0.085, 0.0],
		[-0.03, 0.385, 0.097, 0.072, 0.115, 0.0],
		[-0.15, 0.392, 0.10, 0.08, 0.14, 0.0],
		[-0.24, 0.415, 0.09, 0.085, 0.13, 0.15],
		[-0.30, 0.46, 0.075, 0.07, 0.095, 0.45],
		[-0.335, 0.51, 0.062, 0.058, 0.07, 0.75],
		[-0.35, 0.535, 0.05, 0.045, 0.052, 1.0],
	]
	Herd._loft(st, body, 0.0, 40, 6, 0.0, 0.0, 2)
	# head: a broad skull with a clear stop, a medium muzzle ending blunt
	var head := [
		[-0.315, 0.565, 0.01, 0.01, 0.01, 1.0],
		[-0.335, 0.565, 0.064, 0.056, 0.058, 1.0],
		[-0.372, 0.555, 0.072, 0.054, 0.062, 1.0],
		[-0.405, 0.54, 0.05, 0.036, 0.045, 1.0],
		[-0.44, 0.53, 0.036, 0.03, 0.036, 1.0],
		[-0.475, 0.522, 0.03, 0.026, 0.03, 1.0],
		[-0.50, 0.518, 0.024, 0.022, 0.024, 1.0],
		[-0.512, 0.517, 0.004, 0.004, 0.004, 1.0],
	]
	Herd._loft(st, head, 0.0, 32, 6, 0.0, 0.0, 3)
	for s in [-1.0, 1.0]:
		# ears: set wide, standing a little then tipping forward over at the top
		var ear := [
			[-0.343, 0.59, 0.017, 0.01, 0.01, 1.0, 0.035],
			[-0.346, 0.61, 0.028, 0.008, 0.008, 1.0, 0.045],
			[-0.356, 0.632, 0.02, 0.006, 0.006, 1.0, 0.053],
			[-0.378, 0.638, 0.004, 0.003, 0.003, 1.0, 0.058],
		]
		Herd._loft(st, ear, s, 12, 3, 0.0, 1.0)
		Herd._sphere(st, Vector3(0.034 * s, 0.57, -0.395), 0.012, 1.0, 0.5)
		var fore := [
			[0.045, 0.40, -0.165, 0.042, 0.055, 0.055],
			[0.05, 0.31, -0.18, 0.03, 0.038, 0.036],
			[0.05, 0.21, -0.185, 0.02, 0.023, 0.022],
			[0.05, 0.12, -0.19, 0.017, 0.019, 0.018],
			[0.05, 0.045, -0.195, 0.017, 0.02, 0.018],
			[0.05, 0.014, -0.21, 0.022, 0.03, 0.018],
			[0.05, -0.003, -0.218, 0.003, 0.003, 0.003],
		]
		var hind := [
			[0.05, 0.39, 0.22, 0.055, 0.075, 0.065],
			[0.06, 0.29, 0.195, 0.042, 0.055, 0.052],
			[0.06, 0.21, 0.225, 0.025, 0.027, 0.03],
			[0.055, 0.125, 0.268, 0.017, 0.019, 0.021],
			[0.05, 0.05, 0.258, 0.017, 0.02, 0.018],
			[0.05, 0.014, 0.245, 0.022, 0.03, 0.018],
			[0.05, -0.003, 0.238, 0.003, 0.003, 0.003],
		]
		Herd._leg(st, fore, s, 0.25 if s > 0 else 0.5, 0.12, 18, 5)
		Herd._leg(st, hind, s, 0.75 if s > 0 else 1.0, 0.125, 18, 5)
	# the tail: a plume, slimmer than a fox's brush, on the same keys (the shader's curl)
	var tail := [
		[0.30, 0.385, 0.012, 0.012, 0.012, 0.0],
		[0.345, 0.38, 0.03, 0.03, 0.03, 0.0],
		[0.429, 0.346, 0.044, 0.05, 0.046, 0.0],
		[0.541, 0.29, 0.05, 0.056, 0.05, 0.0],
		[0.653, 0.234, 0.044, 0.048, 0.044, 0.0],
		[0.731, 0.201, 0.026, 0.026, 0.026, 0.0],
		[0.754, 0.192, 0.003, 0.003, 0.003, 0.0],
	]
	Herd._loft(st, tail, 0.0, 28, 5, 0.0, 0.75, 3)
	st.generate_tangents()
	return st.commit()
