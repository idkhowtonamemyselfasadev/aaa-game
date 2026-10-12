class_name Soak
extends Node
## Rain soaks an actor (hero, Hollows): under rain `level` creeps up to drenched in about
## `soak_time` s at a downpour and dries over `dry_time` s once it stops; wading through a
## pool soaks the legs up to the water line at once. Every ShaderMaterial on the actor whose
## shader includes wet.gdshaderinc (has a `soak` uniform) gets `soak`, `wade_soak` and
## `wade_line` each frame. Add as a child of the actor; the world's Weather is found via the
## actor's parent (`weather` property of the World).
## A soaked actor sheds its water: drops run off the fingertips, elbows, chin, coat hem and
## the low end of its staff/spear and fall free (Weather.shed_drop), heavy while drenched,
## a slow tick as it dries; wading legs drip from the knees for a while after the pool.

@export var soak_time := 35.0
@export var dry_time := 200.0
@export var wade_depth := 0.32     # metres above the ground the pool soaks the legs to

var level := 0.0     # 0 dry .. 1 drenched
var wade := 0.0      # 0 .. 1 legs soaked from wading
var wade_line := -10000.0

var _mats: Array[ShaderMaterial] = []
var _scan := 0.0
var _has_soak := {}  # Shader -> bool

@export var shed_rate := 14.0     # drops per second when drenched (level 1)
var _shed_acc := 0.0
var _rng := RandomNumberGenerator.new()
var _skel: Skeleton3D
var _bones := {}     # role -> bone index
var _last_pos := Vector3.ZERO

func _process(delta: float) -> void:
	var actor := get_parent() as Node3D
	if actor == null:
		return
	var wx = actor.get_parent().get("weather") if actor.get_parent() != null else null
	var rain: float = wx.rain if wx != null else 0.0
	# under an oak the crown catches most of it (a few drips still get through)
	if wx != null:
		rain *= 1.0 - wx.shelter_at(actor.global_position.x, actor.global_position.z)
	if rain > 0.02:
		level = move_toward(level, 1.0, delta * rain / soak_time)
	else:
		level = move_toward(level, 0.0, delta / dry_time)
	if wx != null and wx.pool_at(actor.global_position.x, actor.global_position.z):
		wade = move_toward(wade, 1.0, delta / 0.6)
		var g: float = actor.global_position.y
		var terrain = actor.get_parent().get("terrain")
		if terrain != null:
			g = terrain.height_at(actor.global_position.x, actor.global_position.z)
		# the water is level: its depth shows where the ground is lowest (the far bank rising
		# out of the pool doesn't lift the line); a pool somewhere else starts a new one
		var line := g + wade_depth
		wade_line = minf(wade_line, line) if absf(wade_line - line) < 0.5 else line
	else:
		wade = move_toward(wade, 0.0, delta / (dry_time * 0.8))
		if wade <= 0.0:
			wade_line = -10000.0
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0          # gear (staff, rags) can be added after us: pick it up
		_collect(actor)
	for m in _mats:
		m.set_shader_parameter("soak", level)
		m.set_shader_parameter("wade_soak", wade)
		m.set_shader_parameter("wade_line", wade_line)
	_shed(actor, wx, delta)

## Drops running off: the rate climbs steeply with the soak (a damp coat barely drips).
func _shed(actor: Node3D, wx, delta: float) -> void:
	var vel := (actor.global_position - _last_pos) / maxf(delta, 1e-4)
	_last_pos = actor.global_position
	if wx == null or not wx.has_method("shed_drop") or delta <= 0.0:
		return
	var cam := actor.get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(actor.global_position) > 30.0:
		_shed_acc = 0.0
		return
	var body := smoothstep(0.12, 1.0, level)
	var legs := smoothstep(0.3, 1.0, wade) * 0.5
	_shed_acc += shed_rate * (body * body + legs * legs) * delta
	var n := mini(int(_shed_acc), 8)
	_shed_acc -= float(int(_shed_acc))
	if n == 0:
		return
	if _skel == null:
		_find_bones(actor)
	var terrain = actor.get_parent().get("terrain")
	vel.y = 0.0
	if vel.length() > 12.0:
		vel = Vector3.ZERO    # a teleport (respawn), not a run
	for k in n:
		var at := _shed_point(actor, body, legs)
		if at == Vector3.INF:
			continue
		var gy: float = terrain.height_at(at.x, at.z) if terrain != null else actor.global_position.y
		# the drop leaves with the body's speed (it was running with it), a little scatter
		var v := vel * 0.85 + Vector3(_rng.randf_range(-0.15, 0.15), -_rng.randf_range(0.1, 0.5), _rng.randf_range(-0.15, 0.15))
		wx.shed_drop(at, gy, v)

func _find_bones(actor: Node3D) -> void:
	_skel = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skel == null:
		return
	for role in ["LeftHand", "RightHand", "LeftForeArm", "RightForeArm", "Head", "Hips", "LeftLeg", "RightLeg"]:
		var b := _skel.find_bone("mixamorig_" + role)
		if b >= 0:
			_bones[role] = b

func _bone_pos(role: String) -> Vector3:
	return _skel.global_transform * _skel.get_bone_global_pose(_bones[role]).origin

## Where the next drop leaves the body. Weighted: the coat hem sheds most, then the hands,
## the staff's low end, elbows and the chin/hair; wading, the knees (shins run with water).
func _shed_point(actor: Node3D, body: float, legs: float) -> Vector3:
	if _skel == null or _bones.is_empty():
		return Vector3.INF
	if _rng.randf() * (body + legs) < legs:
		var knee: String = ["LeftLeg", "RightLeg"][_rng.randi() % 2]
		if _bones.has(knee):
			return _bone_pos(knee) + Vector3(_rng.randf_range(-0.06, 0.06), -0.08, _rng.randf_range(-0.06, 0.06))
		return Vector3.INF
	var u := _rng.randf()
	if u < 0.4 and _bones.has("Hips"):
		# the hem: a ring round the hips, below the sash
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.16, 0.22)
		return _bone_pos("Hips") + Vector3(cos(a) * r, -_rng.randf_range(0.18, 0.3), sin(a) * r)
	if u < 0.68:
		var hand: String = ["LeftHand", "RightHand"][_rng.randi() % 2]
		if _bones.has(hand):
			# fingertips hang ~9 cm past the wrist
			return _bone_pos(hand) + Vector3(_rng.randf_range(-0.03, 0.03), -0.09, _rng.randf_range(-0.03, 0.03))
	if u < 0.85:
		var pole := _pole_end(actor)
		if pole != Vector3.INF:
			return pole
	if u < 0.94:
		var elbow: String = ["LeftForeArm", "RightForeArm"][_rng.randi() % 2]
		if _bones.has(elbow):
			return _bone_pos(elbow) + Vector3(0.0, -0.05, 0.0)
	if _bones.has("Head"):
		# chin and the hair's ends
		var hb := _skel.global_transform * _skel.get_bone_global_pose(_bones["Head"])
		var fwd := hb.basis.z.normalized()
		return hb.origin + fwd * _rng.randf_range(-0.08, 0.1) + Vector3(_rng.randf_range(-0.05, 0.05), -0.04, 0.0)
	return Vector3.INF

## The lower end of a staff or spear the actor carries (it runs off the shaft to the end).
func _pole_end(actor: Node3D) -> Vector3:
	var pole = actor.get("staff")
	if pole == null:
		pole = actor.get("spear")
	if not (pole is Node3D) or not (pole as Node3D).is_visible_in_tree():
		return Vector3.INF
	var half: float = pole.LENGTH * 0.5
	var t := (pole as Node3D).global_transform
	var a := t * Vector3(0, -half, 0)
	var b := t * Vector3(0, half, 0)
	return a if a.y < b.y else b

func _collect(actor: Node) -> void:
	_mats.clear()
	for n in actor.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		_take(gi.material_override)
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			for s in mi.get_surface_override_material_count():
				_take(mi.get_surface_override_material(s))

func _take(m: Material) -> void:
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null or _mats.has(sm):
		return
	if not _has_soak.has(sm.shader):
		var found := false
		for u in sm.shader.get_shader_uniform_list():
			if u["name"] == "soak":
				found = true
		_has_soak[sm.shader] = found
	if _has_soak[sm.shader]:
		_mats.append(sm)

## Where the water soaks this point, for bots: 0..1 (the shader's own estimate, top-facing).
func wet_estimate() -> float:
	return clampf(level * 1.5, 0.0, 1.0)
