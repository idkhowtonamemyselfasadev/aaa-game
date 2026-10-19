class_name Hens
extends Node3D
## Hens in the garth behind the stone cottage (owner's "villages with sound and movement").
## Five birds of mixed plumage keep the yard by the clock:
##  - by day they potter about it in short, jerky walks (the head held still, then thrust),
##    stop to scratch the turf back with one foot and then the other, and peck at what it
##    turned up, clucking to themselves now and then;
##  - a hero walking up on one sets it running off with its wings half out and a squawk;
##    the rest of the flock steps away and starts up again a few seconds later;
##  - heavy rain sends them in under the cottage's back eaves to stand it out, fluffed up;
##  - at dusk they gather at the foot of the hen house's ladder (HenHouse) and go up it one
##    at a time, into the house for the night; at first light they come down it again one
##    after another, the first out soonest.
##  - morning and afternoon Edda casts grain over the east wall (HenFeed -> `scatter`): the
##    grains lie where they fell, pale on the scratched earth, and the hens come running with
##    their wings half out and work through them one beak-length at a time, a peck for a
##    grain (some miss), until the last is gone. When they hear her call as she comes round
##    with the bag (`expect`), they leave off and gather at the inside of the east wall,
##    heads up toward her, jostling, and wait there for the grain.
## They stay inside the garth walls (a clamp to the yard's quadrilateral in the cottage's
## frame), keep apart from each other and never leave by the field gate.
## Procedural mesh (Herd's loft helpers), posed in hen.gdshader.
## Bots read `hens` (dicts), `pecks`, `scratches`, `clucks`, `flees`, `walked`.

signal clucked(at: Vector3)     # a soft cluck from one going about the yard
signal squawked(at: Vector3)    # an alarm squawk from one put to flight

enum { STAND, WALK, SCRATCH, PECK, FLEE, ROOST, SHELTER, CLIMB, DESCEND }

const COUNT := 5
const WALK_V := 0.42       # m/s pottering
const RUN_V := 2.6         # m/s running from the hero
const SHY_R := 1.9         # a hero this close (+0.45 m per m/s he moves) puts one to flight
const ROOST_H := 19.4      # they go up to the back wall at dusk
const RISE_H := 5.9        # and come down again at first light
const RAIN_IN := 0.45      # rain this heavy sends them under the eaves
const CLIMB_T := 2.6       # seconds up (or down) the ladder
## The garth inside its walls in the cottage's frame (DryWall.RUNS_LOCAL pulled in ~0.6 m),
## counter-clockwise: east wall, back wall, west wall, the cottage's back wall.
const YARD := [Vector2(3.3, -3.3), Vector2(4.0, -9.65), Vector2(-4.65, -10.05), Vector2(-3.3, -3.3)]
## Where they stand out the rain: along the back wall under the
## eaves (eaves out to z -3.18, the wall's face at -2.8).
const EAVES_Z := -3.45
const GRAIN_COL := Color(0.62, 0.50, 0.30)   # wheat, dull gold
const GRAIN_MAX := 240
const GRAIN_FLY := 0.5     # s from the hand to the ground
## Plumage: [body, dark (lacing, tail), hackle (neck)], one per bird.
const BREEDS := [
	[Color(0.36, 0.17, 0.07), Color(0.13, 0.06, 0.03), Color(0.46, 0.25, 0.10)],    # brown (red-brown hybrid)
	[Color(0.035, 0.035, 0.04), Color(0.02, 0.025, 0.03), Color(0.04, 0.045, 0.05)], # black (green sheen)
	[Color(0.42, 0.40, 0.37), Color(0.13, 0.13, 0.14), Color(0.48, 0.46, 0.43)],    # cuckoo (barred grey)
	[Color(0.52, 0.36, 0.19), Color(0.32, 0.20, 0.09), Color(0.56, 0.40, 0.22)],    # buff
	[Color(0.33, 0.20, 0.10), Color(0.08, 0.05, 0.04), Color(0.42, 0.30, 0.15)],    # partridge (laced)
]

var world: Node3D
var cottage: StoneCottage
var house: HenHouse
var terrain: Terrain
var weather: Weather
var hens: Array = []       # per bird: {mi, pos (local xz), yaw, state, t, speed, phase, peck, sit, wing, scratch, ...}
var pecks := 0
var scratches := 0
var clucks := 0
var flees := 0
var walked := 0.0
var went_in := 0          # times one went up the ladder into the house (bots)
var came_out := 0
var grain: Array[Vector2] = []    # grains lying in the yard (local xz)
var thrown := 0           # grains cast in (bots)
var fed := 0              # grains eaten (bots)
var at_wall := 0          # hens waiting at the east wall for the grain right now (bots)
var _call_t := 0.0        # > 0 while her call is still fresh
var _call_from := Vector2.ZERO   # where she called from (local xz)
var _grain_y: Array[float] = []
var _grain_b: Array[Basis] = []
var _grain_mm: MultiMesh
var _landing: Array = []  # [s until it lands, local centre, local throw direction]
var _rng := RandomNumberGenerator.new()
var _prev_hero := Vector3.ZERO
var _hero_v := 0.0

func setup(w: Node3D) -> void:
	world = w
	cottage = w.get("stone_cottage")
	terrain = w.get_node("Terrain")
	weather = w.get("weather")
	name = "Hens"
	_rng.seed = 7741
	w.add_child(self)
	house = HenHouse.new()
	cottage.add_child(house)
	house.setup(terrain)
	var mesh := build_mesh()
	var sh: Shader = load("res://shaders/hen.gdshader")
	for i in COUNT:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var b: Array = BREEDS[i % BREEDS.size()]
		mat.set_shader_parameter("body", b[0])
		mat.set_shader_parameter("dark", b[1])
		mat.set_shader_parameter("hackle", b[2])
		mat.set_shader_parameter("pattern", float(i))
		var mi := MeshInstance3D.new()
		mi.name = "Hen_%d" % i
		mi.mesh = mesh
		mi.material_override = mat
		var sc := _rng.randf_range(0.92, 1.06)
		mi.scale = Vector3.ONE * sc
		add_child(mi)
		var at := Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-8.5, -4.8))
		hens.append({"mi": mi, "pos": at, "yaw": _rng.randf() * TAU, "state": STAND, "t": _rng.randf_range(0.5, 3.0),
			"speed": 0.0, "phase": _rng.randf(), "peck": 0.0, "sit": 0.0, "wing": 0.0, "scratch": 0.0,
			"goal": at, "n": 0, "cluck_t": _rng.randf_range(2.0, 9.0), "calm": 0.0, "bob": 0.0, "head": 0.0,
			"head_goal": 0.0, "fluff": 0.0, "id": i, "inside": false, "air": -INF, "c": 0.0, "feed": false, "heard": false})
	_grain_mm = MultiMesh.new()
	_grain_mm.transform_format = MultiMesh.TRANSFORM_3D
	_grain_mm.mesh = grain_mesh()
	_grain_mm.instance_count = GRAIN_MAX
	_grain_mm.visible_instance_count = 0
	var gmi := MultiMeshInstance3D.new()
	gmi.name = "Grain"
	gmi.multimesh = _grain_mm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = GRAIN_COL
	gm.roughness = 0.6
	gmi.material_override = gm
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cottage.add_child(gmi)
	_prev_hero = _hero_pos()
	_settle_now()

## One wheat grain, ~8 mm long, its long axis along y.
static func grain_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.0024
	m.height = 0.0085
	m.radial_segments = 6
	m.rings = 3
	return m

## A handful cast from `from` toward world `to` (`reach` m off): it lands GRAIN_FLY s later
## as a fan of grains strung out along the throw.
func scatter(to: Vector3, reach: float, from: Vector3) -> void:
	var dl := _local_of(to) - _local_of(from)
	_landing.append([GRAIN_FLY, _local_of(to), dl.normalized() if dl.length() > 0.01 else Vector2.LEFT, reach])

func _land(c: Vector2, dir: Vector2) -> void:
	var n := _rng.randi_range(18, 24)
	for i in n:
		if grain.size() >= GRAIN_MAX:
			break
		var l := clamp_yard(c + dir * _rng.randfn(0.0, 0.42) + dir.orthogonal() * _rng.randfn(0.0, 0.26))
		if HenHouse.covers(l, 0.05):
			continue
		var g := cottage.to_global(Vector3(l.x, 0, l.y))
		grain.append(l)
		_grain_y.append(terrain.height_at(g.x, g.z) - cottage.global_position.y + 0.002)
		# lying on its side, turned any way
		_grain_b.append(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5 + _rng.randf_range(-0.2, 0.2)))
		thrown += 1
	_sync_grain()

func _sync_grain() -> void:
	for i in grain.size():
		_grain_mm.set_instance_transform(i, Transform3D(_grain_b[i], Vector3(grain[i].x, _grain_y[i], grain[i].y)))
	_grain_mm.visible_instance_count = grain.size()

## Takes the grain nearest `beak` within `r` (a peck that found one).
func _eat_near(beak: Vector2, r: float) -> bool:
	var bi := -1
	var bd := r * r
	for i in grain.size():
		var d := grain[i].distance_squared_to(beak)
		if d < bd:
			bd = d
			bi = i
	if bi < 0:
		return false
	var last := grain.size() - 1
	grain[bi] = grain[last]
	_grain_y[bi] = _grain_y[last]
	_grain_b[bi] = _grain_b[last]
	grain.resize(last)
	_grain_y.resize(last)
	_grain_b.resize(last)
	fed += 1
	_sync_grain()
	return true

func _nearest_grain(p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	for g in grain:
		var d := g.distance_squared_to(p)
		if d < bd:
			bd = d
			best = g
	return best

## At the grain while there is any: runs to the nearest, a beak's length short of it, and
## pecks; true while it is feeding (the usual pottering is off).
func _feed(h: Dictionary, dt: float) -> bool:
	if grain.is_empty():
		h.feed = false
		return false
	if h.state == PECK and h.feed:
		if h.t <= 0.0:
			h.n -= 1
			pecks += 1
			if _rng.randf() < 0.6:
				_eat_near((h.pos as Vector2) + _fwd(h.yaw) * 0.1, 0.16)
			h.t = _rng.randf_range(0.22, 0.4)
			if h.n <= 0:
				h.state = STAND
				h.t = 0.0
		return true
	if not h.feed:
		# heads up at the patter, then off to it, the nearest first
		h.feed = true
		h.state = STAND
		h.t = 0.2 + 0.25 * h.id
		h.head_goal = 0.0
	if h.state == STAND and h.t > 0.0:
		return true
	var best := _nearest_grain(h.pos)
	var to: Vector2 = best - (h.pos as Vector2)
	var dist := to.length()
	if dist > 0.26:
		h.goal = best - to / dist * 0.1
		h.state = WALK
		var fast := dist > 1.0
		_walk(h, dt, RUN_V * 0.55 if fast else WALK_V * 1.4)
		if fast:
			h.wing = maxf(h.wing, 0.3)
		return true
	h.yaw = atan2(-to.x, -to.y)
	h.state = PECK
	h.n = _rng.randi_range(2, 4)
	h.t = 0.3
	return true

## Edda's call from beyond the wall: the hens come to the east wall and wait for the grain.
func expect(from: Vector3) -> void:
	_call_t = 7.0
	_call_from = _local_of(from)

## Where a bird waits for the grain: strung along the inside of the east wall near where the
## handfuls land, a little off the stones, the nearer ones to her the first there.
static func wall_spot(id: int) -> Vector2:
	var a: Vector2 = YARD[0]
	var b: Vector2 = YARD[1]
	var e := (b - a).normalized()
	var inward := Vector2(e.y, -e.x)
	return a + (b - a) * (0.5 + 0.085 * id) + inward * (0.42 + 0.12 * float(id % 2))

## At her call (and no grain down yet): to the wall at a hurry, then stand there facing it,
## heads up and turning, and stir now and then. True while it is at this.
func _gather(h: Dictionary, dt: float) -> bool:
	if _call_t <= 0.0 or not grain.is_empty() or not _landing.is_empty():
		h.heard = false
		return false
	if not h.heard:
		# heads up at the call first, then off, some sooner than others
		h.heard = true
		h.state = STAND
		h.t = 0.15 + 0.3 * float((h.id * 3) % 5) / 5.0
		h.head_goal = 0.0
		return true
	var spot := wall_spot(h.id)
	var to: Vector2 = spot - (h.pos as Vector2)
	if to.length() > 0.12:
		if h.state == STAND and h.t > 0.0 and h.speed < 0.05:
			return true
		if h.state != WALK or (h.goal as Vector2).distance_to(spot) > 0.01:
			h.state = WALK
			h.goal = spot
		var fast := to.length() > 1.2
		_walk(h, dt, RUN_V * 0.5 if fast else WALK_V * 1.5)
		if fast:
			h.wing = maxf(h.wing, 0.25)
		return true
	at_wall += 1
	# facing the wall (and her, beyond it), the head cocked toward where she called from
	var a: Vector2 = YARD[0]
	var e: Vector2 = ((YARD[1] as Vector2) - a).normalized()
	var out := Vector2(-e.y, e.x)
	var want := atan2(-out.x, -out.y)
	h.yaw = lerp_angle(h.yaw, want, minf(1.0, dt * 3.0))
	h.speed = 0.0
	if h.state != STAND:
		h.state = STAND
		h.t = _rng.randf_range(0.6, 1.4)
	if h.t <= 0.0:
		var c: Vector2 = _call_from - (h.pos as Vector2)
		var look := clampf(wrapf(atan2(-c.x, -c.y) - h.yaw, -PI, PI), -0.8, 0.8)
		h.head_goal = clampf(look + _rng.randf_range(-0.35, 0.35), -0.9, 0.9)
		h.t = _rng.randf_range(0.5, 1.3)
	return true

## Puts them where the hour has them at once (game start, or a bot / shot jumping the clock).
func _settle_now() -> void:
	var night := _night(world.time_of_day)
	for h: Dictionary in hens:
		if night:
			_go_inside(h)
			h.sit = 1.0
		_place(h)

func _night(hr: float) -> bool:
	return hr >= ROOST_H or hr < RISE_H

func _hero_pos() -> Vector3:
	var p: Node3D = world.get("player")
	return p.global_position if p else Vector3(1e6, 0, 1e6)

## In the house for the night: out of sight, on the perch.
func _go_inside(h: Dictionary) -> void:
	h.pos = HenHouse.inside()
	h.state = ROOST
	h.inside = true
	h.air = -INF
	h.speed = 0.0
	h.t = 0.0
	(h.mi as Node3D).visible = false

## Where one waits its turn for the ladder: a loose knot round its foot.
func _queue_spot(id: int) -> Vector2:
	return HenHouse.foot() + Vector2(0.25 + 0.22 * (id % 3), 0.42 * (id - 2) + 0.1 * sin(id * 1.9))

func _on_ladder() -> bool:
	for o: Dictionary in hens:
		if o.state == CLIMB or o.state == DESCEND:
			return true
	return false

## Each bird's place along the back wall, spread out under the eaves.
func _roost_spot(id: int) -> Vector2:
	return Vector2(lerpf(-2.6, 2.4, (id + 0.5) / COUNT) + 0.12 * sin(id * 2.3), EAVES_Z - 0.05 * (id % 2))

func _face_yard(id: int) -> float:
	return PI + 0.5 * sin(id * 1.7)   # local yaw facing out into the yard (-Z), heads a little this way and that

## True when the local point lies inside the yard quadrilateral.
static func inside_yard(l: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(l, PackedVector2Array(YARD))

## How hard the hens have worked the turf at world (x, z): 1 over the open garth (no tall
## grass, the sward scratched short and patchy down to bare earth), 0 outside it, fading up
## over ~0.9 m from the walls' feet where a fringe of tufts survives. Grass/flowers read it.
static func scratched(x: float, z: float) -> float:
	var d := Vector2(x, z) - StoneCottage.SITE
	if d.length_squared() > 196.0:
		return 0.0
	var y := StoneCottage.yaw()
	var l := Vector2(d.x * cos(y) - d.y * sin(y), d.x * sin(y) + d.y * cos(y))
	if not inside_yard(l):
		return 0.0
	var e := INF
	for i in YARD.size():
		e = minf(e, l.distance_to(Geometry2D.get_closest_point_to_segment(l, YARD[i], YARD[(i + 1) % YARD.size()])))
	return smoothstep(0.0, 0.9, e)

## Pulls a local point back into the yard.
static func clamp_yard(l: Vector2) -> Vector2:
	if inside_yard(l):
		return l
	var best := l
	var bd := INF
	for i in YARD.size():
		var q := Geometry2D.get_closest_point_to_segment(l, YARD[i], YARD[(i + 1) % YARD.size()])
		if q.distance_squared_to(l) < bd:
			bd = q.distance_squared_to(l)
			best = q
	# a hair in from the edge, toward the yard's middle
	return best.lerp(Vector2(-0.2, -6.8), 0.02)

func _local_of(g: Vector3) -> Vector2:
	var l := cottage.to_local(g)
	return Vector2(l.x, l.z)

func _place(h: Dictionary) -> void:
	var mi: MeshInstance3D = h.mi
	var g := cottage.to_global(Vector3(h.pos.x, 0, h.pos.y))
	g.y = terrain.height_at(g.x, g.z) if h.air == -INF else h.air
	mi.global_position = g
	mi.global_rotation = Vector3(0, cottage.global_rotation.y + h.yaw, 0)
	mi.set_instance_shader_parameter("phase", h.phase)
	mi.set_instance_shader_parameter("speed", h.speed)
	mi.set_instance_shader_parameter("peck", h.peck)
	mi.set_instance_shader_parameter("sit", h.sit)
	mi.set_instance_shader_parameter("wing", h.wing)
	mi.set_instance_shader_parameter("scratch", h.scratch)
	mi.set_instance_shader_parameter("bob", h.bob)
	mi.set_instance_shader_parameter("head_yaw", h.head)
	mi.set_instance_shader_parameter("fluff", h.fluff)

## World position of a bird (bots).
func at(i: int) -> Vector3:
	return (hens[i].mi as Node3D).global_position

func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	var hr: float = world.time_of_day
	var hero := _hero_pos()
	_hero_v = lerpf(_hero_v, Vector2(hero.x - _prev_hero.x, hero.z - _prev_hero.z).length() / maxf(dt, 1e-4), minf(1.0, dt * 6.0))
	if _hero_v > 30.0:
		_hero_v = 0.0                      # teleported (bots, respawn)
	_prev_hero = hero
	var hl := _local_of(hero)
	var raining := weather != null and weather.rain > RAIN_IN
	var night := _night(hr)
	_call_t = maxf(0.0, _call_t - dt)
	at_wall = 0
	for i in range(_landing.size() - 1, -1, -1):
		_landing[i][0] -= dt
		if _landing[i][0] <= 0.0:
			_land(_landing[i][1], _landing[i][2])
			_landing.remove_at(i)
	for h: Dictionary in hens:
		_think(h, dt, hl, night, raining)
		_animate(h, dt)
		_place(h)

func _think(h: Dictionary, dt: float, hl: Vector2, night: bool, raining: bool) -> void:
	var d_hero: float = (h.pos as Vector2).distance_to(hl)
	var shy := SHY_R + 0.45 * _hero_v
	h.calm = maxf(0.0, h.calm - dt)
	# a hero walking up on it: off it runs, wings half out, unless it is settled for the night
	# and he only creeps (a roosting hen only shifts and grumbles at a walk)
	if d_hero < shy and h.state != FLEE and h.state != CLIMB and h.state != DESCEND and not h.inside and not (h.state == ROOST and _hero_v < 2.0 and d_hero > 0.7):
		var away: Vector2 = ((h.pos as Vector2) - hl).normalized() if d_hero > 0.01 else Vector2.RIGHT
		away = away.rotated(_rng.randf_range(-0.5, 0.5))
		var goal := clamp_yard((h.pos as Vector2) + away * _rng.randf_range(2.5, 3.6))
		# pinned against a wall: run along it instead
		if goal.distance_to(h.pos) < 1.0:
			goal = clamp_yard((h.pos as Vector2) + away.orthogonal() * signf(_rng.randf() - 0.5) * 3.0)
		h.goal = goal
		h.state = FLEE
		h.t = 2.2
		h.sit = 0.0
		h.peck = 0.0
		h.scratch = 0.0
		flees += 1
		squawked.emit((h.mi as Node3D).global_position + Vector3.UP * 0.3)
		return
	h.t -= dt
	match h.state:
		FLEE:
			if _walk(h, dt, RUN_V) or h.t <= 0.0:
				h.state = STAND
				h.t = _rng.randf_range(1.5, 3.0)
				h.calm = 3.0
			return
		ROOST:
			if night:
				h.t = 0.0
				return
			# morning: out one after another, the first a few seconds after first light
			if not night and h.inside:
				if h.t <= -2.0 - 3.5 * h.id and not _on_ladder():
					h.state = DESCEND
					h.c = 1.0
					h.inside = false
					(h.mi as Node3D).visible = true
					h.yaw = -PI * 0.5      # facing +x, out of the hole
					h.sit = 0.0
					h.fluff = 0.4
				return
			if not night:
				h.state = STAND
				h.t = _rng.randf_range(0.5, 2.0)
			return
		CLIMB, DESCEND:
			_climb(h, dt)
			return
	# night: to the ladder's foot, wait a turn, up it and in
	if night:
		var q := HenHouse.foot()
		if not _on_ladder() and (h.pos as Vector2).distance_to(q) < 1.4 and _first_waiting(h):
			if (h.pos as Vector2).distance_to(q) > 0.1:
				h.goal = q
				h.state = WALK
				_walk(h, dt, WALK_V)
				return
			h.state = CLIMB
			h.c = 0.0
			h.peck = 0.0
			h.scratch = 0.0
			return
		var spot := _queue_spot(h.id)
		if (h.pos as Vector2).distance_to(spot) > 0.15:
			if h.state != WALK or (h.goal as Vector2).distance_to(spot) > 0.01:
				h.state = WALK
				h.goal = spot
			_walk(h, dt, WALK_V * 1.3)
		else:
			h.yaw = lerp_angle(h.yaw, PI * 0.5, minf(1.0, dt * 2.0))   # facing the ladder (-x)
			h.speed = 0.0
			h.state = STAND
			h.t = 1.0
		return
	# rain: in under the back eaves to stand it out
	if raining:
		var spot := _roost_spot(h.id)
		if (h.pos as Vector2).distance_to(spot) > 0.15:
			if h.state != WALK or (h.goal as Vector2).distance_to(spot) > 0.01:
				h.state = WALK
				h.goal = spot
			_walk(h, dt, WALK_V * 1.3)
			return
		h.yaw = lerp_angle(h.yaw, _face_yard(h.id), minf(1.0, dt * 2.0))
		h.speed = 0.0
		h.state = SHELTER
		return
	if h.state == SHELTER:
		h.state = STAND
		h.t = _rng.randf_range(0.5, 2.0)
	var feeding := _feed(h, dt)
	if not feeding and h.calm <= 0.0:
		feeding = _gather(h, dt)
	if not feeding:
		match h.state:
			STAND:
				if h.t <= 0.0:
					_next(h)
			WALK:
				if _walk(h, dt, WALK_V) or h.t <= 0.0:
					h.state = STAND
					h.t = _rng.randf_range(0.4, 1.6)
			SCRATCH:
				if h.t <= 0.0:
					# a step back to look at what it turned up, then at it
					h.state = PECK
					h.n = _rng.randi_range(2, 5)
					h.t = 0.35
					h.pos = clamp_yard((h.pos as Vector2) - _fwd(h.yaw) * 0.08)
			PECK:
				if h.t <= 0.0:
					h.n -= 1
					pecks += 1
					h.t = _rng.randf_range(0.28, 0.5)
					if h.n <= 0:
						h.state = STAND
						h.t = _rng.randf_range(0.6, 2.0)
	# a cluck to itself now and then, more often while it works the turf
	h.cluck_t -= dt * (2.5 if feeding else 1.6 if h.state == SCRATCH or h.state == PECK else 1.0)
	if h.cluck_t <= 0.0:
		h.cluck_t = _rng.randf_range(3.5, 11.0)
		clucks += 1
		clucked.emit((h.mi as Node3D).global_position + Vector3.UP * 0.3)

## The waiting bird nearest the ladder goes next.
func _first_waiting(h: Dictionary) -> bool:
	var q := HenHouse.foot()
	var d: float = (h.pos as Vector2).distance_to(q)
	for o: Dictionary in hens:
		if o != h and not o.inside and o.state != CLIMB and (o.pos as Vector2).distance_to(q) < d - 0.01:
			return false
	return true

## Up (CLIMB) or down (DESCEND) the ladder between its foot and the pop-hole: a hop up onto
## the plank, short careful steps with a wing flick, in through the hole or off the end.
func _climb(h: Dictionary, dt: float) -> void:
	var up: bool = h.state == CLIMB
	h.c = clampf(h.c + (dt if up else -dt) / CLIMB_T, 0.0, 1.0)
	var fl := HenHouse.foot() - Vector2(0.12, 0)
	var top := HenHouse.sill()
	var u: float = h.c
	h.pos = fl.lerp(top, u) if u > 0.0 else HenHouse.foot()
	var g0 := terrain.height_at(cottage.to_global(Vector3(fl.x, 0, fl.y)).x, cottage.to_global(Vector3(fl.x, 0, fl.y)).z)
	h.air = lerpf(g0, house.sill_y(), u) + 0.02
	h.yaw = PI * 0.5 if up else -PI * 0.5
	h.speed = 0.35
	h.wing = maxf(h.wing, 0.35 * absf(sin(h.c * 19.0)))
	if up and h.c >= 1.0:
		went_in += 1
		clucked.emit((h.mi as Node3D).global_position + Vector3.UP * 0.3)
		_go_inside(h)
		h.t = 0.0
	elif not up and h.c <= 0.0:
		came_out += 1
		h.air = -INF
		h.pos = clamp_yard(HenHouse.foot() + Vector2(0.3, 0.0))
		h.state = STAND
		h.t = _rng.randf_range(0.5, 1.5)
		clucked.emit((h.mi as Node3D).global_position + Vector3.UP * 0.3)

## What a standing bird does next: potter on a little, scratch, peck, or look round.
func _next(h: Dictionary) -> void:
	var r := _rng.randf()
	if r < 0.42:
		var step := _fwd(h.yaw + _rng.randf_range(-1.4, 1.4)) * _rng.randf_range(0.5, 1.8)
		var goal := (h.pos as Vector2) + step
		# keep to the open yard, drift back toward the middle from the walls
		if not inside_yard(goal) or HenHouse.covers(goal, 0.1) or _rng.randf() < 0.15:
			goal = (h.pos as Vector2).lerp(Vector2(_rng.randf_range(-2.8, 2.8), _rng.randf_range(-8.9, -4.6)), 0.5)
		h.goal = clamp_yard(goal)
		h.state = WALK
		h.t = 8.0
	elif r < 0.66:
		h.state = SCRATCH
		h.t = _rng.randf_range(0.9, 1.6)
		scratches += 1
	elif r < 0.88:
		h.state = PECK
		h.n = _rng.randi_range(1, 4)
		h.t = 0.3
	else:
		h.head_goal = _rng.randf_range(-0.9, 0.9)
		h.state = STAND
		h.t = _rng.randf_range(0.8, 2.2)

## Local forward of a bird at `yaw` (mesh faces -Z).
static func _fwd(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))

## Walks/runs toward `goal`, kept apart from the others; true once there.
func _walk(h: Dictionary, dt: float, top: float) -> bool:
	var to: Vector2 = (h.goal as Vector2) - (h.pos as Vector2)
	var d := to.length()
	if d < 0.08:
		h.speed = move_toward(h.speed, 0.0, 4.0 * dt)
		return true
	var want_yaw := atan2(-to.x, -to.y)
	var turn := 9.0 if h.state == FLEE else 4.0
	h.yaw += clampf(wrapf(want_yaw - h.yaw, -PI, PI), -turn * dt, turn * dt)
	var facing := cos(wrapf(want_yaw - h.yaw, -PI, PI))
	h.speed = move_toward(h.speed, top * clampf(facing, 0.15, 1.0) * minf(1.0, d * 2.5 + 0.2), (10.0 if h.state == FLEE else 2.5) * dt)
	var mv := _fwd(h.yaw) * minf(h.speed * dt, d)
	# keep a beak's length from the others
	for o: Dictionary in hens:
		if o == h:
			continue
		var sep: Vector2 = (h.pos as Vector2) - (o.pos as Vector2)
		var sl := sep.length()
		if sl < 0.32 and sl > 0.001:
			mv += sep / sl * (0.32 - sl) * minf(1.0, dt * 4.0)
	var np := clamp_yard((h.pos as Vector2) + mv)
	walked += np.distance_to(h.pos)
	h.pos = np
	return false

## Gait phase, peck, scratch, head bob, the flap and the settle.
func _animate(h: Dictionary, dt: float) -> void:
	var spd: float = h.speed
	if h.state != WALK and h.state != FLEE:
		h.speed = move_toward(spd, 0.0, 3.0 * dt)
	# a hen takes short quick steps: ~2.2 strides a second at a potter, ~4 at a run
	h.phase = fmod(h.phase + dt * (0.6 + spd * 3.6), 1.0)
	# the head holds still in space then thrusts forward with each step
	h.bob = fmod(h.phase * 2.0, 1.0) if spd > 0.05 else move_toward(h.bob, 0.0, dt * 3.0)
	var pk := 0.0
	if h.state == PECK:
		# down fast, a tap, back up
		var u: float = clampf(1.0 - h.t / 0.3, 0.0, 1.0)
		pk = sin(PI * clampf(u * 1.6, 0.0, 1.0))
	elif h.state == SCRATCH:
		pk = 0.35       # head lowered, eyeing the scratch
	h.peck = move_toward(h.peck, pk, dt * 9.0)
	var sc := 0.0
	if h.state == SCRATCH:
		sc = fmod(h.t * 2.4, 2.0)      # 0..1 left foot rakes back, 1..2 right
	h.scratch = sc
	h.wing = move_toward(h.wing, 1.0 if h.state == FLEE else 0.0, dt * (8.0 if h.state == FLEE else 2.0))
	h.sit = move_toward(h.sit, 1.0 if h.state == ROOST else 0.0, dt * 0.8)
	h.fluff = move_toward(h.fluff, 1.0 if h.state == ROOST or h.state == SHELTER else 0.0, dt * 0.5)
	if _rng.randf() < dt * 0.4:
		h.head_goal = _rng.randf_range(-0.7, 0.7) if h.state != ROOST else _rng.randf_range(-0.3, 0.3)
	# a hen looks round in jerks: snap to the new angle
	h.head = move_toward(h.head, h.head_goal, dt * 6.0)

# ---------------------------------------------------------------- mesh

## A laying hen about 0.42 m to the top of the comb, 0.4 m breast to tail, facing -Z, feet
## at y = 0. COLOR: r leg (0.25 left, 0.5 right), g below the hock, b neck/head weight,
## a part (0 body, 0.2 wing, 0.35 tail, 0.5 eye, 0.65 beak, 0.8 comb/wattles, 1 shank/toes).
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body: a tilted egg, broad low breast forward, the back sloping up to the tail, then the
	# neck rising from the crop (z, y, half-width, half-height above, below, bend)
	var body := [
		[0.175, 0.30, 0.012, 0.012, 0.012, 0.0],
		[0.16, 0.285, 0.055, 0.045, 0.05, 0.0],
		[0.11, 0.26, 0.098, 0.075, 0.09, 0.0],
		[0.035, 0.24, 0.118, 0.088, 0.108, 0.0],
		[-0.045, 0.24, 0.115, 0.09, 0.11, 0.0],
		[-0.105, 0.255, 0.094, 0.08, 0.092, 0.05],
		[-0.14, 0.285, 0.068, 0.06, 0.066, 0.3],
		[-0.155, 0.325, 0.046, 0.045, 0.048, 0.65],
		[-0.162, 0.365, 0.036, 0.036, 0.038, 0.9],
		[-0.165, 0.395, 0.032, 0.032, 0.032, 1.0],
	]
	Herd._loft(st, body, 0.0, 28, 5, 0.0, 0.0, 3)
	# head: round crown into the face
	var head := [
		[-0.135, 0.41, 0.004, 0.004, 0.004, 1.0],
		[-0.145, 0.412, 0.024, 0.024, 0.022, 1.0],
		[-0.165, 0.415, 0.031, 0.03, 0.03, 1.0],
		[-0.19, 0.413, 0.027, 0.026, 0.025, 1.0],
		[-0.205, 0.408, 0.017, 0.017, 0.016, 1.0],
		[-0.21, 0.405, 0.003, 0.003, 0.003, 1.0],
	]
	Herd._loft(st, head, 0.0, 20, 4, 0.0, 0.0, 3)
	# beak: short, hooked a touch down at the tip
	var beak := [
		[-0.198, 0.408, 0.011, 0.009, 0.009, 1.0],
		[-0.215, 0.403, 0.0085, 0.006, 0.007, 1.0],
		[-0.229, 0.396, 0.005, 0.004, 0.004, 1.0],
		[-0.238, 0.389, 0.001, 0.001, 0.001, 1.0],
	]
	Herd._loft(st, beak, 0.0, 12, 3, 0.0, 0.65)
	# single comb: a thin upright blade along the crown with five points
	var comb := [
		[-0.14, 0.432, 0.003, 0.004, 0.003, 1.0],
		[-0.15, 0.437, 0.0045, 0.022, 0.004, 1.0],
		[-0.16, 0.442, 0.0045, 0.012, 0.004, 1.0],
		[-0.168, 0.444, 0.0045, 0.028, 0.004, 1.0],
		[-0.176, 0.444, 0.0045, 0.014, 0.004, 1.0],
		[-0.184, 0.442, 0.0045, 0.026, 0.004, 1.0],
		[-0.192, 0.436, 0.0045, 0.012, 0.004, 1.0],
		[-0.199, 0.428, 0.004, 0.016, 0.004, 1.0],
		[-0.205, 0.42, 0.003, 0.004, 0.003, 1.0],
	]
	Herd._loft(st, comb, 0.0, 8, 3, 0.0, 0.8)
	for s in [-1.0, 1.0]:
		# wattles under the beak and the eyes either side of the head
		Herd._sphere(st, Vector3(0.008 * s, 0.383, -0.198), 0.011, 1.0, 0.8)
		Herd._sphere(st, Vector3(0.0255 * s, 0.421, -0.184), 0.0055, 1.0, 0.5)
		# a folded wing lying along each flank (z, y, half-width, above, below, bend, x)
		var wing := [
			[-0.095, 0.275, 0.006, 0.01, 0.01, 0.0, 0.082],
			[-0.065, 0.273, 0.018, 0.045, 0.04, 0.0, 0.103],
			[0.02, 0.272, 0.022, 0.055, 0.05, 0.0, 0.112],
			[0.10, 0.278, 0.016, 0.044, 0.034, 0.0, 0.095],
			[0.165, 0.29, 0.004, 0.012, 0.008, 0.0, 0.055],
		]
		Herd._loft(st, wing, s, 14, 4, 0.0, 0.2)
		# legs: a feathered thigh hidden in the fluff, then a bare scaled shank (x, y, z,
		# half-width, half-depth front, back)
		var shank := [
			[0.045, 0.19, 0.01, 0.034, 0.04, 0.04],
			[0.046, 0.13, 0.012, 0.02, 0.024, 0.022],
			[0.046, 0.105, 0.008, 0.0085, 0.009, 0.0085],
			[0.046, 0.05, 0.0, 0.0075, 0.008, 0.0075],
			[0.046, 0.016, -0.004, 0.0085, 0.0095, 0.009],
			[0.046, 0.004, -0.004, 0.002, 0.002, 0.002],
		]
		Herd._leg(st, shank, s, 0.25 if s < 0 else 0.5, 0.115, 10, 3)
		# toes: three forward, splayed, and one behind (z, y, hw, above, below, bend, x)
		for tz in [[-0.06, 0.035], [-0.068, 0.0], [-0.058, -0.03], [0.035, 0.0]]:
			var toe := [
				[-0.004, 0.009, 0.006, 0.005, 0.005, 0.0, 0.046],
				[-0.004 + tz[0] * 0.55, 0.006, 0.0045, 0.004, 0.004, 0.0, 0.046 + tz[1] * 0.55],
				[-0.004 + tz[0], 0.003, 0.0025, 0.0025, 0.002, 0.0, 0.046 + tz[1]],
			]
			Herd._loft(st, toe, s, 6, 2, 0.25 if s < 0 else 0.5, 1.0)
	# tail: the hen's short fan of feathers carried up behind the back
	var tail := [
		[0.13, 0.275, 0.05, 0.03, 0.035, 0.0],
		[0.175, 0.31, 0.046, 0.04, 0.03, 0.0],
		[0.21, 0.35, 0.034, 0.042, 0.022, 0.0],
		[0.228, 0.385, 0.02, 0.03, 0.012, 0.0],
		[0.236, 0.405, 0.002, 0.002, 0.002, 0.0],
	]
	Herd._loft(st, tail, 0.0, 16, 4, 0.0, 0.35, 3)
	st.generate_tangents()
	return st.commit()
