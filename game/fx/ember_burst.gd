class_name EmberBurst
extends Node3D
## A spit of fire out of a split armour seam (a boss's growth moment): a tight jet of white-hot
## sparks that cool to orange and red as they fly and fall, a few slower glowing flakes that
## drift up on the heat, a puff of dark smoke and a short orange flash on the plate round it.
## Frees itself when done. `power` ~1 for a seam on a soldier-sized body; the knight passes its
## size so the jet stays in proportion as it grows.

static var _spark_tex: Texture2D
static var _smoke_tex: Texture2D

static func spawn(parent: Node, pos: Vector3, dir: Vector3, power: float) -> EmberBurst:
	var fx := EmberBurst.new()
	fx.name = "EmberBurst"
	parent.add_child(fx)
	fx.global_position = pos
	fx._build(dir.normalized() if dir.length() > 1e-3 else Vector3.UP, power)
	return fx

func _build(dir: Vector3, power: float) -> void:
	var p := maxf(power, 0.3)
	# the jet: fast, short-lived sparks streaked along their flight (velocity-aligned quads)
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = int(clampf(16.0 * sqrt(p), 10.0, 40.0))
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 0.85
	sparks.local_coords = false
	sparks.direction = dir
	sparks.spread = 28.0
	# a short hot spit, not a fountain: a bigger body throws a little farther, not 2x as far
	sparks.initial_velocity_min = 1.4 * pow(p, 0.35)
	sparks.initial_velocity_max = 3.8 * pow(p, 0.35)
	sparks.gravity = Vector3(0, -7.0, 0)
	sparks.damping_min = 2.0
	sparks.damping_max = 4.0
	sparks.particle_flag_align_y = true
	sparks.scale_amount_min = 0.6 * pow(p, 0.35)
	sparks.scale_amount_max = 1.2 * pow(p, 0.35)
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.1))
	sparks.scale_amount_curve = sc
	sparks.color_ramp = _ramp([Color(1.0, 0.78, 0.42, 1.0), Color(1.0, 0.42, 0.08, 1.0), Color(0.6, 0.1, 0.02, 0.0)])
	var sq := QuadMesh.new()
	sq.size = Vector2(0.02, 0.09)
	sq.material = _glow_mat(2.2)
	sparks.mesh = sq
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)
	sparks.emitting = true
	# flakes: slow glowing cinders lifted on the heat, tumbling, going out
	var flakes := CPUParticles3D.new()
	flakes.name = "Flakes"
	flakes.amount = int(clampf(10.0 * sqrt(p), 6.0, 28.0))
	flakes.lifetime = 2.2
	flakes.one_shot = true
	flakes.explosiveness = 0.6
	flakes.local_coords = false
	flakes.direction = (dir + Vector3.UP).normalized()
	flakes.spread = 50.0
	flakes.initial_velocity_min = 0.4 * sqrt(p)
	flakes.initial_velocity_max = 1.6 * sqrt(p)
	flakes.gravity = Vector3(0, 0.6, 0)
	flakes.damping_min = 0.6
	flakes.damping_max = 1.2
	flakes.angular_velocity_min = -180.0
	flakes.angular_velocity_max = 180.0
	flakes.scale_amount_min = 0.6 * sqrt(p)
	flakes.scale_amount_max = 1.3 * sqrt(p)
	flakes.color_ramp = _ramp([Color(1.0, 0.7, 0.3, 1.0), Color(1.0, 0.3, 0.05, 0.9), Color(0.25, 0.05, 0.02, 0.0)])
	var fq := QuadMesh.new()
	fq.size = Vector2(0.035, 0.035)
	fq.material = _glow_mat(1.8)
	flakes.mesh = fq
	flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flakes)
	flakes.emitting = true
	# smoke: a dark breath pushed out of the seam that rises and spreads
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 6
	smoke.lifetime = 1.6
	smoke.one_shot = true
	smoke.explosiveness = 0.7
	smoke.local_coords = false
	smoke.direction = (dir * 0.6 + Vector3.UP).normalized()
	smoke.spread = 30.0
	smoke.initial_velocity_min = 0.3 * sqrt(p)
	smoke.initial_velocity_max = 0.9 * sqrt(p)
	smoke.gravity = Vector3(0, 0.8, 0)
	smoke.damping_min = 0.8
	smoke.damping_max = 1.4
	smoke.scale_amount_min = 0.7 * sqrt(p)
	smoke.scale_amount_max = 1.2 * sqrt(p)
	var ssc := Curve.new()
	ssc.add_point(Vector2(0, 0.35))
	ssc.add_point(Vector2(1, 1.0))
	smoke.scale_amount_curve = ssc
	smoke.color_ramp = _ramp([Color(0.12, 0.09, 0.08, 0.0), Color(0.10, 0.08, 0.07, 0.4), Color(0.16, 0.15, 0.14, 0.0)])
	var mq := QuadMesh.new()
	mq.size = Vector2(0.5, 0.5)
	var mm := StandardMaterial3D.new()
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_texture = _smoke()
	mm.vertex_color_use_as_albedo = true
	mm.vertex_color_is_srgb = true
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.billboard_keep_scale = true
	mm.roughness = 1.0
	mm.metallic_specular = 0.0
	mm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mm.proximity_fade_enabled = true
	mm.proximity_fade_distance = 0.2
	mq.material = mm
	smoke.mesh = mq
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	smoke.emitting = true
	# the flash on the plate round the seam
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.45, 0.12)
	flash.light_energy = 2.2
	flash.omni_range = 1.4 * sqrt(p)
	flash.shadow_enabled = false
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.35)
	get_tree().create_timer(2.4, false).timeout.connect(queue_free)

static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[cols.size() - 1])
	for i in range(1, cols.size() - 1):
		g.add_point(float(i) / (cols.size() - 1), cols[i])
	return g

## Unshaded, additive, HDR-bright (glow picks it up) and coloured by the particle ramp.
static func _glow_mat(energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = _spark()
	m.albedo_color = Color(energy, energy, energy, 1.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m

static func _spark() -> Texture2D:
	if _spark_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.3, Color(1, 1, 1, 0.8))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_spark_tex = t
	return _spark_tex

static func _smoke() -> Texture2D:
	if _smoke_tex == null:
		_smoke_tex = ImpactFX._clump_tex(true)
	return _smoke_tex
