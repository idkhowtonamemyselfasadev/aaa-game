class_name ImpactFX
extends Node3D
## One-shot hit burst at a contact point: flying chaff/splinters thrown along the swing,
## a dust puff that blooms and settles, and (on metal) a spark spray with a brief flash.
## Frees itself when done.

static var _dust_tex: Texture2D

static func spawn(parent: Node, pos: Vector3, swing_dir: Vector3, kind: String, power: float) -> ImpactFX:
	var fx := ImpactFX.new()
	fx.name = "Impact"
	parent.add_child(fx)
	fx.global_position = pos
	fx._build(swing_dir.normalized(), kind, power)
	return fx

func _build(dir: Vector3, kind: String, power: float) -> void:
	var chaff_col := Color(0.62, 0.50, 0.29)
	var dust_col := Color(0.5, 0.44, 0.34, 0.5)
	if kind == "wood":
		chaff_col = Color(0.40, 0.33, 0.24)
	elif kind == "stone":
		chaff_col = Color(0.42, 0.41, 0.38)
		dust_col = Color(0.55, 0.54, 0.50, 0.45)
	# chaff: thin stalk fragments thrown out along the swing, tumbling, falling
	var chaff := CPUParticles3D.new()
	chaff.name = "Chaff"
	chaff.amount = int(44 * power)
	chaff.lifetime = 1.4
	chaff.one_shot = true
	chaff.explosiveness = 0.95
	chaff.local_coords = false
	chaff.direction = (dir + Vector3.UP * 0.45).normalized()
	chaff.spread = 38.0
	chaff.initial_velocity_min = 1.8 * power
	chaff.initial_velocity_max = 5.0 * power
	chaff.gravity = Vector3(0, -7.5, 0)
	chaff.damping_min = 1.5
	chaff.damping_max = 3.0
	chaff.angular_velocity_min = -720.0
	chaff.angular_velocity_max = 720.0
	chaff.angle_min = 0.0
	chaff.angle_max = 360.0
	chaff.scale_amount_min = 0.5
	chaff.scale_amount_max = 1.3
	chaff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chaff.emission_sphere_radius = 0.06
	chaff.particle_flag_rotate_y = false
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.013) if kind == "straw" else Vector2(0.03, 0.012)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = chaff_col
	cm.roughness = 0.8
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cm.billboard_keep_scale = true
	cm.vertex_color_use_as_albedo = true
	q.material = cm
	chaff.mesh = q
	var cg := Gradient.new()
	cg.set_color(0, Color(1.1, 1.05, 1.0))
	cg.set_color(1, Color(0.7, 0.68, 0.62))
	chaff.color_initial_ramp = cg
	add_child(chaff)
	chaff.emitting = true
	# dust: soft puffs that bloom out of the contact and drift down
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = int(12 * power) + 4
	dust.lifetime = 1.1
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.local_coords = false
	dust.direction = (dir * 0.6 + Vector3.UP * 0.3).normalized()
	dust.spread = 70.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.6 * power
	dust.gravity = Vector3(0, -0.25, 0)
	dust.damping_min = 2.0
	dust.damping_max = 3.5
	dust.angle_min = 0.0
	dust.angle_max = 360.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.08
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(0.3, 0.8))
	sc.add_point(Vector2(1, 1.0))
	dust.scale_amount_curve = sc
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.4
	var dg := Gradient.new()
	dg.set_color(0, dust_col)
	dg.set_color(1, Color(dust_col.r, dust_col.g, dust_col.b, 0.0))
	dg.add_point(0.15, dust_col)
	dust.color_ramp = dg
	var dq := QuadMesh.new()
	dq.size = Vector2(0.7, 0.7)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = _soft_tex()
	dm.vertex_color_use_as_albedo = true
	dm.vertex_color_is_srgb = true      # dust_col is authored in sRGB
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.billboard_keep_scale = true
	dm.roughness = 1.0
	dm.shadow_to_opacity = false
	dm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	dm.proximity_fade_enabled = true
	dm.proximity_fade_distance = 0.25
	dq.material = dm
	dust.mesh = dq
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	dust.emitting = true
	if kind == "metal":
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.75, 0.4)
		flash.light_energy = 3.0
		flash.omni_range = 2.5
		add_child(flash)
		var tw := create_tween()
		tw.tween_property(flash, "light_energy", 0.0, 0.12)
	get_tree().create_timer(2.0, false).timeout.connect(queue_free)

static func _soft_tex() -> Texture2D:
	if _dust_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_dust_tex = t
	return _dust_tex
