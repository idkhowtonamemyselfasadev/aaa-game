class_name DodgeFX
extends Node3D
## Perfect-dodge burst: a ring of pale-gold motes shed along the dash where the blow passed,
## drifting up and out like disturbed ash, with a brief warm flash. Frees itself when done.

static func spawn(parent: Node, pos: Vector3, dir: Vector3) -> DodgeFX:
	var fx := DodgeFX.new()
	fx.name = "DodgeFX"
	parent.add_child(fx)
	fx.global_position = pos
	fx._build(dir)
	return fx

func _build(dir: Vector3) -> void:
	var motes := CPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = 70
	motes.lifetime = 1.1
	motes.one_shot = true
	motes.explosiveness = 0.9
	motes.local_coords = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(0.25, 0.8, 0.25)
	motes.direction = (-dir + Vector3.UP * 0.6).normalized() if dir.length() > 0.1 else Vector3.UP
	motes.spread = 70.0
	motes.initial_velocity_min = 0.6
	motes.initial_velocity_max = 2.4
	motes.gravity = Vector3(0, 0.6, 0)
	motes.damping_min = 1.5
	motes.damping_max = 2.5
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	q.material = m
	motes.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.86, 0.55, 0.0))
	g.add_point(0.08, Color(1.0, 0.86, 0.55, 1.0))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.55, 0.25, 0.0))
	motes.color_ramp = g
	add_child(motes)
	motes.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.light_energy = 2.2
	flash.omni_range = 3.5
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.35)
	get_tree().create_timer(1.4, false).timeout.connect(queue_free)

static var _dot: Texture2D
static func _soft_dot() -> Texture2D:
	if _dot == null:
		var gt := GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = g
		gt.width = 32
		gt.height = 32
		_dot = gt
	return _dot
