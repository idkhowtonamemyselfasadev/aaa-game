class_name HollowArrow
extends Node3D
## A loosed arrow: flies straight from the string at SPEED with a little drop, tumbling never;
## it strikes the hero if its path passes through the hero's body (Player.receive_attack with
## the arrow itself as the attacker, so a parry turns the arrow, not the archer). A hero who
## strafed off the aim line, or rolled as it arrived, lets it pass; it buries itself in the
## turf where it lands and stays a while, or glances off spinning when parried.

const SPEED := 30.0
const DROP := 3.0                # m/s² of fall (a heavy war arrow over a short range)
const LIFE := 3.0
const STUCK_LIFE := 10.0
const HIT_R := 0.38              # path within this of the hero's spine line
const DAMAGE := 18.0

## where the arrow ended its flight: result is "hit", "parried", "dodged", "perfect", "ground"
signal landed(point: Vector3, result: String)

var vel := Vector3.ZERO
var damage := DAMAGE
var archer: Node3D
var result := ""                 # set when it first meets the hero or the ground
var _age := 0.0
var _stuck := -1.0
var _spin := Vector3.ZERO
var _passed := false             # the hero dodged it: it flies on and ignores them
var _player: Player
var _terrain: Node
var _mesh: MeshInstance3D

static func loose(parent: Node, from: Vector3, v: Vector3, by: Node3D) -> HollowArrow:
	var a := HollowArrow.new()
	a.name = "Arrow"
	a.vel = v
	a.archer = by
	parent.add_child(a)
	a.global_position = from
	a._orient()
	return a

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = HollowBow.arrow_mesh()
	# the mesh runs nock -> point along +Y; centre it so the arrow pivots on its middle
	_mesh.position = Vector3(0, -HollowBow.ARROW_LEN * 0.5, 0)
	add_child(_mesh)
	_player = get_parent().get_node_or_null("Player") as Player
	_terrain = get_parent().get_node_or_null("Terrain")

func _orient() -> void:
	if vel.length() < 1e-3:
		return
	var d := vel.normalized()
	var x := Vector3.UP.cross(d)
	if x.length() < 1e-3:
		x = Vector3.RIGHT
	x = x.normalized()
	global_basis = Basis(x, d, x.cross(d).normalized()).orthonormalized()

## The point (tip) in world space.
func point() -> Vector3:
	return global_position + global_basis.y.normalized() * HollowBow.ARROW_LEN * 0.5

func _physics_process(delta: float) -> void:
	_age += delta
	if _stuck >= 0.0:
		_stuck += delta
		if _stuck > STUCK_LIFE:
			queue_free()
		return
	if _age > LIFE:
		queue_free()
		return
	var p0 := point()
	vel.y -= DROP * delta
	if result == "parried":
		# glancing off the staff: spinning, falling, no longer a threat
		vel.y -= 9.0 * delta
		global_position += vel * delta
		global_basis = global_basis.rotated(_spin.normalized(), _spin.length() * delta).orthonormalized()
	else:
		global_position += vel * delta
		_orient()
	var p1 := point()
	if result != "parried" and not _passed and _player != null and not _player.is_dead():
		var a := _player.global_position + Vector3.UP * 0.35
		var b := _player.global_position + Vector3.UP * 1.6
		if _seg_seg(p0, p1, a, b) < HIT_R:
			_meet_hero(p1)
			if result == "hit":
				return
	if _terrain != null and _terrain.has_method("height_at"):
		var g: float = _terrain.height_at(p1.x, p1.z)
		if p1.y <= g + 0.02:
			# bury the point a hand's breadth in the turf, the shaft standing out at its angle
			global_position += Vector3(0, g - p1.y - 0.1, 0)
			_stuck = 0.0
			var tr := get_parent().get_node_or_null("Trample")
			if result != "parried":
				ImpactFX.spawn(get_parent(), Vector3(p1.x, g + 0.03, p1.z), Vector3.UP - vel.normalized() * 0.3, "turf", 0.35)
			if result == "":
				result = "ground"
			landed.emit(Vector3(p1.x, g, p1.z), "ground")
			if tr != null and tr.has_method("add_herd_point"):
				tr.add_herd_point(Vector2(p1.x, p1.z), Vector2(vel.x, vel.z).normalized(), 0.35, 0.2, 0.15, 0.0)

func _meet_hero(at: Vector3) -> void:
	var r := _player.receive_attack(self, damage, false, false)
	result = r
	landed.emit(at, r)
	match r:
		"hit":
			_player.add_shake(0.3)
			ImpactFX.spawn(get_parent(), at, vel.normalized(), "wood", 0.5)
			queue_free()
		"parried":
			# the staff turns it: thrown off upward and aside, spinning end over end
			var side := vel.normalized().cross(Vector3.UP)
			vel = (-vel.normalized() * 0.25 + side * (0.6 if randf() < 0.5 else -0.6) + Vector3.UP * 0.7).normalized() * 9.0
			_spin = side * 22.0
		"dodged", "perfect", "miss":
			_passed = true

## Closest distance between segments p0-p1 and a-b.
static func _seg_seg(p0: Vector3, p1: Vector3, a: Vector3, b: Vector3) -> float:
	var best := INF
	for i in 9:
		var q := p0.lerp(p1, i / 8.0)
		var ab := b - a
		var f := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * f))
	return best
