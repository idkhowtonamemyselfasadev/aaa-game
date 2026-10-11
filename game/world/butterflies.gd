class_name Butterflies
extends Node3D
## Butterflies by day (owner's "alive" list): four meadow species streaming around the
## camera. Each one settles on the grass heads (wings shut overhead, or held open to bask),
## takes off after a while on a jinking, bobbing flight to another spot a few metres off,
## and bursts up and away when the hero comes close (sooner when running). They are out
## from mid-morning to early evening and gone in the dusk.
## One PlaneMesh MultiMesh; wing beat and pattern are in butterfly.gdshader.

enum { REST, FLY, FLEE }

@export var count: int = 40
@export var radius: float = 30.0
@export var scare_radius: float = 2.2
@export var seed: int = 777

var terrain: Terrain
var _world: Node
var _rng := RandomNumberGenerator.new()
var _bs: Array = []
var _mm: MultiMesh
var _anchor := Vector3.INF
var _threat_prev := Vector3.INF
var _t := 0.0
var day := 0.0
var flee_events := 0          # bots read this: butterflies the hero has put up

class Fly:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var target := Vector3.ZERO
	var state := 0
	var timer := 0.0
	var rest := 1.0
	var yaw := 0.0
	var phase := 0.0
	var species := 0
	var bask := 0.0
	var span := 0.03
	var gate := 0.0
	var jink := Vector3.ZERO

func _ready() -> void:
	_world = get_parent().get_parent()   # Insects -> World
	_rng.seed = seed
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 1.2)
	plane.subdivide_width = 1          # vertices at x = -1, 0, 1: the hinge on the body
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = plane
	_mm.instance_count = count
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/butterfly.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Butterflies"
	mmi.multimesh = _mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-400, -50, -400), Vector3(800, 300, 800))
	add_child(mmi)
	for i in count:
		var b := Fly.new()
		b.phase = _rng.randf() * TAU
		# whites and tortoiseshells common, blues in the short turf, peacocks scarce
		var r := _rng.randf()
		b.species = 1 if r < 0.34 else 0 if r < 0.62 else 2 if r < 0.86 else 3
		b.span = [0.026, 0.030, 0.017, 0.031][b.species] * _rng.randf_range(0.9, 1.1)
		b.bask = 1.0 if b.species != 1 and _rng.randf() < 0.6 else 0.0
		b.gate = float(i) / count
		_bs.append(b)

func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b: Fly in _bs:
		out.append(b.pos)
	return out

## [resting, flying, fleeing] among the ones out right now
func census() -> Array[int]:
	var c: Array[int] = [0, 0, 0]
	for b: Fly in _bs:
		if _out(b) > 0.0:
			c[b.state] += 1
	return c

func _out(b: Fly) -> float:
	return clampf((day - b.gate * 0.8) * 5.0, 0.0, 1.0)

func _hour() -> float:
	var h = _world.get("time_of_day")
	return 13.0 if h == null else float(h)

func _process(delta: float) -> void:
	_t += delta
	var h := _hour()
	day = smoothstep(8.5, 10.0, h) * (1.0 - smoothstep(17.6, 18.6, h))
	var cam := get_viewport().get_camera_3d()
	var player: Node3D = _world.get_node_or_null("Player")
	var anchor := cam.global_position if cam else (player.global_position if player else Vector3.ZERO)
	var threat := player.global_position if player else anchor
	var tvel := Vector3.ZERO if _threat_prev == Vector3.INF or delta <= 0.0 else (threat - _threat_prev) / delta
	_threat_prev = threat
	var tspeed := Vector2(tvel.x, tvel.z).length()
	if _anchor == Vector3.INF or _anchor.distance_to(anchor) > radius:
		for b: Fly in _bs:
			_settle_at(b, _spot(anchor, _rng.randf_range(3.0, radius)))
	_anchor = anchor
	var scare_r := scare_radius + minf(tspeed, 8.0) * 0.3
	for i in _bs.size():
		var b: Fly = _bs[i]
		var off := Vector2(b.pos.x - anchor.x, b.pos.z - anchor.z)
		if off.length() > radius + 5.0:
			_settle_at(b, _spot(anchor, radius * _rng.randf_range(0.75, 0.95), Vector3(-off.x, 0, -off.y)))
		var out := _out(b)
		# the hero coming close puts it up
		var rel := b.pos - threat - Vector3(0, 0.6, 0)
		var d := Vector2(rel.x, rel.z).length()
		if out > 0.0 and b.state != FLEE and d < scare_r and (tspeed > 0.5 or d < scare_r * 0.6):
			flee_events += 1
			b.state = FLEE
			b.timer = _rng.randf_range(1.6, 2.8)
			var away := Vector3(rel.x, 0, rel.z).normalized() if d > 0.05 else Vector3.FORWARD
			away = away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
			b.vel = away * 2.6 + Vector3(0, 1.8, 0)
			b.target = b.pos + away * 9.0 + Vector3(0, 2.5, 0)
		match b.state:
			REST:
				b.rest = minf(b.rest + delta * 3.0, 1.0)
				b.timer -= delta
				if b.timer <= 0.0 and out > 0.0:
					_take_off(b, anchor)
			FLY, FLEE:
				b.rest = maxf(b.rest - delta * 8.0, 0.0)
				b.timer -= delta
				# jinking flight: the aim wobbles sideways and up/down several times a second
				if _rng.randf() < delta * 4.0:
					b.jink = Vector3(_rng.randfn(0, 1.0), _rng.randfn(0, 0.7), _rng.randfn(0, 1.0))
				var to := b.target - b.pos
				var speed := 3.2 if b.state == FLEE else 1.4
				var want := to.normalized() * speed + b.jink * (0.6 if b.state == FLEE else 0.9)
				want.y += sin(_t * 9.0 + b.phase) * 0.5      # the bob of each wing stroke
				b.vel = b.vel.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
				b.pos += b.vel * delta
				var g := terrain.height_at(b.pos.x, b.pos.z)
				b.pos.y = clampf(b.pos.y, g + 0.3, g + 4.5)
				if b.state == FLEE and b.timer <= 0.0:
					# calm again: drift off to settle somewhere away from the hero
					var away2 := Vector3(b.pos.x - threat.x, 0, b.pos.z - threat.z).normalized()
					b.state = FLY
					b.timer = 12.0
					b.target = _spot(b.pos, _rng.randf_range(5.0, 10.0), away2)
				elif b.state == FLY and (to.length() < 0.25 or b.timer <= 0.0):
					if out > 0.0:
						b.state = REST
						b.pos = b.target
						b.vel = Vector3.ZERO
						b.timer = _rng.randf_range(4.0, 14.0)
						b.yaw = _rng.randf() * TAU
					else:
						b.target = _spot(b.pos, 4.0)
				if b.vel.length() > 0.05:
					b.yaw = lerp_angle(b.yaw, atan2(-b.vel.x, -b.vel.z), clampf(delta * 6.0, 0.0, 1.0))
		var basis := Basis(Vector3.UP, b.yaw)
		if b.state != REST:
			basis = basis * Basis(Vector3.RIGHT, clampf(b.vel.y * 0.2, -0.4, 0.4))
		var scale := b.span * out
		_mm.set_instance_transform(i, Transform3D(basis, b.pos))
		var bask := b.bask * (1.0 if b.state == REST else 0.0)
		_mm.set_instance_custom_data(i, Color(b.phase, b.rest, float(b.species) + bask * 0.5, scale))

func _take_off(b: Fly, anchor: Vector3) -> void:
	b.state = FLY
	b.timer = 12.0
	b.vel = Vector3(0, 0.8, 0)
	# mostly short hops across the meadow, drawn back toward the camera's bubble
	var toward := Vector3(anchor.x - b.pos.x, 0, anchor.z - b.pos.z)
	b.target = _spot(b.pos, _rng.randf_range(3.0, 12.0), toward if toward.length() > radius * 0.6 else Vector3.ZERO)

func _settle_at(b: Fly, p: Vector3) -> void:
	b.pos = p
	b.target = p
	b.vel = Vector3.ZERO
	b.state = REST
	b.rest = 1.0
	b.timer = _rng.randf_range(0.5, 14.0)
	b.yaw = _rng.randf() * TAU

## A perch on the grass heads near `centre`, on open meadow (not rock slopes or the map edge).
func _spot(centre: Vector3, r: float, toward := Vector3.ZERO) -> Vector3:
	var p := centre
	for tries in 8:
		var a := _rng.randf() * TAU
		if toward != Vector3.ZERO:
			a = atan2(toward.z, toward.x) + _rng.randf_range(-0.8, 0.8)
		p = Vector3(centre.x + cos(a) * r, 0, centre.z + sin(a) * r)
		var half := terrain.size_m * 0.5 - 4.0
		p.x = clampf(p.x, -half, half)
		p.z = clampf(p.z, -half, half)
		if terrain.normal_at(p.x, p.z).y >= 0.88 or tries == 7:
			break
	p.y = terrain.height_at(p.x, p.z) + _rng.randf_range(0.42, 0.72)
	return p
