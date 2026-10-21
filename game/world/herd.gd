class_name Herd
extends Node3D
## Wildlife, second pass (DESIGN §8): a herd of red deer hinds with their calves grazing the
## open meadow. They drift slowly across their feeding ground, heads down, one or another
## always lifting her head to chew and look round. A hero coming into sight puts heads up:
## they stand and stare at him, ears forward; come closer, or run at them, and they bolt
## together in a gallop away from him, slow to a trot, and settle to graze again far off.
## All geometry is procedural (one deer mesh, posed per instance in deer.gdshader).

@export var terrain_path: NodePath = ^"../Terrain"
@export var hinds: int = 7
@export var calves: int = 2
@export var stags: int = 1                 # a royal stag that keeps company with the hinds
@export var alert_radius: float = 42.0     # heads up (+2 m per m/s the threat moves)
@export var flee_radius: float = 24.0      # bolt (+2 m per m/s)
@export var safe_radius: float = 85.0      # stop running this far from the threat
@export var seed: int = 4242

enum { CALM, ALERT, FLEE }

signal barked(at: Vector3)            # a hind's alarm bark as the herd bolts
signal galloped(at: Vector3)          # one bound's four hooves drumming the turf
signal roared(at: Vector3)            # the stag bells at dusk and dawn (rut)

var _terrain: Terrain
var _trample: Trample
var hoof_prints := 0             # bots read this: prints pressed since start
var _rng := RandomNumberGenerator.new()
var _mm: MultiMesh
var _mm_stag: MultiMesh
var _deer: Array = []
var _obstacles: Array[Vector3] = []
var state := CALM
var anchor := Vector3.ZERO       # herd centre the deer graze round
var _wander := Vector3.ZERO
var _flee_dir := Vector3.ZERO
var _rim_side := 0.0             # which way a flight swings along the valley rim (latched)
var _calm_t := 0.0
var _alert_t := 0.0
var _threat_prev := {}
var threat_pos := Vector3.ZERO
var flee_events := 0             # bots read these
var alert_events := 0
var force_bed := false          # shots: lie down whatever the hour
var roar_t := 20.0              # s to the stag's next roar while the herd is at peace
var barks := 0                  # bots read these
var roars := 0
var _bark_q: Array = []         # [s left, deer] barks still to come in this alarm
# Hesper: the herd knows her. A grazing deer near her lifts its head and watches her a
# while, then goes back to the grass; she never alarms the herd.
var familiar: Node3D
const FAMILIAR_R := 24.0
var glances := 0                # bots read this: times a deer looked up at her

class Deer:
	var pos := Vector3.ZERO
	var yaw := 0.0
	var speed := 0.0
	var phase := 0.0
	var head := 1.0          # 0 up .. 1 grazing
	var head_target := 1.0
	var head_yaw := 0.0
	var look_t := 0.0
	var step_t := 0.0
	var goal := Vector3.ZERO
	var slot := Vector2.ZERO
	var scale := 1.0
	var gait := 1.0          # top speed in flight (m/s)
	var pitch := 0.0
	var hoof_d := 0.0        # m walked since the last hoof print
	var hoof_side := 0
	var bound := 0
	var trail_d := 0.0       # m run since the last herd trail point
	var stag := false
	var bed := 0.0           # 0 standing .. 1 lying in its bed (front kneels first)
	var bed_target := 0.0
	var bed_jit := 0.0       # h: each deer lies down / gets up at its own time
	var bed_d := 0.0         # s since its bed was last pressed into the grass
	var glance_t := 0.0      # s left watching Hesper (negative: s until it may look again)

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_trample = get_node_or_null("../Trample")
	_rng.seed = seed
	var flora: Flora = get_node_or_null("../Flora")
	if flora:
		_obstacles.append_array(flora.tree_positions)
		_obstacles.append_array(flora.rock_positions)
	_obstacles.append_array(Cottage.outline_points())   # the house on the west of the green
	anchor = _pick_site()
	# the stone cottage: deer steer round its walls (added after the site pick, which
	# keeps to open meadow 45 m out anyway)
	var ct: StoneCottage = get_node_or_null("../StoneCottage")
	if ct:
		_obstacles.append_array(ct.outline(2.4))
	var wct: WhiteCottage = get_node_or_null("../WhiteCottage")
	if wct:
		_obstacles.append_array(wct.outline(2.4))
	var dw: DryWall = get_node_or_null("../DryWall")
	if dw:
		_obstacles.append_array(dw.outline(2.0))
	_obstacles.append_array(YardWall.outline(1.6))   # and the yard walls between the houses
	_obstacles.append(Vector3(LanternPost.SITE.x, 0.0, LanternPost.SITE.y))   # the lantern post
	_wander = Vector3(1, 0, 0).rotated(Vector3.UP, _rng.randf() * TAU)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/deer.gdshader")
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = build_mesh()
	_mm.instance_count = hinds + calves
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Deer"
	mmi.multimesh = _mm
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-300, -50, -300), Vector3(600, 200, 600))
	add_child(mmi)
	if stags > 0:
		var smat := mat.duplicate() as ShaderMaterial
		smat.set_shader_parameter("stag", 1.0)
		_mm_stag = MultiMesh.new()
		_mm_stag.transform_format = MultiMesh.TRANSFORM_3D
		_mm_stag.use_custom_data = true
		_mm_stag.mesh = build_mesh(true)
		_mm_stag.instance_count = stags
		var smi := MultiMeshInstance3D.new()
		smi.name = "Stags"
		smi.multimesh = _mm_stag
		smi.material_override = smat
		smi.custom_aabb = mmi.custom_aabb
		add_child(smi)
	for i in hinds + calves + stags:
		var d := Deer.new()
		var calf := i >= hinds and i < hinds + calves
		d.stag = i >= hinds + calves
		d.scale = _rng.randf_range(0.6, 0.68) if calf else _rng.randf_range(0.92, 1.04)
		d.slot = Vector2(_rng.randfn(0.0, 4.5), _rng.randfn(0.0, 4.5))
		if d.stag:   # a big stag, keeping a little apart at the edge of his hinds
			d.scale = _rng.randf_range(1.12, 1.18)
			var a := _rng.randf() * TAU
			d.slot = Vector2(cos(a), sin(a)) * _rng.randf_range(7.0, 9.0)
		if calf:   # a calf keeps to its mother's flank
			var m: Deer = _deer[i - hinds]
			d.slot = m.slot + Vector2(_rng.randf_range(-1.6, 1.6), _rng.randf_range(-1.6, 1.6))
		d.pos = _ground(anchor + Vector3(d.slot.x, 0, d.slot.y))
		d.goal = d.pos
		d.yaw = _rng.randf() * TAU
		d.head = 1.0 if _rng.randf() < 0.75 else 0.0
		d.head_target = d.head
		d.look_t = _rng.randf_range(1.0, 9.0)
		d.step_t = _rng.randf_range(2.0, 12.0)
		d.phase = _rng.randf()
		d.gait = _rng.randf_range(10.5, 12.5) * (0.92 if calf else 1.0)
		d.bed_jit = fposmod(i * 0.618034, 1.0) * 1.2 - 0.6   # (keeps the herd's random stream)
		_deer.append(d)
	_write_instances()

## An open, level patch of meadow 45-90 m from the start, clear of trees and rocks.
func _pick_site() -> Vector3:
	var best := Vector3(-50, 0, 45)
	var best_s := -INF
	for k in 64:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(45.0, 90.0)
		var c := Vector3(cos(a) * r, 0, sin(a) * r)
		var s := _terrain.normal_at(c.x, c.z).y * 20.0 + minf(_clear_at(c), 20.0)
		if s > best_s:
			best_s = s
			best = c
	return _ground(best)

func _clear_at(c: Vector3) -> float:
	var m := 1e9
	for o in _obstacles:
		m = minf(m, Vector2(o.x - c.x, o.z - c.z).length())
	return m

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _terrain.height_at(p.x, p.z), p.z)

func stag_count() -> int:
	var n := 0
	for d: Deer in _deer:
		if d.stag:
			n += 1
	return n

func is_stag(k: int) -> bool:
	return (_deer[k] as Deer).stag

func deer_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for d: Deer in _deer:
		out.append(d.pos)
	return out

func centre() -> Vector3:
	var c := Vector3.ZERO
	for d: Deer in _deer:
		c += d.pos
	return c / maxf(1.0, _deer.size())

func heads_up() -> int:
	var n := 0
	for d: Deer in _deer:
		if d.head < 0.3:
			n += 1
	return n

## Put the herd somewhere else (tests, shots): grazing, calm.
func place(at: Vector3) -> void:
	anchor = _ground(at)
	state = CALM
	for d: Deer in _deer:
		d.pos = _ground(anchor + Vector3(d.slot.x, 0, d.slot.y))
		d.goal = d.pos
		d.speed = 0.0
	_write_instances()

# ---------------------------------------------------------------- simulation

## Hour of the world clock (13 with no World, as in the deer viewer).
func _hour() -> float:
	var h = get_parent().get("time_of_day")
	return 13.0 if h == null else float(h)

## Night rest: the herd beds down in the meadow from about 22 h to 5 h, each deer at its
## own time (the hinds settle within an hour of each other, rise again before dawn).
func _resting(d: Deer, h: float) -> bool:
	return h > 21.8 + d.bed_jit or h < 4.8 + d.bed_jit

## Deer lying in their beds (bots).
func bedded() -> int:
	var n := 0
	for d: Deer in _deer:
		if d.bed > 0.95:
			n += 1
	return n

func _threat(dt: float) -> Array:
	var pl := get_node_or_null("../Player") as Node3D
	if pl == null:
		return [Vector3(1e6, 0, 1e6), 0.0]
	var p := pl.global_position
	var prev: Vector3 = _threat_prev.get(0, p)
	_threat_prev[0] = p
	var spd := Vector2(p.x - prev.x, p.z - prev.z).length() / maxf(dt, 0.001)
	# a jump of tens of metres in a frame is a respawn/teleport, not a charge
	return [p, 0.0 if spd > 25.0 else minf(spd, 12.0)]

func _process(delta: float) -> void:
	# a slow frame (or the bots' 4x time scale) is split into <= 1/30 s steps instead of
	# clamped, so the herd keeps real time with the physics-driven hero; only a hitch over
	# 0.5 s loses time (a slow box at 4x hit the old 0.2 s cap every frame and the deer
	# fell behind a sprinting hero)
	var th := _threat(maxf(delta, 0.001))
	var steps := clampi(ceili(delta * 30.0), 1, 15)
	var dt := minf(delta / steps, 1.0 / 30.0)
	for i in steps:
		_tick(dt, th)

func _tick(dt: float, th: Array) -> void:
	var tp: Vector3 = th[0]
	var tspd: float = th[1]
	threat_pos = tp
	var c := centre()
	var dist := Vector2(tp.x - c.x, tp.z - c.z).length()
	match state:
		CALM:
			# the feeding ground creeps across the meadow; turn back from trees and the edge
			var ahead := anchor + _wander * 6.0
			if _clear_at(ahead) < 6.0 or Vector2(ahead.x, ahead.z).length() > 180.0 or _terrain.normal_at(ahead.x, ahead.z).y < 0.9:
				_wander = _wander.rotated(Vector3.UP, _rng.randf_range(1.5, 3.0))
			_wander = _wander.rotated(Vector3.UP, _rng.randfn(0.0, 0.05) * dt)
			if bedded() < _deer.size() / 2:
				anchor = _ground(anchor + _wander * 0.06 * dt)
			if dist < alert_radius + 2.0 * tspd:
				state = ALERT
				_alert_t = 0.0
				alert_events += 1
		ALERT:
			_alert_t += dt
			if dist < flee_radius + 2.0 * tspd or (tspd > 4.5 and dist < alert_radius) or _alert_t > 40.0:
				_bolt(tp)
			elif dist > alert_radius + 8.0:
				_alert_t = 0.0
				_calm_t += dt
				if _calm_t > 5.0:
					state = CALM
					_calm_t = 0.0
			else:
				_calm_t = 0.0
		FLEE:
			# veer along the valley rather than into trees or off the edge
			var away := Vector3(c.x - tp.x, 0, c.z - tp.z).normalized()
			var dir := (_flee_dir * 0.7 + away * 0.3).normalized()
			var probe := anchor + dir * 14.0
			if Vector2(probe.x, probe.z).length() > 200.0:
				# swing along the rim on the side away from the threat, never back past it;
				# the side is picked once per flight so a flight straight at the rim can't dither
				var tang := dir.cross(Vector3.UP)
				if _rim_side == 0.0:
					var score := tang.dot(away)
					if absf(score) < 0.15:
						score = tang.dot(-probe)
					_rim_side = 1.0 if score >= 0.0 else -1.0
				tang *= _rim_side
				dir = (dir * 0.3 + tang).normalized()
			_flee_dir = _flee_dir.lerp(dir, minf(1.0, dt * 1.5)).normalized()
			var lead := 11.5 if dist < safe_radius else maxf(0.0, 11.5 - (dist - safe_radius) * 0.6)
			anchor = _ground(anchor + _flee_dir * lead * dt)
			if dist > safe_radius + 15.0:
				state = CALM
				_wander = _flee_dir
				for d: Deer in _deer:
					d.look_t = _rng.randf_range(3.0, 10.0)
	for i in range(_bark_q.size() - 1, -1, -1):
		_bark_q[i][0] -= dt
		if _bark_q[i][0] <= 0.0:
			var bd: Deer = _bark_q[i][1]
			_bark_q.remove_at(i)
			barks += 1
			barked.emit(bd.pos + Vector3.UP * 1.3 * bd.scale)
	_rut(dt)
	for d: Deer in _deer:
		_update_deer(d, dt, tp)
	_write_instances()

## Rut: an undisturbed stag roars now and then through the evening and the small hours
## before dawn, a long groaning bellow carried down the vale, quiet through the day.
func _rut(dt: float) -> void:
	if state != CALM or stags <= 0:
		return
	var h := _hour()
	var dusk := h > 17.5 and h < 23.0
	var dawn := h > 4.0 and h < 7.0
	roar_t -= dt
	if roar_t > 0.0:
		return
	roar_t = _rng.randf_range(25.0, 70.0) if (dusk or dawn) else _rng.randf_range(15.0, 30.0)
	if not (dusk or dawn):
		return
	var st: Deer = _deer[_deer.size() - 1]
	roars += 1
	st.head_target = 0.0   # head up and stretched out to bellow
	st.look_t = _rng.randf_range(4.0, 7.0)
	roared.emit(st.pos + Vector3.UP * 1.5 * st.scale)

func _bolt(from: Vector3) -> void:
	state = FLEE
	flee_events += 1
	_rim_side = 0.0
	var c := centre()
	_flee_dir = Vector3(c.x - from.x, 0, c.z - from.z).normalized().rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4))
	anchor = _ground(c)
	for d: Deer in _deer:
		d.head_target = 0.0
	# the hind nearest the threat barks first, one or two others take it up as they run
	var near: Deer = _deer[0]
	for d: Deer in _deer:
		if not d.stag and d.pos.distance_to(from) < near.pos.distance_to(from):
			near = d
	_bark_q.append([0.0, near])
	for k in _rng.randi_range(1, 2):
		_bark_q.append([_rng.randf_range(0.5, 1.6), _deer[_rng.randi() % _deer.size()]])

func _update_deer(d: Deer, dt: float, tp: Vector3) -> void:
	var want_speed := 0.0
	var target := d.goal
	var night := state == CALM and (force_bed or _resting(d, _hour()))
	d.bed_target = 1.0 if night else 0.0
	if night or d.bed > 0.0:
		# lying in the grass chewing the cud: head up looking round, now and then dozing
		# with the muzzle let down; the bed is pressed into the grass under her
		d.look_t -= dt
		if d.look_t < 0.0:
			var doze := _rng.randf() < 0.35
			d.head_target = 0.3 if doze else 0.0
			d.head_yaw = _rng.randf_range(-0.25, 0.25) if doze else _rng.randf_range(-0.8, 0.8)
			d.look_t = _rng.randf_range(4.0, 14.0)
		if state == CALM:
			d.goal = d.pos
			d.step_t = _rng.randf_range(2.0, 8.0)
		d.bed_d += dt
		if d.bed > 0.9 and d.bed_d > 8.0 and _trample:
			d.bed_d = 0.0
			var bf := Vector3(-sin(d.yaw), 0, -cos(d.yaw))
			_trample.add_herd_point(Vector2(d.pos.x, d.pos.z), Vector2(bf.x, bf.z), 1.0)
	# down slowly (kneel, then the haunches), up quickly (haunches first) in alarm
	d.bed = move_toward(d.bed, d.bed_target, (0.45 if d.bed_target > d.bed else (1.4 if state != CALM else 0.6)) * dt)
	match state:
		CALM:
			if night or d.bed > 0.0:
				pass
			elif not _glance(d, dt):
				_graze(d, dt)
			target = d.goal
			if d.bed <= 0.0 and Vector2(target.x - d.pos.x, target.z - d.pos.z).length() > 0.6:
				want_speed = 0.55 if d.head_target > 0.5 else 0.9
		ALERT:
			d.head_target = 0.0
			target = d.pos
			# turn the head (and, slowly, the body) to stare at the threat
			var to := Vector3(tp.x - d.pos.x, 0, tp.z - d.pos.z)
			var want := atan2(-to.x, -to.z)
			var rel := wrapf(want - d.yaw, -PI, PI)
			d.head_yaw = clampf(rel, -1.1, 1.1)
			if absf(rel) > 1.0:
				d.yaw += signf(rel) * minf(absf(rel) - 1.0, 0.8 * dt)
		FLEE:
			d.head_target = 0.0
			d.head_yaw = 0.0
			if d.bed > 0.15:   # still scrambling up out of the bed
				target = d.pos
			# in flight the stag closes in and runs in his hinds' tracks (one shared lane)
			target = anchor + Vector3(d.slot.x, 0, d.slot.y) * (0.3 if d.stag else 0.8) + _flee_dir * 4.0
			var dist := Vector2(tp.x - d.pos.x, tp.z - d.pos.z).length()
			want_speed = d.gait if dist < safe_radius else lerpf(d.gait, 2.2, clampf((dist - safe_radius) / 15.0, 0.0, 1.0))
			if d.bed > 0.15:
				want_speed = 0.0
	# steer along the heading (no sideways sliding): turn toward the target, keep apart,
	# swerve round trees and rocks
	var steer := Vector3(target.x - d.pos.x, 0, target.z - d.pos.z)
	if steer.length() > 0.01:
		steer = steer.normalized()
	for o: Deer in _deer:
		if o == d:
			continue
		var off := Vector3(d.pos.x - o.pos.x, 0, d.pos.z - o.pos.z)
		var l := off.length()
		if l < 1.8 and l > 0.001:
			steer += off / l * (1.8 - l) * 1.2
	for ob in _obstacles:
		var off2 := Vector3(d.pos.x - ob.x, 0, d.pos.z - ob.z)
		var l2 := off2.length()
		if l2 < 3.2 and l2 > 0.001:
			steer += off2 / l2 * (3.2 - l2) * 1.5
	if want_speed > 0.0 and steer.length() > 0.05:
		var want_yaw := atan2(-steer.x, -steer.z)
		var turn := (4.0 if state == FLEE else 1.6) * dt
		d.yaw += clampf(wrapf(want_yaw - d.yaw, -PI, PI), -turn, turn)
	var acc := 7.0 if state == FLEE else 1.2
	d.speed = move_toward(d.speed, want_speed, acc * dt)
	var fwd := Vector3(-sin(d.yaw), 0, -cos(d.yaw))
	d.pos += fwd * d.speed * dt
	d.pos.y = _terrain.height_at(d.pos.x, d.pos.z)
	_hooves(d, fwd, d.speed * dt)
	# stride: ~1.6 m per walk cycle, ~4.6 m per gallop bound (scaled with the animal)
	var stride := lerpf(1.6, 4.6, smoothstep(2.6, 5.0, d.speed)) * d.scale
	d.phase = fposmod(d.phase + d.speed * dt / stride, 1.0)
	# the head comes up quickly in alarm, goes down slowly
	var hr := 3.5 if d.head_target < d.head else 0.9
	d.head = move_toward(d.head, d.head_target, hr * dt)
	var hf := _terrain.height_at(d.pos.x + fwd.x * 0.85 * d.scale, d.pos.z + fwd.z * 0.85 * d.scale)
	var hb := _terrain.height_at(d.pos.x - fwd.x * 0.85 * d.scale, d.pos.z - fwd.z * 0.85 * d.scale)
	d.pitch = atan2(hf - hb, 1.7 * d.scale) * 0.8

## A grazing deer near Hesper now and then lifts its head, turns it to her and watches,
## standing still, for a few seconds; true while it does.
func _glance(d: Deer, dt: float) -> bool:
	d.glance_t -= dt
	if familiar == null or not familiar.is_inside_tree():
		return false
	var fp := familiar.global_position
	var to := Vector3(fp.x - d.pos.x, 0, fp.z - d.pos.z)
	if to.length() > FAMILIAR_R:
		return false
	if d.glance_t < -12.0 and _rng.randf() < dt * 0.05:
		d.glance_t = _rng.randf_range(2.5, 6.0)
		glances += 1
	if d.glance_t <= 0.0:
		return false
	d.head_target = 0.0
	d.goal = d.pos
	var rel := wrapf(atan2(-to.x, -to.z) - d.yaw, -PI, PI)
	d.head_yaw = clampf(rel, -1.1, 1.1)
	if d.glance_t < 0.1:
		d.look_t = _rng.randf_range(1.0, 3.0)   # back down to the grass soon after
	return true

## Calm grazing: lift the head to chew and look round, then back down to the grass; step
## on to fresh grass near her place in the herd now and then.
func _graze(d: Deer, dt: float) -> void:
	d.look_t -= dt
	if d.look_t < 0.0:
		if d.head_target > 0.5:
			d.head_target = 0.0
			d.look_t = _rng.randf_range(2.0, 5.0)
			d.head_yaw = _rng.randf_range(-0.6, 0.6)
		else:
			d.head_target = 1.0
			d.look_t = _rng.randf_range(5.0, 16.0)
			d.head_yaw = _rng.randf_range(-0.2, 0.2)
	d.step_t -= dt
	var slot := anchor + Vector3(d.slot.x, 0, d.slot.y)
	if d.step_t < 0.0 or d.pos.distance_to(slot) > 9.0:
		d.step_t = _rng.randf_range(6.0, 18.0)
		d.goal = _ground(slot + Vector3(_rng.randfn(0.0, 1.5), 0, _rng.randfn(0.0, 1.5)))

## Press hoof prints behind a moving deer. Walking, the hind foot lands in the fore print
## (direct register), so one slot print per foot pair, alternating sides; at a gallop the
## four hooves land in a group per bound (hinds ahead of the fores), claws splayed, deeper.
func _hooves(d: Deer, fwd: Vector3, moved: float) -> void:
	if _trample == null or moved <= 0.0:
		return
	d.hoof_d += moved
	# the grass along the run is combed over: hard at a gallop, a faint path at a walk
	if d.speed > 0.6:
		d.trail_d += moved
		var gap := lerpf(2.2, 1.5, smoothstep(1.0, 5.0, d.speed)) * d.scale
		if d.trail_d >= gap:
			d.trail_d = 0.0
			_trample.add_herd_point(Vector2(d.pos.x, d.pos.z), Vector2(fwd.x, fwd.z), lerpf(0.35, 1.0, smoothstep(1.0, 6.0, d.speed)))
	var f2 := Vector2(fwd.x, fwd.z)
	var side := Vector2(-fwd.z, fwd.x)
	var L := 0.08 * d.scale
	var at := Vector2(d.pos.x, d.pos.z)
	if d.speed < 4.0:
		var step := 0.8 * d.scale * lerpf(1.0, 1.4, clampf((d.speed - 1.0) / 3.0, 0.0, 1.0))
		if d.hoof_d < step:
			return
		d.hoof_d = 0.0
		d.hoof_side = 1 - d.hoof_side
		var lat := 0.085 * d.scale * (1.0 if d.hoof_side == 0 else -1.0)
		var tr := clampf((d.speed - 1.2) / 2.8, 0.0, 1.0)   # a trot digs in a little more
		_trample.add_hoof(at + side * lat, f2.rotated(lat * 1.2), lerpf(0.6, 0.8, tr), 0.15 * tr, L)
		hoof_prints += 1
	else:
		var bnd := 4.6 * d.scale
		if d.hoof_d < bnd:
			return
		d.hoof_d = 0.0
		d.bound += 1
		galloped.emit(d.pos)
		if d.bound % 2 == 1:   # every other bound: keeps the shared buffer a long trail
			return
		# fore L, fore R, then the hinds landing ahead and wider
		var offs := [Vector2(-0.95, 0.06), Vector2(-0.7, -0.07), Vector2(-0.15, 0.1), Vector2(0.1, -0.11)]
		for o: Vector2 in offs:
			var p := at + f2 * (o.x * d.scale + _rng.randf_range(-0.04, 0.04)) + side * o.y * d.scale
			_trample.add_hoof(p, f2.rotated(_rng.randf_range(-0.15, 0.15)), 1.0, _rng.randf_range(0.7, 1.0), L)
			hoof_prints += 1

func _write_instances() -> void:
	var hi := 0
	var si := 0
	for d: Deer in _deer:
		var b := Basis(Vector3.UP, d.yaw) * Basis(Vector3.RIGHT, d.pitch)
		var mm := _mm_stag if d.stag else _mm
		var i := si if d.stag else hi
		if d.stag:
			si += 1
		else:
			hi += 1
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * d.scale), d.pos - Vector3.UP * 0.03))
		# a deer in (or getting into or out of) its bed stands still: the speed slot then
		# carries -bed for the lying pose in deer.gdshader
		mm.set_instance_custom_data(i, Color(d.phase, -d.bed if d.bed > 0.001 else d.speed / 10.0, d.head, d.head_yaw))

# ---------------------------------------------------------------- mesh

## One red deer hind, about 1.15 m at the shoulder, 2 m nose to tail, facing -Z. `stag`:
## a thick rutting neck and a royal head of antlers (brow, bez, trez and a crown cup).
static func build_mesh(stag := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body + neck: one loft from the rump round to the throat (z, y, half-width, half-height
	# above, below, bend weight)
	var body := [
		[0.76, 1.03, 0.01, 0.01, 0.01, 0.0],
		[0.71, 1.04, 0.11, 0.09, 0.14, 0.0],
		[0.60, 1.04, 0.18, 0.12, 0.215, 0.0],
		[0.42, 1.01, 0.21, 0.13, 0.225, 0.0],
		[0.18, 0.98, 0.225, 0.14, 0.285, 0.0],
		[-0.10, 0.98, 0.225, 0.155, 0.32, 0.0],
		[-0.34, 1.01, 0.195, 0.20, 0.36, 0.0],
		[-0.52, 1.04, 0.16, 0.215, 0.35, 0.0],
		[-0.66, 1.14, 0.135, 0.15, 0.24, 0.15],
		[-0.81, 1.29, 0.11, 0.12, 0.185, 0.4],
		[-0.93, 1.43, 0.092, 0.10, 0.145, 0.65],
		[-1.01, 1.54, 0.08, 0.085, 0.115, 0.9],
		[-1.05, 1.61, 0.06, 0.06, 0.07, 1.0],
	]
	if stag:   # rut neck: swollen, deep-chested, the throat heavy with mane
		for i in range(6, body.size()):
			var w := 1.0 + 0.32 * smoothstep(5.0, 9.0, float(i)) * (1.0 - 0.6 * smoothstep(10.0, 12.0, float(i)))
			body[i][2] *= w
			body[i][3] *= lerpf(1.0, w, 0.6)
			body[i][4] *= w * 1.05
	_loft(st, body, 0.0, 32, 3, 0.0, 0.0, 1)
	if stag:
		for s in [-1.0, 1.0]:
			_antler(st, s)
	var head := [
		[-0.990, 1.665, 0.01, 0.01, 0.01, 1.0],
		[-1.030, 1.660, 0.076, 0.07, 0.10, 1.0],
		[-1.110, 1.625, 0.078, 0.066, 0.115, 1.0],
		[-1.200, 1.570, 0.062, 0.056, 0.09, 1.0],
		[-1.280, 1.515, 0.049, 0.048, 0.068, 1.0],
		[-1.340, 1.475, 0.043, 0.043, 0.054, 1.0],
		[-1.380, 1.452, 0.035, 0.036, 0.042, 1.0],
		[-1.400, 1.446, 0.004, 0.004, 0.004, 1.0],
	]
	_loft(st, head, 0.0, 18, 3, 0.0, 0.0)
	for s in [-1.0, 1.0]:
		# ears: broad, flattened lofts swept up and out from behind the eyes
		var ear := [
			[-1.04, 1.65, 0.014, 0.014, 0.014, 1.0, 0.05],
			[-1.025, 1.70, 0.055, 0.013, 0.013, 1.0, 0.10],
			[-1.005, 1.76, 0.062, 0.011, 0.011, 1.0, 0.155],
			[-0.99, 1.82, 0.04, 0.009, 0.009, 1.0, 0.195],
			[-0.985, 1.85, 0.004, 0.004, 0.004, 1.0, 0.205],
		]
		_loft(st, ear, s, 10, 2, 0.0, 1.0)
		_sphere(st, Vector3(0.064 * s, 1.618, -1.14), 0.018, 1.0, 0.5)
		# legs: (x, y, z, half-width, half-depth front, half-depth back)
		var fore := [
			[0.07, 1.00, -0.40, 0.09, 0.12, 0.11],
			[0.10, 0.84, -0.38, 0.065, 0.085, 0.115],
			[0.12, 0.70, -0.40, 0.056, 0.072, 0.07],
			[0.115, 0.56, -0.41, 0.038, 0.048, 0.044],
			[0.11, 0.45, -0.42, 0.036, 0.04, 0.038],
			[0.11, 0.30, -0.42, 0.021, 0.024, 0.024],
			[0.11, 0.13, -0.42, 0.023, 0.028, 0.026],
			[0.11, 0.06, -0.44, 0.024, 0.03, 0.026],
			[0.11, 0.01, -0.47, 0.025, 0.04, 0.02],
			[0.11, -0.005, -0.475, 0.004, 0.004, 0.004],
		]
		var hind := [
			[0.08, 1.00, 0.40, 0.11, 0.18, 0.15],
			[0.12, 0.84, 0.39, 0.095, 0.16, 0.15],
			[0.135, 0.70, 0.43, 0.068, 0.085, 0.105],
			[0.125, 0.58, 0.48, 0.045, 0.045, 0.068],
			[0.12, 0.51, 0.53, 0.036, 0.032, 0.05],
			[0.115, 0.46, 0.54, 0.03, 0.03, 0.04],
			[0.11, 0.30, 0.52, 0.021, 0.024, 0.025],
			[0.11, 0.13, 0.50, 0.023, 0.028, 0.026],
			[0.11, 0.06, 0.49, 0.024, 0.03, 0.026],
			[0.11, 0.01, 0.46, 0.025, 0.04, 0.02],
			[0.11, -0.005, 0.455, 0.004, 0.004, 0.004],
		]
		_leg(st, fore, s, 0.25 if s > 0 else 0.5, 0.45)
		_leg(st, hind, s, 0.75 if s > 0 else 1.0, 0.46)
	# tail: short, flat, hanging over the rump patch
	var tail := [
		[0.70, 1.04, 0.01, 0.01, 0.01, 0.0],
		[0.75, 1.02, 0.045, 0.025, 0.02, 0.0],
		[0.79, 0.94, 0.04, 0.02, 0.02, 0.0],
		[0.80, 0.88, 0.003, 0.003, 0.003, 0.0],
	]
	_loft(st, tail, 0.0, 10, 3, 0.0, 0.0)
	st.generate_tangents()
	return st.commit()

## One antler (side s): a main beam rising up, out and back from the pedicle and curving
## forward into a crown cup, with brow, bez and trez tines reaching forward over the face.
## Tagged part 0.25 and bend 1.0 so it rides the head through grazing and staring.
static func _antler(st: SurfaceTool, s: float) -> void:
	var beam := [Vector3(0.042, 1.665, -1.075), Vector3(0.085, 1.73, -1.05), Vector3(0.15, 1.84, -0.99),
		Vector3(0.23, 1.99, -0.94), Vector3(0.29, 2.15, -0.95), Vector3(0.31, 2.29, -1.0),
		Vector3(0.30, 2.38, -1.05)]
	_branch(st, beam, 0.03, 0.016, s)
	_branch(st, [Vector3(0.08, 1.72, -1.05), Vector3(0.10, 1.73, -1.15), Vector3(0.12, 1.78, -1.25), Vector3(0.13, 1.85, -1.31)], 0.019, 0.004, s)
	_branch(st, [Vector3(0.12, 1.79, -1.01), Vector3(0.15, 1.81, -1.10), Vector3(0.17, 1.86, -1.19), Vector3(0.18, 1.92, -1.23)], 0.016, 0.004, s)
	_branch(st, [Vector3(0.255, 2.05, -0.94), Vector3(0.28, 2.08, -1.03), Vector3(0.31, 2.13, -1.12), Vector3(0.32, 2.19, -1.16)], 0.016, 0.004, s)
	# crown: the beam splits into a cup of three points
	_branch(st, [Vector3(0.30, 2.36, -1.04), Vector3(0.34, 2.43, -1.10), Vector3(0.37, 2.50, -1.13)], 0.015, 0.003, s)
	_branch(st, [Vector3(0.30, 2.36, -1.04), Vector3(0.28, 2.45, -1.07), Vector3(0.27, 2.54, -1.06)], 0.015, 0.003, s)
	_branch(st, [Vector3(0.30, 2.33, -1.01), Vector3(0.31, 2.41, -0.95), Vector3(0.32, 2.48, -0.92)], 0.013, 0.003, s)

static func _branch(st: SurfaceTool, keys: Array, r0: float, r1: float, s: float) -> void:
	var pts: Array = []
	var rings: Array = []
	var n := keys.size()
	var sub := 4
	for i in n - 1:
		for j in sub:
			var t := float(j) / sub
			var q: Vector3 = keys[i].cubic_interpolate(keys[i + 1], keys[maxi(i - 1, 0)], keys[mini(i + 2, n - 1)], t)
			pts.append(q)
	pts.append(keys[n - 1])
	for i in pts.size():
		var f := float(i) / (pts.size() - 1)
		var r := lerpf(r0, r1, pow(f, 0.8)) * 1.35 * (1.0 + 0.25 * smoothstep(0.08, 0.0, f))   # burr at the base
		pts[i] = Vector3(pts[i].x * s, pts[i].y, pts[i].z)
		rings.append([0, 0, r, r * 0.92, r * 0.92, 1.0])
	_tube(st, pts, rings, 8, s, 0.0, -1.0, 0.25, false)

## Loft rings through `keys` (z, y, hw, hu, hd, bend[, x]) in the YZ plane; each ring is a
## half-ellipse above (hu) and below (hd) the path, hw wide. Keys are resampled with cubic
## interpolation, `sub` rings per span.
## `muscle`: 0 plain, 1 deer landmarks, 2 fox landmarks, 3 plain with grid normals.
static func _loft(st: SurfaceTool, keys: Array, side: float, seg: int, sub: int, leg: float, part: float, muscle := 0) -> void:
	var rings: Array = []
	for i in keys.size() - 1:
		var k0: Array = keys[maxi(i - 1, 0)]
		var k1: Array = keys[i]
		var k2: Array = keys[i + 1]
		var k3: Array = keys[mini(i + 2, keys.size() - 1)]
		for j in sub:
			var t := float(j) / sub
			var r := []
			for c in k1.size():
				r.append(cubic_interpolate(k1[c], k2[c], k0[c], k3[c], t))
			rings.append(r)
	rings.append(keys[keys.size() - 1])
	var pts: Array = []
	for r: Array in rings:
		var x: float = r[6] if r.size() > 6 else 0.0
		pts.append(Vector3(x * side, r[1], r[0]))
	_tube(st, pts, rings, seg, side, leg, -1.0, part, true, muscle)

static func _leg(st: SurfaceTool, keys: Array, side: float, leg: float, knee_y: float, seg := 12, sub := 3) -> void:
	var pts: Array = []
	var rings: Array = []
	for i in keys.size() - 1:
		var k0: Array = keys[maxi(i - 1, 0)]
		var k1: Array = keys[i]
		var k2: Array = keys[i + 1]
		var k3: Array = keys[mini(i + 2, keys.size() - 1)]
		for j in sub:
			var t := float(j) / sub
			var r := []
			for c in k1.size():
				r.append(cubic_interpolate(k1[c], k2[c], k0[c], k3[c], t))
			rings.append(r)
	rings.append(keys[keys.size() - 1])
	var rr: Array = []
	for r: Array in rings:
		pts.append(Vector3(r[0] * side, r[1], r[2]))
		rr.append([0, 0, r[3], r[4], r[5], 0.0])
	_tube(st, pts, rr, seg, side, leg, knee_y, 0.0, false, 3 if sub > 3 else 0)

## Sweep ellipse rings along `pts`. Ring frame: X across, u = perpendicular to the path in YZ
## (up for a forward path, forward for a downward one).
static func _tube(st: SurfaceTool, pts: Array, rings: Array, seg: int, side: float, leg: float, knee_y: float, part: float, mirror_x: bool, muscle := 0) -> void:
	var n := pts.size()
	var verts: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var tng: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var u := Vector3(0, -tng.z, tng.y).normalized()
		if u.length() < 0.5:
			u = Vector3.UP
		var r: Array = rings[i]
		var row := []
		for k in seg + 1:
			var a := TAU * k / seg
			var ca := cos(a)
			var sa := sin(a)
			var hu: float = r[3] if sa > 0.0 else r[4]
			var q: Vector3 = p + Vector3(ca * float(r[2]), 0, 0) + u * sa * hu
			var nn := (Vector3(ca / maxf(float(r[2]), 0.001), 0, 0) + u * sa / maxf(hu, 0.001)).normalized()
			var low := 0.0
			if knee_y > -0.5:
				low = smoothstep(knee_y + 0.04, knee_y - 0.04, q.y)
			var col := Color(leg, low, float(r[5]), part)
			row.append([q, nn, col, Vector2(float(k) / seg, float(i) / (n - 1))])
		verts.append(row)
	if muscle == 1:
		_sculpt(verts, n, seg)
	elif muscle == 2:
		_sculpt_fox(verts, n, seg)
	elif muscle == 3:
		_grid_normals(verts, n, seg)
	for i in n - 1:
		for k in seg:
			var a: Array = verts[i][k]
			var b: Array = verts[i][k + 1]
			var c: Array = verts[i + 1][k]
			var d: Array = verts[i + 1][k + 1]
			# winding: counter-clockwise seen from outside (Godot front faces are CW in
			# screen space, so emit a, c, b)
			for v: Array in [a, b, c, b, d, c]:
				st.set_normal(v[1])
				st.set_color(v[2])
				st.set_uv(v[3])
				st.add_vertex(v[0])

## Body landmarks on the barrel loft: shoulder blade and the triceps mass over the foreleg,
## the rounded haunch and stifle over the hind leg, a hollow in the flank between them and
## a faint rib swell. Pushes the sides out along X, then rebuilds normals from the grid.
static func _sculpt(verts: Array, n: int, seg: int) -> void:
	for i in n:
		for k in seg + 1:
			var v: Array = verts[i][k]
			var q: Vector3 = v[0]
			var nn: Vector3 = v[1]
			var d := 0.05 * _bump(q.z + 0.37 - (q.y - 1.1) * 0.35, q.y - 1.10, 0.11, 0.16)   # scapula, sloping forward-down
			d += 0.035 * _bump(q.z + 0.29, q.y - 0.84, 0.09, 0.08)   # triceps over the elbow
			d += 0.06 * _bump(q.z - 0.47, q.y - 0.99, 0.17, 0.15)   # haunch
			d += 0.03 * _bump(q.z - 0.32, q.y - 0.79, 0.08, 0.08)    # stifle / thigh front
			d -= 0.04 * _bump(q.z - 0.13, q.y - 0.88, 0.10, 0.09)   # flank hollow
			d += 0.012 * _bump(q.z + 0.06, q.y - 0.92, 0.17, 0.12)   # rib barrel
			d -= 0.022 * _bump(q.z + 0.19 - (q.y - 1.1) * 0.35, q.y - 1.0, 0.045, 0.13)   # groove behind the blade
			var lat := smoothstep(0.0, 0.75, absf(nn.x))
			v[0] = q + Vector3(signf(nn.x) * d * lat * 2.0, 0, 0)
	_grid_normals(verts, n, seg)

## The fox's landmarks at its scale: shoulder blades and the elbow mass over the forelegs,
## round haunches over the hind legs, a slight hollow at the loin between them, so the barrel
## stops reading as a smooth tube from the side and a sat fox gets its haunch bulge.
static func _sculpt_fox(verts: Array, n: int, seg: int) -> void:
	for i in n:
		for k in seg + 1:
			var v: Array = verts[i][k]
			var q: Vector3 = v[0]
			var nn: Vector3 = v[1]
			var d := 0.010 * _bump(q.z + 0.17 - (q.y - 0.42) * 0.4, q.y - 0.41, 0.045, 0.05)   # scapula
			d += 0.008 * _bump(q.z + 0.15, q.y - 0.33, 0.04, 0.035)   # elbow / triceps
			d += 0.014 * _bump(q.z - 0.235, q.y - 0.39, 0.06, 0.05)   # haunch
			d += 0.006 * _bump(q.z - 0.18, q.y - 0.32, 0.035, 0.035)   # stifle
			d -= 0.007 * _bump(q.z - 0.06, q.y - 0.35, 0.05, 0.045)   # loin / flank hollow
			var lat := smoothstep(0.0, 0.75, absf(nn.x))
			v[0] = q + Vector3(signf(nn.x) * d * lat, 0, 0)
	_grid_normals(verts, n, seg)

## Normals from the vertex grid (along the path x around the ring), so tapers and sculpted
## bulges shade with their real slope instead of the ring's flat ellipse normal.
static func _grid_normals(verts: Array, n: int, seg: int) -> void:
	for i in n:
		for k in seg + 1:
			var v: Array = verts[i][k]
			var a: Vector3 = verts[mini(i + 1, n - 1)][k][0] - verts[maxi(i - 1, 0)][k][0]
			var b: Vector3 = verts[i][(k + 1) % seg][0] - verts[i][(k - 1 + seg) % seg][0]
			var nn := a.cross(b)
			if nn.length() < 1e-6:
				continue
			nn = nn.normalized()
			if nn.dot(v[1]) < 0.0:
				nn = -nn
			v[1] = nn

static func _bump(dz: float, dy: float, sz: float, sy: float) -> float:
	return exp(-(dz * dz) / (sz * sz) - (dy * dy) / (sy * sy))

static func _sphere(st: SurfaceTool, c: Vector3, r: float, bend: float, part: float) -> void:
	var seg := 10
	for i in seg:
		for k in seg:
			var quad := []
			for o in [[0, 0], [0, 1], [1, 0], [1, 1]]:
				var th := PI * float(i + o[0]) / seg
				var ph := TAU * float(k + o[1]) / seg
				var nn := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				quad.append(nn)
			for nn: Vector3 in [quad[0], quad[2], quad[1], quad[1], quad[2], quad[3]]:
				st.set_normal(nn)
				st.set_color(Color(0, 0, bend, part))
				st.set_uv(Vector2.ZERO)
				st.add_vertex(c + nn * r)
