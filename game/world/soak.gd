class_name Soak
extends Node
## Rain soaks an actor (hero, Hollows): under rain `level` creeps up to drenched in about
## `soak_time` s at a downpour and dries over `dry_time` s once it stops; wading through a
## pool soaks the legs up to the water line at once. Every ShaderMaterial on the actor whose
## shader includes wet.gdshaderinc (has a `soak` uniform) gets `soak`, `wade_soak` and
## `wade_line` each frame. Add as a child of the actor; the world's Weather is found via the
## actor's parent (`weather` property of the World).

@export var soak_time := 35.0
@export var dry_time := 200.0
@export var wade_depth := 0.32     # metres above the ground the pool soaks the legs to

var level := 0.0     # 0 dry .. 1 drenched
var wade := 0.0      # 0 .. 1 legs soaked from wading
var wade_line := -10000.0

var _mats: Array[ShaderMaterial] = []
var _scan := 0.0
var _has_soak := {}  # Shader -> bool

func _process(delta: float) -> void:
	var actor := get_parent() as Node3D
	if actor == null:
		return
	var wx = actor.get_parent().get("weather") if actor.get_parent() != null else null
	var rain: float = wx.rain if wx != null else 0.0
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
