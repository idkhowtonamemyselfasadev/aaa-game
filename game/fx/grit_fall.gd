class_name GritFall
extends Node3D
## Grit and dust shaken loose from the top of a standing stone when the ground heaves: a trickle
## of dark crumbs dropping straight down the face, and a pale curtain of fine dust streaming
## after them that slows, spreads and drifts off as it nears the turf. Frees itself when done.
## `width` is roughly the stone's width; `drop` the height it falls (sets the dust's lifetime).

static func spawn(parent: Node, top: Vector3, width: float, drop: float) -> GritFall:
	var fx := GritFall.new()
	fx.name = "GritFall"
	parent.add_child(fx)
	fx.global_position = top
	fx._build(maxf(width, 0.4), maxf(drop, 1.0))
	return fx

func _build(width: float, drop: float) -> void:
	var fall_t := sqrt(2.0 * drop / 9.8)
	# crumbs: small stone chips, lit, dropping freely
	var crumbs := CPUParticles3D.new()
	crumbs.name = "Crumbs"
	crumbs.amount = 18
	crumbs.lifetime = fall_t + 0.2
	crumbs.one_shot = true
	crumbs.explosiveness = 0.35     # a spill over ~half a second, not a single pop
	crumbs.local_coords = false
	crumbs.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	crumbs.emission_box_extents = Vector3(width * 0.4, 0.05, width * 0.25)
	crumbs.direction = Vector3.DOWN
	crumbs.spread = 12.0
	crumbs.initial_velocity_min = 0.0
	crumbs.initial_velocity_max = 0.6
	crumbs.gravity = Vector3(0, -9.8, 0)
	crumbs.angular_velocity_min = -360.0
	crumbs.angular_velocity_max = 360.0
	crumbs.scale_amount_min = 0.5
	crumbs.scale_amount_max = 1.4
	var cq := QuadMesh.new()
	cq.size = Vector2(0.05, 0.05)
	var cm := StandardMaterial3D.new()
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cm.alpha_scissor_threshold = 0.5
	cm.albedo_texture = ImpactFX._clump_tex(false)
	cm.albedo_color = Color(0.30, 0.29, 0.26)
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cm.billboard_keep_scale = true
	cm.roughness = 1.0
	cq.material = cm
	crumbs.mesh = cq
	crumbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crumbs)
	crumbs.emitting = true
	# dust curtain: soft puffs that fall, drag to a hang and spread out low
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 14
	dust.lifetime = fall_t * 1.6 + 1.2
	dust.one_shot = true
	dust.explosiveness = 0.3
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(width * 0.45, 0.1, width * 0.3)
	dust.direction = Vector3.DOWN
	dust.spread = 18.0
	dust.initial_velocity_min = 0.5
	dust.initial_velocity_max = 1.5
	dust.gravity = Vector3(0, -5.0, 0)
	dust.damping_min = 1.6
	dust.damping_max = 2.6
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, 1.0))
	dust.scale_amount_curve = sc
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.5
	var dg := Gradient.new()
	var col := Color(0.58, 0.55, 0.50)
	dg.set_color(0, Color(col.r, col.g, col.b, 0.0))
	dg.add_point(0.12, Color(col.r, col.g, col.b, 0.32))
	dg.set_color(1, Color(col.r, col.g, col.b, 0.0))
	dust.color_ramp = dg
	var dq := QuadMesh.new()
	dq.size = Vector2(0.9, 0.9)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = ImpactFX._clump_tex(true)
	dm.vertex_color_use_as_albedo = true
	dm.vertex_color_is_srgb = true
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.billboard_keep_scale = true
	dm.roughness = 1.0
	dm.metallic_specular = 0.0
	dm.backlight_enabled = true
	dm.backlight = Color(0.25, 0.23, 0.2)
	dm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	dm.proximity_fade_enabled = true
	dm.proximity_fade_distance = 0.3
	dq.material = dm
	dust.mesh = dq
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	dust.emitting = true
	get_tree().create_timer(dust.lifetime + 0.8, false).timeout.connect(queue_free)
