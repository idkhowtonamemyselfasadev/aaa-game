class_name Shockwave
extends Node3D
## The ground wave a giant's stomp sends out: a ring of torn turf and dust racing outward over
## the real ground from the stamped foot, a band of churned earth under it with an ember
## edge in the burning phase, the dust hanging in the air behind it. Anyone standing on the
## ground when the front passes is thrown down (unblockable). Readable and fair: it is a
## visible wall moving at a fixed speed, so a roll timed as it reaches the hero passes
## through it on the i-frames (and later, a jump clears it). Frees itself when the dust settles.

signal passed(result: String)

const SEGS := 72
const BAND := 1.1          # m: the churned band's width (and the hit front's)
const LIFE_AFTER := 2.2    # s the dust hangs after the front stops

var source: Node           # the giant (receive_attack's attacker)
var player: Player
var terrain: Terrain
var max_r := 12.0
var speed := 10.0
var damage := 20.0
var ember := false         # burning phase: the band's edge glows
var r := 0.4               # m: the front's radius now
var t := 0.0
var result := ""           # "" until the front reaches (or dies short of) the hero
var _done_t := -1.0
var _mesh: MeshInstance3D
var _im: ImmediateMesh
var _mat: StandardMaterial3D
var _dust: CPUParticles3D
var _clods: CPUParticles3D
var _light: OmniLight3D

func _ready() -> void:
	_im = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.name = "Band"
	_mesh.mesh = _im
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 1.0
	_mat.albedo_color = Color(1, 1, 1)
	if ember:
		_mat.emission_enabled = true
		_mat.emission = Color(1.0, 0.36, 0.08)
		_mat.emission_energy_multiplier = 2.5
	_mesh.material_override = _mat
	add_child(_mesh)
	_mesh.top_level = true
	_mesh.global_transform = Transform3D.IDENTITY
	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = 520
	_dust.lifetime = 1.8
	_dust.randomness = 0.5
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_dust.emission_ring_axis = Vector3.UP
	_dust.emission_ring_height = 0.5
	_dust.direction = Vector3.UP
	_dust.spread = 20.0
	_dust.initial_velocity_min = 1.4
	_dust.initial_velocity_max = 3.6
	_dust.gravity = Vector3(0, -0.4, 0)
	_dust.damping_min = 0.8
	_dust.damping_max = 1.6
	_dust.scale_amount_min = 0.7
	_dust.scale_amount_max = 1.6
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.35, 1.0))
	sc.add_point(Vector2(1.0, 1.4))
	_dust.scale_amount_curve = sc
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = ImpactFX._soft_tex()
	dm.roughness = 1.0
	q.material = dm
	_dust.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0.5, 0.44, 0.34, 0.0), Color(0.48, 0.42, 0.32, 0.75),
		Color(0.5, 0.45, 0.37, 0.4), Color(0.52, 0.48, 0.4, 0.0)])
	_dust.color_ramp = g
	add_child(_dust)
	# clods and torn grass kicked up off the front, falling back
	_clods = CPUParticles3D.new()
	_clods.name = "Clods"
	_clods.amount = 160
	_clods.lifetime = 0.9
	_clods.local_coords = false
	_clods.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_clods.emission_ring_axis = Vector3.UP
	_clods.emission_ring_height = 0.05
	_clods.direction = Vector3.UP
	_clods.spread = 25.0
	_clods.initial_velocity_min = 2.5
	_clods.initial_velocity_max = 5.0
	_clods.gravity = Vector3(0, -12.0, 0)
	_clods.scale_amount_min = 0.5
	_clods.scale_amount_max = 1.3
	var cq := BoxMesh.new()
	cq.size = Vector3(0.06, 0.045, 0.05)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.2, 0.15, 0.1)
	cm.roughness = 1.0
	cq.material = cm
	_clods.mesh = cq
	_clods.angle_max = 180.0
	add_child(_clods)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.omni_range = 6.0
	_light.light_energy = 2.5 if ember else 0.0
	_light.visible = ember
	_light.position.y = 0.5
	add_child(_light)
	_dust.emitting = true
	_clods.emitting = true
	_apply_ring()

func _ground(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain != null else global_position.y

func _apply_ring() -> void:
	for p: CPUParticles3D in [_dust, _clods]:
		p.emission_ring_radius = r
		p.emission_ring_inner_radius = maxf(r - BAND * 0.5, 0.0)

func _process(delta: float) -> void:
	t += delta
	var c := global_position
	if _done_t < 0.0:
		var r0 := r
		r = minf(r + speed * delta, max_r)
		_apply_ring()
		_check(r0, r)
		if r >= max_r:
			_done_t = 0.0
			_dust.emitting = false
			_clods.emitting = false
			if result == "":
				result = "miss"
				passed.emit(result)
	else:
		_done_t += delta
	# the churned band: dark torn earth, fading out behind the front and as it dies
	var fade := 1.0 - clampf(_done_t / 0.6, 0.0, 1.0) if _done_t >= 0.0 else 1.0
	var spread := clampf(r / max_r, 0.0, 1.0)
	var a := (0.85 - 0.35 * spread) * fade
	_im.clear_surfaces()
	if a > 0.01:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var inner := maxf(r - BAND * 1.6, 0.0)
		for i in SEGS + 1:
			var ang := TAU * i / SEGS
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var jag := 1.0 + 0.04 * sin(ang * 13.0 + t * 3.0) + 0.03 * sin(ang * 7.0 - 1.3)
			var po := c + dir * r * jag
			var pi := c + dir * inner * jag
			po.y = _ground(po.x, po.z) + 0.05
			pi.y = _ground(pi.x, pi.z) + 0.05
			_im.surface_set_color(Color(0.16, 0.12, 0.08, a) if not ember else Color(0.35, 0.12, 0.04, a))
			_im.surface_add_vertex(po)
			_im.surface_set_color(Color(0.22, 0.18, 0.13, 0.0))
			_im.surface_add_vertex(pi)
		_im.surface_end()
	if ember:
		_light.light_energy = 2.5 * fade * (1.0 - 0.6 * spread)
	if _done_t > LIFE_AFTER:
		queue_free()

## The front swept from r0 to r1 this frame: a hero on the ground in that band is thrown down.
func _check(r0: float, r1: float) -> void:
	if result != "" or player == null or player.is_dead():
		return
	var d := player.global_position - global_position
	var hd := Vector2(d.x, d.z).length()
	if hd > r1 + BAND * 0.5 or hd < r0 - BAND * 0.5:
		return
	# off the ground (a jump, the glider): the wave runs on under the hero
	var gy := _ground(player.global_position.x, player.global_position.z)
	if player.global_position.y - gy > 0.45:
		result = "over"
	else:
		result = player.receive_attack(source if source != null else self, damage, true, true)
		if result == "hit":
			player.add_shake(0.6)
			ImpactFX.spawn(get_parent(), player.global_position + Vector3.UP * 0.4, d.normalized(), "dirt", 1.2)
	passed.emit(result)
