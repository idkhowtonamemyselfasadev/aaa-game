class_name ImpactFX
extends Node3D
## One-shot hit burst at a contact point: flying chaff/splinters thrown along the swing,
## a dust puff that blooms and settles, and (on metal) a spark spray with a brief flash.
## Frees itself when done.

static var _dust_tex: Texture2D
static var _crumb_tex: Texture2D
static var _haze_tex: Texture2D
## how many bursts of each kind have been spawned (bots read it)
static var spawned := {}

static func spawn(parent: Node, pos: Vector3, swing_dir: Vector3, kind: String, power: float) -> ImpactFX:
	var fx := ImpactFX.new()
	fx.name = "Impact"
	parent.add_child(fx)
	fx.global_position = pos
	fx._build(swing_dir.normalized(), kind, power)
	spawned[kind] = int(spawned.get(kind, 0)) + 1
	return fx

func _build(dir: Vector3, kind: String, power: float) -> void:
	var chaff_col := Color(0.62, 0.50, 0.29)
	var dust_col := Color(0.5, 0.44, 0.34, 0.5)
	if kind == "wood":
		chaff_col = Color(0.40, 0.33, 0.24)
	elif kind == "pierce":
		# an arrow driven into cloth and flesh: a few dark threads and splinters, a faint grey breath
		chaff_col = Color(0.16, 0.13, 0.10)
		dust_col = Color(0.30, 0.28, 0.25, 0.22)
	elif kind == "stone":
		chaff_col = Color(0.42, 0.41, 0.38)
		dust_col = Color(0.55, 0.54, 0.50, 0.45)
	elif kind == "dirt":
		# a body thrown down: torn grass bits and a broad, low cloud of dry soil
		chaff_col = Color(0.45, 0.42, 0.26)
		dust_col = Color(0.47, 0.41, 0.31, 0.55)
	elif kind == "turf":
		# a blade buried in the meadow: dark moist soil clods (not the pale chaff of a body
		# thrown down) and a thin, shaded haze of fine soil that hugs the ground
		chaff_col = Color(0.20, 0.15, 0.10)
		dust_col = Color(0.33, 0.29, 0.23, 0.30)
	if kind == "ash":
		# a boss bursting its armour: charred flakes and a dark breath of ash round the body
		chaff_col = Color(0.11, 0.09, 0.08)
		dust_col = Color(0.14, 0.12, 0.11, 0.75)
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
	if kind == "turf":
		chaff.amount = int(22 * power)
		chaff.direction = (dir * 0.5 + Vector3.UP).normalized()
		chaff.spread = 45.0
		chaff.initial_velocity_min = 1.2 * power
		chaff.initial_velocity_max = 3.0 * power
		chaff.scale_amount_min = 0.7
		chaff.scale_amount_max = 1.8
	if kind == "dirt":
		chaff.amount = int(18 * power)
		chaff.direction = Vector3.UP
		chaff.spread = 60.0
		chaff.initial_velocity_min = 0.8 * power
		chaff.initial_velocity_max = 2.6 * power
	if kind == "pierce":
		chaff.amount = int(16 * power) + 2
		chaff.spread = 25.0
		chaff.initial_velocity_min = 0.8 * power
		chaff.initial_velocity_max = 2.4 * power
	if kind == "ash":
		# flakes, not chips: capped speed so a giant's burst hangs round it instead of
		# fountaining 15 m up, thrown out all round, drifting down slowly
		chaff.amount = int(clampf(26.0 * power, 20.0, 90.0))
		chaff.lifetime = 2.2
		chaff.direction = Vector3.UP
		chaff.spread = 80.0
		chaff.initial_velocity_min = 0.8
		chaff.initial_velocity_max = minf(2.2 * sqrt(power), 5.5)
		chaff.emission_sphere_radius = 0.35 * power
	chaff.gravity = Vector3(0, -2.2 if kind == "ash" else -7.5, 0)
	chaff.damping_min = 1.5
	chaff.damping_max = 3.0
	chaff.angular_velocity_min = -720.0
	chaff.angular_velocity_max = 720.0
	chaff.angle_min = 0.0
	chaff.angle_max = 360.0
	if kind == "pierce":
		chaff.scale_amount_min = 0.4
		chaff.scale_amount_max = 0.9
	elif kind != "turf":
		chaff.scale_amount_min = 0.5
		chaff.scale_amount_max = 1.3
	chaff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	if kind != "ash":
		chaff.emission_sphere_radius = 0.06
	chaff.particle_flag_rotate_y = false
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.05) if kind == "ash" else (Vector2(0.12, 0.013) if kind == "straw" else (Vector2(0.04, 0.034) if kind == "turf" else Vector2(0.03, 0.012)))
	var cm := StandardMaterial3D.new()
	cm.albedo_color = chaff_col
	cm.roughness = 0.8
	if kind == "pierce":
		cm.vertex_color_is_srgb = true
		cm.metallic_specular = 0.1
	if kind == "turf" or kind == "ash":
		# ragged soil crumbs / charred flakes: an alpha-scissored lumpy blot instead of a sliver
		cm.albedo_texture = _clump_tex()
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		cm.alpha_scissor_threshold = 0.5
		cm.roughness = 0.95
		cm.metallic_specular = 0.2
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cm.billboard_keep_scale = true
	cm.vertex_color_use_as_albedo = true
	q.material = cm
	chaff.mesh = q
	var cg := Gradient.new()
	cg.set_color(0, Color(1.0, 1.0, 1.0) if kind in ["turf", "pierce", "ash"] else Color(1.1, 1.05, 1.0))
	cg.set_color(1, Color(0.55, 0.62, 0.45) if kind == "turf" else (Color(0.7, 0.66, 0.62) if kind == "ash" else (Color(0.8, 0.8, 0.8) if kind == "pierce" else Color(0.7, 0.68, 0.62))))  # some crumbs keep a grass tint
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
	if kind == "dirt":
		# rolls out along the ground from under the body rather than bursting up
		dust.amount += 8
		dust.direction = Vector3.UP
		dust.spread = 90.0
		dust.flatness = 0.75
		dust.initial_velocity_max = 2.2 * power
		dust.emission_sphere_radius = 0.35
	elif kind == "pierce":
		# a small, quick grey breath at the wound, never a bright puff
		dust.amount = 3
		dust.lifetime = 0.6
		dust.initial_velocity_max = 0.5
		dust.emission_sphere_radius = 0.04
	elif kind == "ash":
		# a dark rolling breath round the body, slow, rising a little on the heat
		dust.amount = int(clampf(8.0 * power, 10.0, 32.0))
		dust.lifetime = 2.0
		dust.direction = Vector3.UP
		dust.spread = 90.0
		dust.flatness = 0.4
		dust.initial_velocity_min = 0.5
		dust.initial_velocity_max = minf(1.2 * sqrt(power), 3.0)
		dust.gravity = Vector3(0, 0.25, 0)
		dust.emission_sphere_radius = 0.4 * power
	elif kind == "turf":
		# a low haze that creeps out from the cut and settles, never a bright puff
		# kept low and short so the buried bit still shows through it
		dust.amount = int(6 * power) + 3
		dust.lifetime = 0.9
		dust.direction = (dir * 0.6 + Vector3.UP * 0.25).normalized()
		dust.spread = 70.0
		dust.flatness = 0.85
		dust.initial_velocity_max = 0.9 * power
		dust.gravity = Vector3(0, -0.6, 0)
		dust.emission_sphere_radius = 0.15
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
	dq.size = Vector2(0.65, 0.65) * power if kind == "ash" else (Vector2(0.45, 0.45) if kind == "turf" else (Vector2(0.25, 0.25) if kind == "pierce" else Vector2(0.7, 0.7)))
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = _soft_tex()
	dm.vertex_color_use_as_albedo = true
	dm.vertex_color_is_srgb = true      # dust_col is authored in sRGB
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.billboard_keep_scale = true
	dm.roughness = 1.0
	# no specular sheen: a billboard facing the lens catches the sun's highlight as a flat glow
	dm.metallic_specular = 0.0
	if kind == "turf" or kind == "dirt" or kind == "ash":
		# light the haze as a soft volume (half-lambert-ish via backlight) and break its edge up
		dm.albedo_texture = _clump_tex(true)
		dm.backlight_enabled = true
		dm.backlight = Color(0.25, 0.22, 0.18)
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

## A lumpy blot: radial falloff broken up by value noise. soft=true gives a feathered
## smoke puff (for dust), false a hard-edged crumb mask (for alpha-scissored clods).
static func _clump_tex(soft := false) -> Texture2D:
	if not soft and _crumb_tex != null:
		return _crumb_tex
	if soft and _haze_tex != null:
		return _haze_tex
	var n := FastNoiseLite.new()
	n.seed = 7 if soft else 3
	n.frequency = 0.09 if soft else 0.16
	n.fractal_octaves = 3
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var d := Vector2(x - sz * 0.5 + 0.5, y - sz * 0.5 + 0.5).length() / (sz * 0.5)
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a: float
			if soft:
				a = clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (0.45 + 0.75 * v)
			else:
				a = 1.0 if d < 0.55 + 0.45 * (v - 0.5) * 2.0 * 0.6 else 0.0
			var shade := 0.85 + 0.3 * v
			img.set_pixel(x, y, Color(shade, shade, shade, clampf(a, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	if soft:
		_haze_tex = t
	else:
		_crumb_tex = t
	return t

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
