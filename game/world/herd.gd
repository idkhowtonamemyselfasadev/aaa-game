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
@export var alert_radius: float = 42.0     # heads up (+2 m per m/s the threat moves)
@export var flee_radius: float = 24.0      # bolt (+2 m per m/s)
@export var safe_radius: float = 85.0      # stop running this far from the threat
@export var seed: int = 4242

enum { CALM, ALERT, FLEE }

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _mm: MultiMesh
var _deer: Array = []
var _obstacles: Array[Vector3] = []
var state := CALM
var anchor := Vector3.ZERO       # herd centre the deer graze round
var _wander := Vector3.ZERO
var _flee_dir := Vector3.ZERO
var _calm_t := 0.0
var _alert_t := 0.0
var _threat_prev := {}
var threat_pos := Vector3.ZERO
var flee_events := 0             # bots read these
var alert_events := 0

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

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_rng.seed = seed
	var flora: Flora = get_node_or_null("../Flora")
	if flora:
		_obstacles.append_array(flora.tree_positions)
		_obstacles.append_array(flora.rock_positions)
	anchor = _pick_site()
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
	for i in hinds + calves:
		var d := Deer.new()
		var calf := i >= hinds
		d.scale = _rng.randf_range(0.6, 0.68) if calf else _rng.randf_range(0.92, 1.04)
		d.slot = Vector2(_rng.randfn(0.0, 4.5), _rng.randfn(0.0, 4.5))
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
	# clamped, so the herd keeps real time; only a hitch over 0.2 s loses time
	var th := _threat(maxf(delta, 0.001))
	var steps := clampi(ceili(delta * 30.0), 1, 6)
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
				var tang := dir.cross(Vector3.UP)
				if tang.dot(-probe) < 0.0:
					tang = -tang
				dir = (dir * 0.3 + tang).normalized()
			_flee_dir = _flee_dir.lerp(dir, minf(1.0, dt * 1.5)).normalized()
			var lead := 11.5 if dist < safe_radius else maxf(0.0, 11.5 - (dist - safe_radius) * 0.6)
			anchor = _ground(anchor + _flee_dir * lead * dt)
			if dist > safe_radius + 15.0:
				state = CALM
				_wander = _flee_dir
				for d: Deer in _deer:
					d.look_t = _rng.randf_range(3.0, 10.0)
	for d: Deer in _deer:
		_update_deer(d, dt, tp)
	_write_instances()

func _bolt(from: Vector3) -> void:
	state = FLEE
	flee_events += 1
	var c := centre()
	_flee_dir = Vector3(c.x - from.x, 0, c.z - from.z).normalized().rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4))
	anchor = _ground(c)
	for d: Deer in _deer:
		d.head_target = 0.0

func _update_deer(d: Deer, dt: float, tp: Vector3) -> void:
	var want_speed := 0.0
	var target := d.goal
	match state:
		CALM:
			d.look_t -= dt
			if d.look_t < 0.0:
				# lift the head to chew and look round, then back down to the grass
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
			target = d.goal
			if Vector2(target.x - d.pos.x, target.z - d.pos.z).length() > 0.6:
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
			target = anchor + Vector3(d.slot.x, 0, d.slot.y) * 0.8 + _flee_dir * 4.0
			var dist := Vector2(tp.x - d.pos.x, tp.z - d.pos.z).length()
			want_speed = d.gait if dist < safe_radius else lerpf(d.gait, 2.2, clampf((dist - safe_radius) / 15.0, 0.0, 1.0))
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
	# stride: ~1.6 m per walk cycle, ~4.6 m per gallop bound (scaled with the animal)
	var stride := lerpf(1.6, 4.6, smoothstep(2.6, 5.0, d.speed)) * d.scale
	d.phase = fposmod(d.phase + d.speed * dt / stride, 1.0)
	# the head comes up quickly in alarm, goes down slowly
	var hr := 3.5 if d.head_target < d.head else 0.9
	d.head = move_toward(d.head, d.head_target, hr * dt)
	var hf := _terrain.height_at(d.pos.x + fwd.x * 0.85 * d.scale, d.pos.z + fwd.z * 0.85 * d.scale)
	var hb := _terrain.height_at(d.pos.x - fwd.x * 0.85 * d.scale, d.pos.z - fwd.z * 0.85 * d.scale)
	d.pitch = atan2(hf - hb, 1.7 * d.scale) * 0.8

func _write_instances() -> void:
	for i in _deer.size():
		var d: Deer = _deer[i]
		var b := Basis(Vector3.UP, d.yaw) * Basis(Vector3.RIGHT, d.pitch)
		_mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * d.scale), d.pos - Vector3.UP * 0.03))
		_mm.set_instance_custom_data(i, Color(d.phase, d.speed / 10.0, d.head, d.head_yaw))

# ---------------------------------------------------------------- mesh

## One red deer hind, about 1.15 m at the shoulder, 2 m nose to tail, facing -Z.
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body + neck: one loft from the rump round to the throat (z, y, half-width, half-height
	# above, below, bend weight)
	var body := [
		[0.76, 1.03, 0.01, 0.01, 0.01, 0.0],
		[0.71, 1.04, 0.11, 0.09, 0.14, 0.0],
		[0.60, 1.04, 0.18, 0.12, 0.24, 0.0],
		[0.42, 1.01, 0.21, 0.13, 0.29, 0.0],
		[0.18, 0.98, 0.225, 0.14, 0.30, 0.0],
		[-0.10, 0.98, 0.225, 0.155, 0.31, 0.0],
		[-0.34, 1.01, 0.195, 0.195, 0.34, 0.0],
		[-0.52, 1.04, 0.155, 0.20, 0.31, 0.0],
		[-0.66, 1.14, 0.135, 0.15, 0.24, 0.15],
		[-0.81, 1.29, 0.11, 0.12, 0.185, 0.4],
		[-0.93, 1.43, 0.092, 0.10, 0.145, 0.65],
		[-1.01, 1.54, 0.08, 0.085, 0.115, 0.9],
		[-1.05, 1.61, 0.06, 0.06, 0.07, 1.0],
	]
	_loft(st, body, 0.0, 24, 3, 0.0, 0.0)
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
			[0.12, 0.70, -0.40, 0.05, 0.06, 0.062],
			[0.115, 0.56, -0.41, 0.035, 0.042, 0.04],
			[0.11, 0.45, -0.42, 0.036, 0.04, 0.038],
			[0.11, 0.30, -0.42, 0.021, 0.024, 0.024],
			[0.11, 0.13, -0.42, 0.023, 0.028, 0.026],
			[0.11, 0.06, -0.44, 0.024, 0.03, 0.026],
			[0.11, 0.01, -0.47, 0.025, 0.04, 0.02],
			[0.11, -0.005, -0.475, 0.004, 0.004, 0.004],
		]
		var hind := [
			[0.08, 1.00, 0.40, 0.11, 0.18, 0.15],
			[0.12, 0.86, 0.38, 0.088, 0.15, 0.14],
			[0.135, 0.70, 0.42, 0.06, 0.06, 0.09],
			[0.125, 0.58, 0.48, 0.042, 0.04, 0.06],
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

## Loft rings through `keys` (z, y, hw, hu, hd, bend[, x]) in the YZ plane; each ring is a
## half-ellipse above (hu) and below (hd) the path, hw wide. Keys are resampled with cubic
## interpolation, `sub` rings per span.
static func _loft(st: SurfaceTool, keys: Array, side: float, seg: int, sub: int, leg: float, part: float) -> void:
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
	_tube(st, pts, rings, seg, side, leg, -1.0, part, true)

static func _leg(st: SurfaceTool, keys: Array, side: float, leg: float, knee_y: float) -> void:
	var pts: Array = []
	var rings: Array = []
	for i in keys.size() - 1:
		var k0: Array = keys[maxi(i - 1, 0)]
		var k1: Array = keys[i]
		var k2: Array = keys[i + 1]
		var k3: Array = keys[mini(i + 2, keys.size() - 1)]
		for j in 3:
			var t := j / 3.0
			var r := []
			for c in k1.size():
				r.append(cubic_interpolate(k1[c], k2[c], k0[c], k3[c], t))
			rings.append(r)
	rings.append(keys[keys.size() - 1])
	var rr: Array = []
	for r: Array in rings:
		pts.append(Vector3(r[0] * side, r[1], r[2]))
		rr.append([0, 0, r[3], r[4], r[5], 0.0])
	_tube(st, pts, rr, 12, side, leg, knee_y, 0.0, false)

## Sweep ellipse rings along `pts`. Ring frame: X across, u = perpendicular to the path in YZ
## (up for a forward path, forward for a downward one).
static func _tube(st: SurfaceTool, pts: Array, rings: Array, seg: int, side: float, leg: float, knee_y: float, part: float, mirror_x: bool) -> void:
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
