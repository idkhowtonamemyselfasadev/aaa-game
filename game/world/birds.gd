class_name Birds
extends Node3D
## Wildlife, first pass (DESIGN §8): rook flocks that feed on the meadow, hop and peck, and
## burst into the air when the player comes close (the nearest birds react first), wheel
## overhead for a while, then glide down onto another clear patch. A pair of red kites
## soars high over the vale by day. All geometry is procedural (one bird mesh, posed per
## instance in bird.gdshader through INSTANCE_CUSTOM).
## Rooks roost together: at dusk each flock lifts off the meadow in ones and twos, streams to
## the rookery (a few oaks in the densest grove), wheels over it and settles into the upper
## crowns for the night; a player walking under the rookery puts them up, they circle and
## settle again. At dawn they leave for the feeding grounds.

@export var terrain_path: NodePath
@export var flock_count: int = 3
@export var birds_per_flock: int = 14
@export var kite_count: int = 2
@export var scare_radius: float = 11.0       # +1.4 m per m/s the threat moves
@export var seed: int = 777
@export var roost_hour: float = 17.8         # flocks head for the rookery from here (+0..0.6 h)
@export var leave_hour: float = 5.6          # and leave it from here (+0..0.5 h)
@export var roost_scare_radius: float = 9.0  # a player this close under the rookery puts them up

enum { GROUND, AIR, LANDING, PERCH }

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _sites: Array[Vector3] = []
var _flocks: Array = []
var _kites: Array = []
var _rook_mm: MultiMesh
var _kite_mm: MultiMesh
var _kite_mmi: MultiMeshInstance3D
var _threat_prev := {}
var scatter_events := 0      # bots read this
var landings := 0
var roost_landings := 0
var rookery := Vector3.ZERO  # centre of the roost trees (ground level)
var rookery_trees: Array[int] = []
var _first := true
var _t := 0.0

class Bird:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var state := 0
	var delay := 0.0
	var phase := 0.0          # wing-beat phase
	var flap := 0.0           # current wing angle
	var fold := 1.0
	var legs := 1.0
	var peck := 0.0
	var peck_t := 0.0
	var hop_t := 0.0
	var hop_to := Vector3.ZERO
	var off := Vector3.ZERO   # slot in the wheeling flock
	var ground_off := Vector2.ZERO
	var roll := 0.0
	var perch := Vector3.ZERO # roost spot in a crown
	var shuffle_t := 0.0

class Flock:
	var site := 0
	var state := 0
	var birds: Array = []
	var air_t := 0.0
	var anchor := Vector3.ZERO
	var idle_t := 0.0
	var roost := false        # heading for / sitting in the rookery
	var jit := 0.0            # per-flock lag on the roost/leave hours

func _ready() -> void:
	_terrain = get_node(terrain_path)
	_rng.seed = seed
	_pick_sites()
	var mesh := _build_bird_mesh()
	var shader: Shader = load("res://shaders/bird.gdshader")
	var rook := ShaderMaterial.new()
	rook.shader = shader
	var kite := ShaderMaterial.new()
	kite.shader = shader
	kite.set_shader_parameter("plumage", Color(0.30, 0.13, 0.05))
	kite.set_shader_parameter("sheen", Color(0.05, 0.03, 0.01))
	kite.set_shader_parameter("beak_col", Color(0.75, 0.62, 0.25))
	kite.set_shader_parameter("bar_col", Color(0.04, 0.035, 0.03))
	kite.set_shader_parameter("roughness", 0.6)
	_rook_mm = _make_mm(mesh, rook, flock_count * birds_per_flock, "Rooks")
	_kite_mm = _make_mm(mesh, kite, kite_count, "Kites")
	_kite_mmi = get_node("Kites")
	for f in flock_count:
		var fl := Flock.new()
		fl.site = f % _sites.size()
		fl.idle_t = _rng.randf_range(60.0, 150.0)
		fl.jit = _rng.randf()
		for i in birds_per_flock:
			var b := Bird.new()
			b.ground_off = Vector2(_rng.randfn(0.0, 2.2), _rng.randfn(0.0, 2.2))
			b.pos = _ground(_sites[fl.site] + Vector3(b.ground_off.x, 0, b.ground_off.y))
			b.hop_to = b.pos
			b.yaw = _rng.randf() * TAU
			b.peck_t = _rng.randf() * 2.0
			b.hop_t = _rng.randf() * 3.0
			b.phase = _rng.randf() * TAU
			b.off = Vector3(_rng.randfn(0.0, 3.5), _rng.randfn(0.0, 1.5), _rng.randfn(0.0, 3.5))
			fl.birds.append(b)
		_flocks.append(fl)
	for k in kite_count:
		var b := Bird.new()
		b.phase = _rng.randf() * TAU
		b.off = Vector3(_rng.randf_range(-60, 60), _rng.randf_range(70, 95), _rng.randf_range(-60, 60))
		b.fold = 0.0
		b.legs = 0.0
		_kites.append(b)
	_pick_rookery()
	_write_instances()

## The rookery: the oak with the most neighbours inside 22 m (a proper grove, out of the
## village), plus its nearest trees; each rook gets its own perch in their upper crowns.
func _pick_rookery() -> void:
	var flora: Flora = get_node_or_null("../Flora")
	if flora == null or flora.tree_positions.is_empty():
		return
	var tp := flora.tree_positions
	var best := 0
	var best_s := -INF
	for i in tp.size():
		var q := tp[i]
		var n := 0
		for o in tp:
			if Vector2(o.x - q.x, o.z - q.z).length() < 22.0:
				n += 1
		var d := Vector2(q.x, q.z).length()
		var s := float(n) - (0.0 if d > 60.0 and d < 180.0 else 100.0)
		if s > best_s:
			best_s = s
			best = i
	var order := range(tp.size())
	var c := tp[best]
	order.sort_custom(func(a, b): return tp[a].distance_squared_to(c) < tp[b].distance_squared_to(c))
	var perches: Array[Vector3] = []
	for k in mini(5, order.size()):
		rookery_trees.append(order[k])
		rookery += tp[order[k]]
		for q in flora.perch_points(order[k]):
			perches.append(q + Vector3.UP * 0.32)   # on top of the sprig, not inside it
	rookery /= rookery_trees.size()
	# spread the birds over the perches; double up (a neighbour's twig) if there are too few
	var bag := perches.duplicate()
	var k2 := 0
	for fl: Flock in _flocks:
		for b: Bird in fl.birds:
			if bag.is_empty():
				bag = perches.duplicate()
			var j := _rng.randi() % bag.size()
			b.perch = bag[j] + (Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)) if k2 >= perches.size() else Vector3.ZERO)
			bag.remove_at(j)
			k2 += 1

func is_night_for(fl: Flock) -> bool:
	var tod = get_parent().get("time_of_day")
	if tod == null or rookery_trees.is_empty():
		return false
	return tod >= roost_hour + fl.jit * 0.6 or tod < leave_hour + fl.jit * 0.5

## Snap a flock onto its perches (night at load time, tests).
func settle_roost(fl: Flock) -> void:
	fl.roost = true
	fl.state = PERCH
	for b: Bird in fl.birds:
		b.state = PERCH
		b.pos = b.perch
		b.vel = Vector3.ZERO
		b.fold = 1.0
		b.legs = 1.0
		b.flap = 0.0
		b.roll = 0.0
		b.yaw = _rng.randf() * TAU

## Lift a flock off gently (not a scare): birds go up in ones and twos over a few seconds
## and fly to `anchor`, where the flock wheels before it lands.
func _lift(fl: Flock, anchor: Vector3, roost: bool) -> void:
	fl.roost = roost
	fl.state = AIR
	fl.air_t = _rng.randf_range(5.0, 8.0)
	fl.anchor = anchor
	for b: Bird in fl.birds:
		b.state = AIR
		b.delay = _rng.randf() * 3.5
		var dir := Vector3(anchor.x - b.pos.x, 0, anchor.z - b.pos.z).normalized()
		b.vel = dir * _rng.randf_range(1.5, 3.0) + Vector3.UP * _rng.randf_range(2.5, 4.0)

func census() -> Dictionary:
	var c := {"ground": 0, "air": 0, "landing": 0, "perch": 0}
	for fl: Flock in _flocks:
		for b: Bird in fl.birds:
			c[["ground", "air", "landing", "perch"][b.state]] += 1
	return c

func bird_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for fl: Flock in _flocks:
		for b: Bird in fl.birds:
			out.append(b.pos)
	return out

## Open meadow patches away from trees and rocks where a flock can feed.
func _pick_sites() -> void:
	var flora: Flora = get_node_or_null("../Flora")
	var cand := [Vector3(22, 0, 9), Vector3(-20, 0, -26), Vector3(-44, 0, 22), Vector3(12, 0, -46),
		Vector3(36, 0, 40), Vector3(62, 0, -28), Vector3(-70, 0, -50), Vector3(-10, 0, 60)]
	for c: Vector3 in cand:
		var ok := true
		if flora:
			for t in flora.tree_positions:
				if Vector2(t.x - c.x, t.z - c.z).length() < 9.0:
					ok = false
					break
		if ok and _terrain.normal_at(c.x, c.z).y > 0.93:
			_sites.append(c)
	if _sites.is_empty():
		_sites.append(Vector3.ZERO)
	var grass: GrassField = get_node_or_null("../Grass")
	if grass:
		grass.cropped_spots.append_array(_sites)

func site_positions() -> Array[Vector3]:
	return _sites

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _terrain.height_at(p.x, p.z), p.z)

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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# instances roam far from the node origin; keep the whole sky in the cull box
	mmi.custom_aabb = AABB(Vector3(-400, -50, -400), Vector3(800, 400, 800))
	add_child(mmi)
	return mm

# ---------------------------------------------------------------- simulation

func _threats(dt: float) -> Array:
	var out := []
	var nodes := []
	var pl := get_node_or_null("../Player")
	if pl:
		nodes.append(pl)
	var cam := get_viewport().get_camera_3d()
	if cam:
		nodes.append(cam)
	for n: Node3D in nodes:
		var p := n.global_position
		var prev: Vector3 = _threat_prev.get(n.get_instance_id(), p)
		_threat_prev[n.get_instance_id()] = p
		var spd := minf(Vector2(p.x - prev.x, p.z - prev.z).length() / maxf(dt, 0.001), 12.0)
		out.append([p, spd])   # horizontal speed only: a player landing from a jump is not a charge
	return out

func _process(delta: float) -> void:
	# clamp: slow software-rendered frames (screenshots) must not teleport birds
	var dt := minf(delta, 1.0 / 30.0)
	_t += dt
	var threats := _threats(dt)
	if _first:
		_first = false
		for fl: Flock in _flocks:
			if is_night_for(fl):
				settle_roost(fl)
	for fl: Flock in _flocks:
		_update_flock(fl, dt, threats)
	var tod = get_parent().get("time_of_day")
	_kite_mmi.visible = tod == null or (tod > 6.5 and tod < 19.0)   # kites roost at night
	for b: Bird in _kites:
		_update_kite(b, dt)
	_write_instances()

## Scare the flock away from `from` (also used by tests and spontaneous take-offs).
func scatter(fl: Flock, from: Vector3) -> void:
	if fl.state == AIR:
		return
	var away := Vector3(fl.birds[0].pos.x - from.x, 0, fl.birds[0].pos.z - from.z)
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	var base := rookery + Vector3.UP * 12.0 if fl.state == PERCH else _sites[fl.site]
	fl.state = AIR
	fl.air_t = _rng.randf_range(8.0, 13.0)
	fl.anchor = base + away * 22.0 + Vector3.UP * 14.0
	scatter_events += 1
	for b: Bird in fl.birds:
		var d := b.pos.distance_to(from)
		b.state = AIR
		b.delay = clampf((d - 3.0) * 0.05, 0.0, 0.5) + _rng.randf() * 0.18
		var dir := (Vector3(b.pos.x - from.x, 0, b.pos.z - from.z).normalized() * 0.6 + away * 0.4).normalized()
		b.vel = dir * _rng.randf_range(2.5, 4.0) + Vector3.UP * _rng.randf_range(3.5, 5.0)

func _update_flock(fl: Flock, dt: float, threats: Array) -> void:
	var site := _sites[fl.site]
	var night := is_night_for(fl)
	if fl.state == GROUND and night:
		_lift(fl, rookery + Vector3.UP * 20.0, true)
	elif fl.state == PERCH:
		if not night:
			fl.site = _landing_site(fl, threats)
			_lift(fl, _sites[fl.site] + Vector3.UP * 16.0, false)
		else:
			for th: Array in threats:
				var tp: Vector3 = th[0]
				if Vector2(tp.x - rookery.x, tp.z - rookery.z).length() < roost_scare_radius + 1.4 * float(th[1]) + 6.0:
					scatter(fl, tp)
					break
	elif fl.state == GROUND:
		fl.idle_t -= dt
		for th: Array in threats:
			var tp: Vector3 = th[0]
			if Vector2(tp.x - site.x, tp.z - site.z).length() < scare_radius + 1.4 * float(th[1]) + 3.0:
				scatter(fl, tp)
				break
		if fl.state == GROUND and fl.idle_t < 0.0:
			# rooks lift off now and then for no reason a player can see
			fl.idle_t = _rng.randf_range(70.0, 160.0)
			scatter(fl, site + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)))
	elif fl.state == AIR:
		fl.air_t -= dt
		if fl.air_t < 0.0:
			fl.roost = night
			if not night:
				fl.site = _landing_site(fl, threats)
			fl.state = LANDING
	var all_down := true
	for b: Bird in fl.birds:
		match b.state:
			GROUND:
				_ground_bird(b, dt)
			PERCH:
				_perch_bird(b, dt)
			AIR:
				all_down = false
				_air_bird(b, fl, dt)
			LANDING:
				all_down = false
				_land_bird(b, fl, dt)
		if fl.state == LANDING and b.state == AIR:
			b.state = LANDING
	if fl.state == LANDING and all_down:
		fl.state = PERCH if fl.roost else GROUND
		fl.idle_t = _rng.randf_range(70.0, 160.0)
		landings += 1
		if fl.roost:
			roost_landings += 1

func _landing_site(fl: Flock, threats: Array) -> int:
	var best := fl.site
	var best_s := -INF
	for i in _sites.size():
		var s := _sites[i]
		var clear := INF
		for th: Array in threats:
			clear = minf(clear, Vector2(th[0].x - s.x, th[0].z - s.z).length())
		var taken := false
		for o: Flock in _flocks:
			if o != fl and o.site == i:
				taken = true
		var score := minf(clear, 60.0) - s.distance_to(fl.anchor) * 0.3 - (40.0 if taken else 0.0) + _rng.randf() * 6.0
		if score > best_s:
			best_s = score
			best = i
	return best

func _ground_bird(b: Bird, dt: float) -> void:
	b.fold = move_toward(b.fold, 1.0, dt * 4.0)
	b.legs = move_toward(b.legs, 1.0, dt * 5.0)
	b.flap = move_toward(b.flap, 0.0, dt * 6.0)
	b.roll = 0.0
	b.vel = Vector3.ZERO
	# walk/hop toward a nearby spot, then peck a few times
	b.hop_t -= dt
	if b.hop_t < 0.0:
		b.hop_t = _rng.randf_range(1.5, 4.5)
		var tgt := b.pos + Vector3(_rng.randfn(0.0, 0.6), 0, _rng.randfn(0.0, 0.6))
		b.hop_to = _ground(tgt)
	var to := b.hop_to - b.pos
	to.y = 0.0
	var moving := to.length() > 0.03
	if moving:
		b.yaw = lerp_angle(b.yaw, atan2(-to.x, -to.z), dt * 8.0)
		b.pos += to.normalized() * minf(to.length(), 0.45 * dt)
		b.pos.y = _terrain.height_at(b.pos.x, b.pos.z) + absf(sin(_t * 9.0 + b.phase)) * 0.025
	b.peck_t -= dt
	if b.peck_t < 0.0 and not moving:
		b.peck_t = _rng.randf_range(0.6, 2.5)
	var pk := clampf(1.0 - absf(b.peck_t - 0.2) * 5.0, 0.0, 1.0)
	b.peck = pk * 0.9 - (0.15 if moving else 0.0)

## Sitting in the crown: wings folded, now and then a shuffle round on the twig or a preen.
func _perch_bird(b: Bird, dt: float) -> void:
	b.fold = move_toward(b.fold, 1.0, dt * 4.0)
	b.legs = move_toward(b.legs, 1.0, dt * 5.0)
	b.flap = move_toward(b.flap, 0.0, dt * 6.0)
	b.roll = 0.0
	b.vel = Vector3.ZERO
	b.shuffle_t -= dt
	if b.shuffle_t < 0.0:
		b.shuffle_t = _rng.randf_range(3.0, 12.0)
		b.hop_t = b.yaw + _rng.randf_range(-1.2, 1.2)
	b.yaw = lerp_angle(b.yaw, b.hop_t, dt * 3.0)
	# head tucked down a little; a short preen dip after each shuffle
	var pr := clampf(1.0 - absf(b.shuffle_t - 1.0) * 2.0, 0.0, 1.0)
	b.peck = -0.15 + pr * 0.5
	b.pos = b.perch + Vector3.UP * absf(sin(_t * 1.3 + b.phase)) * 0.01

func _air_bird(b: Bird, fl: Flock, dt: float) -> void:
	if b.delay > 0.0:
		b.delay -= dt
		b.peck = move_toward(b.peck, -0.2, dt * 4.0)
		return
	b.fold = move_toward(b.fold, 0.0, dt * 6.0)
	b.legs = move_toward(b.legs, 0.0, dt * 2.5)
	b.peck = move_toward(b.peck, 0.0, dt * 3.0)
	var t := _t * 0.35 + b.phase
	var wheel := fl.anchor + Vector3(cos(_t * 0.22 + fl.site) * 14.0, 0, sin(_t * 0.22 + fl.site) * 14.0)
	var tgt := wheel + b.off.rotated(Vector3.UP, t) + Vector3(0, sin(t * 1.7) * 1.5, 0)
	var climbing := b.vel.y > 1.0
	_steer(b, tgt, 9.0, 9.0, dt)
	var beat := 7.0 if climbing else (4.2 if sin(t * 2.3) > -0.4 else 0.0)
	_wings(b, beat, 0.95 if climbing else 0.75, dt)

func _land_bird(b: Bird, fl: Flock, dt: float) -> void:
	var tgt := b.perch if fl.roost else _ground(_sites[fl.site] + Vector3(b.ground_off.x, 0, b.ground_off.y))
	var d := b.pos.distance_to(tgt)
	if d < 0.35:
		if fl.roost:
			b.state = PERCH
			b.pos = tgt
			b.hop_t = b.yaw
			b.shuffle_t = _rng.randf_range(1.0, 8.0)
			return
		b.state = GROUND
		b.pos = tgt
		b.hop_to = tgt
		b.hop_t = _rng.randf_range(0.5, 2.0)
		return
	# glide in on a shallow path, flare (fast beats, legs down) over the last few metres
	var approach := tgt + Vector3.UP * clampf(d * 0.25, 0.0, 6.0)
	_steer(b, approach if d > 4.0 else tgt, clampf(d * 0.9, 1.5, 9.0), 12.0, dt)
	b.fold = move_toward(b.fold, 0.0, dt * 6.0)
	b.legs = move_toward(b.legs, 1.0 if d < 5.0 else 0.0, dt * 3.0)
	if d < 4.0:
		_wings(b, 8.0, 1.0, dt)
	else:
		_wings(b, 0.0, 0.2, dt)

func _steer(b: Bird, tgt: Vector3, speed: float, accel: float, dt: float) -> void:
	var want := (tgt - b.pos).limit_length(speed)
	if (tgt - b.pos).length() > 2.0:
		want = (tgt - b.pos).normalized() * speed
	var old := b.vel
	b.vel = b.vel.move_toward(want, accel * dt)
	b.pos += b.vel * dt
	var floor_y := _terrain.height_at(b.pos.x, b.pos.z)
	if b.pos.y < floor_y + 0.02:
		b.pos.y = floor_y + 0.02
		b.vel.y = maxf(b.vel.y, 0.0)
	var hv := Vector2(b.vel.x, b.vel.z)
	if hv.length() > 0.3:
		b.yaw = atan2(-b.vel.x, -b.vel.z)
	# bank into turns: lateral acceleration against the heading
	var acc := (b.vel - old) / maxf(dt, 0.001)
	var right := Vector3(cos(b.yaw), 0, -sin(b.yaw))
	b.roll = lerpf(b.roll, clampf(acc.dot(right) * 0.12, -0.9, 0.9), dt * 4.0)

func _wings(b: Bird, beat_hz: float, amp: float, dt: float) -> void:
	if beat_hz > 0.0:
		b.phase += beat_hz * TAU * dt
		b.flap = sin(b.phase) * amp + 0.15
	else:
		# glide: wings out flat with a slight dihedral
		b.flap = move_toward(b.flap, 0.12, dt * 5.0)

func _update_kite(b: Bird, dt: float) -> void:
	b.phase += dt * 0.16
	var dir := 1.0 if int(b.off.x) % 2 == 0 else -1.0
	var c := Vector3(b.off.x, _terrain.height_at(b.off.x, b.off.z) + b.off.y, b.off.z)
	var r := 45.0 + sin(b.phase * 0.37) * 12.0
	var a := b.phase * dir
	b.pos = c + Vector3(cos(a) * r, sin(b.phase * 0.8) * 4.0, sin(a) * r)
	var tang := Vector3(-sin(a), 0, cos(a)) * dir
	b.yaw = atan2(-tang.x, -tang.z)
	b.vel = tang * 8.0
	# bank into the circle; soaring on flat wings with the odd slow flex
	var right := Vector3(cos(b.yaw), 0, -sin(b.yaw))
	b.roll = 0.3 * signf(right.dot(c - b.pos))
	b.flap = 0.1 + sin(_t * 1.3 + b.off.x) * 0.03

func _write_instances() -> void:
	var i := 0
	for fl: Flock in _flocks:
		for b: Bird in fl.birds:
			_write(_rook_mm, i, b, 1.0)
			i += 1
	for k in _kites.size():
		_write(_kite_mm, k, _kites[k], 2.0)

func _write(mm: MultiMesh, i: int, b: Bird, s: float) -> void:
	var pitch := 0.0
	if (b.state == AIR or b.state == LANDING) and b.vel.length() > 0.5:
		pitch = clampf(atan2(b.vel.y, Vector2(b.vel.x, b.vel.z).length()), -0.7, 0.9) * 0.6
	var basis := Basis(Vector3.UP, b.yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, b.roll)
	mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * s), b.pos))
	mm.set_instance_custom_data(i, Color(b.flap, b.legs, b.peck, b.fold))

# ---------------------------------------------------------------- mesh

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _ix := PackedInt32Array()

func _vert(p: Vector3, n: Vector3, c: Color, uv := Vector2.ZERO) -> int:
	_v.append(p)
	_n.append(n.normalized())
	_c.append(c)
	_uv.append(uv)
	return _v.size() - 1

func _quad(a: int, b: int, c: int, d: int) -> void:
	_ix.append_array([a, b, c, a, c, d])

## A rook ~0.45 m long, ~0.85 m wingspan, origin at the feet, facing -Z.
func _build_bird_mesh() -> ArrayMesh:
	# body loft: z, centre y, half-width, half-height, beak mask
	var st := [
		[0.13, 0.135, 0.012, 0.010, 0.0], [0.09, 0.135, 0.045, 0.040, 0.0],
		[0.03, 0.135, 0.062, 0.058, 0.0], [-0.03, 0.14, 0.060, 0.058, 0.0],
		[-0.07, 0.155, 0.042, 0.044, 0.0], [-0.095, 0.17, 0.034, 0.036, 0.0],
		[-0.125, 0.175, 0.035, 0.034, 0.0], [-0.150, 0.172, 0.026, 0.024, 0.0],
		[-0.160, 0.168, 0.014, 0.015, 1.0], [-0.205, 0.160, 0.003, 0.003, 1.0]]
	var sides := 10
	var rings := []
	for s: Array in st:
		var ring := []
		for k in sides:
			var a := float(k) / sides * TAU
			var dx := cos(a)
			var dy := sin(a)
			# belly a little flatter, back rounder
			var hy: float = s[3] * (0.85 if dy < 0.0 else 1.0)
			var p := Vector3(dx * s[2], s[1] + dy * hy, s[0])
			var n := Vector3(dx / maxf(s[2], 0.001), dy / maxf(hy, 0.001), 0.0)
			ring.append(_vert(p, n, Color(0, 0, s[4], 0), Vector2(float(k) / sides, s[0])))
		rings.append(ring)
	for r in rings.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			_quad(rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k])
	# caps
	var tail_c := _vert(Vector3(0, 0.135, 0.135), Vector3(0, 0, 1), Color(0, 0, 0, 0))
	for k in sides:
		_ix.append_array([tail_c, rings[0][(k + 1) % sides], rings[0][k]])
	# eye glints: tiny dark beads either side of the head
	for sx in [-1.0, 1.0]:
		var e := Vector3(sx * 0.031, 0.183, -0.128)
		var a := _vert(e + Vector3(0, 0.006, 0), Vector3(sx, 0, 0), Color(0, 0, 0, 0))
		var b2 := _vert(e + Vector3(0, -0.004, -0.006), Vector3(sx, 0, 0), Color(0, 0, 0, 0))
		var c2 := _vert(e + Vector3(0, -0.004, 0.006), Vector3(sx, 0, 0), Color(0, 0, 0, 0))
		_ix.append_array([a, b2, c2])
	# tail fan: wedge of long feathers, slightly rounded end
	var tl := []
	for k in 7:
		var u := float(k) / 6.0 * 2.0 - 1.0
		tl.append(_vert(Vector3(u * 0.045, 0.128, 0.27 - u * u * 0.012), Vector3.UP, Color(0.95, 0, 0, 0)))
	var tr0 := _vert(Vector3(-0.022, 0.134, 0.10), Vector3.UP, Color(0, 0, 0, 0))
	var tr1 := _vert(Vector3(0.022, 0.134, 0.10), Vector3.UP, Color(0, 0, 0, 0))
	for k in 6:
		var root := tr0 if k < 3 else tr1
		_ix.append_array([root, tl[k], tl[k + 1]])
	_ix.append_array([tr0, tl[3], tr1])
	# wings
	for side in [1.0, -1.0]:
		var g := 1.0 if side > 0.0 else 0.5
		var x0 := 0.035
		var x1 := 0.29
		var segs := 5
		var lead := []
		var trail := []
		for k in segs + 1:
			var f := float(k) / segs
			var x := lerpf(x0, x1, f)
			var span := (x - x0) / 0.39
			var lz := lerpf(-0.055, -0.035, f) - sin(f * PI) * 0.012
			var tz := lerpf(0.085, 0.05, f)
			lead.append(_vert(Vector3(x * side, 0.155 + f * 0.004, lz), Vector3.UP, Color(span, g, 0, 0)))
			trail.append(_vert(Vector3(x * side, 0.152, tz), Vector3.UP, Color(span, g, 0, 0)))
		for k in segs:
			_quad(lead[k], lead[k + 1], trail[k + 1], trail[k])
		# primaries: five fingered feathers fanning back from the hand
		for p in 5:
			var ang := lerpf(0.05, -0.75, float(p) / 4.0)
			var root := Vector3(x1 * side, 0.157, lerpf(-0.03, 0.04, float(p) / 4.0))
			var dir := Vector3(cos(ang) * side, 0.0, -sin(ang))
			var ln := lerpf(0.13, 0.10, float(p) / 4.0)
			var w := Vector3(-dir.z, 0, dir.x) * 0.014
			var a := _vert(root - w, Vector3.UP, Color(0.68, g, 0, 0))
			var b2 := _vert(root + w, Vector3.UP, Color(0.68, g, 0, 0))
			var tip := root + dir * ln
			var c2 := _vert(tip + w * 0.4, Vector3.UP, Color(1.0, g, 0, 0))
			var d2 := _vert(tip - w * 0.4 + dir * 0.012, Vector3.UP, Color(1.0, g, 0, 0))
			_quad(a, b2, c2, d2)
	# legs: two crossed thin quads each, plus three toes
	for sx in [-1.0, 1.0]:
		var top := Vector3(sx * 0.022, 0.10, 0.0)
		var foot := Vector3(sx * 0.024, 0.0, -0.008)
		for o: Vector3 in [Vector3(0.004, 0, 0), Vector3(0, 0, 0.004)]:
			var a := _vert(top - o, Vector3(0, 0, -1), Color(0, 0, 0, 1))
			var b2 := _vert(top + o, Vector3(0, 0, -1), Color(0, 0, 0, 1))
			var c2 := _vert(foot + o, Vector3(0, 0, -1), Color(0, 0, 0, 1))
			var d2 := _vert(foot - o, Vector3(0, 0, -1), Color(0, 0, 0, 1))
			_quad(a, b2, c2, d2)
		for t in [-0.5, 0.0, 0.5]:
			var td := Vector3(sin(t), 0, -cos(t)) * 0.035
			var a := _vert(foot + Vector3(-0.003, 0.002, 0), Vector3.UP, Color(0, 0, 0, 1))
			var b2 := _vert(foot + Vector3(0.003, 0.002, 0), Vector3.UP, Color(0, 0, 0, 1))
			var c2 := _vert(foot + td + Vector3(0, 0.001, 0), Vector3.UP, Color(0, 0, 0, 1))
			_ix.append_array([a, b2, c2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_COLOR] = _c
	arr[Mesh.ARRAY_TEX_UV] = _uv
	arr[Mesh.ARRAY_INDEX] = _ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
