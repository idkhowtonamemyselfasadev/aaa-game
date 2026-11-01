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
const TRAIL_LIFE := 0.11         # s of tail positions kept: ~3 m of streak at full speed
const TRAIL_W := 0.032           # m across the streak
const IN_HERO_LIFE := 2.6        # s an arrow that struck stays stuck in the hero
const BURY := 0.12               # m the point sinks past the body surface (~to the spine)
const SNAP_AFTER := 0.06         # s into a roll before a lodged shaft snaps on the ground
const SNAP_KEEP := 0.55          # share of the shaft (from the nock) that breaks off and falls
const BROKEN_LIFE := 6.0         # s the snapped half lies in the grass

## where the arrow ended its flight: result is "hit", "parried", "dodged", "perfect", "ground", "wall"
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
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array = []       # [age, tail position]
var in_hero := -1.0              # >= 0: stuck in the hero this long
var frozen := false              # shots: physics stopped, the streak is redrawn for the lens
var broken := false              # a roll snapped the lodged shaft: this is the fletched half
var lying := false               # the snapped half has come to rest on the turf
var solid_hits := 0              # bots: times it struck a wall, trunk or rock
var snaps := 0                   # bots: times this arrow snapped (0 or 1)

func _process(_delta: float) -> void:
	if frozen:
		_update_trail(0.0, false)

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
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.name = "Streak"
	_trail.top_level = true
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/arrow_trail.gdshader")
	_trail.material_override = mat
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY

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

## The nock (tail) in world space.
func tail() -> Vector3:
	return global_position - global_basis.y.normalized() * HollowBow.ARROW_LEN * 0.5

## Length of the visible streak (m), for the bots.
func streak_length() -> float:
	var l := 0.0
	for i in range(1, _trail_pts.size()):
		l += (_trail_pts[i][1] as Vector3).distance_to(_trail_pts[i - 1][1])
	return l

func _physics_process(delta: float) -> void:
	_age += delta
	_update_trail(delta, _stuck < 0.0 and in_hero < 0.0 and result != "parried" and not broken)
	if in_hero >= 0.0:
		in_hero += delta
		if in_hero > IN_HERO_LIFE:
			queue_free()
		elif _player != null and _player.dodge_t >= SNAP_AFTER:
			_snap()
		return
	if broken:
		_fall_broken(delta)
		return
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
	if _hit_solid(p0, p1):
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

## A wall, a trunk or a rock across this step's path: the arrow buries its point there and
## stands out of it at its angle (a parried one just drops). The turf is left to height_at.
func _hit_solid(p0: Vector3, p1: Vector3) -> bool:
	if not is_inside_tree() or p0.is_equal_approx(p1):
		return false
	var q := PhysicsRayQueryParameters3D.create(p0, p1, 1)
	if archer is CollisionObject3D:
		q.exclude = [(archer as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.collider == _terrain:
		return false
	var at: Vector3 = hit.position
	var n: Vector3 = hit.normal
	_trail_pts.clear()
	_trail_mesh.clear_surfaces()
	if result == "parried":
		vel = vel.bounce(n) * 0.2
		return false
	var d := vel.normalized()
	global_position = at + d * 0.06 - d * HollowBow.ARROW_LEN * 0.5
	_stuck = 0.0
	ImpactFX.spawn(get_parent(), at, n, "pierce", 0.3)
	if result == "":
		result = "wall"
	solid_hits += 1
	landed.emit(at, "wall")
	return true

func _meet_hero(at: Vector3) -> void:
	var r := _player.receive_attack(self, damage, false, false)
	result = r
	landed.emit(at, r)
	match r:
		"hit":
			_player.add_shake(0.3)
			ImpactFX.spawn(get_parent(), at, vel.normalized(), "pierce", 0.5)
			_stick_in_hero()
		"parried":
			# the staff turns it: thrown off upward and aside, spinning end over end
			var side := vel.normalized().cross(Vector3.UP)
			vel = (-vel.normalized() * 0.25 + side * (0.6 if randf() < 0.5 else -0.6) + Vector3.UP * 0.7).normalized() * 9.0
			_spin = side * 22.0
		"dodged", "perfect", "miss":
			_passed = true

## The arrow lodges in the hero's torso where it struck, at the angle it flew, and rides
## the upper spine (so it sways with every clip) until IN_HERO_LIFE has passed.
func _stick_in_hero() -> void:
	var d := vel.normalized()
	var a := _player.global_position + Vector3.UP * 0.35
	var b := _player.global_position + Vector3.UP * 1.6
	# the spine point nearest the flight line, kept on the torso
	var p := point()
	var ab := b - a
	var f := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var c := a + ab * f
	c.y = clampf(c.y, _player.global_position.y + 1.05, _player.global_position.y + 1.42)
	# the body surface the arrow meets: ~0.13 m out from the spine toward where it came from
	var flat := Vector3(d.x, 0.0, d.z)
	if flat.length() < 1e-3:
		flat = Vector3.FORWARD
	var surf := c - flat.normalized() * 0.13
	global_position = surf + d * BURY - d * HollowBow.ARROW_LEN * 0.5
	_orient()
	_trail_pts.clear()
	_trail_mesh.clear_surfaces()
	in_hero = 0.0
	var slot := _player.find_child("BackSlot", true, false) as Node3D
	if slot != null:
		var g := global_transform
		get_parent().remove_child(self)
		slot.add_child(self)
		global_transform = g

## The hero rolled on the lodged arrow: the shaft breaks a hand above the wound, the head
## stays buried (gone from view), and the fletched half drops off spinning into the grass.
func _snap() -> void:
	var g := global_transform
	var world := _player.get_parent()
	get_parent().remove_child(self)
	world.add_child(self)
	global_transform = g
	in_hero = -1.0
	broken = true
	snaps += 1
	# keep only the nock end of the mesh: shrink along the shaft about the nock
	var keep := HollowBow.ARROW_LEN * SNAP_KEEP
	_mesh.scale = Vector3(1.0, SNAP_KEEP, 1.0)
	_mesh.position = Vector3(0, -keep * 0.5, 0)
	# re-centre the node on what is left so it pivots on the broken half's middle
	var shift := global_basis.y.normalized() * (-(HollowBow.ARROW_LEN - keep) * 0.5)
	global_position += shift
	var roll_v := Vector3.ZERO
	if _player.has_method("get_real_velocity"):
		roll_v = _player.get_real_velocity()
	var side := global_basis.x.normalized() * (0.6 if randf() < 0.5 else -0.6)
	vel = -roll_v * 0.25 + side + Vector3.UP * 1.6
	_spin = (global_basis.z.normalized() * 14.0 + Vector3(randf() - 0.5, 0, randf() - 0.5) * 6.0)
	_age = 0.0
	landed.emit(global_position, "snapped")

func _fall_broken(delta: float) -> void:
	if lying:
		_stuck += delta
		if _stuck > BROKEN_LIFE:
			queue_free()
		return
	if _age > LIFE:
		queue_free()
		return
	vel.y -= 9.8 * delta
	global_position += vel * delta
	global_basis = global_basis.rotated(_spin.normalized(), _spin.length() * delta).orthonormalized()
	if _terrain == null or not _terrain.has_method("height_at"):
		return
	var g: float = _terrain.height_at(global_position.x, global_position.z)
	if global_position.y <= g + 0.025:
		# lie in the grass: shaft level along its last heading, rolled a little
		var d := global_basis.y.normalized()
		d.y = 0.0
		if d.length() < 1e-3:
			d = Vector3.FORWARD
		d = d.normalized()
		var x := Vector3.UP.cross(d).normalized()
		global_basis = Basis(x, d, Vector3.UP).rotated(d, randf_range(-0.4, 0.4)).orthonormalized()
		# the terrain mesh is a grid that cuts the chords of height_at's curve, and the low
		# sward sits on it: rest on the blades a few cm up rather than sink out of sight
		global_position.y = g + 0.04
		lying = true
		_stuck = 0.0
		landed.emit(global_position, "litter")
		# its weight bends the blades under it so the shaft lies on, not hidden in, the sward
		var tr := get_parent().get_node_or_null("Trample")
		if tr != null and tr.has_method("add_herd_point"):
			tr.add_herd_point(Vector2(global_position.x + d.x * 0.18, global_position.z + d.z * 0.18), Vector2(d.x, d.z), 0.7, 0.0, 0.15, 0.35)

# --- the flight streak: a camera-facing ribbon through the tail's recent positions ---

func _update_trail(delta: float, flying: bool) -> void:
	for q in _trail_pts:
		q[0] += delta
	if flying:
		_trail_pts.push_front([0.0, tail()])
	while _trail_pts.size() > 0 and float(_trail_pts.back()[0]) > TRAIL_LIFE:
		_trail_pts.pop_back()
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = cam.global_position if cam != null else global_position + Vector3.UP * 5.0
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail_pts.size():
		var q: Vector3 = _trail_pts[i][1]
		var nb: Vector3 = _trail_pts[mini(i + 1, _trail_pts.size() - 1)][1]
		var pb: Vector3 = _trail_pts[maxi(i - 1, 0)][1]
		var along := (pb - nb)
		if along.length() < 1e-4:
			along = vel
		var side := along.cross(eye - q)
		side = side.normalized() * TRAIL_W * 0.5 if side.length() > 1e-6 else Vector3.UP * TRAIL_W * 0.5
		var age := float(_trail_pts[i][0]) / TRAIL_LIFE
		# a short fade-in at the nock so the streak does not start as a hard edge
		var alpha := clampf(float(i) / 2.0, 0.35, 1.0)
		_trail_mesh.surface_set_color(Color(1, 1, 1, alpha))
		_trail_mesh.surface_set_uv(Vector2(age, 0.0))
		_trail_mesh.surface_add_vertex(q + side)
		_trail_mesh.surface_set_color(Color(1, 1, 1, alpha))
		_trail_mesh.surface_set_uv(Vector2(age, 1.0))
		_trail_mesh.surface_add_vertex(q - side)
	_trail_mesh.surface_end()

## Closest distance between segments p0-p1 and a-b.
static func _seg_seg(p0: Vector3, p1: Vector3, a: Vector3, b: Vector3) -> float:
	var best := INF
	for i in 9:
		var q := p0.lerp(p1, i / 8.0)
		var ab := b - a
		var f := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * f))
	return best
